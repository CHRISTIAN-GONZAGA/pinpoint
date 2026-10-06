import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/design_system/plates.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/widgets/app_text_field.dart';
import 'package:pinpoint/core/widgets/primary_button.dart';
import 'package:pinpoint/core/widgets/secondary_button.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';

/// Inline login checks. Copy says what is wrong and how to fix it.
String? validateLoginEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Enter the email on your account.';
  }
  if (!email.contains('@')) {
    return 'Add an @ sign, like you@example.com.';
  }
  return null;
}

String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter your password.';
  }
  if (value.length < 8) {
    return 'Use at least 8 characters.';
  }
  return null;
}

/// Premium login screen with guest access option.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBiometricState);
  }

  Future<void> _loadBiometricState() async {
    final canUnlock = await ref.read(canUseBiometricUnlockProvider.future);
    if (!mounted) return;
    setState(() => _biometricAvailable = canUnlock);
    if (canUnlock) {
      final email = await ref.read(authLocalDataSourceProvider).getLastLoginEmail();
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final success = await ref.read(authNotifierProvider.notifier).unlockWithBiometrics();
    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock failed. Sign in with your password.')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authNotifierProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(authNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Login failed')),
      );
    }
  }

  Future<void> _continueAsGuest() async {
    await ref.read(authNotifierProvider.notifier).continueAsGuest();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.stageOf(brightness),
      body: Column(
        children: [
          ZigzagEdge(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: PlateCard(
                  color: AppColors.paperOf(brightness),
                  borderColor: AppColors.edgeOf(brightness),
                  padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFillOf(brightness),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.place, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pinpoint',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.inkOf(brightness),
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 0.95,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jeep routes, fares and places in Butuan City',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.inkSecondaryOf(brightness),
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sign in', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Keep your saved places and routes on every phone you use.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSecondaryOf(Theme.of(context).brightness),
                          ),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      autocorrect: false,
                      validator: validateLoginEmail,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      obscureText: _obscurePassword,
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: validateLoginPassword,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? true),
                            ),
                            const Text('Keep me signed in'),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.forgotPassword),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.primaryText
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_biometricAvailable) ...[
                      OutlinedButton.icon(
                        onPressed: auth.isLoading ? null : _unlockWithBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock with biometrics'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    PrimaryButton(
                      label: 'Sign in',
                      isLoading: auth.isLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Continue as guest',
                      onPressed: auth.isLoading ? null : _continueAsGuest,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text('New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
