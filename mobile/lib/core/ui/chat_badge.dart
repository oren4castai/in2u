import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/matches/matches_controller.dart';

class ChatsBadgeButton extends ConsumerWidget {
  const ChatsBadgeButton({
    super.key,
    required this.onPressed,
    this.tooltip,
    this.icon = const Icon(Icons.favorite_border),
  });

  final VoidCallback onPressed;
  final String? tooltip;
  final Widget icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesControllerProvider);
    final hasMatches = matches.valueOrNull?.isNotEmpty == true;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: icon,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (hasMatches)
          Positioned(
            // position the small dot at the top-right of the icon
            right: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
