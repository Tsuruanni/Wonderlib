import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import 'steps/avatar_step.dart';

/// Multi-step onboarding flow shown on first login.
/// Uses a PageView so new steps can be added easily.
/// Current steps: [AvatarStep]
/// Future steps: welcome intro, name input, tutorial, etc.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Add new steps here — order matters
  late final List<Widget> _steps = [
    AvatarStep(onComplete: _nextStep),
    // Future steps:
    // WelcomeStep(onComplete: _nextStep),
    // NameStep(onComplete: _nextStep),
    // TutorialStep(onComplete: _nextStep),
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // All steps done — go to main app
      clearAvatarSetupGuard();
      context.go(AppRoutes.avatarCustomize);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator (only show if more than 1 step)
            if (_steps.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Row(
                  children: List.generate(_steps.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _currentStep
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _steps,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
