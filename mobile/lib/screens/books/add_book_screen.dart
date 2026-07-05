import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/open_library_service.dart';
import '../../utils/geohash.dart';
import '../../widgets/book_cover.dart';

/// Riverpod handle for the lookup service — overridable in widget tests.
final openLibraryServiceProvider =
    Provider<OpenLibraryService>((ref) => OpenLibraryService());

/// Add a book (mock #1d, spec §6): search or ISBN → Open Library prefill →
/// user confirms language + condition (both required). Manual entry uses the
/// same fields. Visibility defaults ON. Covers are generated placeholders.
class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _yearController = TextEditingController();
  final _pagesController = TextEditingController();
  final _publisherController = TextEditingController();
  final _isbnController = TextEditingController();

  Timer? _debounce;
  List<OpenLibraryBook> _results = [];
  bool _searching = false;
  bool _saving = false;

  /// Whether the form was prefilled from an Open Library match.
  bool _matched = false;
  bool _manualMode = false;

  String? _language;
  BookCondition? _condition;
  bool _visible = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _pagesController.dispose();
    _publisherController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  bool get _showForm => _matched || _manualMode;

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _authorController.text.trim().isNotEmpty &&
      _language != null &&
      _condition != null &&
      !_saving;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final q = query.trim();
      if (q.length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final results =
          await ref.read(openLibraryServiceProvider).searchBooks(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _selectMatch(OpenLibraryBook book) {
    setState(() {
      _matched = true;
      _manualMode = false;
      _results = [];
      _searchController.text = book.title;
      _titleController.text = book.title;
      _authorController.text = book.author ?? '';
      _yearController.text = book.publishYear?.toString() ?? '';
      _pagesController.text = book.pages?.toString() ?? '';
      _publisherController.text = book.publisher ?? '';
      _isbnController.text = book.isbn ?? '';
    });
  }

  Future<void> _save() async {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(currentProfileProvider);
    if (currentUser == null || !_canSave) return;

    setState(() => _saving = true);

    final centroidLat = profile?.centroidLat;
    final centroidLng = profile?.centroidLng;

    final book = Book(
      id: '',
      ownerId: currentUser.uid,
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      year: int.tryParse(_yearController.text.trim()),
      pages: int.tryParse(_pagesController.text.trim()),
      publisher: _publisherController.text.trim().isEmpty
          ? null
          : _publisherController.text.trim(),
      isbn: _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.trim(),
      language: _language,
      condition: _condition!,
      visible: _visible,
      source: _matched ? BookSource.scan : BookSource.manual,
      postalCode: profile?.postalCode,
      locationLat: centroidLat,
      locationLng: centroidLng,
      geohash: (centroidLat != null && centroidLng != null)
          ? Geohash.encode(centroidLat, centroidLng)
          : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created =
        await ref.read(bookActionsProvider.notifier).createBook(book);
    if (!mounted) return;
    setState(() => _saving = false);

    if (created != null) {
      ref.invalidate(myBooksProvider);
      ref.invalidate(booksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${created.title} is on your shelf'),
          backgroundColor: AppColors.green,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add the book. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final languages = <String>{
      ...?profile?.languages,
      ...NeighborhoodLanguages.quick,
    }.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Add a book'),
        actions: [
          if (!_manualMode)
            TextButton(
              key: const Key('enter_manually'),
              onPressed: () => setState(() {
                _manualMode = true;
                _matched = false;
                _results = [];
              }),
              child: const Text('Enter manually'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_manualMode) ...[
              TextField(
                key: const Key('lookup_field'),
                controller: _searchController,
                onChanged: _onQueryChanged,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Title or ISBN',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.ink3, size: 20),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Point at the cover or the ISBN barcode — or type it here.',
                style: AppTypography.sansRegular.copyWith(
                  fontSize: 12,
                  color: AppColors.ink3,
                ),
              ),
              const SizedBox(height: 12),
              ..._results.map((result) => _MatchTile(
                    key: Key('match_${result.title}'),
                    book: result,
                    onTap: () => _selectMatch(result),
                  )),
            ],
            if (_matched) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                    Text(
                      'We found it — Open Library match',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 12.5,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_showForm) ...[
              const SizedBox(height: 18),
              _FieldLabel('Title'),
              TextField(
                key: const Key('title_field'),
                controller: _titleController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Author'),
              TextField(
                key: const Key('author_field'),
                controller: _authorController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Year'),
                        TextField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Pages'),
                        TextField(
                          controller: _pagesController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel('Publisher'),
              TextField(controller: _publisherController),
              const SizedBox(height: 20),
              _FieldLabel('Language of this copy'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: languages.map((language) {
                  final selected = _language == language;
                  return GestureDetector(
                    key: Key('add_language_$language'),
                    onTap: () => setState(() => _language = language),
                    child: _SelectableChip(
                        label: language, selected: selected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _FieldLabel('Condition'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BookCondition.values.map((condition) {
                  final selected = _condition == condition;
                  return GestureDetector(
                    key: Key('condition_${condition.value}'),
                    onTap: () => setState(() => _condition = condition),
                    child: _SelectableChip(
                        label: condition.displayName, selected: selected),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: SwitchListTile(
                  key: const Key('visible_toggle'),
                  value: _visible,
                  onChanged: (v) => setState(() => _visible = v),
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppColors.green,
                  title: Text(
                    'Visible on my shelf',
                    style: AppTypography.sansSemiBold.copyWith(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('add_to_shelf'),
                onPressed: _canSave ? _save : null,
                child: Text(_saving ? 'Adding…' : 'Add to my shelf'),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quick language options shared with neighborhood setup.
class NeighborhoodLanguages {
  static const quick = ['Türkçe', 'English', 'Deutsch', 'Français'];
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.sansSemiBold.copyWith(
          fontSize: 12.5,
          color: AppColors.ink2,
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _SelectableChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.greenTint : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.green : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.sansBold.copyWith(
          fontSize: 13,
          color: selected ? AppColors.green : AppColors.ink2,
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final OpenLibraryBook book;
  final VoidCallback onTap;

  const _MatchTile({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 48,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 68,
                  height: 96,
                  child:
                      BookCover(title: book.title, author: book.author ?? ''),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansBold.copyWith(
                      fontSize: 14,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (book.author != null) book.author,
                      if (book.publishYear != null) '${book.publishYear}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 12,
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink3, size: 20),
          ],
        ),
      ),
    );
  }
}
