import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match.dart';

/// Holds the [Match] that should trigger the celebration overlay.
/// Set to [null] once the overlay has been dismissed.
final matchCelebrationProvider = StateProvider<Match?>((ref) => null);
