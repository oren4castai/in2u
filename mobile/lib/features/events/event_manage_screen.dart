import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exceptions.dart';
import '../../core/models/my_event.dart';
import '../../core/models/venue_participant.dart';
import '../../core/models/venue_stats.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/venues/venue_repository.dart';
import '../../routing/routes.dart';
import '../venues/active_venue_controller.dart';
import 'event_providers.dart';

class EventManageScreen extends ConsumerStatefulWidget {
  const EventManageScreen({super.key, required this.venueGuid});
  final String venueGuid;

  @override
  ConsumerState<EventManageScreen> createState() => _EventManageScreenState();
}

class _EventManageScreenState extends ConsumerState<EventManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _endEvent(MyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Event'),
        content: Text('End "${event.name}"? All participants will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Event'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _ending = true);
    try {
      await ref.read(venueRepositoryProvider).closeEvent(widget.venueGuid);
      ref.invalidate(myEventsProvider);
      if (mounted) context.go(AppRoutes.discover);
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  Future<void> _forceCheckout(VenueParticipant p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove participant'),
        content: Text('Remove ${p.displayName} from this event?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(venueRepositoryProvider)
          .forceCheckout(widget.venueGuid, p.userGuid);
      ref.invalidate(eventParticipantsProvider(widget.venueGuid));
      ref.invalidate(eventStatsProvider(widget.venueGuid));
      if (mounted) showAppSnackBar(ref, '${p.displayName} removed.');
    } on ApiException catch (e) {
      if (mounted) showAppError(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myEventsAsync = ref.watch(myEventsProvider);
    final statsAsync = ref.watch(eventStatsProvider(widget.venueGuid));
    final participantsAsync =
        ref.watch(eventParticipantsProvider(widget.venueGuid));

    final event = myEventsAsync.valueOrNull
        ?.where((e) => e.venueGuid == widget.venueGuid)
        .firstOrNull;

    final isLive = event?.isActive == true;
    final shareCode = statsAsync.valueOrNull?.shareCode ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              final active = ref.read(activeVenueProvider).valueOrNull;
              context.go(active != null ? AppRoutes.swipe : AppRoutes.discover);
            }
          },
        ),
        title: const Text('Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: shareCode.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: shareCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share code copied!')),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Event header ────────────────────────────────────────────
          _EventHeader(
            event: event,
            venueGuid: widget.venueGuid,
          ),
          const SizedBox(height: 4),
          // ── Stats row ───────────────────────────────────────────────
          statsAsync.when(
            loading: () => const _StatsPlaceholder(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _StatsSection(stats: stats),
          ),
          const SizedBox(height: 8),
          // ── Live banner ─────────────────────────────────────────────
          if (isLive)
            statsAsync.maybeWhen(
              data: (stats) => _LiveBanner(shareCode: stats.shareCode),
              orElse: () => const SizedBox.shrink(),
            ),
          if (isLive) const SizedBox(height: 8),
          // ── Tab bar ─────────────────────────────────────────────────
          TabBar(
            controller: _tabs,
            tabs: [
              participantsAsync.maybeWhen(
                data: (list) => Tab(text: 'Participants ${list.length}'),
                orElse: () => const Tab(text: 'Participants'),
              ),
            ],
          ),
          // ── Tab content (scrollable) ─────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ParticipantsTab(
                  participantsAsync: participantsAsync,
                  searchCtrl: _searchCtrl,
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  onForceCheckout: _forceCheckout,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: event != null
          ? _BottomBar(
              onEdit: () async {
                await context.push(AppRoutes.eventEditFor(widget.venueGuid));
                if (mounted) {
                  ref.invalidate(myEventsProvider);
                  ref.invalidate(eventStatsProvider(widget.venueGuid));
                }
              },
              onEnd: _ending ? null : () => _endEvent(event),
            )
          : null,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _EventHeader extends StatelessWidget {
  final MyEvent? event;
  final String venueGuid;

  const _EventHeader({
    required this.event,
    required this.venueGuid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = event?.isActive == true;
    // Add cache-buster based on event data hash so photo reloads when event updates
    final cacheBuster = event?.hashCode ?? '';
    final photoUrl =
        '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(venueGuid)}?cb=$cacheBuster';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: event?.hasPhoto == true
                    ? Image.network(
                        photoUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PhotoPlaceholder(size: 110),
                      )
                    : _PhotoPlaceholder(size: 110),
              ),
              if (isLive)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event?.name ?? '',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event?.startsAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatRange(event!.startsAt!, event!.durationHours),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event?.isPublic == true ? 'Public' : 'Private',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRange(DateTime start, int? durationH) {
    final fmt = DateFormat('MMM d, HH:mm');
    if (durationH == null) return fmt.format(start.toLocal());
    final end = start.add(Duration(hours: durationH));
    return '${fmt.format(start.toLocal())} – ${DateFormat('HH:mm').format(end.toLocal())}';
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final double size;
  const _PhotoPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.white54),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final VenueStats stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.people_alt_outlined,
              label: 'Joined',
              value: stats.joinedCount,
              sparkline: stats.joinedSparkline,
              color: Colors.pinkAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.favorite_outline,
              label: 'Matches',
              value: stats.matchesCount,
              sparkline: stats.matchesSparkline,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.remove_red_eye_outlined,
              label: 'Views',
              value: stats.viewsCount,
              sparkline: stats.viewsSparkline,
              color: Colors.purpleAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final num value;
  final List<num> sparkline;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sparkline,
    required this.color,
  });

  String _fmt(num v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}K'
        : value.toString();
    return Container(
      height: 120,
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
          SizedBox(
            height: 24,
            width: double.infinity,
            child: sparkline.length >= 2
                ? CustomPaint(
                    painter: _SparklinePainter(data: sparkline, color: color),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<num> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final doubles = data.map((e) => e.toDouble()).toList();
    final maxVal = doubles.reduce((a, b) => a > b ? a : b);
    final minVal = doubles.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs();
    final step = size.width / (doubles.length - 1);
    final path = Path();
    for (int i = 0; i < doubles.length; i++) {
      final x = i * step;
      final normalized = range == 0 ? 0.5 : (doubles[i] - minVal) / range;
      final y =
          size.height - normalized * size.height * 0.85 - size.height * 0.075;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

class _StatsPlaceholder extends StatelessWidget {
  const _StatsPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 100, child: Center(child: CircularProgressIndicator()));
}

// ── Live Banner ───────────────────────────────────────────────────────────────

class _LiveBanner extends StatelessWidget {
  final String shareCode;
  const _LiveBanner({required this.shareCode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your event is live!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('People can join and match with others.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: shareCode.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: shareCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share code copied!')),
                      );
                    },
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('Share'),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: tabBar,
      );

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ── Participants tab ──────────────────────────────────────────────────────────

class _ParticipantsTab extends StatelessWidget {
  final AsyncValue<List<VenueParticipant>> participantsAsync;
  final TextEditingController searchCtrl;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<VenueParticipant> onForceCheckout;

  const _ParticipantsTab({
    required this.participantsAsync,
    required this.searchCtrl,
    required this.search,
    required this.onSearchChanged,
    required this.onForceCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search participants...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: participantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyErrorMessage(e))),
            data: (all) {
              final filtered = search.isEmpty
                  ? all
                  : all
                      .where((p) => p.displayName
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No participants yet.'));
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _ParticipantTile(
                  participant: filtered[i],
                  onCheckout: () => onForceCheckout(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final VenueParticipant participant;
  final VoidCallback onCheckout;
  const _ParticipantTile({required this.participant, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final age = participant.age;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.person),
      ),
      title: Text(participant.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: age != null ? Text('$age years old') : null,
      trailing: IconButton(
        icon: const Icon(Icons.logout, size: 20),
        tooltip: 'Remove from event',
        onPressed: onCheckout,
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback? onEnd;
  const _BottomBar({required this.onEdit, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Event'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEnd,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('End Event'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
