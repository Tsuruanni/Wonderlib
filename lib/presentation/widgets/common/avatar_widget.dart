import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/entities/avatar.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.width,
    this.height,
    this.fallbackInitials,
    this.showBorder = true,
    this.borderRadius,
    this.stretch = false,
  });

  final EquippedAvatar avatar;
  final double size;
  /// Override width/height independently for rectangular avatars.
  final double? width;
  final double? height;
  final String? fallbackInitials;
  final bool showBorder;
  /// When set, uses rounded rectangle instead of circle.
  final double? borderRadius;
  /// When true, height expands to fill parent (use with IntrinsicHeight).
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (avatar.isEmpty) {
      return _buildInitials(theme);
    }

    // Build layers: background items (z < 5), base animal (z: 5), above items (z >= 5)
    final allLayers = <_RenderLayer>[];

    // Base body at z=0, all accessory layers render on top
    if (avatar.baseUrl != null) {
      allLayers.add(_RenderLayer(z: 0, url: avatar.baseUrl!));
    }

    for (final layer in avatar.layers) {
      allLayers.add(_RenderLayer(z: layer.zIndex, url: layer.url));
    }

    allLayers.sort((a, b) => a.z.compareTo(b.z));

    final w = width ?? size;
    final isRounded = borderRadius != null;

    return Container(
      width: w,
      height: stretch ? null : (height ?? size),
      decoration: showBorder
          ? BoxDecoration(
              shape: isRounded ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isRounded ? BorderRadius.circular(borderRadius!) : null,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: size > 60 ? 3 : 2,
              ),
            )
          : null,
      child: isRounded
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius!),
              child: Stack(
                fit: StackFit.expand,
                children: allLayers.map((layer) => _buildImage(layer.url)).toList(),
              ),
            )
          : ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: allLayers.map((layer) => _buildImage(layer.url)).toList(),
              ),
            ),
    );
  }

  static bool _isSvg(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    return path.toLowerCase().endsWith('.svg');
  }

  Widget _buildImage(String url) {
    if (_isSvg(url)) {
      return SizedBox.expand(
        child: SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const SizedBox.shrink(),
        ),
      );
    }
    return SizedBox.expand(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildInitials(ThemeData theme) {
    final w = width ?? size;
    final isRounded = borderRadius != null;

    return Container(
      width: w,
      height: stretch ? null : (height ?? size),
      decoration: BoxDecoration(
        shape: isRounded ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isRounded ? BorderRadius.circular(borderRadius!) : null,
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
        border: showBorder
            ? Border.all(color: theme.colorScheme.primary, width: size > 60 ? 3 : 2)
            : null,
      ),
      child: Center(
        child: Text(
          fallbackInitials ?? '?',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _RenderLayer {
  const _RenderLayer({required this.z, required this.url});
  final int z;
  final String url;
}
