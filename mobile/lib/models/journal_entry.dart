import 'firestore_helpers.dart';

/// Journal entry types (decision D5: reuses the blogPosts collection).
enum JournalEntryType {
  story('story'),
  list('list'),
  event('event');

  final String value;
  const JournalEntryType(this.value);

  static JournalEntryType fromString(String? raw) {
    for (final t in JournalEntryType.values) {
      if (t.value == raw) return t;
    }
    return JournalEntryType.story;
  }

  String get label {
    switch (this) {
      case JournalEntryType.story:
        return 'Stories';
      case JournalEntryType.list:
        return 'Reading lists';
      case JournalEntryType.event:
        return 'Meetups';
    }
  }
}

/// Club journal entry (mock #1l) — read-only in v1 (spec §1).
class JournalEntry {
  final String id;
  final JournalEntryType type;
  final String title;
  final String? summary;
  final String content;
  final String author;

  /// Events only: when/where + optional join link (D11 — mailto or URL).
  final DateTime? eventAt;
  final String? eventLocation;
  final String? joinUrl;

  final DateTime publishedAt;

  JournalEntry({
    required this.id,
    required this.type,
    required this.title,
    this.summary,
    required this.content,
    required this.author,
    this.eventAt,
    this.eventLocation,
    this.joinUrl,
    required this.publishedAt,
  });

  factory JournalEntry.fromFirestore(Map<String, dynamic> data, String id) {
    return JournalEntry(
      id: id,
      type: JournalEntryType.fromString(data['type'] as String?),
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String?,
      content: data['content'] as String? ?? '',
      author: data['author'] as String? ?? 'The club',
      eventAt: dateFromFirestore(data['eventAt']),
      eventLocation: data['eventLocation'] as String?,
      joinUrl: data['joinUrl'] as String?,
      publishedAt: dateFromFirestore(data['publishedAt']) ??
          dateFromFirestore(data['createdAt']) ??
          DateTime.now(),
    );
  }

  /// Rough "N min read" from content length (mock #1l shows read times).
  int get readMinutes => (content.split(RegExp(r'\s+')).length / 200)
      .ceil()
      .clamp(1, 60);
}
