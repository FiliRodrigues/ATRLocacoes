import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AiSpinner extends StatefulWidget {
  final double size;
  const AiSpinner({super.key, this.size = 16});

  @override
  State<AiSpinner> createState() => _AiSpinnerState();
}

class _AiSpinnerState extends State<AiSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.size * 0.625;
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [AppColors.atrOrange, Colors.transparent],
            stops: [0.7, 1.0],
          ),
        ),
        child: Center(
          child: Container(
            width: inner,
            height: inner,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevatedDark,
            ),
          ),
        ),
      ),
    );
  }
}
