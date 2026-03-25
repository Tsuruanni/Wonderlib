import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/entities/avatar.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.fallbackInitials,
    this.showBorder = true,
  });

  final EquippedAvatar avatar;
  final double size;
  final String? fallbackInitials;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (avatar.isEmpty) {
      return _buildInitials(theme);
    }

    // Build layers: background items (z < 5), base animal (z: 5), above items (z >= 5)
    final allLayers = <_RenderLayer>[];

    for (final layer in avatar.layers.where((l) => l.zIndex < 5)) {
      allLayers.add(_RenderLayer(z: layer.zIndex, url: layer.url));
    }

    if (avatar.baseUrl != null) {
      allLayers.add(_RenderLayer(z: 5, url: avatar.baseUrl!));
    }

    for (final layer in avatar.layers.where((l) => l.zIndex >= 5)) {
      allLayers.add(_RenderLayer(z: layer.zIndex, url: layer.url));
    }

    allLayers.sort((a, b) => a.z.compareTo(b.z));

    return Container(
      width: size,
      height: size,
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: size > 60 ? 3 : 2,
              ),
            )
          : null,
      child: ClipOval(
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
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
