import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../auth/token_storage.dart';
import '../models/chat_message.dart';
import '../models/match.dart';
import 'hub_events.dart';

const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080/api/v1',
);

final venueHubClientProvider = Provider<VenueHubClient>((ref) {
  final client = VenueHubClient(ref);
  ref.onDispose(client.dispose);
  return client;
});

class VenueHubClient {
  VenueHubClient(this._ref);

  final Ref _ref;
  HubConnection? _connection;
  final _events = StreamController<HubEvent>.broadcast();
  final _connectionState = StreamController<HubConnectionState>.broadcast();

  Stream<HubEvent> get events => _events.stream;
  Stream<HubConnectionState> get connectionState => _connectionState.stream;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (_connection != null &&
        (_connection!.state == HubConnectionState.Connected ||
            _connection!.state == HubConnectionState.Connecting)) {
      return;
    }

    final url = _deriveHubUrl(_apiBaseUrl);

    final connection = HubConnectionBuilder()
        .withUrl(
      url,
      options: HttpConnectionOptions(
        accessTokenFactory: () async =>
            (await _ref.read(tokenStorageProvider).readAccessToken()) ?? '',
      ),
    )
        .withAutomaticReconnect(
      retryDelays: [0, 2000, 5000, 10000],
    ).build();

    connection.on('VenueJoined', _onVenueJoined);
    connection.on('PresenceUpdated', _onPresenceUpdated);
    connection.on('VenueLeft', _onVenueLeft);
    connection.on('ForceCheckout', _onForceCheckout);
    connection.on('MatchCreated', _onMatchCreated);
    connection.on('MatchEnded', _onMatchEnded);
    connection.on('MessageReceived', _onMessageReceived);
    connection.on('TypingChanged', _onTypingChanged);
    connection.on('MessageRead', _onMessageRead);
    connection.on('EventListChanged', _onEventListChanged);
    connection.on('VenueAnnouncement', _onVenueAnnouncement);

    connection.onclose(({Exception? error}) {
      _connectionState.add(HubConnectionState.Disconnected);
    });
    connection.onreconnecting(({Exception? error}) {
      _connectionState.add(HubConnectionState.Reconnecting);
    });
    connection.onreconnected(({String? connectionId}) {
      _connectionState.add(HubConnectionState.Connected);
      _events.add(const ReconnectedEvent());
      // Re-announce foreground app state after reconnect.
      unawaited(_safeSetAppState(true));
    });

    _connection = connection;
    await connection.start();
    _connectionState.add(HubConnectionState.Connected);
    // Tell the server we are in the foreground as soon as we connect.
    unawaited(_safeSetAppState(true));
  }

  Future<void> _safeSetAppState(bool isForeground) async {
    try {
      await setAppState(isForeground);
    } catch (e) {
      debugPrint('setAppState failed: $e');
    }
  }

  Future<void> disconnect() async {
    final c = _connection;
    if (c == null) return;
    try {
      await c.stop();
    } catch (_) {
      // ignore
    }
    _connection = null;
    _connectionState.add(HubConnectionState.Disconnected);
  }

  Future<void> joinVenue(String venueGuid) => _invoke('JoinVenue', [venueGuid]);

  Future<void> leaveVenueGroup(String venueGuid) =>
      _invoke('LeaveVenue', [venueGuid]);

  Future<void> sendLocation(String venueGuid, double lat, double lng) =>
      _invoke('SendLocation', [venueGuid, lat, lng]);

  Future<void> sendMessage(
    String matchGuid,
    String body,
    String? clientMsgId,
  ) =>
      _invoke('SendMessage', [matchGuid, body, clientMsgId ?? '']);

  Future<void> sendTyping(String matchGuid, bool isTyping) =>
      _invoke('Typing', [matchGuid, isTyping]);

  Future<void> markRead(String matchGuid, String messageGuid) =>
      _invoke('MarkRead', [matchGuid, messageGuid]);

  Future<void> setAppState(bool isForeground) =>
      _invoke('SetAppState', [isForeground]);

  Future<void> _invoke(String method, List<Object> args) async {
    final c = _connection;
    if (c == null || c.state != HubConnectionState.Connected) {
      throw StateError('Hub is not connected');
    }
    await c.invoke(method, args: args);
  }

  void _onVenueJoined(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(VenueJoinedEvent(
      p['venueGuid'].toString(),
      p['membershipGuid'].toString(),
    ));
  }

  void _onPresenceUpdated(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(PresenceUpdatedEvent(
      p['venueGuid'].toString(),
      p['densityBucket'].toString(),
    ));
  }

  void _onVenueLeft(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(VenueLeftEvent(
      p['venueGuid'].toString(),
      p['reason'].toString(),
    ));
  }

  void _onForceCheckout(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(ForceCheckoutEvent(
      p['venueGuid'].toString(),
      p['reason'].toString(),
    ));
  }

  void _onMatchCreated(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(MatchCreatedEvent(Match.fromJson(p)));
  }

  void _onMatchEnded(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(MatchEndedEvent(
      p['matchGuid'].toString(),
      (p['reason'] ?? '').toString(),
    ));
  }

  void _onMessageReceived(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(MessageReceivedEvent(ChatMessage.fromJson(p)));
  }

  void _onTypingChanged(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(TypingChangedEvent(
      p['matchGuid'].toString(),
      p['fromUserGuid'].toString(),
      p['isTyping'] == true,
    ));
  }

  void _onMessageRead(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    _events.add(MessageReadEvent(
      p['matchGuid'].toString(),
      p['messageGuid'].toString(),
      DateTime.parse(p['readAt'].toString()),
    ));
  }

  void _onEventListChanged(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    final venueGuid = p['venueGuid']?.toString();
    final kind = p['kind']?.toString();
    if (venueGuid == null || kind == null) return;
    _events.add(EventListChangedEvent(venueGuid, kind));
  }

  void _onVenueAnnouncement(List<Object?>? args) {
    final p = _firstMap(args);
    if (p == null) return;
    final venueGuid = p['venueGuid']?.toString();
    if (venueGuid == null) return;
    _events.add(VenueAnnouncementEvent(
      venueGuid,
      (p['title'] ?? 'Venue announcement').toString(),
      (p['body'] ?? '').toString(),
    ));
  }

  Map<String, dynamic>? _firstMap(List<Object?>? args) {
    if (args == null || args.isEmpty) return null;
    final first = args.first;
    if (first is Map) {
      return first.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  void dispose() {
    disconnect();
    _events.close();
    _connectionState.close();
  }

  static String _deriveHubUrl(String apiBase) {
    final u = Uri.parse(apiBase);
    final hubPath = u.path.replaceAll('/api/v1', '');
    return u.replace(path: '$hubPath/hubs/venue').toString();
  }
}
