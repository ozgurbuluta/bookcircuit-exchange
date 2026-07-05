import 'dart:math';

import '../models/models.dart';

/// Pure search-domain logic (spec §7): postal-centroid radius filtering,
/// distance sort, own-book exclusion, language filtering and counts.
class GeoSearch {
  /// Great-circle distance in km (Haversine).
  static double haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Filters to requestable books within [radiusKm] of the centroid,
  /// annotates each with its distance, excludes the viewer's own books,
  /// optionally filters by language, and sorts nearest-first (spec §7).
  static List<Book> nearby({
    required List<Book> books,
    required double centerLat,
    required double centerLng,
    double radiusKm = 1.0,
    String? excludeOwnerId,
    String? language,
    String? query,
  }) {
    final q = query?.trim().toLowerCase();

    final results = books
        .where((b) => b.isRequestable)
        .where((b) => b.ownerId != excludeOwnerId)
        .where((b) => language == null || b.language == language)
        .where((b) =>
            q == null ||
            q.isEmpty ||
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .where((b) => b.locationLat != null && b.locationLng != null)
        .map((b) => b.copyWith(
              distanceKm: haversineKm(
                  centerLat, centerLng, b.locationLat!, b.locationLng!),
            ))
        .where((b) => b.distanceKm! <= radiusKm)
        .toList()
      ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));

    return results;
  }

  /// Language → count over a result set (map filter chips, mock #1b).
  static Map<String, int> languageCounts(List<Book> books) {
    final counts = <String, int>{};
    for (final book in books) {
      final lang = book.language;
      if (lang == null || lang.isEmpty) continue;
      counts[lang] = (counts[lang] ?? 0) + 1;
    }
    return counts;
  }

  /// "Most loved this month": most-requested books first (spec §7),
  /// request count breaking ties by recency.
  static List<Book> mostLoved(List<Book> books, {int limit = 5}) {
    final loved = books.where((b) => b.requestCount > 0).toList()
      ..sort((a, b) {
        final byRequests = b.requestCount.compareTo(a.requestCount);
        if (byRequests != 0) return byRequests;
        return b.createdAt.compareTo(a.createdAt);
      });
    return loved.take(limit).toList();
  }

  /// "New nearby": latest arrivals within the radius (spec §7).
  static List<Book> newNearby(List<Book> books, {int limit = 8}) {
    final sorted = [...books]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }
}
