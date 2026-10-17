import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dart:math';

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const ProgressRing({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            return CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(progress: value),
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(value * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.textPrimary,
                              fontSize: size * 0.22,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Recovered',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: size * 0.08,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = AppTheme.surfaceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
        stops: [0.0, 1.0],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}
