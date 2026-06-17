import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exceptions.dart';
import '../../core/models/owner_venue_detail.dart';
import '../../core/owner/owner_repository.dart';
import '../../core/ui/global_messenger.dart';
import '../../routing/routes.dart';
import 'owner_providers.dart';

class VenueDetailScreen extends ConsumerWidget {
  const VenueDetailScreen({super.key, required this.ownerGuid});
  final String ownerGuid;

  Future<void> _deleteVenue(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete venue'),
        content: const Text(
          'This will permanently delete the venue and ALL events under it, including active ones. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(ownerRepositoryProvider).deleteVenue(ownerGuid);
      ref.invalidate(ownerVenuesProvider);
      if (context.mounted) context.pop();
    } on ApiException catch (e) {
      if (context.mounted) showAppError(ref, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerVenueDetailProvider(ownerGuid));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen(
          data: (d) => d.name,
          orElse: () => 'Venue',
        )),
        actions: [
          if (async.hasValue)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              tooltip: 'Delete venue',
              onPressed: () => _deleteVenue(context, ref),
            ),
        ],
      ),
      floatingActionButton: async.maybeWhen(
        data: (detail) => FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('New Event'),
          onPressed: () => context.push(
            AppRoutes.ownerCreateEventFor(ownerGuid),
            extra: {
              'lat': detail.lat,
              'lng': detail.lng,
              'radiusM': detail.radiusM,
            },
          ),
        ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(friendlyErrorMessage(e), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(ownerVenueDetailProvider(ownerGuid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownerVenueDetailProvider(ownerGuid));
            await ref.read(ownerVenueDetailProvider(ownerGuid).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _VenueHeader(detail: detail),
              const SizedBox(height: 20),
              Text('Active events',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (detail.activeEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No active events in this venue.'),
                )
              else
                for (final e in detail.activeEvents) ...[
                  _EventTile(ownerGuid: ownerGuid, event: e),
                  const SizedBox(height: 8),
                ],
              if (detail.closedEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Closed events',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final e in detail.closedEvents) ...[
                  _ClosedEventTile(ownerGuid: ownerGuid, event: e),
                  const SizedBox(height: 8),
                ],
              ],
              if (detail.pastEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Past events',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final p in detail.pastEvents) ...[
                  _PastEventTile(ownerGuid: ownerGuid, event: p),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueHeader extends StatelessWidget {
  final OwnerVenueDetail detail;
  const _VenueHeader({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl =
        '$kApiBaseUrl${ApiEndpoints.ownerPhotoServe(detail.ownerGuid)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: detail.hasPhoto
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _HeaderPlaceholder(theme),
                  )
                : _HeaderPlaceholder(theme),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _MetaChip(
                        icon: Icons.my_location,
                        label: '${detail.radiusM} m radius'),
                    _MetaChip(
                        icon: Icons.event_available,
                        label: '${detail.allowPublicEventsCount} public slots'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _OwnerStatCard(
                        icon: Icons.people_alt_outlined,
                        label: 'Joined',
                        value: detail.totals.joined,
                        color: Colors.pinkAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OwnerStatCard(
                        icon: Icons.favorite_outline,
                        label: 'Matches',
                        value: detail.totals.matches,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OwnerStatCard(
                        icon: Icons.remove_red_eye_outlined,
                        label: 'Views',
                        value: detail.totals.views,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPlaceholder extends StatelessWidget {
  final ThemeData theme;
  const _HeaderPlaceholder(this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.storefront,
          size: 48, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EventTile extends ConsumerStatefulWidget {
  final String ownerGuid;
  final OwnerActiveEvent event;
  const _EventTile({required this.ownerGuid, required this.event});

  @override
  ConsumerState<_EventTile> createState() => _EventTileState();
}

class _EventTileState extends ConsumerState<_EventTile> {
  bool _busy = false;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    _messageController.clear();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send popup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Everyone currently in "${widget.event.name}" will see this popup in the app.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              autofocus: true,
              maxLines: 4,
              maxLength: 180,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Write the popup message...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = _messageController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (message == null || message.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .sendEventAnnouncement(widget.event.venueGuid, message);
      if (mounted) {
        showAppSnackBar(
            ref, 'Popup sent to ${widget.event.liveCount} user(s).');
      }
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close event'),
        content: Text(
          'Close "${widget.event.name}"? Members will be removed. The event will be saved and can be rescheduled later.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close event'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .closeEvent(widget.event.venueGuid);
      ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid));
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete event'),
        content: Text('Remove "${widget.event.name}" from your venue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .deleteEvent(widget.event.venueGuid);
      ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid));
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.event;
    final photoUrl =
        '${kApiBaseUrl}${ApiEndpoints.venuePhotoServe(e.venueGuid)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            if (e.hasPhoto)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(Icons.image_not_supported,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                          child:
                              Text(e.name, style: theme.textTheme.titleSmall)),
                      if (e.liveCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('LIVE',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  if (e.startsAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: theme.hintColor),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, HH:mm')
                              .format(e.startsAt!.toLocal()),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${e.liveCount} live · ${e.joinedCount} joined · ${e.matchesCount} matches · ${e.viewsCount} views',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      context.push(AppRoutes.eventEditFor(e.venueGuid));
                      break;
                    case 'announce':
                      _sendAnnouncement();
                      break;
                    case 'close':
                      _close();
                      break;
                    case 'delete':
                      _delete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (e.isMine)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'announce',
                    child: Text('Send popup'),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Close'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ClosedEventTile extends ConsumerStatefulWidget {
  final String ownerGuid;
  final OwnerClosedEvent event;
  const _ClosedEventTile({required this.ownerGuid, required this.event});

  @override
  ConsumerState<_ClosedEventTile> createState() => _ClosedEventTileState();
}

class _ClosedEventTileState extends ConsumerState<_ClosedEventTile> {
  bool _busy = false;

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;

    final startsAt =
        DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);

    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .rescheduleEvent(widget.event.venueGuid, startsAt);
      ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid));
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete closed event'),
        content: Text('Remove "${widget.event.name}" from your venue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .deleteEvent(widget.event.venueGuid);
      ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid));
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.event;
    final photoUrl =
        '${kApiBaseUrl}${ApiEndpoints.venuePhotoServe(e.venueGuid)}';

    return Card(
      child: ListTile(
        leading: e.hasPhoto
            ? SizedBox(
                width: 50,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(Icons.image_not_supported,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            : Icon(Icons.event_busy, color: theme.colorScheme.onSurfaceVariant),
        title: Text(e.name),
        subtitle: e.startsAt != null
            ? Text(
                'Was ${DateFormat('MMM d, HH:mm').format(e.startsAt!.toLocal())}')
            : null,
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'reschedule':
                      _reschedule();
                      break;
                    case 'delete':
                      _delete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reschedule',
                    child: Text('Reschedule'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PastEventTile extends ConsumerStatefulWidget {
  final String ownerGuid;
  final OwnerPastEvent event;
  const _PastEventTile({required this.ownerGuid, required this.event});

  @override
  ConsumerState<_PastEventTile> createState() => _PastEventTileState();
}

class _PastEventTileState extends ConsumerState<_PastEventTile> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete past event'),
        content: Text(
          'Remove "${widget.event.name}" from history?\n\nThis will reduce your accumulated totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .deletePastEvent(widget.ownerGuid, widget.event.id);
      ref.invalidate(ownerVenueDetailProvider(widget.ownerGuid));
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.event;
    return Card(
      child: ListTile(
        title: Text(p.name),
        subtitle: Text('${p.joinedCount} joined · ${p.matchesCount} matches'),
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).colorScheme.error,
                onPressed: _delete,
              ),
      ),
    );
  }
}

class _OwnerStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final Color color;

  const _OwnerStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}K'
        : value.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(display,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
