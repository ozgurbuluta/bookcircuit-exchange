import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ProposeSwapScreen extends ConsumerStatefulWidget {
  final String bookId;

  const ProposeSwapScreen({super.key, required this.bookId});

  @override
  ConsumerState<ProposeSwapScreen> createState() => _ProposeSwapScreenState();
}

class _ProposeSwapScreenState extends ConsumerState<ProposeSwapScreen> {
  String? _selectedBookId;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _sendOffer() async {
    if (_selectedBookId == null) return;

    final targetBook = ref.read(bookProvider(widget.bookId)).value;
    if (targetBook == null) return;

    final trade = await ref.read(tradeActionsProvider.notifier).createTrade(
          partnerId: targetBook.userId,
          myBookIds: [_selectedBookId!],
          theirBookIds: [widget.bookId],
          message: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );

    if (trade != null && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swap offer sent to ${targetBook.owner?.displayName ?? 'owner'}'),
          backgroundColor: AppColors.sage,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetBookAsync = ref.watch(bookProvider(widget.bookId));
    final myBooksAsync = ref.watch(myBooksProvider);
    final actionState = ref.watch(tradeActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.rust),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Offer a swap',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target book
                  SectionHeader(title: "You'd like"),
                  const SizedBox(height: 12),
                  targetBookAsync.when(
                    data: (book) => book != null
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.paper2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line, width: 0.5),
                            ),
                            child: Row(
                              children: [
                                BookCover(
                                  imageUrl: book.coverImgUrl,
                                  title: book.title,
                                  author: book.author,
                                  width: 44,
                                  borderRadius: 4,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        style: AppTypography.serifSemiBold.copyWith(
                                          fontSize: 16,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      Text(
                                        'from ${book.owner?.displayName ?? 'owner'}',
                                        style: AppTypography.sansRegular.copyWith(
                                          fontSize: 13,
                                          color: AppColors.ink2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text('Book not found'),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error loading book'),
                  ),

                  const SizedBox(height: 24),

                  // My books selection
                  SectionHeader(title: 'Offer from your shelf'),
                  const SizedBox(height: 12),
                  myBooksAsync.when(
                    data: (books) {
                      final available = books.where((b) => b.status == BookStatus.available).toList();
                      return SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final book = available[index];
                            final isSelected = _selectedBookId == book.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedBookId = book.id),
                                child: SizedBox(
                                  width: 100,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(7),
                                              color: isSelected
                                                  ? AppColors.rust.withValues(alpha: 0.12)
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected ? AppColors.rust : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: BookCover(
                                              imageUrl: book.coverImgUrl,
                                              title: book.title,
                                              author: book.author,
                                              width: 92,
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: AppColors.rust,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppColors.paper2, width: 2),
                                                ),
                                                child: const Icon(Icons.check, size: 13, color: Colors.white),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        book.title,
                                        style: AppTypography.serifSemiBold.copyWith(
                                          fontSize: 13,
                                          color: AppColors.ink,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Error loading books'),
                  ),

                  const SizedBox(height: 24),

                  // Note
                  SectionHeader(title: 'Add a note'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Introduce yourself and your offer...',
                    ),
                    style: AppTypography.serifRegular.copyWith(
                      fontSize: 15.5,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Send button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.9),
              border: const Border(top: BorderSide(color: AppColors.line, width: 0.5)),
            ),
            child: AppButton(
              onPressed: _selectedBookId != null ? _sendOffer : null,
              isLoading: actionState.isLoading,
              width: double.infinity,
              child: Text(_selectedBookId != null ? 'Send swap offer' : 'Choose a book to offer'),
            ),
          ),
        ],
      ),
    );
  }
}
