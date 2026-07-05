import 'package:flutter_test/flutter_test.dart';
import 'package:turtle_turning_pages/services/open_library_service.dart';

void main() {
  group('OpenLibraryService.parseSearchResults', () {
    test('maps the fields the confirm card needs (mock #1d)', () {
      final books = OpenLibraryService.parseSearchResults({
        'docs': [
          {
            'title': 'Norwegian Wood',
            'author_name': ['Haruki Murakami'],
            'isbn': ['9780099448822'],
            'cover_i': 11153541,
            'first_publish_year': 1987,
            'number_of_pages_median': 296,
            'publisher': ['Vintage'],
          },
        ],
      });

      expect(books, hasLength(1));
      final book = books.first;
      expect(book.title, 'Norwegian Wood');
      expect(book.author, 'Haruki Murakami');
      expect(book.isbn, '9780099448822');
      expect(book.publishYear, 1987);
      expect(book.pages, 296);
      expect(book.publisher, 'Vintage');
      expect(book.coverUrl, contains('11153541'));
    });

    test('tolerates sparse docs and skips titleless entries', () {
      final books = OpenLibraryService.parseSearchResults({
        'docs': [
          {'title': 'Bare Minimum'},
          {'author_name': ['No Title']},
          {},
        ],
      });

      expect(books, hasLength(1));
      expect(books.first.title, 'Bare Minimum');
      expect(books.first.author, isNull);
      expect(books.first.pages, isNull);
    });

    test('empty payload yields empty list', () {
      expect(OpenLibraryService.parseSearchResults({}), isEmpty);
    });
  });

  group('OpenLibraryService.looksLikeIsbn', () {
    test('recognizes ISBN-10 and ISBN-13, with dashes', () {
      expect(OpenLibraryService.looksLikeIsbn('9780099448822'), isTrue);
      expect(OpenLibraryService.looksLikeIsbn('978-0-09-944882-2'), isTrue);
      expect(OpenLibraryService.looksLikeIsbn('0099448823'), isTrue);
      expect(OpenLibraryService.looksLikeIsbn('009944882X'), isTrue);
    });

    test('rejects titles', () {
      expect(OpenLibraryService.looksLikeIsbn('Norwegian Wood'), isFalse);
      expect(OpenLibraryService.looksLikeIsbn('1984'), isFalse);
    });
  });
}
