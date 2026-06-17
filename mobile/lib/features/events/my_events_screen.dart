import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/my_event.dart';
import '../../core/ui/global_messenger.dart';
import '../../routing/routes.dart';
import 'event_providers.dart';

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        actions: [
          async.maybeWhen(
            data: (events) {
              final hasActive = events.any((e) => e.status == 'Active');
              if (hasActive) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => context.push(AppRoutes.createEvent),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
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
                onPressed: () => ref.invalidate(myEventsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (events) {
          if (events.isEmpty)
            return _EmptyState(
                onCreateTap: () => context.push(AppRoutes.createEvent));
          if (events.length == 1 && events.first.isActive) {
            // Auto-navigate to manage for the single active event
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context
                    .replace(AppRoutes.eventManageFor(events.first.venueGuid));
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _EventTile(
              event: events[i],
              onTap: () =>
                  context.push(AppRoutes.eventManageFor(events[i].venueGuid)),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_outlined, size: 64),
          const SizedBox(height: 16),
          Text('No events yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Create your first event and start matching.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final MyEvent event;
  final VoidCallback onTap;
  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = event.isActive;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(event.name),
        subtitle: event.startsAt != null
            ? Text(DateFormat('MMM d, HH:mm').format(event.startsAt!.toLocal()))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLive
                    ? Colors.green.withOpacity(0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isLive ? 'LIVE' : event.status,
                style: TextStyle(
                  fontSize: 11,
                  color: isLive ? Colors.green : theme.hintColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
