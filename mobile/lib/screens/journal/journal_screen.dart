import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';

/// Journal feed — read-only stream from blogPosts (decision D5).
final journalEntriesProvider =
    StreamProvider.autoDispose<List<JournalEntry>>((ref) {
  return FirebaseService.db
      .collection('blogPosts')
      .orderBy('publishedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc.data(), doc.id))
          .toList());
});

/// Club journal (mock #1l): stories, reading lists, events with Join.
/// Read-only in v1 — no authoring anywhere (spec §11).
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Club journal')),
      body: SafeArea(
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text('Could not load the journal.',
                style:
                    AppTypography.sansRegular.copyWith(color: AppColors.ink2)),
          ),
          data: (entries) => entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book_outlined,
                            size: 48, color: AppColors.piriMoss),
                        const SizedBox(height: 16),
                        Text(
                          'The journal is warming up',
                          textAlign: TextAlign.center,
                          style: AppTypography.serifRegular.copyWith(
                            fontSize: 20,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stories, reading lists and club events will appear here.',
                          textAlign: TextAlign.center,
                          style: AppTypography.sansRegular.copyWith(
                            fontSize: 13.5,
                            color: AppColors.ink2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _JournalCard(entry: entries[index]),
                ),
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;

  const _JournalCard({required this.entry});

  Future<void> _join() async {
    // D11: keep it simple — the Join button opens a link or mailto.
    final target = entry.joinUrl ??
        'mailto:hello@turtleturningpages.com?subject=${Uri.encodeComponent('Joining: ${entry.title}')}';
    final uri = Uri.tryParse(target);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              entry.type.label.toUpperCase(),
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.8,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: AppTypography.serifRegular.copyWith(
                fontSize: 24,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.author} · ${entry.readMinutes} min read',
              style: AppTypography.sansRegular.copyWith(
                fontSize: 12,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              entry.content,
              style: AppTypography.sansRegular.copyWith(
                fontSize: 14.5,
                color: AppColors.ink,
                height: 1.65,
              ),
            ),
            if (entry.type == JournalEntryType.event) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _join,
                child: const Text('Join'),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('journal_${entry.id}'),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.type.label.toUpperCase(),
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.title,
              style: AppTypography.serifRegular.copyWith(
                fontSize: 18,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            if (entry.summary != null) ...[
              const SizedBox(height: 6),
              Text(
                entry.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 13,
                  color: AppColors.ink2,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.type == JournalEntryType.event &&
                            entry.eventAt != null
                        ? [
                            DateFormat('EEE d MMM · HH:mm')
                                .format(entry.eventAt!),
                            if (entry.eventLocation != null)
                              entry.eventLocation!,
                          ].join(' · ')
                        : '${entry.author} · ${entry.readMinutes} min read',
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 11.5,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
                if (entry.type == JournalEntryType.event)
                  GestureDetector(
                    key: Key('join_${entry.id}'),
                    onTap: _join,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Join',
                        style: AppTypography.sansExtraBold.copyWith(
                          fontSize: 12,
                          color: AppColors.bg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
