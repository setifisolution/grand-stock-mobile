import 'package:flutter/material.dart';
import '../manager/assets_manager.dart';
import '../models/filter_option.dart';
import '../models/notification_model.dart';
import '../screens/notification_screen.dart';
import 'app_name_text.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  // ✅ Callbacks
  final VoidCallback? onDelete;
  final VoidCallback? onSave;
  final ValueChanged<String>? onFilter;
  final VoidCallback? onShare;
  final Function(String, bool)? onMarkAsRead;
  final Function()? onMarkAllAsRead;
  final Function(String)? onRemoveNotification;
  final VoidCallback? onViewModeToggle;

  // ✅ UI Properties
  final String? text;
  final bool showNotificationIcon;
  final int unreadCount;
  final List<NotificationModel>? notifications;
  final bool isGridView;
  final double? fontSize;
  final String? textInDialog;
  final double bottomSpacing;
  final List<FilterOption>? filterOptions;
  final String? filterTooltip;
  final PreferredSizeWidget? bottomWidget;
  const CustomAppBar({
    super.key,
    this.onDelete,
    this.text,
    this.showNotificationIcon = false,
    this.unreadCount = 0,
    this.notifications,
    this.onMarkAsRead,
    this.onMarkAllAsRead,
    this.onRemoveNotification,
    this.onViewModeToggle,
    this.isGridView = false,
    this.fontSize,
    this.textInDialog,
    this.bottomWidget,
    this.bottomSpacing = 0.0,
    this.onFilter,
    this.onSave,
    this.onShare,
    this.filterOptions,
    this.filterTooltip,
  });

  @override
  Size get preferredSize {
    double totalHeight = kToolbarHeight;
    if (bottomWidget != null) {
      totalHeight += bottomWidget!.preferredSize.height + bottomSpacing;
    }
    return Size.fromHeight(totalHeight);
  }

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget? bottom = bottomWidget;
    if (bottomWidget != null && bottomSpacing > 0) {
      bottom = PreferredSize(
        preferredSize: Size.fromHeight(
          bottomWidget!.preferredSize.height + bottomSpacing,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: bottomSpacing),
          child: bottomWidget!,
        ),
      );
    }
    final defaultFilterOptions = const [
      FilterOption(value: 'all', label: 'Tous les produits', icon: Icons.done_all, iconColor: Colors.grey),
      FilterOption(value: 'valide', label: '✅ Validé', icon: Icons.check_circle, iconColor: Colors.green),
      FilterOption(value: 'no saisse', label: '⏳ Non saisi', icon: Icons.pending, iconColor: Colors.orange),
      FilterOption(value: 'missing', label: '❌ Manquant', icon: Icons.error_outline, iconColor: Colors.red),
    ];
    final activeFilterOptions = filterOptions ?? defaultFilterOptions;
    return AppBar(
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(AssetsManager.logo, width: 50, height: 50),
          const SizedBox(width: 4),
          AppNameTextWidget(fontSize: fontSize, text: text),
        ],
      ),
      actions: [
        // 🔔 Notification Icon
        if (showNotificationIcon)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  if (notifications != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    );
                  }
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

        // 👁️ View Mode Toggle
        if (onViewModeToggle != null)
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: isGridView ? 'Switch to List View' : 'Switch to Grid View',
            onPressed: onViewModeToggle,
          ),

        // 💾 Save Button
        Visibility(
          visible: onSave != null,
          child: IconButton(onPressed: onSave, icon: const Icon(Icons.save_alt)),
        ),

        // 🔗 Share Button
        Visibility(
          visible: onShare != null,
          child: IconButton(onPressed: onShare, icon: const Icon(Icons.share)),
        ),

        // 🗑️ Delete Button
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog.adaptive(
                  title: Text('Clear $textInDialog'),
                  content: Text(
                    'Are you sure you want to remove all items from your $textInDialog?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Cancel'),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDelete?.call();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),

        // 🔘 FILTER BUTTON - ✅ DYNAMIC & UNIVERSAL
        if (onFilter != null && activeFilterOptions.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            tooltip: filterTooltip ?? 'Filtrer par statut',
            offset: const Offset(0, 50),
            onSelected: onFilter,
            itemBuilder: (context) => activeFilterOptions
                .map((option) => PopupMenuItem<String>(
              value: option.value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, color: option.iconColor, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(option.label),
                ],
              ),
            ))
                .toList(),
          ),
      ],
      bottom: bottom,
    );
  }
}