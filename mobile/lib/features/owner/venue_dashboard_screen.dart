import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/my_claim.dart';
import '../../core/models/owner_venue_summary.dart';
import '../../core/owner/owner_repository.dart';
import '../../routing/routes.dart';
import 'owner_providers.dart';

class VenueDashboardScreen extends ConsumerWidget {
  const VenueDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(ownerVenuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Venue Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerVenuesProvider);
          ref.invalidate(myClaimsProvider);
          await ref.read(ownerVenuesProvider.future);
        },
        child: venuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(ownerVenuesProvider),
          ),
          data: (venues) {
            final claimsAsync = ref.watch(myClaimsProvider);
            final pending = claimsAsync.maybeWhen(
              data: (claims) =>
                  claims.where((c) => c.isPending).toList(growable: false),
              orElse: () => const <MyClaim>[],
            );

            if (venues.isEmpty && pending.isEmpty) {
              return _EmptyState(
                onClaim: () => context.push(AppRoutes.claimVenue),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final v in venues) ...[
                  _VenueCard(
                    venue: v,
                    onView: () => context
                        .push(AppRoutes.ownerVenueDetailFor(v.ownerGuid)),
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete venue'),
                          content: const Text(
                            'This will permanently delete the venue and ALL events under it. This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await ref
                            .read(ownerRepositoryProvider)
                            .deleteVenue(v.ownerGuid);
                        ref.invalidate(ownerVenuesProvider);
                        ref.invalidate(myClaimsProvider);
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Pending review',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final c in pending) ...[
                    _PendingClaimTile(claim: c),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.claimVenue),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Claim another venue'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClaim;
  const _EmptyState({required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.storefront_outlined, size: 64),
        const SizedBox(height: 16),
        Center(
          child: Text('You don\'t own any venues yet',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Claim a venue to manage the events inside it.'),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onClaim,
            icon: const Icon(Icons.add_business),
            label: const Text('Claim a Venue'),
          ),
        ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  final OwnerVenueSummary venue;
  final VoidCallback onView;
  final VoidCallback onDelete;
  const _VenueCard(
      {required this.venue, required this.onView, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: venue.hasPhoto
                    ? Image.network(
                        '$kApiBaseUrl${ApiEndpoints.ownerPhotoServe(venue.ownerGuid)}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _CardPhotoPlaceholder(theme),
                      )
                    : _CardPhotoPlaceholder(theme),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.event, size: 16, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text('${venue.activeEventCount} active'),
                      const SizedBox(width: 16),
                      Icon(Icons.people, size: 16, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text('${venue.liveCount} live'),
                    ],
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onView, child: const Text('View')),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              tooltip: 'Delete venue',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPhotoPlaceholder extends StatelessWidget {
  final ThemeData theme;
  const _CardPhotoPlaceholder(this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.storefront,
          size: 24, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _PendingClaimTile extends StatelessWidget {
  final MyClaim claim;
  const _PendingClaimTile({required this.claim});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hourglass_empty),
        title: Text(claim.name),
        subtitle: const Text('Awaiting approval'),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
