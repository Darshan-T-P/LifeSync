import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value; // 0-100
  final Color? color;

  const ProgressBar({super.key, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: clamped / 100,
        backgroundColor: Colors.grey[100],
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppTheme.highlight),
        minHeight: 6,
      ),
    );
  }
}
