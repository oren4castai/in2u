import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/venue.dart';
import '../../../core/ui/global_messenger.dart';
import '../../../core/venues/venue_repository.dart';
import '../../../routing/routes.dart';
import '../active_venue_controller.dart';
import '../discovery/discovery_providers.dart';
import '../widgets/ambient_avatars_row.dart';
import '../widgets/venue_card.dart';

final venueDetailsProvider =
    FutureProvider.autoDispose.family<Venue, String>((ref, guid) async {
  final pos = await ref.watch(currentPositionProvider.future);
  return ref.read(venueRepositoryProvider).getDetails(
        guid,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
});

class VenueDetailsScreen extends ConsumerStatefulWidget {
  const VenueDetailsScreen({
    super.key,
    required this.venueGuid,
    this.fromShareCode = false,
  });
  final String venueGuid;
  final bool fromShareCode;

  @override
  ConsumerState<VenueDetailsScreen> createState() => _VenueDetailsScreenState();
}

class _VenueDetailsScreenState extends ConsumerState<VenueDetailsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(venueDetailsProvider(widget.venueGuid));
    final active = ref.watch(activeVenueProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(friendlyErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(venueDetailsProvider(widget.venueGuid)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (venue) => _Body(
          venue: venue,
          active: active,
          busy: _busy,
          fromShareCode: widget.fromShareCode,
          onCheckIn: () => _onCheckIn(venue),
          onSwitch: () => _onCheckIn(venue),
        ),
      ),
    );
  }

  Future<void> _onCheckIn(Venue venue) async {
    setState(() => _busy = true);
    try {
      await ref.read(activeVenueProvider.notifier).checkIn(venue);
      if (!mounted) return;
      context.go(AppRoutes.swipe);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppError(ref, e);
    } catch (e) {
      if (!mounted) return;
      showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.venue,
    required this.active,
    required this.busy,
    required this.fromShareCode,
    required this.onCheckIn,
    required this.onSwitch,
  });

  final Venue venue;
  final Venue? active;
  final bool busy;
  final bool fromShareCode;
  final VoidCallback onCheckIn;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = active?.venueGuid == venue.venueGuid;
    final hasOther = active != null && !isCurrent;
    // Global venues have no location requirement
    final withinRadius =
        venue.type == 'Global' || venue.distanceM <= venue.radiusM;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (venue.type == 'Global')
          // Global venue image from assets
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/global.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          )
        else if (venue.hasPhoto)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(venue.venueGuid)}?cb=${venue.hashCode}',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        Text(venue.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(venue.type),
            ),
            if (venue.type != 'Global') ...[
              const SizedBox(width: 12),
              Icon(Icons.place, size: 16, color: theme.hintColor),
              const SizedBox(width: 4),
              Text(_formatDistance(venue.distanceM)),
            ],
            const SizedBox(width: 16),
            DensityIndicator(bucket: venue.densityBucket),
          ],
        ),
        const SizedBox(height: 16),
        _buildAction(
          context,
          isCurrent: isCurrent,
          hasOther: hasOther,
          withinRadius: withinRadius,
        ),
        if (!venue.isActive) ...[
          const SizedBox(height: 16),
          Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'This venue is currently ${venue.status}.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        if (venue.isEvent && venue.startsAt != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_formatEventRange(venue.startsAt!, venue.endsAt)),
              ),
              if (venue.eventType == 'Public')
                IconButton(
                  icon: const Icon(Icons.directions_car),
                  iconSize: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _openNavigation(venue),
                  tooltip: 'Open navigation',
                ),
            ],
          ),
          if (venue.startsAt!.isAfter(DateTime.now().toUtc()))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _upcomingLabel(venue.startsAt!),
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
        if (venue.ambientPreview.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Vibes here', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AmbientAvatarsRow(items: venue.ambientPreview, radius: 22),
        ],
        if (venue.description != null && venue.description!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(venue.description!),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required bool isCurrent,
    required bool hasOther,
    required bool withinRadius,
  }) {
    if (isCurrent) {
      return const SizedBox.shrink();
    }
    if (hasOther) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "You'll leave ${active!.name} when you check in here.",
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (busy || !withinRadius) ? null : onSwitch,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Switch to this venue'),
          ),
        ],
      );
    }
    final bool notYetStarted = venue.isEvent &&
        venue.startsAt != null &&
        venue.startsAt!.isAfter(DateTime.now().toUtc());
    final bool isPrivateWithoutCode =
        venue.eventType == 'Private' && !fromShareCode;
    return FilledButton(
      onPressed:
          (busy || !withinRadius || notYetStarted || isPrivateWithoutCode)
              ? null
              : onCheckIn,
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              isPrivateWithoutCode
                  ? 'Private event - use share code to join'
                  : notYetStarted
                      ? 'Event hasn\'t started yet'
                      : withinRadius
                          ? 'Check in'
                          : 'Move closer to check in (${_formatDistance(venue.distanceM)} away)',
            ),
    );
  }

  Future<void> _openNavigation(Venue venue) async {
    final lat = venue.lat;
    final lng = venue.lng;
    final name = Uri.encodeComponent(venue.name);

    // Try Google Maps first
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$name',
    );

    // Fallback to Waze
    final wazeUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(wazeUrl)) {
        await launchUrl(wazeUrl);
      } else {
        // Fallback to standard maps URL
        await launchUrl(Uri.parse('https://maps.google.com/?q=$lat,$lng'));
      }
    } catch (e) {
      // Silently fail if no navigation app is available
    }
  }
}

String _formatDistance(double m) {
  if (m < 1000) return '${m.round()} m';
  return '${(m / 1000).toStringAsFixed(1)} km';
}

String _formatEventRange(DateTime startUtc, DateTime? endUtc) {
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
