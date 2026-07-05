import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _locationController = TextEditingController(text: profile?.formattedLocation ?? '');
    _websiteController = TextEditingController(text: profile?.website ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.ink2),
              title: Text('Take photo', style: AppTypography.sansSemiBold.copyWith(color: AppColors.ink)),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => _selectedImage = File(picked.path));
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
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() => _selectedImage = File(picked.path));
                }
              },
            ),
            if (_selectedImage != null || ref.read(currentProfileProvider)?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.rust),
                title: Text('Remove photo', style: AppTypography.sansSemiBold.copyWith(color: AppColors.rust)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedImage = null);
                  // TODO: Also mark for removal on save
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

    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;

    // Upload a newly-picked avatar to Storage and use its download URL.
    String? avatarUrl = currentProfile.avatarUrl;
    if (_selectedImage != null) {
      try {
        avatarUrl = await FirebaseService.uploadAvatar(_selectedImage!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $e')),
          );
        }
        return;
      }
    }

    final updated = currentProfile.copyWith(
      fullName: _nameController.text.trim(),
      avatarUrl: avatarUrl,
    );

    final success = await ref.read(authProvider.notifier).updateProfile(updated);
    if (success && mounted) {
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.rust),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit profile',
          style: AppTypography.serifSemiBold.copyWith(fontSize: 18, color: AppColors.ink),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: authState.isLoading ? null : _save,
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
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    if (_selectedImage != null)
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      UserAvatar(profile: profile, size: 84),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.rust,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.paper, width: 2.5),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Text(
                  'Change photo',
                  style: AppTypography.sansSemiBold.copyWith(
                    fontSize: 13.5,
                    color: AppColors.rust,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Fields
              _buildField('Full name', _nameController),
              _buildField('Bio', _bioController, isMultiline: true),
              _buildField('Location', _locationController),
              _buildField('Website', _websiteController),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.sansBold.copyWith(
              fontSize: 11.5,
              letterSpacing: 0.6,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            maxLines: isMultiline ? 3 : 1,
            decoration: InputDecoration(
              hintText: 'Enter $label',
            ),
            style: isMultiline
                ? AppTypography.serifRegular.copyWith(fontSize: 15.5, color: AppColors.ink)
                : AppTypography.sansRegular.copyWith(fontSize: 15.5, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
