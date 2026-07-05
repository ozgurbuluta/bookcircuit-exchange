import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// Chats-tab badge: incoming requests waiting on you (v1 proxy for unread —
/// per-thread read tracking is a v1.1 follow-up).
final unreadMessagesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final userId = FirebaseService.currentUser?.uid;
  if (userId == null) return 0;
  final trades = await FirebaseService.getUserTrades();
  return trades
      .where((t) => t.ownerId == userId && t.status.value == 'requested')
      .length;
});
