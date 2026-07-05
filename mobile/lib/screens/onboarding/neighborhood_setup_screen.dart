import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/neighborhood_service.dart';

/// Neighborhood setup (mock #3e, spec §5): valid postal code (geocoded to an
/// areaLabel) + at least one language. GPS only ever FILLS the postal field.
class NeighborhoodSetupScreen extends ConsumerStatefulWidget {
  const NeighborhoodSetupScreen({super.key});

  @override
  ConsumerState<NeighborhoodSetupScreen> createState() =>
      _NeighborhoodSetupScreenState();
}

class _NeighborhoodSetupScreenState
    extends ConsumerState<NeighborhoodSetupScreen> {
  final _postalController = TextEditingController();
  final Set<String> _selectedLanguages = {};
  final List<String> _extraLanguages = [];

  NeighborhoodResult? _resolved;
  bool _resolving = false;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    _selectedLanguages
        .addAll(NeighborhoodService.preselectLanguages(locale));
  }

  @override
  void dispose() {
    _postalController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _resolved != null && _selectedLanguages.isNotEmpty && !_saving;

  Future<void> _resolvePostal(String value) async {
    if (!NeighborhoodService.isPlausiblePostalCode(value)) {
      setState(() => _resolved = null);
      return;
    }
    setState(() => _resolving = true);
    final service = ref.read(neighborhoodServiceProvider);
    final result = await service.resolvePostalCode(value);
    if (!mounted) return;
    setState(() {
      _resolved = result;
      _resolving = false;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final service = ref.read(neighborhoodServiceProvider);
    final postal = await service.postalCodeFromDeviceLocation();
    if (!mounted) return;
    setState(() => _locating = false);

    if (postal == null || postal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not read a postal code from your location.')),
      );
      return;
    }
    _postalController.text = postal;
    await _resolvePostal(postal);
  }

  Future<void> _continue() async {
    final resolved = _resolved;
    final profile = ref.read(currentProfileProvider);
    if (resolved == null || profile == null) return;

    setState(() => _saving = true);
    final updated = profile.copyWith(
      postalCode: resolved.postalCode,
      areaLabel: resolved.areaLabel,
      languages: _selectedLanguages.toList(),
      centroidLat: resolved.lat,
      centroidLng: resolved.lng,
    );
    final ok = await ref.read(authProvider.notifier).updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      context.go(AppRoutes.firstShelf);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Try again.')),
      );
    }
  }

  Future<void> _showMoreLanguages() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: NeighborhoodService.moreLanguages
              .where((l) => !_selectedLanguages.contains(l))
              .map((l) => ListTile(
                    title: Text(l,
                        style: AppTypography.sansSemiBold
                            .copyWith(color: AppColors.ink)),
                    onTap: () => Navigator.pop(ctx, l),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _extraLanguages.add(picked);
        _selectedLanguages.add(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipLanguages = [
      ...NeighborhoodService.quickLanguages,
      ..._extraLanguages,
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'SET-UP · 1 OF 2',
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.8,
                color: AppColors.ink3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your corner of the city',
              style: AppTypography.serifRegular.copyWith(
                fontSize: 26,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Books show up by walking distance, so we start from your postal code.',
              style: AppTypography.sansRegular.copyWith(
                fontSize: 13.5,
                color: AppColors.ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Postal code',
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 12.5,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('postal_field'),
                    controller: _postalController,
                    onChanged: _resolvePostal,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: '34710',
                      suffixIcon: _resolving
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _resolved != null
                              ? const Icon(Icons.check_circle_outline,
                                  color: AppColors.green)
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const Key('use_location'),
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.near_me_outlined, size: 16),
                  label: const Text('Use my location'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Languages you read',
              style: AppTypography.sansSemiBold.copyWith(
                fontSize: 12.5,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...chipLanguages.map((language) {
                  final selected = _selectedLanguages.contains(language);
                  return GestureDetector(
                    key: Key('language_$language'),
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedLanguages.remove(language);
                      } else {
                        _selectedLanguages.add(language);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.greenTint : AppColors.surface,
                        border: Border.all(
                          color: selected ? AppColors.green : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        language,
                        style: AppTypography.sansBold.copyWith(
                          fontSize: 13,
                          color: selected ? AppColors.green : AppColors.ink2,
                        ),
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  key: const Key('more_languages'),
                  onTap: _showMoreLanguages,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+ More',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 13,
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              key: const Key('privacy_preview'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Neighbors will see ',
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink2,
                      ),
                    ),
                    TextSpan(
                      text: _resolved?.areaLabel ?? 'your neighborhood',
                      style: AppTypography.sansExtraBold.copyWith(
                        fontSize: 12.5,
                        color: AppColors.green,
                      ),
                    ),
                    TextSpan(
                      text: ' — never your street or your door.',
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 12.5,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              key: const Key('setup_continue'),
              onPressed: _canContinue ? _continue : null,
              child: Text(_saving ? 'Saving…' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
