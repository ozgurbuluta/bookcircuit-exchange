import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../services/open_library_service.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  ConsumerState<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _isbnController = TextEditingController();

  BookCondition _condition = BookCondition.good;
  File? _coverImage;
  String? _coverUrl;

  List<OpenLibraryBook> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  OpenLibraryBook? _selectedBook;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _isbnController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await OpenLibraryService.searchBooks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectBook(OpenLibraryBook book) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedBook = book;
      _titleController.text = book.title;
      _authorController.text = book.author ?? '';
      _descriptionController.text = book.description ?? '';
      _isbnController.text = book.isbn ?? '';
      _coverUrl = book.coverUrl;
      _coverImage = null;
      _searchResults = [];
      _searchController.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBook = null;
      _titleController.clear();
      _authorController.clear();
      _descriptionController.clear();
      _isbnController.clear();
      _coverUrl = null;
      _coverImage = null;
    });
  }

  Future<void> _pickCoverImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add book cover',
                style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.ink2),
              title: Text('Take photo', style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 600,
                  maxHeight: 900,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _coverImage = File(picked.path);
                    _coverUrl = null;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.ink2),
              title: Text('Choose from library', style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 600,
                  maxHeight: 900,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _coverImage = File(picked.path);
                    _coverUrl = null;
                  });
                }
              },
            ),
            if (_coverImage != null || _coverUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.rust),
                title: Text('Remove photo', style: AppTypography.sansSemiBold.copyWith(color: AppColors.rust)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _coverImage = null;
                    _coverUrl = null;
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final book = Book(
      id: '',
      userId: currentUser.uid,
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      condition: _condition,
      isbn: _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.trim(),
      coverImgUrl: _coverUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await ref.read(bookActionsProvider.notifier).createBook(book);
    if (created != null && mounted) {
      ref.invalidate(myBooksProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(bookActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add Book',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: actionState.isLoading ? null : _save,
            child: Text(
              'Save',
              style: AppTypography.sansBold.copyWith(
                fontSize: 15,
                color: AppColors.rust,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book search section
              _buildLabel('Search book library'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paper2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line, width: 0.5),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: _isSearching ? AppColors.rust : AppColors.ink3,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: AppTypography.sansRegular.copyWith(
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search by title or author...',
                                hintStyle: AppTypography.sansRegular.copyWith(
                                  fontSize: 15,
                                  color: AppColors.ink3,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          if (_isSearching)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.rust),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.line, width: 0.5)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final book = _searchResults[index];
                            return InkWell(
                              onTap: () => _selectBook(book),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  border: index > 0
                                      ? const Border(top: BorderSide(color: AppColors.line2, width: 0.5))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    if (book.coverUrl != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: CachedNetworkImage(
                                          imageUrl: book.coverUrl!,
                                          width: 40,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            width: 40,
                                            height: 56,
                                            color: AppColors.paper3,
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            width: 40,
                                            height: 56,
                                            color: AppColors.paper3,
                                            child: const Icon(Icons.book, size: 20, color: AppColors.ink3),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 40,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: AppColors.paper3,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.book, size: 20, color: AppColors.ink3),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book.title,
                                            style: AppTypography.sansSemiBold.copyWith(
                                              fontSize: 14,
                                              color: AppColors.ink,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (book.author != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              book.author!,
                                              style: AppTypography.sansRegular.copyWith(
                                                fontSize: 12,
                                                color: AppColors.ink3,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.add_circle_outline, size: 20, color: AppColors.rust),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              if (_selectedBook != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: AppColors.sage),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Book details auto-filled',
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: AppColors.sage,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearSelection,
                        child: Text(
                          'Clear',
                          style: AppTypography.sansSemiBold.copyWith(
                            fontSize: 13,
                            color: AppColors.ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Cover image picker
              Center(
                child: GestureDetector(
                  onTap: _pickCoverImage,
                  child: _coverImage != null || _coverUrl != null
                      ? Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.ink.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _coverImage != null
                                    ? Image.file(_coverImage!, fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: _coverUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: AppColors.paper3),
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.paper3,
                                          child: const Icon(Icons.broken_image, color: AppColors.ink3),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.rust,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          width: 120,
                          height: 180,
                          decoration: BoxDecoration(
                            color: AppColors.paper2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line, width: 1.5, style: BorderStyle.solid),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.ink3),
                              const SizedBox(height: 8),
                              Text(
                                'Add cover',
                                style: AppTypography.sansSemiBold.copyWith(
                                  fontSize: 12,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              _buildField(
                'Title',
                _titleController,
                required: true,
                hint: 'Enter book title',
              ),

              // Author
              _buildField(
                'Author',
                _authorController,
                required: true,
                hint: 'Enter author name',
              ),

              // Condition
              _buildLabel('Condition'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BookCondition.values.map((c) {
                  final isSelected = c == _condition;
                  return GestureDetector(
                    onTap: () => setState(() => _condition = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.ink : AppColors.paper2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? AppColors.ink : AppColors.line,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        c.displayName,
                        style: AppTypography.sansSemiBold.copyWith(
                          fontSize: 13,
                          color: isSelected ? AppColors.paper : AppColors.ink2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Description
              _buildField(
                'Description (optional)',
                _descriptionController,
                hint: 'Book summary or notes about your copy...',
                isMultiline: true,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.sansBold.copyWith(
        fontSize: 11.5,
        letterSpacing: 0.6,
        color: AppColors.ink3,
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 4 : 1,
            decoration: InputDecoration(hintText: hint),
            validator: required
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
            style: isMultiline
                ? AppTypography.serifRegular.copyWith(fontSize: 15.5, color: AppColors.ink)
                : AppTypography.sansRegular.copyWith(fontSize: 15.5, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
