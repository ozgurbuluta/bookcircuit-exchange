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

      return items.map((item) {
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
      }).where((book) => book.title.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }
}
