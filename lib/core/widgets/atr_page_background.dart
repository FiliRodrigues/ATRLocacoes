import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AtrPageBackground extends StatelessWidget {
  final Widget child;
  final bool grid;

  const AtrPageBackground({
    super.key,
    required this.child,
    this.grid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundDark,
            AppColors.atrNavyDarker,
            AppColors.backgroundDark,
          ],
          stops: [0, 0.5, 1],
        ),
      ),
      child: grid
          ? CustomPaint(
              painter: _GridPainter(),
              child: child,
            )
          : child,
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 0.5;

    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
