import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin/admin_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/models/admin_claim.dart';
import '../../core/models/admin_event.dart';
import '../../core/models/admin_stats.dart';
import '../../core/models/admin_user.dart';
import '../../core/models/admin_venue.dart';
import '../../core/ui/global_messenger.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  AdminStats? _stats;
  List<AdminClaim> _claims = const [];
  List<AdminVenue> _venues = const [];
  List<AdminEvent> _events = const [];
  List<AdminUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    final search = _searchCtrl.text.trim();

    try {
      final results = await Future.wait<dynamic>([
        repo.getStats(),
        repo.listClaims(search: search),
        repo.listVenues(search: search),
        repo.listEvents(search: search),
        repo.listUsers(search: search),
      ]);
      if (!mounted) return;
      if (results.length != 5) throw Exception('Unexpected response');
      setState(() {
        try {
          _stats = results[0] is AdminStats
              ? results[0] as AdminStats
              : throw TypeError();
          _claims = results[1] is List<AdminClaim>
              ? results[1] as List<AdminClaim>
              : <AdminClaim>[];
          _venues = results[2] is List<AdminVenue>
              ? results[2] as List<AdminVenue>
              : <AdminVenue>[];
          _events = results[3] is List<AdminEvent>
              ? results[3] as List<AdminEvent>
              : <AdminEvent>[];
          _users = results[4] is List<AdminUser>
              ? results[4] as List<AdminUser>
              : <AdminUser>[];
        } catch (_) {
          _stats = AdminStats(
            usersTotal: 0,
            usersOnline: 0,
            venuesTotal: 0,
            eventsTotal: 0,
            eventsActive: 0,
            publicEventsTotal: 0,
            privateEventsTotal: 0,
            publicEventsActive: 0,
            privateEventsActive: 0,
          );
          _claims = <AdminClaim>[];
          _venues = <AdminVenue>[];
          _events = <AdminEvent>[];
          _users = <AdminUser>[];
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approveClaim(AdminClaim claim) async {
    await _runBusy(
        () => ref.read(adminRepositoryProvider).approveClaim(claim.claimGuid));
    await _load();
  }

  Future<void> _deleteClaim(AdminClaim claim) async {
    final ok = await _confirm(
        'Delete this claim?', 'This will permanently delete the claim.');
    if (!ok) return;
    await _runBusy(
        () => ref.read(adminRepositoryProvider).deleteClaim(claim.claimGuid));
    await _load();
  }

  Future<void> _deleteVenue(AdminVenue venue) async {
    final ok = await _confirm(
      'Delete venue?',
      'This permanently deletes the venue and all related data.',
    );
    if (!ok) return;
    await _runBusy(
        () => ref.read(adminRepositoryProvider).deleteVenue(venue.venueGuid));
    await _load();
  }

  Future<void> _deleteEvent(AdminEvent event) async {
    final ok = await _confirm(
      'Delete event?',
      'This permanently deletes the event and all related data.',
    );
    if (!ok) return;
    await _runBusy(
        () => ref.read(adminRepositoryProvider).deleteEvent(event.venueGuid));
    await _load();
  }

  Future<void> _deleteUser(AdminUser user) async {
    final ok = await _confirm(
      'Delete user?',
      'This permanently deletes the user. If this user owns venues, all owned venues and events are also deleted.',
    );
    if (!ok) return;
    await _runBusy(
        () => ref.read(adminRepositoryProvider).deleteUser(user.userGuid));
    await _load();
  }

  Future<void> _runBusy(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } catch (e) {
      if (!mounted) return;
      showAppError(ref, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Control'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Claims'),
              Tab(text: 'Venues'),
              Tab(text: 'Events'),
              Tab(text: 'Users'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading || _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).logout();
                    },
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      enabled: !_loading && !_busy,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: const InputDecoration(
                        hintText: 'Search venues, events, users, claims',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading || _busy ? null : _load,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
            if (_stats != null) _StatsBar(stats: _stats!),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : TabBarView(
                          children: [
                            _ClaimsTab(
                              claims: _claims,
                              busy: _busy,
                              onApprove: _approveClaim,
                              onDelete: _deleteClaim,
                            ),
                            _VenuesTab(
                              venues: _venues,
                              busy: _busy,
                              onDelete: _deleteVenue,
                            ),
                            _EventsTab(
                              events: _events,
                              busy: _busy,
                              onDelete: _deleteEvent,
                            ),
                            _UsersTab(
                              users: _users,
                              busy: _busy,
                              onDelete: _deleteUser,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _StatChip(label: 'Users', value: '${stats.usersTotal}'),
          _StatChip(label: 'Online', value: '${stats.usersOnline}'),
          _StatChip(label: 'Venues', value: '${stats.venuesTotal}'),
          _StatChip(label: 'Events', value: '${stats.eventsTotal}'),
          _StatChip(label: 'Active events', value: '${stats.eventsActive}'),
          _StatChip(label: 'Public', value: '${stats.publicEventsTotal}'),
          _StatChip(label: 'Private', value: '${stats.privateEventsTotal}'),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Chip(label: Text('$label: $value')),
    );
  }
}

class _ClaimsTab extends StatelessWidget {
  const _ClaimsTab({
    required this.claims,
    required this.busy,
    required this.onApprove,
    required this.onDelete,
  });

  final List<AdminClaim> claims;
  final bool busy;
  final Future<void> Function(AdminClaim claim) onApprove;
  final Future<void> Function(AdminClaim claim) onDelete;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) return const Center(child: Text('No claims'));
    return ListView.builder(
      itemCount: claims.length,
      itemBuilder: (context, index) {
        final c = claims[index];
        final pending = c.status.toLowerCase() == 'pending';
        return ListTile(
          title: Text(c.name),
          subtitle: Text('${c.contactName} | ${c.contactPhone} | ${c.status}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending)
                TextButton(
                  onPressed: busy ? null : () => onApprove(c),
                  child: const Text('Approve'),
                ),
              IconButton(
                onPressed: busy ? null : () => onDelete(c),
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Delete claim',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VenuesTab extends StatelessWidget {
  const _VenuesTab({
    required this.venues,
    required this.busy,
    required this.onDelete,
  });

  final List<AdminVenue> venues;
  final bool busy;
  final Future<void> Function(AdminVenue venue) onDelete;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const Center(child: Text('No venues'));
    return ListView.builder(
      itemCount: venues.length,
      itemBuilder: (context, index) {
        final v = venues[index];
        return ListTile(
          leading: _VenuePhoto(venueGuid: v.venueGuid, hasPhoto: v.hasPhoto),
          title: Text(v.name),
          subtitle: Text(
              'status=${v.status} | owner=${v.ownerName ?? '-'} | by=${v.creatorName ?? '-'}'),
          trailing: v.type.toLowerCase() == 'global'
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: busy ? null : () => onDelete(v),
                  icon: const Icon(Icons.delete_forever),
                ),
        );
      },
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.events,
    required this.busy,
    required this.onDelete,
  });

  final List<AdminEvent> events;
  final bool busy;
  final Future<void> Function(AdminEvent event) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const Center(child: Text('No events'));
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final e = events[index];
        return ListTile(
          leading: _VenuePhoto(venueGuid: e.venueGuid, hasPhoto: e.hasPhoto),
          title: Text(e.name),
          subtitle: Text(
              'status=${e.status} | type=${e.eventType} | owner=${e.ownerName ?? '-'}'),
          trailing: IconButton(
            onPressed: busy ? null : () => onDelete(e),
            icon: const Icon(Icons.delete_forever),
          ),
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.busy,
    required this.onDelete,
  });

  final List<AdminUser> users;
  final bool busy;
  final Future<void> Function(AdminUser user) onDelete;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const Center(child: Text('No users'));
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final isAdmin = u.role.toLowerCase() == 'admin';
        return ListTile(
          leading: _UserPhoto(userGuid: u.userGuid, hasPhoto: u.hasPhoto),
          title: Row(
            children: [
              Expanded(child: Text(u.displayName)),
              if (u.isVenueOwner)
                const Chip(
                  label: Text('Venue owner'),
                  visualDensity: VisualDensity.compact,
                ),
              if (u.hasActiveEvent)
                const Chip(
                  label: Text('Active event'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          subtitle: Text('${u.email} | role=${u.role}'),
          trailing: isAdmin
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: busy ? null : () => onDelete(u),
                  icon: const Icon(Icons.delete_forever),
                ),
        );
      },
    );
  }
}

class _UserPhoto extends StatelessWidget {
  const _UserPhoto({required this.userGuid, required this.hasPhoto});

  final String userGuid;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    if (!hasPhoto) return const CircleAvatar(child: Icon(Icons.person));
    final url = '$kApiBaseUrl${ApiEndpoints.photo(userGuid)}';
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person),
        ),
      ),
    );
  }
}

class _VenuePhoto extends StatelessWidget {
  const _VenuePhoto({required this.venueGuid, required this.hasPhoto});

  final String venueGuid;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    if (!hasPhoto) return const CircleAvatar(child: Icon(Icons.place));
    final url = '$kApiBaseUrl${ApiEndpoints.venuePhotoServe(venueGuid)}';
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.place),
        ),
      ),
    );
  }
}
