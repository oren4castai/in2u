import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/chats/chat_repository.dart';
import '../../core/models/chat_message.dart';
import '../../core/signalr/hub_events.dart';
import '../../core/signalr/venue_hub_client.dart';
import '../../core/utils/client_msg_id.dart';

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  (ref, matchGuid) => ChatController(ref, matchGuid),
);

class ChatState {
  final AsyncValue<void> historyStatus;
  final List<ChatMessage> messages;
  final bool loadingMore;
  final bool hasMore;
  final bool peerTyping;
  final DateTime? peerTypingExpiresAt;
  final bool ended;

  const ChatState({
    required this.historyStatus,
    required this.messages,
    required this.loadingMore,
    required this.hasMore,
    required this.peerTyping,
    required this.peerTypingExpiresAt,
    required this.ended,
  });

  factory ChatState.initial() => const ChatState(
        historyStatus: AsyncValue.loading(),
        messages: <ChatMessage>[],
        loadingMore: false,
        hasMore: true,
        peerTyping: false,
        peerTypingExpiresAt: null,
        ended: false,
      );

  ChatState copyWith({
    AsyncValue<void>? historyStatus,
    List<ChatMessage>? messages,
    bool? loadingMore,
    bool? hasMore,
    bool? peerTyping,
    DateTime? peerTypingExpiresAt,
    bool clearPeerTypingExpiresAt = false,
    bool? ended,
  }) {
    return ChatState(
      historyStatus: historyStatus ?? this.historyStatus,
      messages: messages ?? this.messages,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      peerTyping: peerTyping ?? this.peerTyping,
      peerTypingExpiresAt: clearPeerTypingExpiresAt
          ? null
          : (peerTypingExpiresAt ?? this.peerTypingExpiresAt),
      ended: ended ?? this.ended,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref, this.matchGuid) : super(ChatState.initial()) {
    final auth = _ref.read(authControllerProvider);
    _myUserGuid = auth is AuthAuthenticated ? auth.user.userGuid : null;

    _authSub = _ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is AuthAuthenticated) {
        _myUserGuid = next.user.userGuid;
      } else if (next is AuthUnauthenticated) {
        _myUserGuid = null;
      }
    });

    _hubSub = _ref.read(venueHubClientProvider).events.listen(_onHubEvent);
    Future.microtask(_loadInitial);
  }

  final Ref _ref;
  final String matchGuid;

  String? _myUserGuid;
  StreamSubscription<HubEvent>? _hubSub;
  ProviderSubscription<AuthState>? _authSub;
  Timer? _peerTypingTimer;
  Timer? _typingThrottleTimer;
  DateTime? _lastTypingTrueAt;
  int? _oldestBeforeId;

  String? get myUserGuid => _myUserGuid;

  Future<void> _loadInitial() async {
    try {
      final resp = await _ref
          .read(chatRepositoryProvider)
          .getHistory(matchGuid, limit: 50);
      if (!mounted) return;
      final ordered = resp.items.reversed.toList(growable: true);
      _oldestBeforeId = resp.nextBeforeId;
      state = state.copyWith(
        historyStatus: const AsyncValue.data(null),
        messages: ordered,
        hasMore: resp.nextBeforeId != null,
      );
    } catch (e, st) {
      if (!mounted) return;
      state = state.copyWith(historyStatus: AsyncValue.error(e, st));
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingMore || !state.hasMore || _oldestBeforeId == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final resp = await _ref.read(chatRepositoryProvider).getHistory(
            matchGuid,
            beforeId: _oldestBeforeId,
            limit: 50,
          );
      if (!mounted) return;
      final older = resp.items.reversed.toList();
      _oldestBeforeId = resp.nextBeforeId;
      state = state.copyWith(
        messages: [...older, ...state.messages],
        loadingMore: false,
        hasMore: resp.nextBeforeId != null,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) return;
    final me = _myUserGuid;
    if (me == null) return;

    final clientMsgId = generateClientMsgId();
    final optimistic = ChatMessage(
      messageGuid: clientMsgId,
      matchGuid: matchGuid,
      fromUserGuid: me,
      body: trimmed,
      sentAt: DateTime.now().toUtc(),
      clientMsgId: clientMsgId,
      pending: true,
    );
    state = state.copyWith(messages: [...state.messages, optimistic]);

    await _attemptSend(trimmed, clientMsgId);
  }

  Future<void> retry(String clientMsgId) async {
    final idx = state.messages
        .indexWhere((m) => m.clientMsgId == clientMsgId && m.failed);
    if (idx < 0) return;
    final msg = state.messages[idx];
    final updated = [...state.messages];
    updated[idx] = msg.copyWith(pending: true, failed: false);
    state = state.copyWith(messages: updated);
    await _attemptSend(msg.body, clientMsgId);
  }

  Future<void> _attemptSend(String body, String clientMsgId) async {
    final hub = _ref.read(venueHubClientProvider);
    try {
      if (hub.isConnected) {
        await hub.sendMessage(matchGuid, body, clientMsgId);
        return;
      }
    } catch (_) {
      // fall through to REST
    }
    try {
      final server = await _ref.read(chatRepositoryProvider).send(
            matchGuid,
            body: body,
            clientMsgId: clientMsgId,
          );
      if (server == null) {
        // 204 -> match gone (hard-deleted by peer leaving).
        if (!mounted) return;
        state = state.copyWith(
          messages: const <ChatMessage>[],
          hasMore: false,
          ended: true,
          peerTyping: false,
          clearPeerTypingExpiresAt: true,
        );
        return;
      }
      _reconcileServerMessage(server);
    } catch (_) {
      _markFailed(clientMsgId);
    }
  }

  void _markFailed(String clientMsgId) {
    if (!mounted) return;
    final idx = state.messages.indexWhere((m) => m.clientMsgId == clientMsgId);
    if (idx < 0) return;
    final updated = [...state.messages];
    updated[idx] = updated[idx].copyWith(pending: false, failed: true);
    state = state.copyWith(messages: updated);
  }

  void _reconcileServerMessage(ChatMessage server) {
    if (!mounted) return;
    final list = [...state.messages];
    int idx = -1;
    if (server.clientMsgId != null) {
      idx = list.indexWhere(
          (m) => m.clientMsgId != null && m.clientMsgId == server.clientMsgId);
    }
    if (idx < 0) {
      idx = list.indexWhere((m) => m.messageGuid == server.messageGuid);
    }
    if (idx >= 0) {
      list[idx] = server;
    } else {
      list.add(server);
    }
    state = state.copyWith(messages: list);
  }

  void _onHubEvent(HubEvent e) {
    if (!mounted) return;
    if (e is MessageReceivedEvent && e.message.matchGuid == matchGuid) {
      _reconcileServerMessage(e.message);
      if (e.message.fromUserGuid != _myUserGuid) {
        _bestEffortMarkRead(e.message.messageGuid);
      }
    } else if (e is TypingChangedEvent &&
        e.matchGuid == matchGuid &&
        e.fromUserGuid != _myUserGuid) {
      if (e.isTyping) {
        final expires = DateTime.now().add(const Duration(seconds: 4));
        state = state.copyWith(
          peerTyping: true,
          peerTypingExpiresAt: expires,
        );
        _peerTypingTimer?.cancel();
        _peerTypingTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          state = state.copyWith(
            peerTyping: false,
            clearPeerTypingExpiresAt: true,
          );
        });
      } else {
        _peerTypingTimer?.cancel();
        state = state.copyWith(
          peerTyping: false,
          clearPeerTypingExpiresAt: true,
        );
      }
    } else if (e is MessageReadEvent && e.matchGuid == matchGuid) {
      final list = [...state.messages];
      final idx = list.indexWhere((m) => m.messageGuid == e.messageGuid);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(readAt: e.readAt);
        state = state.copyWith(messages: list);
      }
    } else if (e is MatchEndedEvent && e.matchGuid == matchGuid) {
      Future.microtask(() {
        if (!mounted) return;
        state = state.copyWith(
          messages: const <ChatMessage>[],
          hasMore: false,
          ended: true,
          peerTyping: false,
          clearPeerTypingExpiresAt: true,
        );
      });
    }
  }

  Future<void> _bestEffortMarkRead(String messageGuid) async {
    try {
      final hub = _ref.read(venueHubClientProvider);
      if (hub.isConnected) {
        await hub.markRead(matchGuid, messageGuid);
      }
    } catch (_) {
      // ignore
    }
  }

  void setTyping(bool isTyping) {
    if (state.ended) return;
    final hub = _ref.read(venueHubClientProvider);
    if (!hub.isConnected) return;
    if (isTyping) {
      final now = DateTime.now();
      if (_lastTypingTrueAt != null &&
          now.difference(_lastTypingTrueAt!) < const Duration(seconds: 3)) {
        return;
      }
      _lastTypingTrueAt = now;
    }
    _typingThrottleTimer?.cancel();
    () async {
      try {
        await hub.sendTyping(matchGuid, isTyping);
      } catch (_) {
        // ignore
      }
    }();
  }

  @override
  void dispose() {
    _hubSub?.cancel();
    _authSub?.close();
    _peerTypingTimer?.cancel();
    _typingThrottleTimer?.cancel();
    final hub = _ref.read(venueHubClientProvider);
    if (hub.isConnected) {
      hub.sendTyping(matchGuid, false).catchError((_) {});
    }
    super.dispose();
  }
}
