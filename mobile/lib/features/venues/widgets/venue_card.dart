import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/venue.dart';

class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venue.type == 'Global') ...[
                // Global venue image from assets
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/global.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (venue.hasPhoto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(venue.venueGuid)}',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (venue.eventType == 'Private') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Private',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _TypeChip(type: venue.type),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (venue.type != 'Global') ...[
                          Icon(Icons.place, size: 16, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Text(_formatDistance(venue.distanceM)),
                          const SizedBox(width: 16),
                        ],
                        DensityIndicator(bucket: venue.densityBucket),
                      ],
                    ),
                    if (venue.ownerName != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront,
                                size: 12,
                                color: theme.colorScheme.onSecondaryContainer),
                            const SizedBox(width: 4),
                            Text(
                              venue.ownerName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (venue.isEvent && venue.startsAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatEventTime(venue.startsAt!, venue.endsAt),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (venue.startsAt!.isAfter(DateTime.now().toUtc()))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _upcomingLabel(venue.startsAt!),
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                    // Always show fake avatars for FOMO
                    const SizedBox(height: 10),
                    const _FakeAvatarsRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final isEvent = type == 'Event';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEvent
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isEvent ? 'Event' : 'Global',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class DensityIndicator extends StatelessWidget {
  const DensityIndicator({super.key, required this.bucket});
  final String bucket;

  @override
  Widget build(BuildContext context) {
    final (count, label, color) = switch (bucket) {
      'chill' => (2, 'Chill', Colors.green),
      'vibing' => (2, 'Vibing', Colors.amber),
      'packed' => (3, 'Packed', Colors.deepOrange),
      _ => (2, 'Chill', Colors.green),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: i < count ? color : Theme.of(context).dividerColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

String _formatDistance(double m) {
  if (m < 1000) return '${m.round()} m';
  return '${(m / 1000).toStringAsFixed(1)} km';
}

String _formatEventTime(DateTime startUtc, DateTime? endUtc) {
  final start = startUtc.toLocal();
  final dayFmt = DateFormat('EEE');
  final timeFmt = DateFormat('h:mm a');
  final startStr = '${dayFmt.format(start)} ${timeFmt.format(start)}';
  if (endUtc == null) return startStr;
  final end = endUtc.toLocal();
  return '$startStr – ${timeFmt.format(end)}';
}

String _upcomingLabel(DateTime startsAt) {
  final diff = startsAt.toLocal().difference(DateTime.now());
  if (diff.inMinutes < 60) {
    return 'Starts in ${diff.inMinutes}m';
  }
  if (diff.inHours < 24) {
    return 'Starts in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
  return 'Starts ${DateFormat('EEE HH:mm').format(startsAt.toLocal())}';
}

/// Static fake avatar row for FOMO - shows overlapping blurred circles + "..."
class _FakeAvatarsRow extends StatefulWidget {
  const _FakeAvatarsRow();

  @override
  State<_FakeAvatarsRow> createState() => _FakeAvatarsRowState();
}

class _FakeAvatarsRowState extends State<_FakeAvatarsRow> {
  late final int _seed = DateTime.now().microsecondsSinceEpoch;

  static const _avatarUrls = [
    '/avatars/1.jpg',
    '/avatars/2.jpg',
    '/avatars/3.jpg',
    '/avatars/4.jpg',
    '/avatars/5.jpg',
    '/avatars/6.jpg',
    '/avatars/7.jpg',
    '/avatars/8.jpg',
  ];

  List<String> _orderedAvatarUrls() {
    final ordered = List<String>.of(_avatarUrls);
    ordered.shuffle(Random(_seed));
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    const overlap = 10.0;
    final theme = Theme.of(context);
    final avatarUrls = _orderedAvatarUrls().take(5).toList();

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
                    child: _BlurredAvatar(
                      url: fullPhotoUrl(avatarUrls[i]),
                      radius: radius,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '...',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredAvatar extends StatelessWidget {
  const _BlurredAvatar({required this.url, required this.radius});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
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
          imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(Icons.person,
                  size: radius,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}
