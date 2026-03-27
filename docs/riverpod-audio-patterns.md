# Riverpod Listener & Audio Patterns

Hard-won patterns from production bugs. Read this before modifying any provider lifecycle, audio playback, or reader screen code.

## Provider Lifecycle Gotchas

| Issue | Wrong | Correct |
|-------|-------|---------|
| Stale state across navigation | Non-autoDispose provider retains value | Reset provider on screen init OR use autoDispose |
| Modifying provider in lifecycle | `ref.read(x.notifier).state = y` in `didChangeDependencies` | Use `Future.microtask()` or `addPostFrameCallback` |
| Captured vs current value | Using local var in callback: `if (isInit) {...}` | Read current: `if (ref.read(provider)) {...}` |

## ref.listen Behavior

```dart
// ONLY fires when value CHANGES, NOT on initial subscription
ref.listen<bool>(myProvider, (previous, current) {
  // This will NOT fire if provider is already true when listener is set up!
});

// Handle both: listener for changes + check current value in postFrameCallback
ref.listen<bool>(chapterInitializedProvider, (prev, initialized) {
  if (initialized && !_hasInitialized) {
    _captureBaseline();
    _hasInitialized = true;
  }
});

WidgetsBinding.instance.addPostFrameCallback((_) {
  if (ref.read(chapterInitializedProvider) && !_hasInitialized) {
    _captureBaseline();
    _hasInitialized = true;
  }
});
```

## "New Items" Detection Pattern

When detecting items completed in THIS session vs loaded from DB:

```dart
// WRONG: _previousIds starts empty, ALL loaded items appear "new"
final newIds = currentIds.difference(_previousIds); // ALL items on first load!

// CORRECT: Capture baseline AFTER data loads, before tracking changes
bool _hasInitializedBaseline = false;
Set<String> _baselineIds = {};

ref.listen<bool>(dataLoadedProvider, (prev, loaded) {
  if (loaded && !_hasInitializedBaseline) {
    _baselineIds = ref.read(itemsProvider).keys.toSet();
    _hasInitializedBaseline = true;
  }
});

if (_hasInitializedBaseline) {
  final newIds = currentIds.difference(_baselineIds);
  if (newIds.isNotEmpty) {
    // These are genuinely new (completed this session)
  }
}
```

## Audio Auto-Play Rules

1. **Never auto-play on chapter load** - User must manually press play
2. **Auto-play after activity completion** - Only if user is in "listening mode"
3. **Auto-play after audio block completion** - Continue to next audio block
4. **Stop audio on navigation** - Call `audioSyncController.stop()` before navigating away

### Listening Mode Concept

`_isInListeningMode` tracks whether user is in an active listening session:

| Action | `isPlaying` | `_isInListeningMode` |
|--------|-------------|----------------------|
| Never pressed play | false | **false** |
| Pressed play | true | **true** |
| Audio completed | false | **true** (flow continues) |
| User pressed pause | false | **false** |
| User pressed stop | false | **false** |

**Auto-play only triggers if `_isInListeningMode == true`.**
This prevents auto-play when user completes activity without ever starting audio.

### Key Files

| File | Responsibility |
|------|----------------|
| `audio_sync_provider.dart` | Core audio playback, word-level audio, segment playback, auto-play orchestration |
| `content_block_list.dart` | Listens for completions, scrolls to next block, calls `onActivityCompleted()` |
| `reader_screen.dart` | Initializes chapter state, stops audio on navigation |

**Note:** Auto-play logic is integrated into `AudioSyncController` (no separate auto-play provider).

## Auto-Scroll Follow Mode

Word-level karaoke scroll stops when user scrolls manually:

| Action | `isFollowingScroll` | Behavior |
|--------|---------------------|----------|
| User presses play | `true` | Scroll follows active word |
| Audio plays, word changes | `true` | Scroll updates |
| User scrolls manually | `false` | Scroll stops, audio continues |
| User presses play again | `true` | Scroll resumes from current word |

### User Scroll Detection

```dart
// reader_body.dart - NotificationListener
if (notification is ScrollStartNotification) {
  if (notification.dragDetails != null) {
    // User initiated scroll (finger drag) - not programmatic
    ref.read(audioSyncControllerProvider.notifier).disableFollowScroll();
  }
}
```

**Key insight:** `dragDetails != null` only set for finger drags. `Scrollable.ensureVisible()` (programmatic scroll) returns `null`.

### State Location

- `AudioSyncState.isFollowingScroll` - scroll follow state
- `AudioSyncController.disableFollowScroll()` - disable follow
- `AudioSyncController.play()` - enable follow (`isFollowingScroll = true`)

### Guard in WordHighlightText

```dart
void didUpdateWidget(...) {
  if (widget.isFollowingScroll &&  // Guard
      widget.activeWordIndex != _previousActiveIndex) {
    _scrollToActiveWord();
  }
}
```
