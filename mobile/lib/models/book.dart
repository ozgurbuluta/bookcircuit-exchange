import 'profile.dart';

/// Book condition enum
enum BookCondition {
  newBook('New'),
  likeNew('Like New'),
  veryGood('Very Good'),
  good('Good'),
  acceptable('Acceptable'),
  poor('Poor');

  final String displayName;
  const BookCondition(this.displayName);

  static BookCondition fromString(String value) {
    return BookCondition.values.firstWhere(
      (c) => c.displayName.toLowerCase() == value.toLowerCase(),
      orElse: () => BookCondition.good,
    );
  }
}

/// Book status enum
enum BookStatus {
  available,
  requested,
  trading,
  completed;

  static BookStatus fromString(String value) {
    return BookStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BookStatus.available,
    );
  }
}

/// Book model
class Book {
  final String id;
  final String userId;
  final String title;
  final String author;
  final String? description;
  final BookCondition condition;
  final String? isbn;
  final String? coverImgUrl;
  final String? publisher;
  final int? publicationYear;
  final String? language;
  final int? pages;
  final List<String>? genres;
  final String? locationText;
  final String? postalCode;
  final double? locationLat;
  final double? locationLng;
  final BookStatus status;
  final String? currentTradeId;
  final int? tradeCount;
  final int? interestCount;
  final double? distanceKm;
  final double? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Profile? owner;

  Book({
    required this.id,
    required this.userId,
    required this.title,
    required this.author,
    this.description,
    required this.condition,
    this.isbn,
    this.coverImgUrl,
    this.publisher,
    this.publicationYear,
    this.language,
    this.pages,
    this.genres,
    this.locationText,
    this.postalCode,
    this.locationLat,
    this.locationLng,
    this.status = BookStatus.available,
    this.currentTradeId,
    this.tradeCount,
    this.interestCount,
    this.distanceKm,
    this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
    this.owner,
  });

  /// Get distance display string
  String? get distanceDisplay {
    if (distanceKm != null) {
      return '${distanceKm!.toStringAsFixed(1)} km';
    }
    if (distanceMeters != null) {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
    }
    return null;
  }

  /// Get a cover color key based on title hash
  String get coverColorKey {
    const colors = ['honey', 'plum', 'slate', 'deepGreen', 'forest', 'terracotta', 'brick'];
    final hash = title.hashCode.abs();
    return colors[hash % colors.length];
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      description: json['description'] as String?,
      condition: BookCondition.fromString(json['condition'] as String? ?? 'Good'),
      isbn: json['isbn'] as String?,
      coverImgUrl: json['cover_img_url'] as String?,
      publisher: json['publisher'] as String?,
      publicationYear: json['publication_year'] as int?,
      language: json['language'] as String?,
      pages: json['pages'] as int?,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>(),
      locationText: json['location_text'] as String?,
      postalCode: json['postal_code'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      status: BookStatus.fromString(json['status'] as String? ?? 'available'),
      currentTradeId: json['current_trade_id'] as String?,
      tradeCount: json['trade_count'] as int?,
      interestCount: json['interest_count'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ??
          (json['calculated_distance_meters'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      owner: json['owner'] != null
          ? Profile.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'author': author,
      'description': description,
      'condition': condition.displayName,
      'isbn': isbn,
      'cover_img_url': coverImgUrl,
      'publisher': publisher,
      'publication_year': publicationYear,
      'language': language,
      'pages': pages,
      'genres': genres,
      'location_text': locationText,
      'postal_code': postalCode,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'status': status.name,
      'current_trade_id': currentTradeId,
      'trade_count': tradeCount,
      'interest_count': interestCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Book copyWith({
    String? id,
    String? userId,
    String? title,
    String? author,
    String? description,
    BookCondition? condition,
    String? isbn,
    String? coverImgUrl,
    String? publisher,
    int? publicationYear,
    String? language,
    int? pages,
    List<String>? genres,
    String? locationText,
    String? postalCode,
    double? locationLat,
    double? locationLng,
    BookStatus? status,
    String? currentTradeId,
    int? tradeCount,
    int? interestCount,
    double? distanceKm,
    double? distanceMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
    Profile? owner,
  }) {
    return Book(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      isbn: isbn ?? this.isbn,
      coverImgUrl: coverImgUrl ?? this.coverImgUrl,
      publisher: publisher ?? this.publisher,
      publicationYear: publicationYear ?? this.publicationYear,
      language: language ?? this.language,
      pages: pages ?? this.pages,
      genres: genres ?? this.genres,
      locationText: locationText ?? this.locationText,
      postalCode: postalCode ?? this.postalCode,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      status: status ?? this.status,
      currentTradeId: currentTradeId ?? this.currentTradeId,
      tradeCount: tradeCount ?? this.tradeCount,
      interestCount: interestCount ?? this.interestCount,
      distanceKm: distanceKm ?? this.distanceKm,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
    );
  }
}
