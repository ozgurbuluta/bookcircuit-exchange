import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../config/env.dart';

/// Search parameters state
class BookSearchParams {
  final String? query;
  final String? genre;
  final double? lat;
  final double? lng;
  final double radius;

  const BookSearchParams({
    this.query,
    this.genre,
    this.lat,
    this.lng,
    this.radius = Env.defaultSearchRadius,
  });

  BookSearchParams copyWith({
    String? query,
    String? genre,
    double? lat,
    double? lng,
    double? radius,
  }) {
    return BookSearchParams(
      query: query ?? this.query,
      genre: genre ?? this.genre,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
    );
  }

  bool get hasLocation => lat != null && lng != null;
}

/// Search params provider
final bookSearchParamsProvider =
    StateProvider<BookSearchParams>((ref) => const BookSearchParams());

/// Calculate distance between two points (Haversine formula)
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth's radius in km
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

/// Books search results provider - cached to avoid refetching
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final params = ref.watch(bookSearchParamsProvider);

  var books = await FirebaseService.getBooks(
    query: params.query,
    genre: params.genre,
  );

  // Apply geographic filter if location is provided
  if (params.hasLocation) {
    books = books.where((book) {
      if (book.locationLat == null || book.locationLng == null) return false;

      final distance = _calculateDistance(
        params.lat!,
        params.lng!,
        book.locationLat!,
        book.locationLng!,
      );

      return distance <= params.radius;
    }).map((book) {
      final distance = _calculateDistance(
        params.lat!,
        params.lng!,
        book.locationLat!,
        book.locationLng!,
      );
      return book.copyWith(distanceKm: distance);
    }).toList();

    // Sort by distance
    books.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
  }

  return books;
});

/// Single book provider - keeps cache for faster navigation back
final bookProvider =
    FutureProvider.family<Book?, String>((ref, bookId) async {
  return FirebaseService.getBook(bookId);
});

/// My books provider - cached
final myBooksProvider = FutureProvider<List<Book>>((ref) async {
  return FirebaseService.getMyBooks();
});

/// User's books provider
final userBooksProvider =
    FutureProvider.family<List<Book>, String>((ref, userId) async {
  return FirebaseService.getUserBooks(userId);
});

/// Book interest state provider
final bookInterestProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, bookId) async {
  // TODO: Implement book interest tracking in Firebase
  return false;
});

/// Available genres
final genresProvider = Provider<List<String>>((ref) {
  return [
    'All',
    'Fiction',
    'Sci-Fi',
    'Memoir',
    'Historical',
    'Nature',
    'Fantasy',
    'Myth',
    'Contemporary',
    'Mystery',
    'Romance',
    'Thriller',
    'Biography',
    'Self-Help',
    'Poetry',
  ];
});

/// Book actions notifier
class BookActionsNotifier extends StateNotifier<AsyncValue<void>> {
  BookActionsNotifier() : super(const AsyncValue.data(null));

  /// Create a new book
  Future<Book?> createBook(Book book) async {
    state = const AsyncValue.loading();
    try {
      final created = await FirebaseService.createBook(book);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Create several books at once (shelf scanner). Returns the number created.
  Future<int> createBooks(List<Book> books) async {
    state = const AsyncValue.loading();
    try {
      final count = await FirebaseService.createBooks(books);
      state = const AsyncValue.data(null);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 0;
    }
  }

  /// Update a book
  Future<Book?> updateBook(Book book) async {
    state = const AsyncValue.loading();
    try {
      final updated = await FirebaseService.updateBook(book);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete a book
  Future<bool> deleteBook(String bookId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.deleteBook(bookId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Toggle interest in a book
  Future<bool> toggleInterest(String bookId) async {
    // TODO: Implement in Firebase
    return false;
  }
}

final bookActionsProvider =
    StateNotifierProvider<BookActionsNotifier, AsyncValue<void>>((ref) {
  return BookActionsNotifier();
});
