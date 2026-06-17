import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../signalr/venue_hub_client.dart';

class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    final hub = ref.read(venueHubClientProvider);
    if (hub.isConnected) {
      hub.setAppState(isForeground).catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
