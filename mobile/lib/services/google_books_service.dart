import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleBook {
  final String title;
  final String? author;
  final String? isbn;
  final String? description;
  final String? coverUrl;
  final int? publishYear;
  final String? publisher;
  final int? pageCount;

  GoogleBook({
    required this.title,
    this.author,
    this.isbn,
    this.description,
    this.coverUrl,
    this.publishYear,
    this.publisher,
    this.pageCount,
  });
}

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  /// Search books - fast and returns good quality data
  static Future<List<GoogleBook>> searchBooks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?q=${Uri.encodeComponent(query)}&maxResults=8&printType=books'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];

      return items
          .map((item) => _parseVolume(item as Map<String, dynamic>))
          .where((book) => book.title.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Find the single best-matching book for a [title]/[author] pair.
  ///
  /// Used by the bookshelf scanner to enrich an AI-detected book with a
  /// canonical cover, ISBN, year and description. Returns `null` when nothing
  /// usable is found so the caller can keep the raw detection.
  static Future<GoogleBook?> findBestMatch(String title, String? author) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return null;

    // Use Google Books' field-qualified search for precision, falling back to a
    // plain query if the qualified search returns nothing.
    final queries = <String>[
      if (author != null && author.trim().isNotEmpty)
        'intitle:$cleanTitle inauthor:${author.trim()}',
      'intitle:$cleanTitle',
      [cleanTitle, author?.trim() ?? ''].where((s) => s.isNotEmpty).join(' '),
    ];

    for (final q in queries) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl?q=${Uri.encodeComponent(q)}&maxResults=3&printType=books'),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        if (items.isEmpty) continue;

        final book = _parseVolume(items.first as Map<String, dynamic>);
        if (book.title.isNotEmpty) return book;
      } catch (_) {
        // Try the next, less strict query.
      }
    }
    return null;
  }

  /// Parse a single Google Books `volume` item into a [GoogleBook].
  static GoogleBook _parseVolume(Map<String, dynamic> item) {
    final volumeInfo = item['volumeInfo'] as Map<String, dynamic>? ?? {};

    // Get authors
    String? author;
    final authors = volumeInfo['authors'] as List<dynamic>?;
    if (authors != null && authors.isNotEmpty) {
      author = authors.first as String;
    }

    // Get ISBN (prefer ISBN-13)
    String? isbn;
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers != null) {
      for (final id in identifiers) {
        if (id['type'] == 'ISBN_13') {
          isbn = id['identifier'];
          break;
        } else if (id['type'] == 'ISBN_10' && isbn == null) {
          isbn = id['identifier'];
        }
      }
    }

    // Get cover image (use larger size)
    String? coverUrl;
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    if (imageLinks != null) {
      // Prefer larger images, use HTTPS
      coverUrl = (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail']) as String?;
      if (coverUrl != null) {
        // Convert to HTTPS and get larger image
        coverUrl = coverUrl.replaceFirst('http://', 'https://');
        coverUrl = coverUrl.replaceFirst('zoom=1', 'zoom=2');
      }
    }

    // Get publish year
    int? publishYear;
    final publishedDate = volumeInfo['publishedDate'] as String?;
    if (publishedDate != null && publishedDate.length >= 4) {
      publishYear = int.tryParse(publishedDate.substring(0, 4));
    }

    return GoogleBook(
      title: volumeInfo['title'] ?? '',
      author: author,
      isbn: isbn,
      description: volumeInfo['description'],
      coverUrl: coverUrl,
      publishYear: publishYear,
      publisher: volumeInfo['publisher'],
      pageCount: volumeInfo['pageCount'],
    );
  }
}
