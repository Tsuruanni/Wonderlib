import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rive/rive.dart' hide Image, LinearGradient;

import '../../../app/text_styles.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/card.dart';
import '../../utils/ui_helpers.dart';

/// Rive asset name → card slot index.
const _imageSlots = {
  'C_K.png': 0,
  'C_Q.png': 1,
  'C_J.png': 2,
};

/// State transition → which card is now visible.
const _stateToCardIndex = {
  'jack2King': 0,
  'king2Queen': 1,
  'queen2Jack': 2,
};

/// Pre-built Rive artboard with card images already decoded.
class PreloadedRiveData {
  PreloadedRiveData(this.riveFile, this.imageMap);
  final RiveFile riveFile;
  final Map<String, Uint8List> imageMap;
}

/// Downloads card images, loads cards.riv, and decodes images into the file.
/// Call during glow phase so everything is instant when reveal starts.
Future<PreloadedRiveData> preloadRiveCards(List<PackCard> cards) async {
  // 1. Download images
  final imageMap = <String, Uint8List>{};
  final dio = Dio();
  try {
    await Future.wait(
      _imageSlots.entries.map((entry) async {
        final index = entry.value;
        if (index >= cards.length) return;
        final imageUrl = cards[index].card.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) return;
        try {
          if (imageUrl.startsWith('assets/')) {
            final data = await rootBundle.load(imageUrl);
            imageMap[entry.key] = data.buffer.asUint8List();
          } else {
            final response = await dio.get<List<int>>(
              imageUrl,
              options: Options(responseType: ResponseType.bytes),
            );
            if (response.data != null) {
              imageMap[entry.key] = Uint8List.fromList(response.data!);
            }
          }
        } catch (e) {
          debugPrint('[RivePack] Failed to load "${entry.key}": $e');
        }
      }),
    );
  } finally {
    dio.close();
  }

  // 2. Load Rive file + decode images in one shot
  final decodeCompleter = Completer<void>();
  var remaining = imageMap.length;
  if (remaining == 0) decodeCompleter.complete();

  final riveFile = await RiveFile.asset(
    'assets/animations/cards.riv',
    assetLoader: CallbackAssetLoader(
      (asset, embeddedBytes) async {
        if (asset is ImageAsset && imageMap.containsKey(asset.name)) {
          final bytes = imageMap[asset.name]!;
          final imgAsset = asset;

          if (embeddedBytes != null) {
            // Get original image dimensions
            final origCodec = await ui.instantiateImageCodec(embeddedBytes);
            final origFrame = await origCodec.getNextFrame();
            final origW = origFrame.image.width;
            final origH = origFrame.image.height;
            origFrame.image.dispose();

            // Decode new image at original dimensions — no PNG re-encode
            final newCodec = await ui.instantiateImageCodec(
              bytes,
              targetWidth: origW,
              targetHeight: origH,
            );
            final newFrame = await newCodec.getNextFrame();
            imgAsset.image = newFrame.image;
          } else {
            await asset.decode(bytes);
          }

          remaining--;
          if (remaining <= 0 && !decodeCompleter.isCompleted) {
            decodeCompleter.complete();
          }
          return true;
        }
        return false;
      },
    ),
  );

  // 3. Wait for all decodes to finish
  await decodeCompleter.future;

  return PreloadedRiveData(riveFile, imageMap);
}

/// Rive-powered card pack reveal with carousel animation.
class RivePackRevealWidget extends StatefulWidget {
  const RivePackRevealWidget({
    super.key,
    required this.cards,
    required this.preloadedData,
    required this.onCardRevealed,
    required this.onAllRevealed,
  });

  final List<PackCard> cards;
  final PreloadedRiveData preloadedData;
  final void Function(int index) onCardRevealed;
  final VoidCallback onAllRevealed;

  @override
  State<RivePackRevealWidget> createState() => _RivePackRevealWidgetState();
}

class _RivePackRevealWidgetState extends State<RivePackRevealWidget> {
  Artboard? _artboard;
  StateMachineController? _smController;

  int _currentIndex = 0;
  final Set<int> _seenIndices = {0};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initRive();
  }

  void _initRive() {
    try {
      final artboard = widget.preloadedData.riveFile.mainArtboard.instance();
      for (final fill in artboard.fills) {
        fill.paint.color = const Color(0x00000000);
      }

      final controller = StateMachineController.fromArtboard(
        artboard,
        'State Machine 1',
        onStateChange: _onRiveStateChange,
      );
      if (controller != null) {
        artboard.addController(controller);
      }

      widget.onCardRevealed(0);

      setState(() {
        _artboard = artboard;
        _smController = controller;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('RivePackRevealWidget init error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onRiveStateChange(String stateMachineName, String stateName) {
    final cardIndex = _stateToCardIndex[stateName];
    if (cardIndex == null || cardIndex >= widget.cards.length) return;

    if (!_seenIndices.contains(cardIndex)) {
      _seenIndices.add(cardIndex);
      widget.onCardRevealed(cardIndex);
    }

    if (mounted) setState(() => _currentIndex = cardIndex);
  }

  void _onContinue() {
    for (var i = 0; i < widget.cards.length; i++) {
      if (!_seenIndices.contains(i)) {
        widget.onCardRevealed(i);
      }
    }
    widget.onAllRevealed();
  }

  @override
  void dispose() {
    _smController?.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cardEpic),
      );
    }

    if (_error != null || _artboard == null) {
      return Center(
        child: Text(
          'Failed to load animation',
          style: AppTextStyles.bodyLarge(color: AppColors.white),
        ),
      );
    }

    final currentCard = _currentIndex < widget.cards.length
        ? widget.cards[_currentIndex]
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildWideLayout(currentCard);
        }
        return _buildNarrowLayout(currentCard);
      },
    );
  }

  Widget _buildRive({BoxFit fit = BoxFit.fitHeight}) {
    return Rive(
      artboard: _artboard!,
      fit: fit,
      enablePointerEvents: true,
    );
  }

  Widget _buildWideLayout(PackCard? currentCard) {
    return Stack(
      children: [
        // Rive — zoomed, shifted up
        Positioned(
          left: -80,
          right: -80,
          top: -160,
          bottom: -80,
          child: ClipRect(
            child: _buildRive(),
          ),
        ),

        // Card info overlay — right side, vertically centered
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentCard != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildCardInfo(currentCard),
                    ),
                  const SizedBox(height: 12),
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ),

      ],
    );
  }

  Widget _buildNarrowLayout(PackCard? currentCard) {
    return Column(
      children: [
        // Rive — zoomed via ClipRect + negative margins
        Expanded(
          flex: 5,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: SizedBox(
                width: 800,
                height: 800,
                child: _buildRive(fit: BoxFit.contain),
              ),
            ),
          ),
        ),

        // Card info + continue — scrollable, safe from overflow
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (currentCard != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCardInfo(currentCard),
                  ),
                const SizedBox(height: 12),
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────

  Widget _buildContinueButton() {
    return SizedBox(
      width: 220,
      height: 48,
      child: ElevatedButton(
        onPressed: _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardEpic,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.cardEpic.withValues(alpha: 0.4),
        ),
        child: Text(
          'CONTINUE',
          style: AppTextStyles.titleMedium().copyWith(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildCardInfo(PackCard packCard) {
    final card = packCard.card;
    final rarityColor = CardColors.getRarityColor(card.rarity);
    final rarityDark = CardColors.getRarityDarkColor(card.rarity);

    return Container(
      key: ValueKey('info_$_currentIndex'),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: rarityDark.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: rarity + badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  rarityColor.withValues(alpha: 0.25),
                  rarityDark.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      card.rarity.label.toUpperCase(),
                      style: AppTextStyles.caption(color: rarityColor).copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CardColors.getRarityStars(card.rarity),
                  style: TextStyle(fontSize: 12, color: rarityColor),
                ),
                const Spacer(),
                if (packCard.isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEW!',
                      style: AppTextStyles.caption(color: AppColors.white).copyWith(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  Text(
                    '\u00d7${packCard.currentQuantity}',
                    style: AppTextStyles.bodyMedium(color: AppColors.white.withValues(alpha: 0.5)).copyWith(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.name,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium(color: AppColors.white).copyWith(fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _chip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.categoryIcon ?? card.category.icon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            card.category.label,
                            style: AppTextStyles.caption(color: AppColors.white.withValues(alpha: 0.7)).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      color: rarityColor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/icons/xp_green_outline.png',
                            width: 14,
                            height: 14,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.bolt,
                              size: 14,
                              color: rarityColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${card.power}',
                            style: AppTextStyles.bodySmall(color: AppColors.white).copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (card.specialSkill != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarityColor.withValues(alpha: 0.12),
                          rarityDark.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: rarityColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'SPECIAL SKILL',
                          style: AppTextStyles.caption(color: rarityColor.withValues(alpha: 0.7)).copyWith(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.specialSkill!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.button(color: Color.lerp(rarityColor, Colors.white, 0.6)).copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                if (card.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    card.description!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall(color: AppColors.white.withValues(alpha: 0.6)).copyWith(fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '#${card.cardNo}',
                  style: AppTextStyles.caption(color: AppColors.white.withValues(alpha: 0.3)).copyWith(fontSize: 11, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _chip({required Widget child, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15) ??
            Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: color != null
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: child,
    );
  }
}
