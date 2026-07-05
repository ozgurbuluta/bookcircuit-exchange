import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Welcome / sign-in (mock #3a): Piri greets, then Apple / Google / email.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.terracotta),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _PiriSpeechBubble(
                      text:
                          "Hello — I'm Piri, the club turtle. I'll walk you in. Slowly, of course.",
                    ),
                    const SizedBox(height: 22),
                    SvgPicture.asset(
                      'assets/images/piri_welcome.svg',
                      width: 186,
                      height: 129,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Turtle Turning Pages',
                      textAlign: TextAlign.center,
                      style: AppTypography.serifRegular.copyWith(
                        fontSize: 27,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Good books travel slowly.',
                      style: AppTypography.sansRegular.copyWith(
                        fontSize: 13,
                        color: AppColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthButton(
                    key: const Key('apple_sign_in'),
                    label: 'Continue with Apple',
                    icon: const Icon(Icons.apple, size: 20, color: AppColors.bg),
                    background: AppColors.ink,
                    foreground: AppColors.bg,
                    enabled: !authState.isLoading,
                    onPressed: () =>
                        ref.read(authProvider.notifier).signInWithApple(),
                  ),
                  const SizedBox(height: 9),
                  _AuthButton(
                    key: const Key('google_sign_in'),
                    label: 'Continue with Google',
                    icon: Text(
                      'G',
                      style: AppTypography.sansExtraBold.copyWith(
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    background: AppColors.surface,
                    foreground: AppColors.ink,
                    bordered: true,
                    enabled: !authState.isLoading,
                    onPressed: () =>
                        ref.read(authProvider.notifier).signInWithGoogle(),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: const Key('email_sign_in'),
                    onPressed: authState.isLoading
                        ? null
                        : () => context.push(AppRoutes.emailSignIn),
                    child: Text(
                      'Use email instead',
                      style: AppTypography.sansBold.copyWith(
                        fontSize: 13,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'By continuing you accept the club rules — be kind, show up, pass books on.',
                    textAlign: TextAlign.center,
                    style: AppTypography.sansRegular.copyWith(
                      fontSize: 10.5,
                      color: AppColors.ink3,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiriSpeechBubble extends StatelessWidget {
  final String text;

  const _PiriSpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.sansRegular.copyWith(
          fontSize: 13,
          height: 1.5,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color background;
  final Color foreground;
  final bool bordered;
  final bool enabled;
  final VoidCallback onPressed;

  const _AuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.bordered = false,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? background : background.withValues(alpha: 0.6),
          border: bordered ? Border.all(color: AppColors.line) : null,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.sansBold.copyWith(
                fontSize: 14,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
