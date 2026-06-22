import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  late TextEditingController _locationController;
  BookCondition? _condition;
  String? _selectedLanguage;
  double? _locationLat;
  double? _locationLng;
  bool _isLocating = false;
  bool _initialized = false;

  static const _languageOptions = ['English', 'Türkçe', 'Deutsch', 'Other'];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initControllers(Book book) {
    if (_initialized) return;
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author);
    _locationController = TextEditingController(text: book.locationText ?? '');
    _condition = book.condition;
    _selectedLanguage = _languageOptions.contains(book.language)
        ? book.language
        : (book.language != null && book.language!.isNotEmpty ? 'Other' : null);
    _locationLat = book.locationLat;
    _locationLng = book.locationLng;
    _initialized = true;
  }

  Future<void> _useCurrentLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      _locationLat = position.latitude;
      _locationLng = position.longitude;

      String label = 'Current location';
      try {
        final placemarks =
            await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[];
          if (p.postalCode != null && p.postalCode!.isNotEmpty) {
            parts.add(p.postalCode!);
          }
          if (p.locality != null && p.locality!.isNotEmpty) {
            parts.add(p.locality!);
          }
          if (parts.isEmpty && p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
            parts.add(p.administrativeArea!);
          }
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {}

      _locationController.text = label;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save(Book book) async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve location coordinates if manually typed
    String locationText = _locationController.text.trim();
    double? locationLat = _locationLat;
    double? locationLng = _locationLng;

    if (locationLat == null && locationText.isNotEmpty) {
      try {
        final locations = await locationFromAddress(locationText);
        if (locations.isNotEmpty) {
          locationLat = locations.first.latitude;
          locationLng = locations.first.longitude;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find that location. Please try a different address.')),
          );
        }
        return;
      }
    }

    if (locationLat == null || locationLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set a location for this book.')),
        );
      }
      return;
    }

    if (_selectedLanguage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a language for this book.')),
        );
      }
      return;
    }

    final updated = book.copyWith(
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      language: _selectedLanguage,
      locationText: locationText,
      locationLat: locationLat,
      locationLng: locationLng,
      condition: _condition,
    );

    final result = await ref.read(bookActionsProvider.notifier).updateBook(updated);
    if (result != null && mounted) {
      ref.invalidate(bookProvider(widget.bookId));
      ref.invalidate(myBooksProvider);
      ref.invalidate(booksProvider);
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

                  // Language (required - dropdown)
                  _buildLabel('Language'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _languageOptions.map((lang) {
                      final isSelected = lang == _selectedLanguage;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedLanguage = lang),
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
                            lang,
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

                  // Location (required)
                  _buildLabel('Location'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _locationController,
                    onChanged: (_) {
                      _locationLat = null;
                      _locationLng = null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Postal code, address, or city',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Location is required';
                      }
                      return null;
                    },
                    style: AppTypography.sansRegular.copyWith(fontSize: 15.5, color: AppColors.ink),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _isLocating ? null : _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.paper2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLocating)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.rust),
                              ),
                            )
                          else
                            const Icon(Icons.my_location, size: 18, color: AppColors.rust),
                          const SizedBox(width: 8),
                          Text(
                            _isLocating ? 'Getting location…' : 'Use my current location',
                            style: AppTypography.sansBold.copyWith(fontSize: 14, color: AppColors.rust),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
