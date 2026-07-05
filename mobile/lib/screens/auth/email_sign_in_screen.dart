import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Email-link sign-in (decision D2): enter email → link sent → check inbox.
/// No password anywhere (spec §5).
class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authProvider.notifier)
        .sendEmailLink(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Sign in with email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: authState.awaitingEmailLink
              ? _CheckYourEmail(email: _emailController.text.trim())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'We will email you a sign-in link. No password to remember.',
                        style: AppTypography.sansRegular.copyWith(
                          fontSize: 14,
                          color: AppColors.ink2,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('email_field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'you@example.com'),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          final valid =
                              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                          return valid ? null : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('send_link_button'),
                        onPressed: authState.isLoading ? null : _sendLink,
                        child: Text(
                            authState.isLoading ? 'Sending…' : 'Send sign-in link'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CheckYourEmail extends StatelessWidget {
  final String email;

  const _CheckYourEmail({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('check_email_state'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 56, color: AppColors.green),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: AppTypography.serifRegular.copyWith(
            fontSize: 22,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a sign-in link to $email. Open it on this device and you are in.',
          textAlign: TextAlign.center,
          style: AppTypography.sansRegular.copyWith(
            fontSize: 14,
            color: AppColors.ink2,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
