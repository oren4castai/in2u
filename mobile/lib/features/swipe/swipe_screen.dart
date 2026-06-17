import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/matches/match_celebration_provider.dart';
import '../../core/models/feed_item.dart';
import '../../core/ui/chat_badge.dart';
import '../../core/ui/match_celebration_overlay.dart';
import '../../routing/routes.dart';
import '../venues/active_venue_controller.dart';
import 'swipe_controller.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  String? _currentVenueGuid; // Track venue to reset swiper on venue change
  List<FeedItem>? _frozenItems; // Items frozen when swiper is created
  Widget?
      _frozenSwiper; // The actual CardSwiper widget - only recreate on venue/refresh

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave venue?'),
        content: const Text(
          'You will stop seeing people here and your active matches at this venue will end.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(activeVenueProvider.notifier).leave();
    if (!mounted) return;
    context.go(AppRoutes.discover);
  }

  @override
  Widget build(BuildContext context) {
    // Use select to only rebuild when venue NAME changes, not on every hub event
    final venueName = ref.watch(
      activeVenueProvider.select((v) => v.valueOrNull?.name),
    );
    final hasVenue = ref.watch(
      activeVenueProvider.select((v) => v.valueOrNull != null),
    );
    final celebration = ref.watch(matchCelebrationProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(venueName ?? 'Discover people'),
            actions: [
              if (hasVenue)
                ChatsBadgeButton(
                  tooltip: 'Matches',
                  onPressed: () => context.push(AppRoutes.matches),
                ),
              if (hasVenue)
                IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  tooltip: 'Leave event',
                  onPressed: () => _confirmLeave(context),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings),
                onSelected: (value) async {
                  if (value == 'profile') context.push(AppRoutes.me);
                  if (value == 'events') context.push(AppRoutes.myEvents);
                  if (value == 'dashboard') {
                    context.push(AppRoutes.venueDashboard);
                  }
                  if (value == 'logout') {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign out?'),
                        content:
                            const Text('Are you sure you want to sign out?'),
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
                  PopupMenuItem(
                      value: 'dashboard', child: Text('Venue Dashboard')),
                  PopupMenuItem(value: 'logout', child: Text('Sign out')),
                ],
              ),
            ],
          ),
          body: !hasVenue
              ? const Center(child: CircularProgressIndicator())
              : _feedBody(context),
        ),
        if (celebration != null)
          Positioned.fill(
            child: MatchCelebrationOverlay(
              match: celebration,
              onDismiss: () =>
                  ref.read(matchCelebrationProvider.notifier).state = null,
            ),
          ),
      ],
    );
  }

  Widget _feedBody(BuildContext context) {
    final active = ref.read(activeVenueProvider).valueOrNull;
    final controller = ref.read(swipeFeedControllerProvider.notifier);
    final state = ref.watch(swipeFeedControllerProvider);

    // Check if venue changed - if so, invalidate frozen swiper
    final venueGuid = active?.venueGuid;
    if (venueGuid != _currentVenueGuid) {
      _currentVenueGuid = venueGuid;
      _frozenSwiper = null;
      _frozenItems = null;
    }

    return state.when(
      loading: () {
        _frozenSwiper = null;
        _frozenItems = null;
        return const Center(child: CircularProgressIndicator());
      },
      error: (e, _) {
        _frozenSwiper = null;
        _frozenItems = null;
        return Center(
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
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      data: (newItems) {
        if (newItems.isEmpty) {
          _frozenSwiper = null;
          _frozenItems = null;

          final exhausted = controller.autoRefreshExhausted;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No one nearby right now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exhausted
                        ? 'Try again later or check a different venue'
                        : 'Checking for new people...',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (exhausted)
                    FilledButton.icon(
                      onPressed: controller.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    )
                  else ...[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: controller.refresh,
                      child: const Text('Refresh now'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // CRITICAL: Reuse frozen swiper if it exists - prevents rebuild during animation
        // BUT: if new users appeared, update the swiper to include them
        if (_frozenSwiper != null && _frozenItems != null) {
          // Check if there are NEW users in newItems that aren't in frozen list
          final frozenGuids = _frozenItems!.map((e) => e.userGuid).toSet();
          final hasNewUsers =
              newItems.any((e) => !frozenGuids.contains(e.userGuid));

          if (!hasNewUsers) {
            // Same users - keep frozen swiper to prevent animation bugs
            return _frozenSwiper!;
          }
          // New users detected - update swiper (safe because new users can't cause reappear bug)
        }

        // Create and freeze the swiper
        _frozenItems = newItems;
        _frozenSwiper = _buildSwiper(newItems, controller);
        return _frozenSwiper!;
      },
    );
  }

  Widget _buildSwiper(
    List<FeedItem> items,
    SwipeFeedController controller,
  ) {
    final displayed = items.length >= 3 ? 3 : items.length;
    return Column(
      children: [
        Expanded(
          child: CardSwiper(
            // Stable key - only changes on venue change
            key: ValueKey('swiper_$_currentVenueGuid'),
            controller: _swiperController,
            cardsCount: items.length,
            numberOfCardsDisplayed: displayed,
            backCardOffset: const Offset(0, 32),
            padding: const EdgeInsets.all(16),
            allowedSwipeDirection:
                const AllowedSwipeDirection.symmetric(horizontal: true),
            onSwipe: (prev, current, direction) {
              if (!mounted) return false;
              if (prev < 0 || prev >= items.length) return true;

              final item = items[prev];
              final userGuid = item.userGuid;
              final right = direction == CardSwiperDirection.right;

              // Mark swiped SYNCHRONOUSLY before anything else
              // This ensures cardBuilder immediately hides this user on any rebuild
              controller.markSwiped(userGuid);

              // Invalidate frozen swiper so any rebuild uses fresh cardBuilder
              // _frozenSwiper = null;
              // _frozenItems = null;

              // Fire and forget the API call
              unawaited(controller.swipe(item, right));

              // After animation, commit to update state
              Future.delayed(const Duration(milliseconds: 400), () {
                if (!mounted) return;
                controller.commitSwipe(userGuid);
              });

              return true;
            },
            onEnd: () {
              // All cards swiped - invalidate frozen swiper and refresh
              _frozenSwiper = null;
              _frozenItems = null;
              controller.onDeckExhausted();
            },
            cardBuilder: (context, index, percentX, percentY) {
              if (index >= items.length) {
                return const SizedBox.shrink();
              }
              final item = items[index];
              // Hide swiped users - prevents flash on rebuild during match celebration
              if (controller.isUserSwiped(item.userGuid)) {
                return const SizedBox.shrink();
              }
              return _SwipeCard(
                item: item,
                swipeProgress: percentX / 100.0,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                color: Colors.red,
                icon: Icons.close,
                onPressed: () =>
                    _swiperController.swipe(CardSwiperDirection.left),
              ),
              _ActionButton(
                color: Colors.green,
                icon: Icons.favorite,
                onPressed: () =>
                    _swiperController.swipe(CardSwiperDirection.right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.item, required this.swipeProgress});

  final FeedItem item;
  final double swipeProgress;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = item.photoUrl != null;
    final isAmbient = item.isAmbient;
    final showAge = item.birthYear != null;
    final age =
        showAge ? (DateTime.now().year - item.birthYear!).toString() : null;
    final blurSigma = isAmbient ? ((item.blur ?? 1) == 1 ? 16.0 : 8.0) : 0.0;

    Widget photo = hasPhoto
        ? Image.network(
            '${fullPhotoUrl(item.photoUrl!)}?cb=${item.hashCode}',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _photoPlaceholder(context),
          )
        : _photoPlaceholder(context);
    if (isAmbient && hasPhoto) {
      photo = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: photo,
      );
    }

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: photo),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: swipeProgress < -0.15 ? 1 : 0,
              child: const _Pill(label: 'NOPE', color: Colors.red),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: swipeProgress > 0.15 ? 1 : 0,
              child: const _Pill(label: 'LIKE', color: Colors.green),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  if (age != null)
                    Text(
                      age,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  if (!isAmbient &&
                      item.bio != null &&
                      item.bio!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.bio!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                  if (isAmbient &&
                      item.styleTags != null &&
                      item.styleTags!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in item.styleTags!)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
      ),
      child: Center(
        child: Icon(Icons.person, size: 96, color: cs.onPrimaryContainer),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
