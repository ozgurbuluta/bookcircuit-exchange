import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Review screen for AI-detected books from a shelf photo.
///
/// Lets the user edit titles/authors, set condition (per book or in bulk),
/// drop wrong detections, and toggle which books to include before adding the
/// whole batch to their library.
class ScanReviewScreen extends ConsumerStatefulWidget {
  final List<DetectedBook> books;

  const ScanReviewScreen({super.key, required this.books});

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late final List<DetectedBook> _books;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _books = List.of(widget.books);
  }

  int get _selectedCount => _books.where((b) => b.include).length;

  Set<String> _existingTitles() {
    final myBooks = ref.read(myBooksProvider).valueOrNull ?? const <Book>[];
    return myBooks.map((b) => b.title.trim().toLowerCase()).toSet();
  }

  void _setAllCondition(BookCondition condition) {
    setState(() {
      for (final b in _books) {
        b.condition = condition;
      }
    });
  }

  void _toggleAll(bool include) {
    setState(() {
      for (final b in _books) {
        b.include = include;
      }
    });
  }

  void _remove(DetectedBook book) {
    HapticFeedback.lightImpact();
    setState(() => _books.remove(book));
  }

  Future<void> _editBook(DetectedBook book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    BookCondition condition = book.condition;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Edit book',
                      style: AppTypography.serifSemiBold
                          .copyWith(fontSize: 18, color: AppColors.ink)),
                  const SizedBox(height: 16),
                  _sheetField('Title', titleController),
                  const SizedBox(height: 12),
                  _sheetField('Author', authorController),
                  const SizedBox(height: 16),
                  _label('Condition'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BookCondition.values.map((c) {
                      final selected = c == condition;
                      return GestureDetector(
                        onTap: () => setSheet(() => condition = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.ink : AppColors.paper2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: selected ? AppColors.ink : AppColors.line, width: 0.5),
                          ),
                          child: Text(c.displayName,
                              style: AppTypography.sansSemiBold.copyWith(
                                  fontSize: 13,
                                  color: selected ? AppColors.paper : AppColors.ink2)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          book.title = titleController.text.trim();
                          book.author = authorController.text.trim();
                          book.condition = condition;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.rust,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('Done',
                              style: AppTypography.sansBold
                                  .copyWith(fontSize: 15.5, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    titleController.dispose();
    authorController.dispose();
  }

  Future<void> _save() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final selected = _books.where((b) => b.include).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);

    final profile = ref.read(currentProfileProvider);
    final toCreate = selected
        .map((d) => d.toBook(userId: currentUser.uid, profile: profile))
        .toList();

    final count = await ref.read(bookActionsProvider.notifier).createBooks(toCreate);

    if (!mounted) return;

    if (count > 0) {
      ref.invalidate(myBooksProvider);
      ref.invalidate(booksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $count ${count == 1 ? 'book' : 'books'} to your library')),
      );
      context.pop();
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add books. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existingTitles();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: _isSaving ? null : () => context.pop(),
        ),
        title: Text('Review Books',
            style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink)),
        centerTitle: true,
        actions: [
          if (_books.isNotEmpty)
            TextButton(
              onPressed: _selectedCount == _books.length
                  ? () => _toggleAll(false)
                  : () => _toggleAll(true),
              child: Text(
                _selectedCount == _books.length ? 'None' : 'All',
                style: AppTypography.sansBold.copyWith(fontSize: 14, color: AppColors.rust),
              ),
            ),
        ],
      ),
      body: _books.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                _buildSummaryBar(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final book = _books[index];
                      final isDup =
                          existing.contains(book.title.trim().toLowerCase());
                      return _buildCard(book, isDup);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _books.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: AppColors.ink3),
            const SizedBox(height: 16),
            Text('No books left to add',
                style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Go back to scan another shelf.',
                textAlign: TextAlign.center,
                style: AppTypography.sansRegular.copyWith(fontSize: 14, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.sage),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Found ${_books.length} ${_books.length == 1 ? 'book' : 'books'}. Tap any to edit.',
              style: AppTypography.sansSemiBold.copyWith(fontSize: 13, color: AppColors.ink2),
            ),
          ),
          GestureDetector(
            onTap: _showBulkConditionSheet,
            child: Row(
              children: [
                const Icon(Icons.tune, size: 16, color: AppColors.rust),
                const SizedBox(width: 4),
                Text('Condition',
                    style: AppTypography.sansBold.copyWith(fontSize: 13, color: AppColors.rust)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkConditionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set condition for all',
                style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BookCondition.values.map((c) {
                return GestureDetector(
                  onTap: () {
                    _setAllCondition(c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.paper2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line, width: 0.5),
                    ),
                    child: Text(c.displayName,
                        style: AppTypography.sansSemiBold
                            .copyWith(fontSize: 14, color: AppColors.ink2)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(DetectedBook book, bool isDuplicate) {
    return GestureDetector(
      onTap: () => _editBook(book),
      child: Opacity(
        opacity: book.include ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.paper2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        width: 48,
                        height: 68,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(width: 48, height: 68, color: AppColors.paper3),
                        errorWidget: (_, __, ___) => _coverFallback(),
                      )
                    : _coverFallback(),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: AppTypography.sansSemiBold
                          .copyWith(fontSize: 14.5, color: AppColors.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author.isEmpty ? 'Unknown author' : book.author,
                      style: AppTypography.sansRegular
                          .copyWith(fontSize: 12.5, color: AppColors.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(book.condition.displayName, AppColors.ink3),
                        if (!book.matched)
                          _chip('Not in catalog', AppColors.gold),
                        if (isDuplicate) _chip('Already in library', AppColors.rust),
                      ],
                    ),
                  ],
                ),
              ),
              // Controls
              Column(
                children: [
                  Checkbox(
                    value: book.include,
                    activeColor: AppColors.sage,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => book.include = v ?? false),
                  ),
                  GestureDetector(
                    onTap: () => _remove(book),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline, size: 20, color: AppColors.ink3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      width: 48,
      height: 68,
      color: AppColors.paper3,
      child: const Icon(Icons.book_outlined, size: 22, color: AppColors.ink3),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: AppTypography.sansSemiBold.copyWith(fontSize: 10.5, color: color)),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line, width: 0.5)),
      ),
      child: GestureDetector(
        onTap: (_isSaving || _selectedCount == 0) ? null : _save,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _selectedCount == 0 ? AppColors.ink3 : AppColors.rust,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text(
                    _selectedCount == 0
                        ? 'Select books to add'
                        : 'Add $_selectedCount ${_selectedCount == 1 ? 'book' : 'books'} to library',
                    style:
                        AppTypography.sansBold.copyWith(fontSize: 15.5, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text.toUpperCase(),
        style: AppTypography.sansBold
            .copyWith(fontSize: 11.5, letterSpacing: 0.6, color: AppColors.ink3));
  }

  Widget _sheetField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          style: AppTypography.sansRegular.copyWith(fontSize: 15.5, color: AppColors.ink),
          decoration: InputDecoration(hintText: 'Enter $label'),
        ),
      ],
    );
  }
}
