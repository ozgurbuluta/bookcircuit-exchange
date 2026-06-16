import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../models/detected_book.dart';
import '../../services/bookshelf_scanner_service.dart';

/// Entry screen for the "Scan a shelf" flow: capture/pick a photo of a
/// bookcase, run AI detection, then hand the results to the review screen.
class ScanShelfScreen extends ConsumerStatefulWidget {
  const ScanShelfScreen({super.key});

  @override
  ConsumerState<ScanShelfScreen> createState() => _ScanShelfScreenState();
}

class _ScanShelfScreenState extends ConsumerState<ScanShelfScreen> {
  final _imagePicker = ImagePicker();
  bool _isScanning = false;
  String _statusText = '';

  Future<void> _pick(ImageSource source) async {
    HapticFeedback.selectionClick();
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      // Higher resolution than a cover shot so spine text stays legible.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() {
      _isScanning = true;
      _statusText = 'Reading the spines…';
    });

    try {
      final bytes = await picked.readAsBytes();
      final mimeType =
          picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final List<DetectedBook> books =
          await BookshelfScannerService.scanShelf(bytes, mimeType: mimeType);

      if (!mounted) return;

      if (books.isEmpty) {
        setState(() => _isScanning = false);
        _showError(
          'No books recognized',
          'Try a closer, well-lit photo where the spines or covers are clearly visible.',
        );
        return;
      }

      // Replace this screen with the review screen so back returns home.
      context.pushReplacement(AppRoutes.scanReview, extra: books);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showError(
        'Scan failed',
        'Something went wrong reading that photo. Please check your connection and try again.\n\n$e',
      );
    }
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper2,
        title: Text(title,
            style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink)),
        content: Text(message,
            style: AppTypography.sansRegular.copyWith(fontSize: 14, color: AppColors.ink2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: AppTypography.sansBold.copyWith(color: AppColors.rust)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: _isScanning ? null : () => context.pop(),
        ),
        title: Text(
          'Scan a Shelf',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
      ),
      body: _isScanning ? _buildScanning() : _buildIntro(),
    );
  }

  Widget _buildScanning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.rust),
          ),
          const SizedBox(height: 24),
          Text(
            _statusText,
            style: AppTypography.serifSemiBold.copyWith(fontSize: 17, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'This can take a few seconds',
            style: AppTypography.sansRegular.copyWith(fontSize: 13, color: AppColors.ink3),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_stories_outlined, size: 64, color: AppColors.sage),
          ),
          const SizedBox(height: 24),
          Text(
            'Add your whole shelf at once',
            textAlign: TextAlign.center,
            style: AppTypography.serifSemiBold.copyWith(fontSize: 22, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'Take a photo of your bookshelf and we’ll recognize the books automatically. '
            'You can review and edit everything before adding them to your library.',
            textAlign: TextAlign.center,
            style: AppTypography.sansRegular.copyWith(
                fontSize: 14.5, height: 1.4, color: AppColors.ink2),
          ),
          const SizedBox(height: 28),
          _tip(Icons.wb_sunny_outlined, 'Good lighting, no glare on the spines'),
          _tip(Icons.straighten_outlined, 'Get close enough to read the titles'),
          _tip(Icons.collections_bookmark_outlined,
              'One shelf at a time works best (up to ${BookshelfScannerService.maxBooks} books)'),
          const SizedBox(height: 32),
          _primaryButton(
            icon: Icons.camera_alt_outlined,
            label: 'Take photo',
            onTap: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          _secondaryButton(
            icon: Icons.photo_library_outlined,
            label: 'Choose from library',
            onTap: () => _pick(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.ink3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppTypography.sansRegular.copyWith(fontSize: 14, color: AppColors.ink2)),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.rust,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(label,
                style: AppTypography.sansBold.copyWith(fontSize: 15.5, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.paper2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink2),
            const SizedBox(width: 10),
            Text(label,
                style: AppTypography.sansBold.copyWith(fontSize: 15.5, color: AppColors.ink2)),
          ],
        ),
      ),
    );
  }
}
