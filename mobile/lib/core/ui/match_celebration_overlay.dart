import 'dart:math';

import 'package:flutter/material.dart';

import '../models/match.dart';

class MatchCelebrationOverlay extends StatefulWidget {
  const MatchCelebrationOverlay({
    super.key,
    required this.match,
    required this.onDismiss,
  });

  final Match match;
  final VoidCallback onDismiss;

  @override
  State<MatchCelebrationOverlay> createState() =>
      _MatchCelebrationOverlayState();
}

class _MatchCelebrationOverlayState extends State<MatchCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Fade-in: 0 → 0.12
  late final Animation<double> _bgOpacity;
  // Text fades in: 0.08 → 0.28
  late final Animation<double> _textOpacity;
  // Heart scale sequence: pop-in → heartbeat → shrink-out
  late final Animation<double> _heartScale;
  // Fade-out: 0.78 → 1.0
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _bgOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.12, curve: Curves.easeIn),
    );

    _textOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.08, 0.28, curve: Curves.easeIn),
    );

    _heartScale = TweenSequence<double>([
      // pop in with overshoot
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 22,
      ),
      // settle back
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0),
        weight: 6,
      ),
      // heartbeat: two beats
      TweenSequenceItem(
        tween: TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.15), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
          TweenSequenceItem(tween: ConstantTween(1.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.12), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 1),
        ]),
        weight: 50,
      ),
      // shrink out
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
    ]).animate(_ctrl);

    _fadeOut = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.78, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final visible =
              (_bgOpacity.value * (1.0 - _fadeOut.value)).clamp(0.0, 1.0);
          return Opacity(
            opacity: visible,
            child: ColoredBox(
              color: Colors.black.withOpacity(0.82),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Glitter / confetti ──────────────────────────────────
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlitterPainter(progress: _ctrl.value),
                    ),
                  ),
                  // ── Centre content ──────────────────────────────────────
                  Center(
                    child: Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            "It's a Match!",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 24,
                                  color: Color(0xFFFF1493),
                                ),
                                Shadow(
                                  blurRadius: 8,
                                  color: Color(0xFFFF69B4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Animated heart
                          Transform.scale(
                            scale: _heartScale.value.clamp(0.0, 2.0),
                            child: const _HeartWidget(),
                          ),
                          const SizedBox(height: 32),
                          // Peer name
                          Text(
                            widget.match.peer.displayName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You both liked each other',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 36),
                          const Text(
                            'Tap anywhere to continue',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white38,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Heart drawn with CustomPainter ──────────────────────────────────────────

class _HeartWidget extends StatelessWidget {
  const _HeartWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(110, 100),
      painter: _HeartPainter(),
    );
  }
}

class _HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    // Classic heart shape via bezier curves
    path.moveTo(w * 0.5, h * 0.85);
    path.cubicTo(w * 0.0, h * 0.55, w * -0.05, h * 0.25, w * 0.25, h * 0.15);
    path.cubicTo(w * 0.38, h * 0.08, w * 0.5, h * 0.15, w * 0.5, h * 0.28);
    path.cubicTo(w * 0.5, h * 0.15, w * 0.62, h * 0.08, w * 0.75, h * 0.15);
    path.cubicTo(w * 1.05, h * 0.25, w * 1.0, h * 0.55, w * 0.5, h * 0.85);
    path.close();

    // Gradient fill
    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFF6B9D),
        const Color(0xFFFF1493),
        const Color(0xFFC71585),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Glow shadow
    final glowPaint = Paint()
      ..color = const Color(0xFFFF1493).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Shine highlight
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final shinePath = Path();
    shinePath.moveTo(w * 0.35, h * 0.20);
    shinePath.cubicTo(
        w * 0.32, h * 0.16, w * 0.42, h * 0.12, w * 0.48, h * 0.19);
    shinePath.cubicTo(
        w * 0.50, h * 0.22, w * 0.38, h * 0.26, w * 0.35, h * 0.20);
    shinePath.close();
    canvas.drawPath(shinePath, shinePaint);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => false;
}

// ─── Glitter / confetti particles ────────────────────────────────────────────

class _GlitterPainter extends CustomPainter {
  const _GlitterPainter({required this.progress});

  final double progress;

  static final _rng = Random(1337);
  static final List<_Particle> _particles =
      List.generate(80, (_) => _Particle.random(_rng));

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42; // near heart centre

    for (final p in _particles) {
      final age = progress - p.delay;
      if (age <= 0) continue;

      final lifetime = 1.0 - p.delay;
      final t = (age / lifetime).clamp(0.0, 1.0);

      // Position: burst from centre with gravity
      final dx = cos(p.angle) * p.speed * t * size.width * 0.52;
      final dy = sin(p.angle) * p.speed * t * size.height * 0.45 +
          0.35 * t * t * size.height;

      // Opacity: fade in then out
      final fadeIn = (t / 0.18).clamp(0.0, 1.0);
      final fadeOut = 1.0 - ((t - 0.45) / 0.55).clamp(0.0, 1.0);
      final opacity = (fadeIn * fadeOut * 0.92).clamp(0.0, 1.0);

      final radius = p.radius * (1.0 - t * 0.35).clamp(0.2, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final x = cx + dx;
      final y = cy + dy;

      if (p.isSquare) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t * p.speed * 8);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: radius * 2, height: radius * 2),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GlitterPainter old) => old.progress != progress;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.radius,
    required this.delay,
    required this.color,
    required this.isSquare,
  });

  factory _Particle.random(Random rng) => _Particle(
        angle: rng.nextDouble() * pi * 2,
        speed: rng.nextDouble() * 0.7 + 0.15,
        radius: rng.nextDouble() * 5.5 + 2.0,
        delay: rng.nextDouble() * 0.30,
        color: _colors[rng.nextInt(_colors.length)],
        isSquare: rng.nextDouble() > 0.55,
      );

  final double angle;
  final double speed;
  final double radius;
  final double delay;
  final Color color;
  final bool isSquare;

  static const _colors = [
    Color(0xFFFF1493), // deep pink
    Color(0xFFFF69B4), // hot pink
    Color(0xFFFFD700), // gold
    Color(0xFFFFF0F5), // near white / lavender blush
    Color(0xFFFF4500), // orange red
    Color(0xFFFFB6C1), // light pink
    Color(0xFFFF6347), // tomato
    Colors.white,
    Color(0xFFDA70D6), // orchid
    Color(0xFFFF8C00), // dark orange
  ];
}
