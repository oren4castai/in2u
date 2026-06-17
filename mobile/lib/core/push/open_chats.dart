import 'package:flutter_riverpod/flutter_riverpod.dart';

final openChatsProvider =
    StateNotifierProvider<OpenChatsController, Set<String>>(
  (ref) => OpenChatsController(),
);

class OpenChatsController extends StateNotifier<Set<String>> {
  OpenChatsController() : super(<String>{});

  void add(String matchGuid) {
    if (state.contains(matchGuid)) return;
    state = {...state, matchGuid};
  }

  void remove(String matchGuid) {
    if (!state.contains(matchGuid)) return;
    state = {...state}..remove(matchGuid);
  }

  bool contains(String matchGuid) => state.contains(matchGuid);
}
