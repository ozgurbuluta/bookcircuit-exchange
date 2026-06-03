import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
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
  final trades = await SupabaseService.getUserTrades(
    statusFilter: filter.statusFilter,
  );
  return trades;
});

/// Single trade provider
final tradeProvider =
    FutureProvider.autoDispose.family<Trade?, String>((ref, tradeId) async {
  return SupabaseService.getTrade(tradeId);
});

/// Pending incoming trades count (for badge)
final pendingTradesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return 0;

  final trades = await SupabaseService.getUserTrades();
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
      final trade = await SupabaseService.createTrade(
        partnerId: partnerId,
        myBookIds: myBookIds,
        theirBookIds: theirBookIds,
        message: message,
      );
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
      await SupabaseService.updateTradeStatus(
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
      await SupabaseService.updateTradeStatus(
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
      await SupabaseService.updateTradeStatus(
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
      await SupabaseService.updateTradeStatus(
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
