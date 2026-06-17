import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/venues/event_category.dart';
import '../../../core/venues/venue_repository.dart';
import '../../../routing/routes.dart';
import '../widgets/venue_card.dart';
import 'discovery_providers.dart';
import 'discovery_refresh_controller.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _radiusDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(discoveryRefreshControllerProvider.notifier).setOnDiscover(true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _radiusDebounceTimer?.cancel();
    // Mark not-on-discover without crashing if the controller has been disposed.
    try {
      ref
          .read(discoveryRefreshControllerProvider.notifier)
          .setOnDiscover(false);
    } catch (_) {}
    super.dispose();
  }

  void _onScroll() {
    final engaged = _scrollController.hasClients &&
        (_scrollController.offset > 100 ||
            _scrollController.position.isScrollingNotifier.value);
    ref.read(discoveryRefreshControllerProvider.notifier).setEngaged(engaged);
  }

  Future<void> _refresh() async {
    ref.invalidate(nearbyVenuesProvider);
    ref.read(discoveryRefreshControllerProvider.notifier).clear();
    await ref.read(nearbyVenuesProvider.future);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(nearbyVenuesProvider);
    final pending = ref.watch(discoveryRefreshControllerProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final radiusM = ref.watch(discoveryRadiusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) async {
              if (value == 'profile') {
                await context.push(AppRoutes.me);
                if (!mounted) return;
                ref.invalidate(nearbyVenuesProvider);
              }
              if (value == 'events') {
                await context.push(AppRoutes.myEvents);
                if (!mounted) return;
                ref.invalidate(nearbyVenuesProvider);
              }
              if (value == 'dashboard') {
                await context.push(AppRoutes.venueDashboard);
                if (!mounted) return;
                ref.invalidate(nearbyVenuesProvider);
              }
              if (value == 'joinCode') {
                await _showJoinCodeDialog(context, ref);
              }
              if (value == 'logout') {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (shouldLogout == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(value: 'events', child: Text('My Events')),
              PopupMenuItem(value: 'dashboard', child: Text('Venue Dashboard')),
              PopupMenuItem(value: 'joinCode', child: Text('Join by code')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (pending) _PendingRefreshBanner(onTap: _refresh),
          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // "All" chip
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: selectedCategory == null,
                    onSelected: (_) => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = null,
                  ),
                ),
                // Category chips
                ...EventCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.displayName),
                        selected: selectedCategory == cat,
                        onSelected: (_) => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = cat,
                      ),
                    )),
              ],
            ),
          ),
          // Distance slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Distance: ${(radiusM / 1000).round()} km'),
                Slider(
                  value: radiusM.toDouble(),
                  min: 1000,
                  max: 300000,
                  divisions: 59,
                  label: '${(radiusM / 1000).round()} km',
                  onChanged: (value) {
                    final newRadius = value.round();
                    ref.read(discoveryRadiusProvider.notifier).state = newRadius;
                    
                    // Debounce backend request
                    _radiusDebounceTimer?.cancel();
                    _radiusDebounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () => ref.invalidate(nearbyVenuesProvider),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: venuesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: _refresh,
              ),
              data: (venues) {
                if (venues.isEmpty) {
                  return _EmptyView(onRefresh: _refresh);
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final v = venues[i];
                      return VenueCard(
                        venue: v,
                        onTap: () async {
                          await context
                              .push(AppRoutes.venueDetailsFor(v.venueGuid));
                          if (!mounted) return;
                          ref.invalidate(nearbyVenuesProvider);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinCodeDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join by code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: const InputDecoration(
            hintText: 'Enter 8-character code',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.length != 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code must be 8 characters')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final pos = await ref.read(currentPositionProvider.future);
                final venue =
                    await ref.read(venueRepositoryProvider).getByShareCode(
                          code,
                          lat: pos?.latitude,
                          lng: pos?.longitude,
                        );
                if (context.mounted) {
                  await context
                      .push(AppRoutes.venueDetailsWithCode(venue.venueGuid));
                  if (mounted) {
                    ref.invalidate(nearbyVenuesProvider);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Event not found or no longer active')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _PendingRefreshBanner extends StatelessWidget {
  const _PendingRefreshBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.refresh, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'New events available — tap to refresh',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore_off, size: 64),
          const SizedBox(height: 12),
          const Text('No venues nearby'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onRefresh(),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
