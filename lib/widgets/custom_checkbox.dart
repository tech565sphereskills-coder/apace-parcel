import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomCircleCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  const CustomCircleCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? AppColors.primaryOrange : Colors.transparent,
          border: Border.all(
            color: value ? AppColors.primaryOrange : const Color(0xFFD1D5DB),
            width: 1.8,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Icon(
              Icons.check_rounded,
              size: size * 0.72,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
