import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/extensions/string_extensions.dart';
import '../../providers/auth_provider.dart';

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
  bool _useStudentNumber = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    context.unfocus();

    final authController = ref.read(authControllerProvider.notifier);

    bool success;
    if (_useStudentNumber) {
      success = await authController.signInWithStudentNumber(
        studentNumber: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await authController.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        context.showErrorSnackBar(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),

                    // App name
                    Text(
                      'ReadEng',
                      style: context.textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Sign in to continue reading',
                      style: context.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Toggle between email and student number
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Email'),
                          icon: Icon(Icons.email_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Student #'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                      ],
                      selected: {_useStudentNumber},
                      onSelectionChanged: (value) {
                        setState(() {
                          _useStudentNumber = value.first;
                          _emailController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Email/Student number input
                    TextFormField(
                      controller: _emailController,
                      keyboardType: _useStudentNumber
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _useStudentNumber ? 'Student Number' : 'Email',
                        prefixIcon: Icon(
                          _useStudentNumber
                              ? Icons.badge_outlined
                              : Icons.email_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) {
                          return _useStudentNumber
                              ? 'Please enter your student number'
                              : 'Please enter your email';
                        }
                        if (!_useStudentNumber && !value!.isValidEmail) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password input
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) {
                          return 'Please enter your password';
                        }
                        if (value!.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                // TODO: Implement forgot password
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    FilledButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In'),
                    ),

                    // Error display
                    if (authState.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          authState.error!,
                          style: TextStyle(
                            color: context.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],

                    // Dev Quick Login (only in debug mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Dev Quick Login',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Students row
                      Row(
                        children: [
                          Expanded(
                            child: _DevLoginButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _quickLogin(
                                        email: 'fresh@demo.com',
                                        password: 'Test1234',
                                      ),
                              icon: Icons.child_care,
                              label: 'Fresh',
                              subtitle: '0 XP',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DevLoginButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _quickLogin(
                                        email: 'active@demo.com',
                                        password: 'Test1234',
                                      ),
                              icon: Icons.school,
                              label: 'Active',
                              subtitle: '500 XP',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DevLoginButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _quickLogin(
                                        email: 'advanced@demo.com',
                                        password: 'Test1234',
                                      ),
                              icon: Icons.star,
                              label: 'Advanced',
                              subtitle: '5000 XP',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Teacher button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => _quickLogin(
                                    email: 'teacher@demo.com',
                                    password: 'Test1234',
                                  ),
                          icon: const Icon(Icons.person, size: 18),
                          label: const Text('Teacher'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickLogin({
    required String email,
    required String password,
  }) async {
    // Set to email mode and fill credentials
    setState(() {
      _useStudentNumber = false;
      _emailController.text = email;
      _passwordController.text = password;
    });

    // Login directly
    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.signInWithEmail(
      email: email,
      password: password,
    );

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        context.showErrorSnackBar(error);
      }
    }
  }
}

/// Dev login button widget for quick testing
class _DevLoginButton extends StatelessWidget {
  const _DevLoginButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
