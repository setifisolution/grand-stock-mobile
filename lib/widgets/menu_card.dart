import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'count_badge.dart';

class MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Gradient? gradient;
  final String? route;
  final void Function(BuildContext context)? onTap;
  final bool isEnabled;
  final bool Function()? validator;
  final String? badge; // Text badge (e.g., "Ouvert", "Fermé")
  final int badgeCount; // ➕ NEW: numeric counter badge (0 = hidden)

  MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.gradient,
    this.route,
    this.onTap,
    this.isEnabled = true,
    this.validator,
    this.badge,
    this.badgeCount = 0,
  });

  bool get isActionable => isEnabled && (validator?.call() ?? true);
}

class MenuCard extends StatelessWidget {
  final MenuItem item;
  final double elevation;
  final VoidCallback? onLongPress;

  const MenuCard({
    super.key,
    required this.item,
    this.elevation = 4,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isActionable = item.isActionable;
    final badge = item.badge ?? (!isActionable ? 'Fermé' : null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isActionable ? item.color : Colors.grey).withOpacity(0.2),
            blurRadius: isActionable ? 12 : 4,
            offset: Offset(0, isActionable ? 4 : 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isActionable ? () => _handleTap(context) : null,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              gradient: _getCardGradient(isActionable),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActionable
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glass-morphism icon container + count badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isActionable
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.grey.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActionable
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                item.icon,
                                key: ValueKey(isActionable),
                                size: 30,
                                color: isActionable
                                    ? Colors.white
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                          if (item.badgeCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: CountBadge(
                                count: item.badgeCount,
                                enabled: isActionable,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isActionable ? Colors.white : Colors.grey[300],
                          letterSpacing: 0.3,
                        ),
                        child: Center(
                          child: Text(
                            item.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),

                // Text badge (top-right corner)
                if (badge != null && badge.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _getBadgeColor(badge),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                // Disabled overlay
                if (!isActionable)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Gradient _getCardGradient(bool isActionable) {
    if (!isActionable) {
      return LinearGradient(
        colors: [Colors.grey[300]!, Colors.grey[200]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return item.gradient ??
        LinearGradient(
          colors: [item.color.withOpacity(0.95), item.color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
  }

  Color _getBadgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'ouvert':
      case 'open':
        return Colors.green;
      case 'fermé':
      case 'closed':
      case 'ferme':
        return Colors.red;
      case 'nouveau':
      case 'new':
        return Colors.blue;
      case 'en cours':
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _handleTap(BuildContext context) {
    if (!item.isActionable) {
      HapticFeedback.selectionClick();
      _showModernSnackbar(context);
      return;
    }

    HapticFeedback.lightImpact();

    if (item.onTap != null) {
      item.onTap!(context);
      return;
    }

    if (item.route != null && item.route!.isNotEmpty) {
      Navigator.pushNamed(context, item.route!);
      return;
    }

    if (kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Action non définie pour: ${item.title}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showModernSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔒 ${item.title} est actuellement fermé',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

