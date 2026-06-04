import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class EditBookScreen extends ConsumerStatefulWidget {
  final String bookId;

  const EditBookScreen({super.key, required this.bookId});

  @override
  ConsumerState<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends ConsumerState<EditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _descriptionController;
  late TextEditingController _isbnController;
  BookCondition? _condition;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  void _initControllers(Book book) {
    if (_initialized) return;
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author);
    _descriptionController = TextEditingController(text: book.description ?? '');
    _isbnController = TextEditingController(text: book.isbn ?? '');
    _condition = book.condition;
    _initialized = true;
  }

  Future<void> _save(Book book) async {
    if (!_formKey.currentState!.validate()) return;

    final updated = book.copyWith(
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isbn: _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.trim(),
      condition: _condition,
    );

    final result = await ref.read(bookActionsProvider.notifier).updateBook(updated);
    if (result != null && mounted) {
      ref.invalidate(bookProvider(widget.bookId));
      ref.invalidate(myBooksProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Book updated',
            style: AppTypography.sansRegular.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.sage,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));
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
          'Edit Book',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
        actions: [
          bookAsync.whenOrNull(
            data: (book) => book != null
                ? TextButton(
                    onPressed: actionState.isLoading ? null : () => _save(book),
                    child: Text(
                      'Save',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 15,
                        color: AppColors.rust,
                      ),
                    ),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(child: Text('Book not found'));
          }

          _initControllers(book);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover preview
                  Center(
                    child: BookCover(
                      imageUrl: book.coverImgUrl,
                      title: book.title,
                      author: book.author,
                      coverColorKey: book.coverColorKey,
                      width: 100,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  _buildField('Title', _titleController, required: true),

                  // Author
                  _buildField('Author', _authorController, required: true),

                  // ISBN
                  _buildField('ISBN (optional)', _isbnController),

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
                    isMultiline: true,
                    hint: 'Describe the condition of your copy...',
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
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
            decoration: InputDecoration(hintText: hint ?? 'Enter ${label.toLowerCase()}'),
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
