import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
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

/// Books search results provider
final booksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final params = ref.watch(bookSearchParamsProvider);

  if (params.hasLocation) {
    return SupabaseService.getBooksWithinDistance(
      lat: params.lat!,
      lng: params.lng!,
      maxDistanceMeters: params.radius * 1000, // km to meters
      query: params.query,
      genre: params.genre,
    );
  }

  return SupabaseService.getBooks(
    query: params.query,
    genre: params.genre,
  );
});

/// Single book provider
final bookProvider =
    FutureProvider.autoDispose.family<Book?, String>((ref, bookId) async {
  return SupabaseService.getBook(bookId);
});

/// My books provider
final myBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  return SupabaseService.getMyBooks();
});

/// User's books provider
final userBooksProvider =
    FutureProvider.autoDispose.family<List<Book>, String>((ref, userId) async {
  return SupabaseService.getUserBooks(userId);
});

/// Book interest state provider
final bookInterestProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, bookId) async {
  return SupabaseService.isInterestedInBook(bookId);
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
      final created = await SupabaseService.createBook(book);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update a book
  Future<Book?> updateBook(Book book) async {
    state = const AsyncValue.loading();
    try {
      final updated = await SupabaseService.updateBook(book);
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
      await SupabaseService.deleteBook(bookId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Toggle interest in a book
  Future<bool> toggleInterest(String bookId) async {
    try {
      return await SupabaseService.toggleBookInterest(bookId);
    } catch (e) {
      return false;
    }
  }
}

final bookActionsProvider =
    StateNotifierProvider<BookActionsNotifier, AsyncValue<void>>((ref) {
  return BookActionsNotifier();
});
