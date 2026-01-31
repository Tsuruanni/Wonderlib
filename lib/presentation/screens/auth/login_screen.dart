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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
