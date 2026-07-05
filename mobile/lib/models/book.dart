import 'firestore_helpers.dart';
import 'profile.dart';

/// Book condition — the 4 spec values (spec §3).
enum BookCondition {
  likeNew('like_new', 'Like new'),
  veryGood('very_good', 'Very good'),
  good('good', 'Good'),
  wellRead('well_read', 'Well read');

  final String value;
  final String displayName;
  const BookCondition(this.value, this.displayName);

  /// Parses spec values plus the legacy 6-value display names
  /// (plan §3 migration table). Unknown values fall back to [good].
  static BookCondition fromString(String? raw) {
    if (raw == null) return BookCondition.good;
    for (final c in BookCondition.values) {
      if (c.value == raw || c.displayName == raw) return c;
    }
    switch (raw) {
      case 'New':
      case 'newBook':
      case 'Like New':
      case 'likeNew':
        return BookCondition.likeNew;
      case 'Very Good':
      case 'veryGood':
        return BookCondition.veryGood;
      case 'Acceptable':
      case 'acceptable':
        return BookCondition.good;
      case 'Poor':
      case 'poor':
        return BookCondition.wellRead;
      default:
        return BookCondition.good;
    }
  }
}

/// Book status — the 3 spec values (spec §3).
enum BookStatus {
  onShelf('on_shelf'),
  inTrade('in_trade'),
  tradedAway('traded_away');

  final String value;
  const BookStatus(this.value);

  static BookStatus fromString(String? raw) {
    if (raw == null) return BookStatus.onShelf;
    for (final s in BookStatus.values) {
      if (s.value == raw || s.name == raw) return s;
    }
    // Legacy statuses
    switch (raw) {
      case 'available':
        return BookStatus.onShelf;
      case 'requested':
      case 'trading':
        return BookStatus.inTrade;
      case 'completed':
        return BookStatus.tradedAway;
      default:
        return BookStatus.onShelf;
    }
  }
}

/// How the book entered the shelf (spec §3).
enum BookSource {
  scan('scan'),
  manual('manual');

  final String value;
  const BookSource(this.value);

  static BookSource fromString(String? raw) =>
      raw == 'scan' ? BookSource.scan : BookSource.manual;
}

/// Book model (spec §3).
///
/// Covers are generated placeholders in v1 — [coverColorKey] picks the
/// colorway; [coverImgUrl] is reserved for v2 photos.
class Book {
  final String id;
  final String ownerId;
  final String title;
  final String author;
  final int? year;
  final int? pages;
  final String? publisher;
  final String? isbn;
  final String? language;
  final BookCondition condition;

  /// Owner can hide a book without removing it (spec §6).
  final bool visible;
  final BookStatus status;
  final BookSource source;

  /// Denormalized count of pending requests — feeds "Most loved this month".
  final int requestCount;

  /// Location derived from the owner's postal centroid (never GPS).
  final String? postalCode;
  final double? locationLat;
  final double? locationLng;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hydrated owner profile (not serialized).
  final Profile? owner;

  /// Search-time distance annotation (not serialized).
  final double? distanceKm;

  // -------------------------------------------------------------------------
  // Legacy fields — kept so pre-redesign screens compile until Phase L.
  // -------------------------------------------------------------------------
  @Deprecated('Removed by the v1 redesign')
  final String? description;
  @Deprecated('Removed by the v1 redesign')
  final List<String>? genres;
  @Deprecated('Photos are v2 — covers are generated placeholders')
  final String? coverImgUrl;
  @Deprecated('Use areaLabel via owner')
  final String? locationText;

  Book({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.author,
    this.year,
    this.pages,
    this.publisher,
    this.isbn,
    this.language,
    required this.condition,
    this.visible = true,
    this.status = BookStatus.onShelf,
    this.source = BookSource.manual,
    this.requestCount = 0,
    this.postalCode,
    this.locationLat,
    this.locationLng,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
    this.distanceKm,
    @Deprecated('Removed by the v1 redesign') this.description,
    @Deprecated('Removed by the v1 redesign') this.genres,
    @Deprecated('Photos are v2') this.coverImgUrl,
    @Deprecated('Use areaLabel via owner') this.locationText,
  });

  @Deprecated('Use ownerId')
  String get userId => ownerId;

  /// A book can be requested only while visible and on the shelf (spec §4.6).
  bool get isRequestable => visible && status == BookStatus.onShelf;

  /// Stable placeholder-cover colorway from the 7-color palette.
  String get coverColorKey {
    const colors = [
      'honey', 'plum', 'slate', 'deepGreen', 'forest', 'terracotta', 'brick'
    ];
    final hash = title.hashCode.abs();
    return colors[hash % colors.length];
  }

  String? get distanceDisplay {
    if (distanceKm == null) return null;
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  factory Book.fromFirestore(Map<String, dynamic> data, String id) {
    return Book(
      id: id,
      ownerId: data['ownerId'] as String? ?? data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      year: (data['year'] as num?)?.toInt() ??
          (data['publicationYear'] as num?)?.toInt(),
      pages: (data['pages'] as num?)?.toInt(),
      publisher: data['publisher'] as String?,
      isbn: data['isbn'] as String?,
      language: data['language'] as String?,
      condition: BookCondition.fromString(data['condition'] as String?),
      visible: data['visible'] as bool? ?? true,
      status: BookStatus.fromString(data['status'] as String?),
      source: BookSource.fromString(data['source'] as String?),
      requestCount: (data['requestCount'] as num?)?.toInt() ?? 0,
      postalCode: data['postalCode'] as String?,
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      createdAt: dateFromFirestore(data['createdAt']) ?? DateTime.now(),
      updatedAt: dateFromFirestore(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'author': author,
      'year': year,
      'pages': pages,
      'publisher': publisher,
      'isbn': isbn,
      'language': language,
      'condition': condition.value,
      'visible': visible,
      'status': status.value,
      'source': source.value,
      'requestCount': requestCount,
      'postalCode': postalCode,
      'locationLat': locationLat,
      'locationLng': locationLng,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Book copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? author,
    int? year,
    int? pages,
    String? publisher,
    String? isbn,
    String? language,
    BookCondition? condition,
    bool? visible,
    BookStatus? status,
    BookSource? source,
    int? requestCount,
    String? postalCode,
    double? locationLat,
    double? locationLng,
    DateTime? createdAt,
    DateTime? updatedAt,
    Profile? owner,
    double? distanceKm,
  }) {
    return Book(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      author: author ?? this.author,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      publisher: publisher ?? this.publisher,
      isbn: isbn ?? this.isbn,
      language: language ?? this.language,
      condition: condition ?? this.condition,
      visible: visible ?? this.visible,
      status: status ?? this.status,
      source: source ?? this.source,
      requestCount: requestCount ?? this.requestCount,
      postalCode: postalCode ?? this.postalCode,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
      distanceKm: distanceKm ?? this.distanceKm,
      // ignore: deprecated_member_use_from_same_package
      description: description,
      // ignore: deprecated_member_use_from_same_package
      genres: genres,
      // ignore: deprecated_member_use_from_same_package
      coverImgUrl: coverImgUrl,
      // ignore: deprecated_member_use_from_same_package
      locationText: locationText,
    );
  }
}
