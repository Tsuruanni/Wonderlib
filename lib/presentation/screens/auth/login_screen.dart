import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/extensions/string_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/game_button.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error,
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Animated Header ---
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 80,
                          color: AppColors.primary,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            duration: 2000.ms,
                            begin: const Offset(0.95, 0.95),
                            end: const Offset(1.05, 1.05),
                            curve: Curves.easeInOut,
                          ),
                    ).animate().fadeIn().scale(delay: 200.ms),

                    const SizedBox(height: 24),
                    Text(
                      'Wonderlib',
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms).moveY(begin: 10, end: 0),
                    
                    Text(
                      'Learn English the fun way!',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms).moveY(begin: 10, end: 0),
                    
                    const SizedBox(height: 48),

                    // --- Form Fields ---
                    // Toggle
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.neutral.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.neutral, width: 2),
                          ),
                          child: Row(
                            children: [
                              _buildToggleOption(
                                'Email', 
                                Icons.email_rounded, 
                                !_useStudentNumber,
                              ),
                              _buildToggleOption(
                                'Student #', 
                                Icons.badge_rounded, 
                                _useStudentNumber,
                              ),
                            ],
                          ),
                        );
                      },
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 24),

                    // Inputs
                    TextFormField(
                      controller: _emailController,
                      keyboardType: _useStudentNumber
                          ? TextInputType.number
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _useStudentNumber ? 'Student Number' : 'Email',
                        prefixIcon: Icon(
                          _useStudentNumber
                              ? Icons.badge_rounded
                              : Icons.email_rounded,
                          color: AppColors.neutralText,
                        ),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) {
                          return _useStudentNumber
                              ? 'Enter your number'
                              : 'Enter your email';
                        }
                        if (!_useStudentNumber && !value!.isValidEmail) {
                          return 'Invalid email address';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 600.ms),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.neutralText),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: AppColors.neutralText,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) return 'Enter password';
                        if (value!.length < 6) return 'Too short (min 6)';
                        return null;
                      },
                      onFieldSubmitted: (_) => _login(),
                    ).animate().fadeIn(delay: 700.ms),
                    
                    const SizedBox(height: 32),

                    // --- Action Buttons ---
                    GameButton(
                      label: isLoading ? 'LOADING...' : 'GET STARTED',
                      onPressed: isLoading ? null : _login,
                      variant: GameButtonVariant.primary,
                      fullWidth: true,
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 16),
                    
                    GameButton(
                      label: 'I FORGOT MY PASSWORD',
                      onPressed: () {
                         // TODO: Implement forgot password
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Working on it!')),
                         );
                      },
                      variant: GameButtonVariant.neutral,
                      fullWidth: true,
                    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0),

                    // --- Dev Options ---
                    if (kDebugMode && !isLoading) ...[
                      const SizedBox(height: 48),
                      const Divider(),
                      Center(
                        child: Text(
                          'DEVELOPER SHORTCUTS',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DevChip(
                            label: 'Student 1',
                            onTap: () => _quickLogin('fresh@demo.com', 'Test1234'),
                          ),
                          _DevChip(
                            label: 'Teacher',
                            onTap: () => _quickLogin('teacher@demo.com', 'Test1234'),
                            color: AppColors.secondary,
                          ),
                        ],
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

  Widget _buildToggleOption(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _useStudentNumber = label == 'Student #';
            _emailController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14), // Slightly less than outer
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.neutralText,
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : AppColors.neutralText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickLogin(String email, String password) async {
    setState(() {
      _useStudentNumber = false;
      _emailController.text = email;
      _passwordController.text = password;
    });
    // Add small delay to visualize the autofill
    await Future.delayed(const Duration(milliseconds: 200));
    await _login();
  }
}

class _DevChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DevChip({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: (color ?? AppColors.primary).withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: color ?? AppColors.primary,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
