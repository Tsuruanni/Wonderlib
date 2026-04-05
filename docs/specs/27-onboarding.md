# Onboarding System

## Overview

Step-based onboarding flow for first-time students. Controlled by `onboarding_enabled` system setting (default: false). When enabled, students with `avatar_base_id = NULL` are redirected to `/avatar-setup` on login.

## Current State

**Status:** Disabled (onboarding_enabled = false)

### Implemented
- `OnboardingScreen` — PageView-based step container with step indicator bar
- `AvatarStep` — Gender selection (Boy/Girl), calls `set_avatar_base` RPC which randomly equips free items
- Router redirect guard (splash + router) gated by `onboarding_enabled` system setting
- Route: `/avatar-setup` → `OnboardingScreen`

### Planned Steps (Not Yet Implemented)
- Welcome/intro screen
- Name input
- App tutorial / feature tour
- Notification permissions
- Interest selection

## Architecture

```
lib/presentation/screens/onboarding/
├── onboarding_screen.dart          ← PageView controller, step indicator
└── steps/
    └── avatar_step.dart            ← Gender selection (implemented)
    // Future:
    // welcome_step.dart
    // name_step.dart
    // tutorial_step.dart
```

### Adding a New Step

1. Create widget in `steps/` with `onComplete` callback
2. Add to `_steps` list in `OnboardingScreen`
3. Step indicator auto-updates (hidden when only 1 step)

### System Setting

| Key | Value | Category | Description |
|-----|-------|----------|-------------|
| `onboarding_enabled` | `false` | general | Enable onboarding flow for new students |

Toggle via admin panel: System Settings → General → onboarding_enabled.

### Flow

```
Login → Splash → check onboarding_enabled setting
  → false: skip to /vocabulary (current behavior)
  → true: check avatar_base_id
    → not null: skip to /vocabulary
    → null: redirect to /avatar-setup → OnboardingScreen
      → AvatarStep → set base → /avatar-customize
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/presentation/screens/onboarding/onboarding_screen.dart` | Step container |
| `lib/presentation/screens/onboarding/steps/avatar_step.dart` | Gender selection step |
| `lib/app/router.dart` | Redirect guard + route definition |

## Dependencies

- `set_avatar_base` RPC (random equips free items per required category)
- `system_settings` table (`onboarding_enabled` key)
- `clearAvatarSetupGuard()` to release redirect after completion
