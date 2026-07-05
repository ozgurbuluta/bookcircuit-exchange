import 'package:cloud_firestore/cloud_firestore.dart';

/// Normalizes the date representations we may encounter in Firestore data:
/// server [Timestamp]s, ISO-8601 strings (fixtures/tests), or [DateTime].
DateTime? dateFromFirestore(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
