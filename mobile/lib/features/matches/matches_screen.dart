import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/ui/global_messenger.dart';
import '../../core/models/match.dart';
import '../../routing/routes.dart';
import 'matches_controller.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchesControllerProvider);
    final controller = ref.read(matchesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: controller.refresh,
          ),
        ],
      ),
      body: state.when(
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
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 64),
                  SizedBox(height: 12),
                  Text('No matches yet'),
                  SizedBox(height: 6),
                  Text('Keep swiping'),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _MatchTile(
                match: matches[i],
                onUnmatch: () => controller.unmatch(matches[i].matchGuid),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onUnmatch});

  final Match match;
  final Future<void> Function() onUnmatch;

  @override
  Widget build(BuildContext context) {
    final peer = match.peer;
    final hasPhoto = peer.photoUrl != null;
    final initial = peer.displayName.isNotEmpty
        ? peer.displayName.characters.first.toUpperCase()
        : '?';
    String title = peer.displayName;
    if (peer.birthYear != null) {
      final age = DateTime.now().year - peer.birthYear!;
      title = '${peer.displayName}, $age';
    }
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            hasPhoto ? NetworkImage(fullPhotoUrl(peer.photoUrl!)) : null,
        child: hasPhoto ? null : Text(initial),
      ),
      title: Text(title),
      subtitle: Text('at ${match.venueName}'),
      trailing: IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        tooltip: 'Chat',
        onPressed: () => context.push(AppRoutes.chatFor(match.matchGuid)),
      ),
      onTap: () => _showProfile(context),
    );
  }

  void _showProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeerProfileSheet(match: match, onUnmatch: onUnmatch),
    );
  }
}

class _PeerProfileSheet extends StatelessWidget {
  const _PeerProfileSheet({required this.match, required this.onUnmatch});

  final Match match;
  final Future<void> Function() onUnmatch;

  @override
  Widget build(BuildContext context) {
    final peer = match.peer;
    final theme = Theme.of(context);
    final hasPhoto = peer.photoUrl != null;
    final age =
        peer.birthYear != null ? DateTime.now().year - peer.birthYear! : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // ── Photo ────────────────────────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      height: 340,
                      width: double.infinity,
                      child: hasPhoto
                          ? Image.network(
                              fullPhotoUrl(peer.photoUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _photoPlaceholder(context),
                            )
                          : _photoPlaceholder(context),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Drag handle
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white54,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Close button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: SafeArea(
                        child: Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Name + age overlay
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Text(
                        age != null
                            ? '${peer.displayName}, $age'
                            : peer.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            const Shadow(blurRadius: 8, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // ── Info ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.place,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Met at ${match.venueName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (peer.bio != null && peer.bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      peer.bio!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                // ── Actions ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push(AppRoutes.chatFor(match.matchGuid));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.person_remove,
                              color: theme.colorScheme.error),
                          label: Text(
                            'Unmatch',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
                          onPressed: () => _confirmUnmatch(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    final peer = match.peer;
    final initial = peer.displayName.isNotEmpty
        ? peer.displayName.characters.first.toUpperCase()
        : '?';
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(fontSize: 80, color: Colors.white54),
        ),
      ),
    );
  }

  Future<void> _confirmUnmatch(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unmatch with ${match.peer.displayName}?'),
        content: const Text(
          'This will end the match and delete your chat history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unmatch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.of(context).pop(); // close the profile sheet
    await onUnmatch();
  }
}
