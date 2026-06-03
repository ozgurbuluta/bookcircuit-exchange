import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';

class EditBookScreen extends ConsumerWidget {
  final String bookId;

  const EditBookScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));

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
          TextButton(
            onPressed: () {
              // Save changes
              context.pop();
            },
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
      body: bookAsync.when(
        data: (book) => book != null
            ? const Center(child: Text('Edit book form here'))
            : const Center(child: Text('Book not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
