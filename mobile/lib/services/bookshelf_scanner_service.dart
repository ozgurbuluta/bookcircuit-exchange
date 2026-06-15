import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/detected_book.dart';
import 'google_books_service.dart';

/// Recognises books from a photo of a bookshelf / cabinet using Gemini (via
/// Firebase AI Logic), then enriches each detection with canonical metadata
/// from Google Books.
///
/// Pipeline:
///   1. Send the image to Gemini with a strict JSON [responseSchema].
///   2. Parse the structured `{title, author, confidence}` list.
///   3. For each detection, look up the best Google Books match to fill in the
///      cover, ISBN, year and description (concurrently).
class BookshelfScannerService {
  /// Gemini Flash: fast + cheap, and plenty accurate for reading spines.
  /// Swap to `gemini-2.5-pro` here if Flash ever misses books.
  static const String _modelName = 'gemini-2.5-flash';

  /// Safety cap so a huge bookcase photo doesn't produce an unwieldy batch.
  static const int maxBooks = 40;

  static final Schema _responseSchema = Schema.array(
    description: 'List of books visible in the photo.',
    items: Schema.object(
      properties: {
        'title': Schema.string(description: 'The full book title.'),
        'author': Schema.string(
          description: 'The primary author. Empty string if not legible.',
        ),
        'confidence': Schema.number(
          description: 'How confident you are, from 0 to 1.',
        ),
      },
      optionalProperties: ['author', 'confidence'],
    ),
  );

  static const String _prompt = '''
You are looking at a photograph of a bookshelf or book cabinet.
Identify every distinct physical book you can see, reading the spines and any visible covers.

Rules:
- Return one entry per physical book. Do not invent books that are not visible.
- Use your knowledge to complete a title/author even if the spine text is partially obscured, worn, or stylised, as long as you are confident which book it is.
- If you genuinely cannot read or identify a book, skip it rather than guessing wildly.
- Do NOT include non-book objects (decor, photo frames, magazines, DVDs).
- Provide the canonical published title and the primary author.
- Order the list roughly left-to-right, top-to-bottom.
''';

  /// Scan [imageBytes] (JPEG/PNG) and return the enriched detected books.
  ///
  /// Throws on hard failures (network/permission/AI errors) so the UI can show
  /// a retry. Returns an empty list when the model simply found no books.
  static Future<List<DetectedBook>> scanShelf(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _responseSchema,
        temperature: 0.1,
      ),
    );

    final response = await model.generateContent([
      Content.multi([
        TextPart(_prompt),
        InlineDataPart(mimeType, imageBytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) return [];

    final raw = _parseDetections(text);
    if (raw.isEmpty) return [];

    // Cap before enriching so we don't fire dozens of needless lookups.
    final limited = raw.take(maxBooks).toList();

    // Enrich all detections concurrently against Google Books.
    final enriched = await Future.wait(
      limited.map(_enrich),
      eagerError: false,
    );

    return enriched;
  }

  /// Parse the model's JSON array into bare detections.
  static List<_RawDetection> _parseDetections(String text) {
    try {
      final decoded = json.decode(text);
      if (decoded is! List) return [];

      final result = <_RawDetection>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final title = (item['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) continue;
        final author = (item['author'] as String?)?.trim() ?? '';
        final confidence = (item['confidence'] as num?)?.toDouble();
        result.add(_RawDetection(title: title, author: author, confidence: confidence));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Enrich a single detection with Google Books metadata.
  static Future<DetectedBook> _enrich(_RawDetection d) async {
    final match = await GoogleBooksService.findBestMatch(d.title, d.author);

    if (match == null) {
      // No catalogue match — keep what the model read.
      return DetectedBook(
        title: d.title,
        author: d.author,
        matched: false,
      );
    }

    return DetectedBook(
      title: match.title.isNotEmpty ? match.title : d.title,
      author: (match.author?.isNotEmpty ?? false) ? match.author! : d.author,
      isbn: match.isbn,
      description: match.description,
      coverUrl: match.coverUrl,
      publishYear: match.publishYear,
      publisher: match.publisher,
      pages: match.pageCount,
      matched: true,
    );
  }
}

class _RawDetection {
  final String title;
  final String author;
  final double? confidence;

  _RawDetection({required this.title, required this.author, this.confidence});
}
