import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/ambient_preview.dart';

class AmbientAvatarsRow extends StatelessWidget {
  const AmbientAvatarsRow({
    super.key,
    required this.items,
    this.maxShown = 5,
    this.radius = 18,
    this.alwaysShowMore = true,
  });

  final List<AmbientPreview> items;
  final int maxShown;
  final double radius;
  final bool alwaysShowMore;

  static const _fakeAvatarUrls = [
    '/avatars/1.jpg',
    '/avatars/2.jpg',
    '/avatars/3.jpg',
    '/avatars/4.jpg',
    '/avatars/5.jpg',
    '/avatars/6.jpg',
    '/avatars/7.jpg',
    '/avatars/8.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.length > 5 ? 5 : items.length;
    final hasMore = alwaysShowMore || items.length > shown;
    final theme = Theme.of(context);
    const overlap = 10.0;
    final avatarUrls = _orderedAvatarUrls(items).take(shown).toList();

    return SizedBox(
      height: radius * 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Overlapping avatars using Stack
          SizedBox(
            width: (avatarUrls.length * (radius * 2 - overlap)) + overlap,
            child: Stack(
              children: [
                for (var i = 0; i < avatarUrls.length; i++)
                  Positioned(
                    left: i * (radius * 2 - overlap),
                    child: _AmbientAvatar(url: avatarUrls[i], radius: radius),
                  ),
              ],
            ),
          ),
          if (hasMore) ...[
            const SizedBox(width: 6),
            Text(
              '...',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _orderedAvatarUrls(List<AmbientPreview> items) {
    final ordered = List<String>.of(_fakeAvatarUrls);
    ordered.shuffle(Random(_stableSeed(items)));
    return ordered;
  }

  int _stableSeed(List<AmbientPreview> items) {
    var hash = 0;
    for (final item in items) {
      for (final codeUnit in item.ambientProfileGuid.codeUnits) {
        hash = 0x1fffffff & (hash * 31 + codeUnit);
      }
    }
    return hash;
  }
}

class _AmbientAvatar extends StatelessWidget {
  const _AmbientAvatar({
    required this.url,
    required this.radius,
  });

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const sigma = 3.0; // Blur to match discovery cards
    final placeholder = CircleAvatar(
      radius: radius - 2, // Account for border
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: const Icon(Icons.person, size: 18),
    );

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Image.network(
            fullPhotoUrl(url),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ),
      ),
    );
  }
}
