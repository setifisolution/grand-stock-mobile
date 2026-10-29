import 'package:flutter/material.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final bool enabled;

  const CountBadge({required this.count, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE53935) : Colors.grey.shade500,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}