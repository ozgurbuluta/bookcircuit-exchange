import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/trade_engine.dart';
import 'auth_provider.dart';

/// The one gateway to the points economy (docs/REDESIGN_PLAN.md, D1).
final tradeEngineProvider =
    Provider<TradeEngine>((ref) => TradeEngine(FirebaseService.db));

/// Trade filter (mock #2c): active vs completed.
enum TradeFilter { active, done }

final tradeFilterProvider =
    StateProvider<TradeFilter>((ref) => TradeFilter.active);

/// Trades list provider
final tradesProvider = FutureProvider.autoDispose<List<Trade>>((ref) async {
  final filter = ref.watch(tradeFilterProvider);
  final trades = await FirebaseService.getUserTrades();

  // Opportunistic client-side expiry (backstop to the scheduled function).
  final engine = ref.read(tradeEngineProvider);
  for (final trade in trades) {
    if (trade.isExpiredAt(DateTime.now())) {
      await engine.expireIfStale(trade.id);
    }
  }

  switch (filter) {
    case TradeFilter.active:
      return trades.where((t) => !t.status.isTerminal).toList();
    case TradeFilter.done:
      return trades.where((t) => t.status.isTerminal).toList();
  }
});

/// Single trade provider
final tradeProvider =
    FutureProvider.autoDispose.family<Trade?, String>((ref, tradeId) async {
  return FirebaseService.getTrade(tradeId);
});

/// Pending incoming trades count (for badges)
final pendingTradesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserProvider)?.uid;
  if (userId == null) return 0;

  final trades = await FirebaseService.getUserTrades();
  return trades
      .where((t) => t.ownerId == userId && t.status == TradeStatus.requested)
      .length;
});

/// Trade actions — thin UI adapter over the TradeEngine. Surfaces engine
/// errors as user-facing messages in [state].
class TradeActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final TradeEngine _engine;
  final String? Function() _currentUserId;

  TradeActionsNotifier(this._engine, this._currentUserId)
      : super(const AsyncValue.data(null));

  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final result = await action();
      state = const AsyncValue.data(null);
      return result;
    } on TradeEngineException catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Human copy for engine errors (spec §10 tone).
  static String describeError(Object? error) {
    if (error is TradeEngineException) {
      switch (error.code) {
        case TradeErrorCode.insufficientPoints:
          return 'Not enough points. Shelve a book to earn points.';
        case TradeErrorCode.duplicateRequest:
          return 'You already asked for this book.';
        case TradeErrorCode.bookNotRequestable:
          return 'This book just left the shelf.';
        case TradeErrorCode.invalidOfferedBook:
          return 'That book of yours is not available to offer.';
        case TradeErrorCode.ownBook:
          return 'This one is already yours.';
        case TradeErrorCode.alreadyConfirmed:
          return 'You already marked this as swapped.';
        case TradeErrorCode.notAllowed:
        case TradeErrorCode.invalidStatus:
        case TradeErrorCode.notFound:
          return 'This trade changed — pull to refresh.';
      }
    }
    return 'Something went wrong. Try again.';
  }

  Future<Trade?> createRequest({
    required String bookId,
    required TradeOffer offer,
    String? offeredBookId,
    String? note,
  }) {
    final uid = _currentUserId();
    if (uid == null) return Future.value(null);
    return _run(() => _engine.createRequest(
          requesterId: uid,
          bookId: bookId,
          offer: offer,
          offeredBookId: offeredBookId,
          note: note,
        ));
  }

  Future<bool> acceptTrade(String tradeId) async {
    final uid = _currentUserId();
    if (uid == null) return false;
    await _run(() => _engine.accept(tradeId: tradeId, actorId: uid));
    return state is AsyncData;
  }

  Future<bool> rejectTrade(String tradeId) async {
    final uid = _currentUserId();
    if (uid == null) return false;
    await _run(() => _engine.decline(tradeId: tradeId, actorId: uid));
    return state is AsyncData;
  }

  Future<bool> cancelTrade(String tradeId) async {
    final uid = _currentUserId();
    if (uid == null) return false;
    await _run(() => _engine.cancel(tradeId: tradeId, actorId: uid));
    return state is AsyncData;
  }

  /// D7: returns true when the trade fully completed (second confirmation).
  Future<SwapConfirmation?> confirmSwap(String tradeId) {
    final uid = _currentUserId();
    if (uid == null) return Future.value(null);
    return _run(() => _engine.confirmSwap(tradeId: tradeId, actorId: uid));
  }
}

final tradeActionsProvider =
    StateNotifierProvider<TradeActionsNotifier, AsyncValue<void>>((ref) {
  return TradeActionsNotifier(
    ref.watch(tradeEngineProvider),
    () => ref.read(currentUserProvider)?.uid,
  );
});
