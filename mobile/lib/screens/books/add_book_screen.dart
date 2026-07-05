import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../config/theme.dart';
import '../../models/book.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../services/google_books_service.dart';

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
  final _locationController = TextEditingController();

  BookCondition _condition = BookCondition.good;
  String? _selectedLanguage;
  File? _coverImage;
  String? _coverUrl;

  static const _languageOptions = ['English', 'Türkçe', 'Deutsch', 'Other'];

  // Per-book location. Coordinates power the distance/radius search; the text is
  // shown to other users. Defaults to the owner's profile location.
  double? _locationLat;
  double? _locationLng;
  bool _isLocating = false;

  List<GoogleBook> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  GoogleBook? _selectedBook;

  @override
  void initState() {
    super.initState();
    // Prefill the location from the user's saved profile location.
    final profile = ref.read(currentProfileProvider);
    if (profile != null) {
      _locationController.text = profile.formattedLocation ?? '';
      _locationLat = profile.locationLat;
      _locationLng = profile.locationLng;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _isbnController.dispose();
    _locationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Capture the device's current GPS position and reverse-geocode it into a
  /// readable place name.
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

      // Best-effort reverse geocoding for a friendly label with postal code.
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
      } catch (_) {/* keep generic label */}

      _locationController.text = label;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
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

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await GoogleBooksService.searchBooks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectBook(GoogleBook book) {
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
      _selectedLanguage = null;
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

    // Upload a locally-picked cover image to Storage and use its URL.
    String? coverUrl = _coverUrl;
    if (_coverImage != null) {
      try {
        coverUrl = await FirebaseService.uploadBookCover(_coverImage!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload cover image: $e')),
          );
        }
        return;
      }
    }

    // Resolve the listing location. Location is required - geocode manually-typed
    // text into coordinates so distance search works.
    String locationText = _locationController.text.trim();
    double? locationLat = _locationLat;
    double? locationLng = _locationLng;

    // If user typed a location but we don't have coordinates, try to geocode it
    if (locationLat == null && locationText.isNotEmpty) {
      try {
        final locations = await locationFromAddress(locationText);
        if (locations.isNotEmpty) {
          locationLat = locations.first.latitude;
          locationLng = locations.first.longitude;
        }
      } catch (_) {
        // If geocoding fails, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find that location. Please try a different address or use current location.')),
          );
        }
        return;
      }
    }

    // Ensure we have coordinates
    if (locationLat == null || locationLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set a location for this book.')),
        );
      }
      return;
    }

    // Ensure language is selected
    if (_selectedLanguage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a language for this book.')),
        );
      }
      return;
    }

    final book = Book(
      id: '',
      ownerId: currentUser.uid,
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      condition: _condition,
      isbn: _isbnController.text.trim().isEmpty
          ? null
          : _isbnController.text.trim(),
      language: _selectedLanguage,
      source: BookSource.manual,
      locationLat: locationLat,
      locationLng: locationLng,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await ref.read(bookActionsProvider.notifier).createBook(book);
    if (created != null && mounted) {
      ref.invalidate(myBooksProvider);
      ref.invalidate(booksProvider);
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add book. Please try again.')),
      );
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

              // Location (required)
              _buildLabel('Location'),
              const SizedBox(height: 7),
              TextFormField(
                controller: _locationController,
                onChanged: (_) {
                  // Manual edit invalidates any GPS coordinates; they'll be
                  // re-geocoded from the typed text on save.
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
