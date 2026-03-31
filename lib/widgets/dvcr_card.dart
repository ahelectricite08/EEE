import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DVCRCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const DVCRCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: child,
    );
  }
}