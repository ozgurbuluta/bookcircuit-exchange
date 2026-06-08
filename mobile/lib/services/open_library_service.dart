import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenLibraryBook {
  final String title;
  final String? author;
  final String? isbn;
  final String? description;
  final String? coverUrl;
  final int? publishYear;

  OpenLibraryBook({
    required this.title,
    this.author,
    this.isbn,
    this.description,
    this.coverUrl,
    this.publishYear,
  });
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';

  static Future<List<OpenLibraryBook>> searchBooks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search.json?q=${Uri.encodeComponent(query)}&limit=10'),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      final docs = data['docs'] as List<dynamic>? ?? [];

      final books = <OpenLibraryBook>[];

      for (final doc in docs) {
        String? author;
        if (doc['author_name'] != null && (doc['author_name'] as List).isNotEmpty) {
          author = doc['author_name'][0];
        }

        String? isbn;
        if (doc['isbn'] != null && (doc['isbn'] as List).isNotEmpty) {
          isbn = doc['isbn'][0];
        }

        String? coverUrl;
        if (doc['cover_i'] != null) {
          coverUrl = 'https://covers.openlibrary.org/b/id/${doc['cover_i']}-M.jpg';
        }

        int? publishYear;
        if (doc['first_publish_year'] != null) {
          publishYear = doc['first_publish_year'];
        }

        books.add(OpenLibraryBook(
          title: doc['title'] ?? '',
          author: author,
          isbn: isbn,
          coverUrl: coverUrl,
          publishYear: publishYear,
        ));
      }

      // Fetch descriptions for the first few books
      for (int i = 0; i < books.length && i < 5; i++) {
        final doc = docs[i];
        if (doc['key'] != null) {
          try {
            final workResponse = await http.get(
              Uri.parse('$_baseUrl${doc['key']}.json'),
            );
            if (workResponse.statusCode == 200) {
              final workData = json.decode(workResponse.body);
              String? description;
              if (workData['description'] != null) {
                if (workData['description'] is String) {
                  description = workData['description'];
                } else if (workData['description'] is Map && workData['description']['value'] != null) {
                  description = workData['description']['value'];
                }
              }
              if (description != null) {
                books[i] = OpenLibraryBook(
                  title: books[i].title,
                  author: books[i].author,
                  isbn: books[i].isbn,
                  description: description,
                  coverUrl: books[i].coverUrl,
                  publishYear: books[i].publishYear,
                );
              }
            }
          } catch (_) {
            // Ignore description fetch errors
          }
        }
      }

      return books;
    } catch (e) {
      return [];
    }
  }
}
