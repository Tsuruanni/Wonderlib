import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';

/// Node types on the learning path.
enum NodeType {
  wordList(Icons.translate_rounded, AppColors.secondary),
  book(Icons.auto_stories_rounded, Color(0xFF1E88E5)),
  game(Icons.sports_esports_rounded, Color(0xFF8E24AA)),
  treasure(Icons.diamond_rounded, Color(0xFFFF9800));

  const NodeType(this.icon, this.color);
  final IconData icon;
  final Color color;
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
  });

  final NodeType type;
  final NodeState state;
  final String? label;
  final VoidCallback? onTap;
  final int starCount;

  /// When set, displays this number inside the node instead of the icon.
  final int? unitNumber;

  static const _size = 64.0;

  @override
  State<PathNode> createState() => _PathNodeState();
}

class _PathNodeState extends State<PathNode> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isNodePressed = false;

  /// Tracks the currently open popup so only one shows at a time.
  static _PathNodeState? _activePopupState;

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
        _ => 'PRACTICE',
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

  void _onTapUp(TapUpDetails _) {
    setState(() => _isNodePressed = false);
    _handleTap();
  }

  void _onTapCancel() {
    setState(() => _isNodePressed = false);
  }

  // ── Popup lifecycle ──────────────────────────────────────

  void _handleTap() {
    if (_showsPopup) {
      _togglePopup();
    } else {
      widget.onTap?.call();
    }
  }

  void _togglePopup() {
    if (_overlayEntry != null) {
      _dismissPopup();
      return;
    }
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
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.state == NodeState.locked;
    final isCompleted = widget.state == NodeState.completed;

    return GestureDetector(
      onTapDown: isLocked ? null : _onTapDown,
      onTapUp: isLocked ? null : _onTapUp,
      onTapCancel: isLocked ? null : _onTapCancel,
      child: SizedBox(
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star row above the node
            if (widget.type == NodeType.wordList &&
                widget.starCount > 0 &&
                !isLocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _StarRow(count: widget.starCount),
              ),
            // Node circle — wrapped in target for popup positioning
            CompositedTransformTarget(
              link: _layerLink,
              child: _NodeCircle(
                type: widget.type,
                state: widget.state,
                size: PathNode._size,
                unitNumber: widget.unitNumber,
                isPressed: _isNodePressed && !isCompleted,
              ),
            ),
            // Label — only for unit-number nodes (unit map)
            if (!_showsPopup && widget.label != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isLocked
                        ? AppColors.neutralText
                        : isCompleted
                            ? AppColors.primary
                            : AppColors.black,
                  ),
                ),
              ),
          ],
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
  });

  final String label;
  final Color color;
  final String buttonText;
  final VoidCallback onStart;

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
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Action button — pressable
                _Pressable3DButton(
                  text: buttonText,
                  textColor: color,
                  onTap: onStart,
                ),
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
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: widget.textColor,
            letterSpacing: 0.5,
          ),
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
        style: GoogleFonts.nunito(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
        ),
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
// Stars
// ════════════════════════════════════════════════════════════

/// Stylized star row above a word list node — gold with dark border.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Padding(
          padding: EdgeInsets.only(
            left: i == 0 ? 0 : 1,
            // Middle star raised slightly for crown effect
            bottom: i == 1 ? 4 : 0,
          ),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: filled ? 22 : 18,
            color: filled ? const Color(0xFFFFD700) : AppColors.neutral,
            shadows: filled
                ? const [
                    // Dark gold border (4 directions)
                    Shadow(
                      color: Color(0xFFB8860B),
                      blurRadius: 0,
                      offset: Offset(1.2, 0),
                    ),
                    Shadow(
                      color: Color(0xFFB8860B),
                      blurRadius: 0,
                      offset: Offset(-1.2, 0),
                    ),
                    Shadow(
                      color: Color(0xFFB8860B),
                      blurRadius: 0,
                      offset: Offset(0, 1.2),
                    ),
                    Shadow(
                      color: Color(0xFFB8860B),
                      blurRadius: 0,
                      offset: Offset(0, -1.2),
                    ),
                    // Glow
                    Shadow(
                      color: Color(0x66FF8F00),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
