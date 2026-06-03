import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _websiteController;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;

    final updated = currentProfile.copyWith(
      fullName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      website: _websiteController.text.trim(),
    );

    final success = await ref.read(authProvider.notifier).updateProfile(updated);
    if (success && mounted) {
      context.pop();
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
              Stack(
                children: [
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
              const SizedBox(height: 8),
              Text(
                'Change photo',
                style: AppTypography.sansSemiBold.copyWith(
                  fontSize: 13.5,
                  color: AppColors.rust,
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
