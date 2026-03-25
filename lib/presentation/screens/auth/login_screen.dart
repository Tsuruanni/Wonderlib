import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rive/rive.dart';

import '../../../app/theme.dart';
import '../../../core/utils/extensions/context_extensions.dart';
import '../../../core/utils/extensions/string_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/common/game_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Rive animation controllers (0.7 = 30% slower)
  late final _owlAnim1 = SimpleAnimation('Timeline 1', autoplay: true);
  late final _owlAnim2 = SimpleAnimation('Timeline 2', autoplay: true);

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    context.unfocus();

    final input = _identityController.text.trim();
    final password = _passwordController.text;

    // @ detection: contains @ → email, otherwise → username (synthetic email)
    final email = input.contains('@') ? input : '$input@owlio.local';

    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.signInWithEmail(
      email: email,
      password: password,
    );

    if (!success && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) {
        showAppSnackBar(context, error, type: SnackBarType.error);
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
                      child: SizedBox(
                        width: 220,
                        height: 180,
                        child: ClipRect(
                          child: Transform.scale(
                            scale: 1.6,
                            child: RiveAnimation.asset(
                              'assets/animations/mascot/flying-owl-mascot-animation.riv',
                              fit: BoxFit.contain,
                              controllers: [_owlAnim1, _owlAnim2],
                              onInit: (_) {
                                _owlAnim1.instance?.animation.speed = 0.7;
                                _owlAnim2.instance?.animation.speed = 0.7;
                              },
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn().scale(delay: 200.ms),

                    const SizedBox(height: 24),
                    Text(
                      'Owlio',
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms).moveY(begin: 10, end: 0),
                    
                    Text(
                      'Fly Through Stories, Glide Through Words.',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: AppColors.neutralText,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms).moveY(begin: 10, end: 0),
                    
                    const SizedBox(height: 48),

                    // --- Form Fields ---
                    TextFormField(
                      controller: _identityController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Username or Email',
                        prefixIcon: Icon(
                          Icons.person_rounded,
                          color: AppColors.neutralText,
                        ),
                      ),
                      validator: (value) {
                        if (value.isNullOrEmpty) {
                          return 'Enter your username or email';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 500.ms),
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
                         showAppSnackBar(context, 'Working on it!');
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
                      // Core accounts
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DevChip(
                            label: 'Fresh (0 XP)',
                            onTap: () => _quickLogin('frestu1', 'Test1234'),
                          ),
                          _DevChip(
                            label: 'Active (500 XP)',
                            onTap: () => _quickLogin('actstu1', 'Test1234'),
                          ),
                          _DevChip(
                            label: 'Advanced (5K)',
                            onTap: () => _quickLogin('advstu1', 'Test1234'),
                            color: AppColors.gemBlue,
                          ),
                          _DevChip(
                            label: 'Teacher',
                            onTap: () => _quickLogin('teacher@demo.com', 'Test1234'),
                            color: AppColors.secondary,
                          ),
                          _DevChip(
                            label: 'Admin',
                            onTap: () => _quickLogin('admin@demo.com', 'Test1234'),
                            color: AppColors.streakOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'CLASS 5-A',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DevChip(label: 'Elif (8.2K)', onTap: () => _quickLogin('eliyil1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Ahmet (3.2K)', onTap: () => _quickLogin('ahmkay1', 'Test1234')),
                          _DevChip(label: 'Zeynep (1.8K)', onTap: () => _quickLogin('zeydem1', 'Test1234')),
                          _DevChip(label: 'Can (12.5K)', onTap: () => _quickLogin('canozt1', 'Test1234'), color: AppColors.gemBlue),
                          _DevChip(label: 'Selin (250)', onTap: () => _quickLogin('selars1', 'Test1234')),
                          _DevChip(label: 'Emre (6.8K)', onTap: () => _quickLogin('emrcel1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Defne (950)', onTap: () => _quickLogin('defsah1', 'Test1234')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'CLASS 5-B',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DevChip(label: 'Berk (9.5K)', onTap: () => _quickLogin('berayd1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Yagmur (4.2K)', onTap: () => _quickLogin('yagkoc1', 'Test1234')),
                          _DevChip(label: 'Arda (2.4K)', onTap: () => _quickLogin('ardyil1', 'Test1234')),
                          _DevChip(label: 'Nil (7.4K)', onTap: () => _quickLogin('nilerd1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Mert (150)', onTap: () => _quickLogin('mertop1', 'Test1234')),
                          _DevChip(label: 'Deniz (5.8K)', onTap: () => _quickLogin('denozk1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Ece (1.2K)', onTap: () => _quickLogin('ecepol1', 'Test1234')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'CLASS 6-A',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _DevChip(label: 'Ali (15K)', onTap: () => _quickLogin('alikor1', 'Test1234'), color: AppColors.gemBlue),
                          _DevChip(label: 'Irem (6.2K)', onTap: () => _quickLogin('ireaks1', 'Test1234'), color: AppColors.cardLegendary),
                          _DevChip(label: 'Burak (3.8K)', onTap: () => _quickLogin('burdog1', 'Test1234')),
                          _DevChip(label: 'Asya (11K)', onTap: () => _quickLogin('asycet1', 'Test1234'), color: AppColors.gemBlue),
                          _DevChip(label: 'Kerem (450)', onTap: () => _quickLogin('kertas1', 'Test1234')),
                          _DevChip(label: 'Melis (2K)', onTap: () => _quickLogin('melyal1', 'Test1234')),
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

  /// Quick login for dev shortcuts — works with both usernames and emails
  /// since _login() handles @ detection automatically.
  Future<void> _quickLogin(String identity, String password) async {
    setState(() {
      _identityController.text = identity;
      _passwordController.text = password;
    });
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
