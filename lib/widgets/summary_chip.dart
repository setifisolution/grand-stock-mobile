import 'package:flutter/material.dart';

class SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final Color unselectedBg;
  final void Function()? onTap;
  const SummaryChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isSelected = false,
    this.unselectedBg = const Color(0xFFF5F5F5), // Default light grey
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? color.withOpacity(0.12) : unselectedBg;
    final borderColor = isSelected ? color : Colors.grey.shade300;
    final iconColor = isSelected ? color : Colors.grey.shade600;
    final valueTextColor = isSelected ? color : Colors.black87;
    final labelTextColor = isSelected
        ? color.withOpacity(0.9)
        : Colors.grey.shade600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueTextColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: labelTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
