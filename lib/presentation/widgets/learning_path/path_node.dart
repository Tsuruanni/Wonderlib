import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../utils/app_icons.dart';

/// Node types on the learning path.
enum NodeType {
  wordList(Icons.translate_rounded, AppColors.secondary, 'voc'),
  book(Icons.auto_stories_rounded, Color(0xFF1E88E5), 'book'),
  game(Icons.sports_esports_rounded, Color(0xFF8E24AA), 'game'),
  treasure(Icons.diamond_rounded, Color(0xFFFF9800), 'treasure');

  const NodeType(this.icon, this.color, this._assetPrefix);
  final IconData icon;
  final Color color;
  final String? _assetPrefix;

  /// Returns the asset path for a given node state, or null if no custom assets.
  String? assetFor(NodeState state, {bool pressed = false}) {
    if (_assetPrefix == null) return null;
    if (pressed) return 'assets/icons/${_assetPrefix}_pressed.png';
    return switch (state) {
      NodeState.locked => 'assets/icons/${_assetPrefix}_locked.png',
      NodeState.available || NodeState.active => 'assets/icons/${_assetPrefix}_active.png',
      NodeState.completed => 'assets/icons/${_assetPrefix}_completed.png',
    };
  }
}

/// Visual state of a node.
enum NodeState { locked, available, active, completed }

/// Universal node widget for the learning path.
/// Renders all node types and states. Receives all data as props — no providers.
///
/// Nodes (without [unitNumber]) show a popup card on tap
/// instead of a text label — the popup contains the name + action button.
class PathNode extends StatefulWidget {
  const PathNode({
    super.key,
    required this.type,
    required this.state,
    this.label,
    this.onTap,
    this.starCount = 0,
    this.unitNumber,
    this.scale = 1.0,
    this.totalSessions,
    this.bestAccuracy,
    this.bestScore,
    this.hasAssignment = false,
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;

  /// When set, displays this number inside the node instead of the icon.
  final int? unitNumber;

  /// Scale factor for the node. 1.0 = default (64px), 0.5 = half size.
  final double scale;

  /// Progress stats — shown in popup card when available.
  final int? totalSessions;
  final double? bestAccuracy;
  final int? bestScore;

  /// Whether this node has an active assignment.
  final bool hasAssignment;

  bool get hasProgress => totalSessions != null && totalSessions! > 0;

  static const baseSize = 64.0;
  static const baseWidth = 140.0;

  /// Captured by [_onTapUp] so the router can zoom from the tapped node.
  static Offset? lastTapGlobalPosition;

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode>
    with SingleTickerProviderStateMixin {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isNodePressed = false;

  /// Tracks the currently open popup so only one shows at a time.
  static _PathNodeState? _activePopupState;

  // Bounce animation for active nodes
  late final AnimationController _bounceController;
  late final Animation<double> _bounce;

  bool get _isActive => widget.state == NodeState.active;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _isActive ? 1200 : 2400),
    );
    _bounce = Tween(begin: 0.0, end: _isActive ? 5.0 : 2.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    if (widget.state != NodeState.locked) {
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PathNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _bounceController.stop();
      _bounceController.duration = Duration(milliseconds: _isActive ? 1200 : 2400);
      _bounce = Tween(begin: 0.0, end: _isActive ? 5.0 : 2.0).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
      );
    }
    final shouldBounce = widget.state != NodeState.locked;
    if (shouldBounce && !_bounceController.isAnimating) {
      _bounceController.repeat(reverse: true);
    } else if (!shouldBounce && _bounceController.isAnimating) {
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  /// Whether this node shows a popup on tap instead of calling onTap directly.
  bool get _showsPopup =>
      widget.unitNumber == null && widget.state != NodeState.locked;

  Color get _popupColor {
    if (widget.state == NodeState.completed) return AppColors.primary;
    return widget.type.color;
  }

  String get _popupButtonText {
    if (widget.state == NodeState.completed) {
      return switch (widget.type) {
        NodeType.book => 'READ AGAIN',
        NodeType.treasure => 'CLAIMED',
        NodeType.game => 'PLAY AGAIN',
        _ => 'PRACTICE AGAIN',
      };
    }
    return switch (widget.type) {
      NodeType.wordList => 'START',
      NodeType.book => 'READ',
      NodeType.game => 'PLAY',
      NodeType.treasure => 'CLAIM',
    };
  }

  // ── Press handling ───────────────────────────────────────

  void _onTapDown(TapDownDetails _) {
    setState(() => _isNodePressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isNodePressed = false);
    PathNode.lastTapGlobalPosition = details.globalPosition;
    _handleTap();
  }

  void _onTapCancel() {
    setState(() => _isNodePressed = false);
  }

  // ── Popup lifecycle ──────────────────────────────────────

  void _handleTap() {
    if (_showsPopup) {
      // Toggle popup on tap
      if (_overlayEntry != null) {
        _dismissPopup();
      } else {
        _showPopup();
      }
    } else {
      widget.onTap?.call();
    }
  }

  void _showPopup() {
    // Dismiss any other open popup first
    _activePopupState?._dismissPopup();

    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        onTap: _dismissPopup,
        behavior: HitTestBehavior.translucent,
        child: SizedBox.expand(
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                offset: const Offset(0, 10),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  builder: (_, value, child) => Transform.scale(
                    scale: value,
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                  child: _PopupCard(
                    label: widget.label ?? '',
                    color: _popupColor,
                    buttonText: _popupButtonText,
                    totalSessions: widget.totalSessions,
                    bestAccuracy: widget.bestAccuracy,
                    bestScore: widget.bestScore,
                    onStart: () {
                      _dismissPopup();
                      widget.onTap?.call();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    _activePopupState = this;
  }

  void _dismissPopup() {
    if (_overlayEntry?.mounted ?? false) {
      _overlayEntry!.remove();
    }
    _overlayEntry = null;
    if (_activePopupState == this) _activePopupState = null;
  }

  @override
  void dispose() {
    _dismissPopup();
    _bounceController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.state == NodeState.locked;
    final isCompleted = widget.state == NodeState.completed;
    final s = widget.scale;
    final nodeSize = PathNode.baseSize * s;
    final nodeWidth = PathNode.baseWidth * s;

    return MouseRegion(
      cursor: isLocked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: isLocked ? null : (_) => setState(() => _isNodePressed = true),
      onExit: isLocked ? null : (_) => setState(() => _isNodePressed = false),
      child: GestureDetector(
      onTapDown: isLocked ? null : _onTapDown,
      onTapUp: isLocked ? null : _onTapUp,
      onTapCancel: isLocked ? null : _onTapCancel,
      child: SizedBox(
        width: nodeWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star row above the node
            if (widget.type == NodeType.wordList &&
                widget.starCount > 0 &&
                !isLocked)
              Padding(
                padding: EdgeInsets.only(bottom: 2 * s),
                child: _StarRow(count: widget.starCount, scale: s),
              ),
            // Node circle — wrapped in target for popup positioning
            // Active nodes get a gentle bounce animation
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _bounce,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -_bounce.value * s),
                    child: child,
                  ),
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: _NodeCircle(
                      type: widget.type,
                      state: widget.state,
                      size: nodeSize,
                      unitNumber: widget.unitNumber,
                      isPressed: _isNodePressed && !isCompleted,
                    ),
                  ),
                ),
                // Assignment badge — position varies per node
                if (widget.hasAssignment && widget.state != NodeState.completed)
                  Builder(builder: (_) {
                    final badgeSize = 90.0 * s;
                    // Deterministic "random" based on label so position is stable across rebuilds
                    final hash = (widget.label ?? '').hashCode;
                    final isRight = hash.isEven;
                    final verticalOffset = ((hash % 5) - 2) * 4.0 * s; // -8 to +8
                    // Push fully outside the node with a small gap
                    final horizontalPush = (nodeSize / 2 + 4 * s);
                    return Positioned(
                      left: isRight ? null : -horizontalPush - badgeSize / 2,
                      right: isRight ? -horizontalPush - badgeSize / 2 : null,
                      top: (nodeSize / 2 - badgeSize / 2) + verticalOffset,
                      child: Image.asset(
                        'assets/icons/quest.png',
                        width: badgeSize,
                        height: badgeSize,
                        filterQuality: FilterQuality.high,
                      ),
                    );
                  }),
              ],
            ),
            // Label — only for unit-number nodes (unit map)
            if (!_showsPopup && widget.label != null)
              Padding(
                padding: EdgeInsets.only(top: 6 * s),
                child: Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium(color: isLocked
                        ? AppColors.neutralText
                        : isCompleted
                            ? AppColors.primary
                            : AppColors.black).copyWith(fontSize: 13 * s),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Popup card
// ════════════════════════════════════════════════════════════

/// Tooltip-style card shown below a tapped node.
class _PopupCard extends StatelessWidget {
  const _PopupCard({
    required this.label,
    required this.color,
    required this.buttonText,
    required this.onStart,
    this.totalSessions,
    this.bestAccuracy,
    this.bestScore,
  });

  final String label;
  final Color color;
  final String buttonText;
  final VoidCallback onStart;
  final int? totalSessions;
  final double? bestAccuracy;
  final int? bestScore;

  bool get _hasProgress => totalSessions != null && totalSessions! > 0;

  @override
  Widget build(BuildContext context) {
    final darkColor = _darken(color, 0.15);

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Triangle pointer ▲
          CustomPaint(
            size: const Size(18, 9),
            painter: _TriangleUpPainter(color: color),
          ),
          // Card body
          Container(
            width: 200,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: darkColor,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  offset: const Offset(0, 6),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleMedium(color: Colors.white).copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Progress stats
                if (_hasProgress) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          icon: const Icon(Icons.repeat_rounded, color: AppColors.neutralText, size: 14),
                          label: 'Sessions',
                          value: '$totalSessions',
                        ),
                        if (bestAccuracy != null) ...[
                          const SizedBox(height: 6),
                          _StatRow(
                            icon: AppIcons.star(size: 14),
                            label: 'Best Accuracy',
                            value: '${bestAccuracy!.toInt()}%',
                          ),
                        ],
                        if (bestScore != null) ...[
                          const SizedBox(height: 6),
                          _StatRow(
                            icon: Image.asset(
                              'assets/icons/gem_outline_256.png',
                              width: 14,
                              height: 14,
                            ),
                            label: 'Top Gems',
                            value: '$bestScore XP',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Action button — hidden when word list is mastered (100% accuracy)
                if (bestAccuracy == null || bestAccuracy! < 100) ...[
                  const SizedBox(height: 10),
                  _Pressable3DButton(
                    text: buttonText,
                    textColor: color,
                    onTap: onStart,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// A white 3D button with press-down effect.
/// Uses opposing top/bottom margins so total height stays constant
/// — prevents the parent card from stretching on press.
class _Pressable3DButton extends StatefulWidget {
  const _Pressable3DButton({
    required this.text,
    required this.textColor,
    required this.onTap,
  });

  final String text;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_Pressable3DButton> createState() => _Pressable3DButtonState();
}

class _Pressable3DButtonState extends State<_Pressable3DButton> {
  bool _pressed = false;
  static const _shadow = 3.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: double.infinity,
        // Top/bottom margins swap so total height never changes
        margin: EdgeInsets.only(
          top: _pressed ? _shadow : 0,
          bottom: _pressed ? 0 : _shadow,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: Offset(0, _pressed ? 0 : _shadow),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          widget.text,
          textAlign: TextAlign.center,
          style: AppTextStyles.button(color: widget.textColor).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class _TriangleUpPainter extends CustomPainter {
  _TriangleUpPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════
// 3D Node Circle
// ════════════════════════════════════════════════════════════

/// The circular 3D node icon with glossy sphere effect.
/// Supports [isPressed] for tap-down visual feedback.
class _NodeCircle extends StatelessWidget {
  const _NodeCircle({
    required this.type,
    required this.state,
    required this.size,
    this.unitNumber,
    this.isPressed = false,
  });

  final NodeType type;
  final NodeState state;
  final double size;
  final int? unitNumber;
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    // Unit-number nodes: PNG background + number overlay
    if (unitNumber != null) {
      return SizedBox(
        width: size,
        height: size + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              isPressed
                  ? 'assets/icons/unit_nodes_pressed.png'
                  : 'assets/icons/unit_nodes.png',
              width: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            Padding(
              padding: EdgeInsets.only(bottom: size * 0.08),
              child: Text(
                '$unitNumber',
                style: AppTextStyles.titleMedium(color: Colors.white).copyWith(fontSize: size * 0.38, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ],
        ),
      );
    }

    // Check for custom asset-based node
    final assetPath = type.assetFor(state, pressed: isPressed);
    if (assetPath != null) {
      return SizedBox(
        width: size,
        height: size + 6,
        child: Image.asset(
          assetPath,
          width: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    final isLocked = state == NodeState.locked;
    final isCompleted = state == NodeState.completed;

    // Completed nodes turn green and stay "pressed down"
    final Color mainColor;
    if (isLocked) {
      mainColor = const Color(0xFFB0BEC5);
    } else if (isCompleted) {
      mainColor = AppColors.primary;
    } else {
      mainColor = type.color;
    }

    final darkColor = _darken(mainColor, isLocked ? 0.12 : 0.20);
    final lightColor = _lighten(mainColor, isLocked ? 0.05 : 0.18);

    // Press / completed = sunk look: reduced shadow, shifted down
    final sunk = isCompleted || isPressed;
    final shadowOffset = sunk ? 2.0 : 6.0;
    final topPad = sunk ? 4.0 : 0.0;

    return SizedBox(
      width: size,
      height: size + 6,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 60),
        padding: EdgeInsets.only(top: topPad),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background glow halo
              if (!isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: mainColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              // Main 3D circle with gradient + extrusion shadow
              AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.25, -0.35),
                    radius: 0.85,
                    colors: [lightColor, mainColor, darkColor],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  boxShadow: [
                    // 3D extrusion (hard shadow, no blur)
                    BoxShadow(
                      color: darkColor,
                      offset: Offset(0, shadowOffset),
                      blurRadius: 0,
                    ),
                    // Soft ambient glow
                    if (!isLocked)
                      BoxShadow(
                        color: mainColor.withValues(alpha: 0.3),
                        offset: Offset(0, shadowOffset),
                        blurRadius: 12,
                      ),
                  ],
                ),
                child: Center(child: _buildContent(isLocked, isCompleted)),
              ),
              // Glossy highlight (upper arc)
              Positioned(
                top: size * 0.08,
                left: size * 0.18,
                child: IgnorePointer(
                  child: Container(
                    width: size * 0.64,
                    height: size * 0.32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(size),
                        bottom: Radius.circular(size * 0.6),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white
                              .withValues(alpha: isLocked ? 0.12 : 0.35),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isLocked, bool isCompleted) {
    if (isLocked) {
      return Icon(
        Icons.lock_rounded,
        color: const Color(0xFF78909C),
        size: size * 0.42,
      );
    }

    if (isCompleted) {
      return Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: size * 0.48,
      );
    }

    // Show unit number if provided, otherwise show icon
    if (unitNumber != null) {
      return Text(
        '$unitNumber',
        style: AppTextStyles.titleMedium(color: Colors.white).copyWith(fontSize: size * 0.38, fontWeight: FontWeight.w900, height: 1),
      );
    }

    return Icon(
      type.icon,
      color: Colors.white,
      size: size * 0.45,
    );
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

// ════════════════════════════════════════════════════════════
// Stat row (popup card)
// ════════════════════════════════════════════════════════════

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption(color: AppColors.neutralText),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodySmall(color: AppColors.black).copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// Stars
// ════════════════════════════════════════════════════════════

/// Stylized star row above a word list node — gold with dark border.
/// Earned stars animate in a looping staggered entrance: scale-bounce + fade in,
/// hold fully lit, fade out together, pause, repeat. Unearned stars stay outlined.
class _StarRow extends StatefulWidget {
  const _StarRow({required this.count, this.scale = 1.0});

  final int count;
  final double scale;

  @override
  State<_StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<_StarRow>
    with SingleTickerProviderStateMixin {
  // Per-star entrance: scale 0.3 → 1.0 (elastic bounce) + linear fade in.
  // Stagger between stars: 300ms. All earned stars hold lit for 1400ms,
  // then fade out together over 400ms, then 700ms pause, then repeat.
  static const _entryMs = 400;
  static const _staggerMs = 300;
  static const _holdMs = 2000;
  static const _fadeOutMs = 400;
  static const _fadeStaggerMs = 80; // exit ripple — star 0 fades first
  static const _pauseMs = 300;
  static const _breathAmp = 0.035; // ±3.5% scale breathing during hold
  static const _breathPeriodMs = 1100; // one full breath = ~1.1s

  late final AnimationController _controller;

  bool get _hasEarnedStars => widget.count >= 1;

  int _cycleFor(int count) {
    if (count < 1) return _entryMs; // idle — controller won't repeat
    final lastEntryEnd = _staggerMs * (count - 1) + _entryMs;
    final lastFadeEnd =
        lastEntryEnd + _holdMs + (count - 1) * _fadeStaggerMs + _fadeOutMs;
    return lastFadeEnd + _pauseMs;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _cycleFor(widget.count)),
    );
    if (_hasEarnedStars) _controller.repeat();
  }

  @override
  void didUpdateWidget(_StarRow old) {
    super.didUpdateWidget(old);
    if (widget.count != old.count) {
      _controller.stop();
      _controller
        ..duration = Duration(milliseconds: _cycleFor(widget.count))
        ..value = 0;
      if (_hasEarnedStars) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opacity + scale for earned star at [index].
  /// Precondition: [index] < widget.count.
  ({double opacity, double scale}) _transformFor(int index) {
    final cycleMs = _cycleFor(widget.count);
    final ms = _controller.value * cycleMs;
    final entryStart = (_staggerMs * index).toDouble();
    final entryEnd = entryStart + _entryMs;
    final allLitStart = _staggerMs * (widget.count - 1) + _entryMs;
    final holdEnd = allLitStart + _holdMs;
    // Exit ripples leftward — rightmost (highest index) fades first
    final fadeStart =
        holdEnd + (widget.count - 1 - index) * _fadeStaggerMs;
    final fadeEnd = fadeStart + _fadeOutMs;

    // Entry: not yet
    if (ms < entryStart) return (opacity: 0, scale: 0.3);
    // Entry: two-phase dramatic pop — scale 0.3 → 1.25 (peak) → 1.0 (settle)
    // Opacity reaches full by 50% of entry so star is fully visible at peak size.
    if (ms < entryEnd) {
      final phase = (ms - entryStart) / _entryMs;
      const peakScale = 1.25;
      const peakAt = 0.6;
      double scale;
      if (phase < peakAt) {
        // Grow past final size
        final t = phase / peakAt;
        scale = 0.3 + (peakScale - 0.3) * Curves.easeOutQuad.transform(t);
      } else {
        // Settle back down to 1.0
        final t = (phase - peakAt) / (1 - peakAt);
        scale = peakScale - (peakScale - 1.0) * Curves.easeOutQuad.transform(t);
      }
      final opacity = (phase / 0.5).clamp(0.0, 1.0);
      return (opacity: opacity, scale: scale);
    }
    // Waiting for later stars to finish entry — sit at scale 1
    if (ms < allLitStart) return (opacity: 1, scale: 1);
    // All lit — synchronized breathing pulse
    if (ms < holdEnd) {
      final t = (ms - allLitStart) / _breathPeriodMs;
      final breath = 1.0 + _breathAmp * math.sin(t * 2 * math.pi);
      return (opacity: 1, scale: breath);
    }
    // Waiting to start this star's fade (staggered exit)
    if (ms < fadeStart) return (opacity: 1, scale: 1);
    // Fade out
    if (ms < fadeEnd) {
      final phase = (ms - fadeStart) / _fadeOutMs;
      return (opacity: 1 - Curves.easeIn.transform(phase), scale: 1);
    }
    return (opacity: 0, scale: 0.3); // gone, waiting for cycle end (pause)
  }

  Padding _starSlot(int i, Widget child) => Padding(
        padding: EdgeInsets.only(
          left: i == 0 ? 0 : 1 * widget.scale,
          // Middle star raised slightly for crown effect
          bottom: i == 1 ? 4 * widget.scale : 0,
        ),
        child: child,
      );

  Widget _outlineStar() => Icon(
        Icons.star_outline_rounded,
        size: 18 * widget.scale,
        color: AppColors.neutral,
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final earned = i < widget.count;
          if (!earned) {
            return _starSlot(i, _outlineStar());
          }
          // Earned slot: outlined placeholder behind + animated gold on top.
          final t = _transformFor(i);
          return _starSlot(
            i,
            Stack(
              alignment: Alignment.center,
              children: [
                _outlineStar(),
                Opacity(
                  opacity: t.opacity,
                  child: Transform.scale(
                    scale: t.scale,
                    child: AppIcons.star(size: 22 * widget.scale),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
