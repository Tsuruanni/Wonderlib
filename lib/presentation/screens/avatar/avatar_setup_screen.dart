import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../providers/avatar_provider.dart';

class AvatarSetupScreen extends ConsumerWidget {
  const AvatarSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bases = ref.watch(avatarBasesProvider);
    final controller = ref.watch(avatarControllerProvider);
    final isLoading = controller is AsyncLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                "Let's create your avatar!",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your character',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              bases.when(
                data: (baseList) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: baseList.map((base) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () async {
                                final error = await ref
                                    .read(avatarControllerProvider.notifier)
                                    .setBase(base.id);
                                if (error != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                  return;
                                }
                                if (context.mounted) {
                                  clearAvatarSetupGuard();
                                  context.go('/avatar-customize');
                                }
                              },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 140,
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: theme.colorScheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: base.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.network(
                                        base.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          base.name == 'male'
                                              ? Icons.man
                                              : Icons.woman,
                                          size: 64,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      base.name == 'male'
                                          ? Icons.man
                                          : Icons.woman,
                                      size: 64,
                                      color: theme.colorScheme.primary,
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              base.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Failed to load. Tap to retry.'),
              ),
              if (isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
