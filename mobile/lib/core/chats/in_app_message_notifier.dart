import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../signalr/hub_events.dart';
import '../signalr/venue_hub_client.dart';
import '../auth/auth_controller.dart';
import '../ui/global_messenger.dart';
import '../ui/venue_announcement_popup.dart';
import '../../features/venues/active_venue_controller.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../push/open_chats.dart';

final inAppMessageNotifierProvider = Provider<InAppMessageNotifier>((ref) {
  final notifier = InAppMessageNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class InAppMessageNotifier {
  InAppMessageNotifier(this._ref) {
    _sub = _ref.read(venueHubClientProvider).events.listen(_onHubEvent);
  }

  final Ref _ref;
  StreamSubscription<HubEvent>? _sub;
  Timer? _dismissTimer;
  AudioPlayer? _player;

  void _onHubEvent(HubEvent e) {
    if (e is MessageReceivedEvent) {
      _handleMessage(e);
      return;
    }

    if (e is VenueAnnouncementEvent) {
      unawaited(_showVenueAnnouncement(e));
    }
  }

  void _handleMessage(MessageReceivedEvent e) {
    // Gate 1: user must be checked into a venue
    final active = _ref.read(activeVenueProvider).value;
    if (active == null) {
      return;
    }

    final msg = e.message;

    // Gate 2: skip echoes — message sent by current user
    final me = _ref.read(authControllerProvider).userOrNull;
    if (me != null &&
        me.userGuid.toLowerCase() == msg.fromUserGuid.toLowerCase()) {
      return;
    }

    // Gate 3: skip if the chat for this match is currently open
    final openChats = _ref.read(openChatsProvider);
    if (openChats.any((g) => g.toLowerCase() == msg.matchGuid.toLowerCase())) {
      return;
    }

    final messengerState = _ref.read(globalMessengerKeyProvider).currentState;
    if (messengerState == null) {
      return;
    }

    // Feedback
    HapticFeedback.lightImpact();
    _playSound();

    final senderName =
        msg.fromDisplayName.isNotEmpty ? msg.fromDisplayName : 'New message';
    final preview =
        msg.body.length > 80 ? '${msg.body.substring(0, 80)}…' : msg.body;

    _dismissTimer?.cancel();
    messengerState.hideCurrentMaterialBanner();
    messengerState.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.chat_bubble_outline),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            children: [
              TextSpan(
                text: senderName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '  '),
              TextSpan(text: preview),
            ],
          ),
        ),
        backgroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: () {
              _dismissTimer?.cancel();
              messengerState.hideCurrentMaterialBanner();
              _ref
                  .read(appRouterProvider)
                  .push(AppRoutes.chatFor(msg.matchGuid));
            },
            child: const Text('OPEN'),
          ),
          TextButton(
            onPressed: () {
              _dismissTimer?.cancel();
              messengerState.hideCurrentMaterialBanner();
            },
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      messengerState.hideCurrentMaterialBanner();
    });
  }

  Future<void> _showVenueAnnouncement(VenueAnnouncementEvent event) async {
    final active = _ref.read(activeVenueProvider).valueOrNull;
    if (active == null ||
        active.venueGuid.toLowerCase() != event.venueGuid.toLowerCase()) {
      return;
    }

    final navigatorState = _ref.read(globalNavigatorKeyProvider).currentState;
    final context = navigatorState?.context;
    if (context == null || !context.mounted) return;

    HapticFeedback.mediumImpact();
    await showVenueAnnouncementPopup(
      context,
      title: event.title,
      body: event.body,
    );
  }

  Future<void> _playSound() async {
    try {
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {
      // Silent fail — banner + haptic still work without sound
    }
  }

  void dispose() {
    _dismissTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _player?.dispose();
    _player = null;
  }
}
