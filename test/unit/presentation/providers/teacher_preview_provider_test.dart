import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio/presentation/providers/teacher_preview_provider.dart';
import 'package:owlio/presentation/providers/auth_provider.dart';

void main() {
  test('returns true when isTeacherProvider is true', () {
    final container = ProviderContainer(
      overrides: [
        isTeacherProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isTeacherPreviewModeProvider), isTrue);
  });

  test('returns false when isTeacherProvider is false', () {
    final container = ProviderContainer(
      overrides: [
        isTeacherProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isTeacherPreviewModeProvider), isFalse);
  });
}
