import 'firestore_helpers.dart';

/// User profile (spec §3 "User").
///
/// Neighbors only ever see [areaLabel] — GPS is never stored (spec §5).
class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  /// Postal code captured during neighborhood setup (#3e).
  final String? postalCode;

  /// Human label geocoded once from [postalCode], e.g. "Moda, Kadıköy".
  final String? areaLabel;

  /// Languages the user reads (≥1 required by onboarding).
  final List<String> languages;

  /// Points balance. New accounts are granted 200 exactly once (spec §4.2).
  final int points;

  /// Guards the one-time welcome grant across repeated social sign-ins.
  final bool pointsGranted;

  final double ratingAvg;
  final int ratingCount;
  final int tradeCount;

  /// Opt-in notification prefs (spec §8) — default off.
  final bool notifyNewBookNearby;
  final bool notifyJournal;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -------------------------------------------------------------------------
  // Legacy fields — kept so pre-redesign screens compile until Phase L.
  // -------------------------------------------------------------------------
  @Deprecated('Removed by the v1 redesign')
  final String? bio;
  @Deprecated('Removed by the v1 redesign')
  final String? website;
  @Deprecated('Removed by the v1 redesign')
  final String? university;
  @Deprecated('Use areaLabel')
  final String? locationCity;
  @Deprecated('Use areaLabel')
  final String? locationState;
  @Deprecated('Use areaLabel')
  final String? locationCountry;
  @Deprecated('GPS is never stored (spec §5)')
  final double? locationLat;
  @Deprecated('GPS is never stored (spec §5)')
  final double? locationLng;

  Profile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.postalCode,
    this.areaLabel,
    this.languages = const [],
    this.points = 0,
    this.pointsGranted = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.tradeCount = 0,
    this.notifyNewBookNearby = false,
    this.notifyJournal = false,
    this.createdAt,
    this.updatedAt,
    @Deprecated('Removed by the v1 redesign') this.bio,
    @Deprecated('Removed by the v1 redesign') this.website,
    @Deprecated('Removed by the v1 redesign') this.university,
    @Deprecated('Use areaLabel') this.locationCity,
    @Deprecated('Use areaLabel') this.locationState,
    @Deprecated('Use areaLabel') this.locationCountry,
    @Deprecated('GPS is never stored (spec §5)') this.locationLat,
    @Deprecated('GPS is never stored (spec §5)') this.locationLng,
  });

  /// Display name (full name or email prefix fallback).
  String get displayName => fullName?.isNotEmpty == true
      ? fullName!
      : email?.split('@').first ?? 'User';

  /// Initials for avatars, stored denormalized as spec `avatarInitials`.
  String get avatarInitials {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) return 'U';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Legacy alias for [avatarInitials].
  String get initials => avatarInitials;

  /// Onboarding gate (#3e): postal code + at least one language.
  bool get hasCompletedSetup =>
      (postalCode?.isNotEmpty ?? false) && languages.isNotEmpty;

  @Deprecated('Use areaLabel')
  String? get formattedLocation => areaLabel;

  factory Profile.fromFirestore(Map<String, dynamic> data, String id) {
    return Profile(
      id: id,
      email: data['email'] as String?,
      fullName: data['fullName'] as String? ?? data['name'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      postalCode: data['postalCode'] as String?,
      areaLabel: data['areaLabel'] as String?,
      languages:
          (data['languages'] as List<dynamic>?)?.cast<String>() ?? const [],
      points: (data['points'] as num?)?.toInt() ?? 0,
      pointsGranted: data['pointsGranted'] as bool? ?? false,
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      tradeCount: (data['tradeCount'] as num?)?.toInt() ?? 0,
      notifyNewBookNearby: data['notifyNewBookNearby'] as bool? ?? false,
      notifyJournal: data['notifyJournal'] as bool? ?? false,
      createdAt: dateFromFirestore(data['createdAt']),
      updatedAt: dateFromFirestore(data['updatedAt']),
    );
  }

  /// Serialization for the `users` collection. Intentionally excludes GPS and
  /// all removed legacy fields (spec §5, plan §3).
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'name': fullName,
      'avatarInitials': avatarInitials,
      'avatarUrl': avatarUrl,
      'postalCode': postalCode,
      'areaLabel': areaLabel,
      'languages': languages,
      'points': points,
      'pointsGranted': pointsGranted,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'tradeCount': tradeCount,
      'notifyNewBookNearby': notifyNewBookNearby,
      'notifyJournal': notifyJournal,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Profile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? postalCode,
    String? areaLabel,
    List<String>? languages,
    int? points,
    bool? pointsGranted,
    double? ratingAvg,
    int? ratingCount,
    int? tradeCount,
    bool? notifyNewBookNearby,
    bool? notifyJournal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      postalCode: postalCode ?? this.postalCode,
      areaLabel: areaLabel ?? this.areaLabel,
      languages: languages ?? this.languages,
      points: points ?? this.points,
      pointsGranted: pointsGranted ?? this.pointsGranted,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      tradeCount: tradeCount ?? this.tradeCount,
      notifyNewBookNearby: notifyNewBookNearby ?? this.notifyNewBookNearby,
      notifyJournal: notifyJournal ?? this.notifyJournal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Legacy JSON support for any remaining old call sites.
  @Deprecated('Use Profile.fromFirestore')
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile.fromFirestore(json, json['id'] as String? ?? '');
  }
}
