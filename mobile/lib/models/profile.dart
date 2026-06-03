/// User profile model
class Profile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? email;
  final String? locationCity;
  final String? locationState;
  final String? locationCountry;
  final double? locationLat;
  final double? locationLng;
  final String? bio;
  final String? website;
  final String? university;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.email,
    this.locationCity,
    this.locationState,
    this.locationCountry,
    this.locationLat,
    this.locationLng,
    this.bio,
    this.website,
    this.university,
    this.createdAt,
    this.updatedAt,
  });

  /// Get display name (full name or fallback to email)
  String get displayName => fullName ?? email?.split('@').first ?? 'User';

  /// Get initials for avatar
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return fullName![0].toUpperCase();
    }
    return 'U';
  }

  /// Get formatted location string
  String? get formattedLocation {
    final parts = [locationCity, locationState, locationCountry]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      email: json['email'] as String?,
      locationCity: json['location_city'] as String?,
      locationState: json['location_state'] as String?,
      locationCountry: json['location_country'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      website: json['website'] as String?,
      university: json['university'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'email': email,
      'location_city': locationCity,
      'location_state': locationState,
      'location_country': locationCountry,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'bio': bio,
      'website': website,
      'university': university,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? fullName,
    String? avatarUrl,
    String? email,
    String? locationCity,
    String? locationState,
    String? locationCountry,
    double? locationLat,
    double? locationLng,
    String? bio,
    String? website,
    String? university,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      locationCountry: locationCountry ?? this.locationCountry,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      university: university ?? this.university,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
