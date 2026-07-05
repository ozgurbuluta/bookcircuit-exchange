import 'firestore_helpers.dart';

/// Rating tags (spec §3): fixed set, sentence-case labels.
enum RatingTag {
  onTime('on_time', 'On time'),
  asDescribed('as_described', 'As described'),
  greatPick('great_pick', 'Great pick');

  final String value;
  final String label;
  const RatingTag(this.value, this.label);

  static RatingTag? fromString(String? raw) {
    for (final t in RatingTag.values) {
      if (t.value == raw) return t;
    }
    return null;
  }
}

/// Post-swap rating (spec §3): one per direction per trade, skippable.
class Rating {
  /// Notes are capped at 140 characters (spec §3).
  static const int maxNoteLength = 140;

  final String id;
  final String tradeId;
  final String fromId;
  final String toId;
  final int stars;
  final Set<RatingTag> tags;
  final String? note;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.tradeId,
    required this.fromId,
    required this.toId,
    required this.stars,
    this.tags = const {},
    this.note,
    required this.createdAt,
  });

  bool get isValid =>
      stars >= 1 &&
      stars <= 5 &&
      (note == null || note!.length <= maxNoteLength);

  factory Rating.fromFirestore(Map<String, dynamic> data, String id) {
    return Rating(
      id: id,
      tradeId: data['tradeId'] as String? ?? '',
      fromId: data['fromId'] as String? ?? '',
      toId: data['toId'] as String? ?? '',
      stars: (data['stars'] as num?)?.toInt() ?? 0,
      tags: ((data['tags'] as List<dynamic>?) ?? const [])
          .map((t) => RatingTag.fromString(t as String?))
          .whereType<RatingTag>()
          .toSet(),
      note: data['note'] as String?,
      createdAt: dateFromFirestore(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tradeId': tradeId,
      'fromId': fromId,
      'toId': toId,
      'stars': stars,
      'tags': tags.map((t) => t.value).toList(),
      'note': note,
      'createdAt': createdAt,
    };
  }
}
