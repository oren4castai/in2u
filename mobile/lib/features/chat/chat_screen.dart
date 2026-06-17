import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/chat_message.dart';
import '../../core/models/match.dart';
import '../../core/push/open_chats.dart';
import '../matches/matches_controller.dart';
import 'chat_controller.dart';
import '../../core/ui/global_messenger.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchGuid});

  final String matchGuid;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _lastMessageCount = 0;
  late final OpenChatsController _openChats;
  late final ChatController _chatNotifier;

  @override
  void initState() {
    super.initState();
    _openChats = ref.read(openChatsProvider.notifier);
    _chatNotifier = ref.read(chatControllerProvider(widget.matchGuid).notifier);
    Future.microtask(() {
      if (!mounted) return;
      _openChats.add(widget.matchGuid);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
    Future.microtask(() {
      _openChats.remove(widget.matchGuid);
      _chatNotifier.setTyping(false);
    });
  }

  bool _nearBottom() {
    if (!_scrollController.hasClients) return true;
    // reverse: true → "bottom" is pixels == 0
    return _scrollController.position.pixels <= 80;
  }

  void _maybeAutoScroll() {
    if (!_scrollController.hasClients) return;
    if (_nearBottom()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Match? _findMatch() {
    final matches = ref.read(matchesControllerProvider).value;
    if (matches == null) return null;
    for (final m in matches) {
      if (m.matchGuid == widget.matchGuid) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider(widget.matchGuid));
    final controller =
        ref.read(chatControllerProvider(widget.matchGuid).notifier);
    final match = _findMatch();

    if (state.messages.length != _lastMessageCount) {
      _lastMessageCount = state.messages.length;
      _maybeAutoScroll();
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/matches');
            }
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match?.peer.displayName ?? 'Chat',
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            if (match != null)
              Text(
                'at ${match.venueName}',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.ended)
              MaterialBanner(
                content: const Text('This match has ended. Chat is closed.'),
                actions: const [
                  SizedBox.shrink(),
                ],
              ),
            Expanded(
              child: state.historyStatus.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(friendlyErrorMessage(e),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                data: (_) => _buildList(state, controller),
              ),
            ),
            if (!state.ended) _buildInputRow(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ChatState state, ChatController controller) {
    final me = controller.myUserGuid;
    final messages = state.messages;
    final hasTyping = state.peerTyping;
    final hasOlderSentinel = state.hasMore || state.loadingMore;

    final itemCount =
        messages.length + (hasTyping ? 1 : 0) + (hasOlderSentinel ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        int i = index;

        if (hasTyping) {
          if (i == 0) {
            return const _TypingIndicator();
          }
          i -= 1;
        }

        if (i < messages.length) {
          // reverse: most recent at the bottom
          final msg = messages[messages.length - 1 - i];
          final isMine = msg.fromUserGuid == me;
          return _MessageBubble(
            message: msg,
            isMine: isMine,
            onRetry: msg.failed && msg.clientMsgId != null
                ? () => controller.retry(msg.clientMsgId!)
                : null,
          );
        }

        // top sentinel
        if (state.loadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: TextButton(
              onPressed: controller.loadOlder,
              child: const Text('Load older messages'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputRow(ChatController controller) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: (value) {
                controller.setTyping(value.trim().isNotEmpty);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              final text = _textController.text;
              if (text.trim().isEmpty) return;
              _textController.clear();
              controller.setTyping(false);
              await controller.sendText(text);
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = isMine ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = isMine ? cs.onPrimaryContainer : cs.onSurface;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final timeText = DateFormat.Hm().format(message.sentAt.toLocal());

    final children = <Widget>[
      Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          message.body,
          style: TextStyle(color: fg),
        ),
      ),
      const SizedBox(height: 2),
      _Footer(
        isMine: isMine,
        timeText: timeText,
        message: message,
        onRetry: onRetry,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align,
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isMine,
    required this.timeText,
    required this.message,
    required this.onRetry,
  });

  final bool isMine;
  final String timeText;
  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final parts = <Widget>[
      Text(timeText, style: style),
    ];
    if (isMine) {
      if (message.pending) {
        parts.add(const SizedBox(width: 6));
        parts.add(const SizedBox(
          height: 10,
          width: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ));
      } else if (message.failed) {
        parts.add(const SizedBox(width: 6));
        parts.add(GestureDetector(
          onTap: onRetry,
          child: Text(
            'Failed - tap to retry',
            style: style?.copyWith(color: Colors.red),
          ),
        ));
      } else if (message.readAt != null) {
        parts.add(const SizedBox(width: 6));
        parts.add(Text('Read', style: style));
      } else {
        parts.add(const SizedBox(width: 6));
        parts.add(Text('Sent', style: style));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts,
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: AnimatedBuilder(
            animation: _ac,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = ((_ac.value + i * 0.2) % 1.0);
                  final opacity = (t < 0.5) ? (t * 2) : (2 - t * 2);
                  return Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                    child: Opacity(
                      opacity: opacity.clamp(0.2, 1.0),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
