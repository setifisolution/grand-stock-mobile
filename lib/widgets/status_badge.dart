import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String? status;
  final bool isExpired;

  const StatusBadge({super.key, required this.status, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final isValide = status?.toLowerCase() == 'validated';
    final isNoSaisse = status?.toLowerCase() == 'no saisse';

    Color badgeColor, textColor, borderColor;
    IconData badgeIcon;

    if (isExpired) {
      badgeColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
      borderColor = Colors.red;
      badgeIcon = Icons.warning_amber_rounded;
    } else if (isValide) {
      badgeColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
      borderColor = Colors.green;
      badgeIcon = Icons.check_circle;
    } else if (isNoSaisse) {
      badgeColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
      borderColor = Colors.red;
      badgeIcon = Icons.pending;
    } else {
      badgeColor = Colors.grey[200]!;
      textColor = Colors.grey[700]!;
      borderColor = Colors.grey[400]!;
      badgeIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            isExpired ? 'Expiré' : (status ?? 'N/A'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
