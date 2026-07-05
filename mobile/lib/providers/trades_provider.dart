import 'package:cloud_firestore/cloud_firestore.dart';
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
      // 'incoming'/'outgoing' are not trade statuses; these are resolved with
      // client-side requester/owner filtering instead (see tradesProvider).
      case TradeFilter.incoming:
      case TradeFilter.outgoing:
        return null;
      case TradeFilter.done:
        return 'swapped';
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
    trades = trades.where((t) => t.ownerId == currentUser.uid).toList();
  } else if (filter == TradeFilter.outgoing && currentUser != null) {
    trades = trades.where((t) => t.requesterId == currentUser.uid).toList();
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
          t.ownerId == userId && t.status == TradeStatus.requested)
      .length;
});

/// Trade actions notifier.
///
/// NOTE: interim implementation — Phase H replaces these plain status writes
/// with the TradeEngine (escrow, refunds, auto-decline, two-sided swap
/// confirmation, book locking) per docs/REDESIGN_PLAN.md §3.
class TradeActionsNotifier extends StateNotifier<AsyncValue<void>> {
  TradeActionsNotifier() : super(const AsyncValue.data(null));

  /// Create a trade request for one book (spec §4).
  Future<Trade?> createTrade({
    required String ownerId,
    required String bookId,
    TradeOffer offer = TradeOffer.points50,
    String? offeredBookId,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = FirebaseService.currentUser;
      if (currentUser == null) throw Exception('Not authenticated');

      final tradeRef = FirebaseService.db.collection('trades').doc();
      await tradeRef.set({
        'bookId': bookId,
        'requesterId': currentUser.uid,
        'ownerId': ownerId,
        'offer': offer.value,
        'offeredBookId': offeredBookId,
        'note': note,
        'status': TradeStatus.requested.value,
        'escrowed': false,
        'swapConfirmedBy': <String>[],
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final trade = await FirebaseService.getTrade(tradeRef.id);
      state = const AsyncValue.data(null);
      return trade;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> _setStatus(String tradeId, TradeStatus status) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseService.updateTradeStatus(
        tradeId: tradeId,
        newStatus: status.value,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Accept a trade
  Future<bool> acceptTrade(String tradeId) =>
      _setStatus(tradeId, TradeStatus.accepted);

  /// Decline a trade
  Future<bool> rejectTrade(String tradeId) =>
      _setStatus(tradeId, TradeStatus.declined);

  /// Cancel a trade
  Future<bool> cancelTrade(String tradeId) =>
      _setStatus(tradeId, TradeStatus.cancelled);

  /// Complete a trade (interim: Phase H replaces with two-sided confirm)
  Future<bool> completeTrade(String tradeId) =>
      _setStatus(tradeId, TradeStatus.swapped);
}

final tradeActionsProvider =
    StateNotifierProvider<TradeActionsNotifier, AsyncValue<void>>((ref) {
  return TradeActionsNotifier();
});
