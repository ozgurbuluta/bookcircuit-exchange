import 'dart:convert';
import 'package:http/http.dart' as http;

/// A prefill candidate from Open Library (spec §6): everything the confirm
/// card (#1d) shows. Language and condition remain the user's call.
class OpenLibraryBook {
  final String title;
  final String? author;
  final String? isbn;
  final String? coverUrl;
  final int? publishYear;
  final int? pages;
  final String? publisher;

  const OpenLibraryBook({
    required this.title,
    this.author,
    this.isbn,
    this.coverUrl,
    this.publishYear,
    this.pages,
    this.publisher,
  });
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';

  final http.Client _client;

  OpenLibraryService({http.Client? client}) : _client = client ?? http.Client();

  /// Pure parser for the /search.json payload — unit-tested separately.
  static List<OpenLibraryBook> parseSearchResults(Map<String, dynamic> data) {
    final docs = data['docs'] as List<dynamic>? ?? const [];
    final books = <OpenLibraryBook>[];

    for (final rawDoc in docs) {
      if (rawDoc is! Map) continue;
      final doc = Map<String, dynamic>.from(rawDoc);
      final title = doc['title'] as String? ?? '';
      if (title.isEmpty) continue;

      final authors = doc['author_name'] as List<dynamic>?;
      final isbns = doc['isbn'] as List<dynamic>?;
      final publishers = doc['publisher'] as List<dynamic>?;

      books.add(OpenLibraryBook(
        title: title,
        author: authors != null && authors.isNotEmpty
            ? authors.first as String
            : null,
        isbn: isbns != null && isbns.isNotEmpty ? isbns.first as String : null,
        coverUrl: doc['cover_i'] != null
            ? 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-M.jpg'
            : null,
        publishYear: (doc['first_publish_year'] as num?)?.toInt(),
        pages: (doc['number_of_pages_median'] as num?)?.toInt(),
        publisher: publishers != null && publishers.isNotEmpty
            ? publishers.first as String
            : null,
      ));
    }

    return books;
  }

  /// Detects whether a query looks like an ISBN (10 or 13 digits, dashes ok).
  static bool looksLikeIsbn(String query) {
    final digits = query.replaceAll(RegExp(r'[- ]'), '');
    return RegExp(r'^\d{9}[\dXx]$|^\d{13}$').hasMatch(digits);
  }

  /// Searches by free text or ISBN.
  Future<List<OpenLibraryBook>> searchBooks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = looksLikeIsbn(q)
        ? Uri.parse(
            '$_baseUrl/search.json?isbn=${Uri.encodeComponent(q.replaceAll(RegExp(r'[- ]'), ''))}&limit=10')
        : Uri.parse('$_baseUrl/search.json?q=${Uri.encodeComponent(q)}&limit=10');

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return const [];
      return parseSearchResults(
          json.decode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return const [];
    }
  }
}
