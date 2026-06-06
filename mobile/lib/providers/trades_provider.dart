import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// Trade filter enum
enum TradeFilter {
  all,
  incoming,
  outgoing,
  done;

  String? get statusFilter {
    switch (this) {
      case TradeFilter.all:
        return null;
      case TradeFilter.incoming:
        return 'incoming';
      case TradeFilter.outgoing:
        return 'outgoing';
      case TradeFilter.done:
        return 'completed';
    }
  }
}

/// Current trade filter provider
final tradeFilterProvider = StateProvider<TradeFilter>((ref) => TradeFilter.all);

/// Trades list provider
final tradesProvider = FutureProvider.autoDispose<List<Trade>>((ref) async {
  final filter = ref.watch(tradeFilterProvider);
  final currentUser = FirebaseService.currentUser;

  var trades = await FirebaseService.getUserTrades(
    statusFilter: filter.statusFilter,
  );

  // Apply additional client-side filtering for incoming/outgoing
  if (filter == TradeFilter.incoming && currentUser != null) {
    trades = trades.where((t) => t.recipientId == currentUser.uid).toList();
  } else if (filter == TradeFilter.outgoing && currentUser != null) {
    trades = trades.where((t) => t.initiatorId == currentUser.uid).toList();
  }

  return trades;
});

/// Single trade provider
final tradeProvider =
    FutureProvider.autoDispose.family<Trade?, String>((ref, tradeId) async {
  return FirebaseService.getTrade(tradeId);
});

/// Pending incoming trades count (for badge)
final pendingTradesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserProvider)?.uid;
  if (userId == null) return 0;

  final trades = await FirebaseService.getUserTrades();
  return trades
      .where((t) =>
          t.recipientId == userId &&
          (t.status == TradeStatus.pending ||
              t.status == TradeStatus.requestPending))
      .length;
});

/// Trade actions notifier
class TradeActionsNotifier extends StateNotifier<AsyncValue<void>> {
  TradeActionsNotifier() : super(const AsyncValue.data(null));

  /// Create a new trade
  Future<Trade?> createTrade({
    required String partnerId,
    required List<String> myBookIds,
    required List<String> theirBookIds,
    String? message,
  }) async {
    state = const AsyncValue.loading();
    try {
      // TODO: Implement create trade in FirebaseService
      // For now, create directly in Firestore
      final currentUser = FirebaseService.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final batch = FirebaseService.db.batch();

      final tradeRef = FirebaseService.db.collection('trades').doc();
      batch.set(tradeRef, {
        'initiatorId': currentUser.uid,
        'recipientId': partnerId,
        'status': 'pending',
        'initiatorMessage': message ?? '',
        'recipientMessage': '',
        'isDirectRequest': theirBookIds.length == 1 && myBookIds.isEmpty,
        'isCounteroffered': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      // Add trade items
      for (final bookId in myBookIds) {
        final itemRef = tradeRef.collection('tradeItems').doc();
        batch.set(itemRef, {
          'bookId': bookId,
          'ownerId': currentUser.uid,
          'recipientId': partnerId,
          'itemType': 'book',
          'createdAt': DateTime.now(),
        });
      }

      for (final bookId in theirBookIds) {
        final itemRef = tradeRef.collection('tradeItems').doc();
        batch.set(itemRef, {
          'bookId': bookId,
          'ownerId': partnerId,
          'recipientId': currentUser.uid,
          'itemType': 'book',
          'createdAt': DateTime.now(),
        });
      }

      await batch.commit();

      final trade = await FirebaseService.getTrade(tradeRef.id);
      state = const AsyncValue.data(null);
      return trade;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Accept a trade
  Future<bool> acceptTrade(String tradeId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.updateTradeStatus(
        tradeId: tradeId,
        newStatus: 'accepted',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Reject a trade
  Future<bool> rejectTrade(String tradeId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.updateTradeStatus(
        tradeId: tradeId,
        newStatus: 'rejected',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Cancel a trade
  Future<bool> cancelTrade(String tradeId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.updateTradeStatus(
        tradeId: tradeId,
        newStatus: 'cancelled',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Complete a trade
  Future<bool> completeTrade(String tradeId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.updateTradeStatus(
        tradeId: tradeId,
        newStatus: 'completed',
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final tradeActionsProvider =
    StateNotifierProvider<TradeActionsNotifier, AsyncValue<void>>((ref) {
  return TradeActionsNotifier();
});
