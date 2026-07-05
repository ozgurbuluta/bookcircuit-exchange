import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../utils/geo_search.dart';
import '../utils/geohash.dart';
import 'auth_provider.dart';

/// Search parameters (spec §7): centered on the user's postal centroid,
/// 1 km default radius, optional text query and language filter.
class BookSearchParams {
  final String? query;
  final String? language;
  final double radius;

  const BookSearchParams({
    this.query,
    this.language,
    this.radius = Env.defaultSearchRadius,
  });

  BookSearchParams copyWith({
    String? query,
    String? language,
    double? radius,
    bool clearLanguage = false,
  }) {
    return BookSearchParams(
      query: query ?? this.query,
      language: clearLanguage ? null : (language ?? this.language),
      radius: radius ?? this.radius,
    );
  }
}

/// Search params provider
final bookSearchParamsProvider =
    StateProvider<BookSearchParams>((ref) => const BookSearchParams());

/// Raw neighborhood pool: requestable books in the geohash cells covering the
/// user's search radius. Distance filtering happens client-side on top.
final nearbyPoolProvider = FutureProvider<List<Book>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final params = ref.watch(bookSearchParamsProvider);

  final lat = profile?.centroidLat;
  final lng = profile?.centroidLng;
  if (lat == null || lng == null) return const [];

  final precision = Geohash.precisionForRadiusKm(params.radius);
  final centerCell = Geohash.encode(lat, lng, precision: precision);
  final cells = Geohash.neighborsOf(centerCell);

  return FirebaseService.getBooksByGeohashCells(cells);
});

/// Books search results: distance-filtered, own books excluded, nearest first.
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final profile = ref.watch(currentProfileProvider);
  final params = ref.watch(bookSearchParamsProvider);
  final pool = await ref.watch(nearbyPoolProvider.future);

  final lat = profile?.centroidLat;
  final lng = profile?.centroidLng;
  if (lat == null || lng == null) return const [];

  return GeoSearch.nearby(
    books: pool,
    centerLat: lat,
    centerLng: lng,
    radiusKm: params.radius,
    excludeOwnerId: profile?.id,
    language: params.language,
    query: params.query,
  );
});

/// Count of books within the radius — the Home map teaser (mock #1a).
final nearbyCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(booksProvider).whenData((books) => books.length);
});

/// Language → count chips for the map view (mock #1b).
final languageCountsProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final profile = ref.watch(currentProfileProvider);
  final params = ref.watch(bookSearchParamsProvider);

  return ref.watch(nearbyPoolProvider).whenData((pool) {
    final lat = profile?.centroidLat;
    final lng = profile?.centroidLng;
    if (lat == null || lng == null) return const <String, int>{};
    // Counts ignore the language filter itself (they ARE the filter).
    final inRadius = GeoSearch.nearby(
      books: pool,
      centerLat: lat,
      centerLng: lng,
      radiusKm: params.radius,
      excludeOwnerId: profile?.id,
    );
    return GeoSearch.languageCounts(inRadius);
  });
});

/// "New nearby" section (spec §7).
final newNearbyProvider = Provider<AsyncValue<List<Book>>>((ref) {
  return ref.watch(booksProvider).whenData(GeoSearch.newNearby);
});

/// "Most loved this month" section (spec §7, by request count).
final mostLovedProvider = Provider<AsyncValue<List<Book>>>((ref) {
  return ref.watch(booksProvider).whenData(GeoSearch.mostLoved);
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
}

final bookActionsProvider =
    StateNotifierProvider<BookActionsNotifier, AsyncValue<void>>((ref) {
  return BookActionsNotifier();
});
