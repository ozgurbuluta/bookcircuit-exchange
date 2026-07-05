import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../services/rating_service.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/rating_tag_chip.dart';

final ratingServiceProvider =
    Provider<RatingService>((ref) => RatingService(FirebaseService.db));

/// Rate the swap (mock #3g): 1-5 stars, optional tags and a short note.
/// Skippable — shown to both parties after a trade completes (spec §2).
class RateSwapScreen extends ConsumerStatefulWidget {
  final String tradeId;

  const RateSwapScreen({super.key, required this.tradeId});

  @override
  ConsumerState<RateSwapScreen> createState() => _RateSwapScreenState();
}

class _RateSwapScreenState extends ConsumerState<RateSwapScreen> {
  final _noteController = TextEditingController();
  int _stars = 0;
  final Set<RatingTag> _tags = {};
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(Trade trade) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null || _stars == 0) return;

    setState(() => _submitting = true);
    try {
      await ref.read(ratingServiceProvider).submit(
            tradeId: trade.id,
            fromId: uid,
            toId: trade.otherPartyId(uid),
            stars: _stars,
            tags: _tags,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — see you at the next swap'),
          backgroundColor: AppColors.green,
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the rating. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradeAsync = ref.watch(tradeProvider(widget.tradeId));
    final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Rate the swap'),
        actions: [
          TextButton(
            key: const Key('skip_rating'),
            onPressed: () => context.pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: tradeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Could not load the trade.',
                style:
                    AppTypography.sansRegular.copyWith(color: AppColors.ink2)),
          ),
          data: (trade) {
            if (trade == null) {
              return const Center(child: Text('Trade not found'));
            }
            final partner = trade.getPartner(currentUserId);

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'How was trading with ${partner?.displayName.split(' ').first ?? 'your neighbor'}?',
                  textAlign: TextAlign.center,
                  style: AppTypography.serifRegular.copyWith(
                    fontSize: 22,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: RatingStars(
                    rating: _stars,
                    size: 40,
                    onChanged: (value) => setState(() => _stars = value),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: RatingTag.values
                      .map((tag) => RatingTagChip(
                            label: tag.label,
                            selected: _tags.contains(tag),
                            onTap: () => setState(() {
                              if (_tags.contains(tag)) {
                                _tags.remove(tag);
                              } else {
                                _tags.add(tag);
                              }
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('rating_note'),
                  controller: _noteController,
                  maxLength: Rating.maxNoteLength,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'A line for the journal, if you like (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('submit_rating'),
                  onPressed:
                      _stars > 0 && !_submitting ? () => _submit(trade) : null,
                  child: Text(_submitting ? 'Sending…' : 'Send rating'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
