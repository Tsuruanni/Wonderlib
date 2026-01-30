import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/extensions/string_extensions.dart';
import '../../providers/auth_provider.dart';

class SchoolCodeScreen extends ConsumerStatefulWidget {
  const SchoolCodeScreen({super.key});

  @override
  ConsumerState<SchoolCodeScreen> createState() => _SchoolCodeScreenState();
}

class _SchoolCodeScreenState extends ConsumerState<SchoolCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authController = ref.read(authControllerProvider.notifier);
      final isValid = await authController.validateSchoolCode(
        _codeController.text.trim(),
      );

      if (!mounted) return;

      if (isValid) {
        context.go(
          AppRoutes.login,
          extra: _codeController.text.trim().toUpperCase(),
        );
      } else {
        context.showErrorSnackBar('Invalid school code');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar('Failed to validate school code');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    // Logo placeholder
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
                      'Enter your school code to continue',
                      style: context.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // School code input
                    TextFormField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'School Code',
                        hintText: 'e.g., YILDIZ2024',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) {
                          return 'Please enter your school code';
                        }
                        if (!value!.isValidSchoolCode) {
                          return 'Invalid school code format';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _validateAndContinue(),
                    ),
                    const SizedBox(height: 24),

                    // Continue button
                    FilledButton(
                      onPressed: _isLoading ? null : _validateAndContinue,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
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
