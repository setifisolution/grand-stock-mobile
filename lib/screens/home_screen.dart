import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../helper/app_dialogs.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/menu_card.dart';
import 'arrangement_screen.dart';
import 'inventory_screen.dart';
import 'products_screen.dart';
import 'transfers_screen.dart';
import 'transfert_intern_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _hasLoadedStatus = false;

  // ➕ Number of items waiting to be arranged (Rangement)
  int _arrangementCount = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _loadArrangementCount();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// TODO: replace with your real source (provider / API call).
  /// Example: final n = await ArrangementService.getPendingCount();
  Future<void> _loadArrangementCount() async {
    const int n = 0; // ← plug your real value here
    if (!mounted) return;
    setState(() => _arrangementCount = n);
  }

  List<MenuItem> _buildMenuItems(TransferValidationProvider provider) {
    return [
      MenuItem(
        title: 'Transfers',
        subtitle: 'Gérer les transferts',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF4A90E2),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF50C9C3)],
        ),
        onTap: (ctx) async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const TransferScreen()),
          );
        },
      ),
      // ➕ NEW MODULE: Rangement (arrangement)
      MenuItem(
        title: 'Rangement',
        subtitle: 'Ranger les produits',
        icon: Icons.move_to_inbox_rounded,
        color: const Color(0xFF00B894),
        gradient: const LinearGradient(
          colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
        ),
        badgeCount: _arrangementCount,
        onTap: (ctx) async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const ArrangementScreen()),
          );
          // Refresh the counter when coming back
          _loadArrangementCount();
        },
      ),
      MenuItem(
        title: 'Inventory',
        subtitle: 'Voir le stock',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFFF9A3D),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9A3D), Color(0xFFFF6B6B)],
        ),
        badge: provider.isStatusLoading
            ? '...'
            : (provider.isInventoryOpen ? 'Ouvert' : 'Fermé'),
        isEnabled: true,
        // Accessible only when inventory is OPEN
        validator: () => provider.isInventoryOpen,
        onTap: (ctx) async {
          if (!provider.isInventoryOpen) {
            HapticFeedback.selectionClick();
            _showStatusSnackbar(ctx, provider, 'inventory');
            return;
          }
          HapticFeedback.mediumImpact();
          await Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => const InventoryScreen(readOnly: false),
            ),
          );
        },
      ),
      MenuItem(
        title: 'Products',
        subtitle: 'Consulter les produits',
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF6C5CE7),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
        badge: provider.isStatusLoading
            ? '...'
            : (provider.isInventoryOpen ? 'Désactivé' : 'Consultation'),
        isEnabled: true,
        validator: () => !provider.isInventoryOpen,
        onTap: (ctx) async {
          if (provider.isInventoryOpen) {
            HapticFeedback.selectionClick();
            _showStatusSnackbar(ctx, provider, 'products');
            return;
          }
          HapticFeedback.lightImpact();
          await Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => const ProductsScreen(readOnly: true),
            ),
          );
        },
      ),
    ];
  }

  void _showStatusSnackbar(
      BuildContext context,
      TransferValidationProvider provider,
      String source,
      ) {
    final message = provider.isStatusLoading
        ? '🔄 Chargement du statut...'
        : (source == 'inventory'
        ? '🔒 Inventaire ${provider.inventoryStatusText} - Accès refusé'
        : '⚠️ Consultation désactivée pendant l\'inventaire ouvert');

    final icon = provider.isStatusLoading
        ? Icons.refresh_rounded
        : (source == 'inventory'
        ? Icons.lock_rounded
        : Icons.info_outline_rounded);

    final bgColor = provider.isStatusLoading
        ? Colors.blue
        : (source == 'inventory'
        ? Colors.red.shade600
        : Colors.orange.shade600);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransferValidationProvider, UserProvider>(
      builder: (context, provider, userProvider, _) {
        final user = userProvider.user;
        final isOpen = provider.isInventoryOpen;

        if (user == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          );
        }

        final warehouse = user.wareHouse;
        final menuItems = _buildMenuItems(provider);

        // Auto-load status once on first build
        if (warehouse.isNotEmpty &&
            !_hasLoadedStatus &&
            !provider.isStatusLoading) {
          _hasLoadedStatus = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadInventoryStatus(warehouse: warehouse);
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          appBar: CustomAppBar(),
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                provider.refreshInventoryStatus(warehouse: warehouse),
                _loadArrangementCount(),
              ]);
            },
            color: Theme.of(context).primaryColor,
            displacement: 20,
            child: FadeTransition(
              opacity: _fadeController,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.15),
                            Theme.of(context).primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar with status ring
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  // transparent so the gradient ring shows
                                  // behind the white initials
                                  backgroundColor: Colors.transparent,
                                  child: Text(
                                    '${user.firstName[0]}${user.lastName[0]}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              // Status indicator
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? Colors.green
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // User info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user.firstName} ${user.lastName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warehouse_rounded,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${user.wareHouse} • Zone: ${user.zone}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Logout + Refresh buttons
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.logout_rounded,
                                  color: Colors.grey[700],
                                  size: 20,
                                ),
                                tooltip: 'Déconnexion',
                                onPressed: () {
                                  AppDialogs.showLogoutDialog(context);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: provider.isStatusLoading
                                      ? null
                                      : () {
                                    HapticFeedback.selectionClick();
                                    provider.refreshInventoryStatus(
                                      warehouse: warehouse,
                                    );
                                    _loadArrangementCount();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: Icon(
                                        provider.isStatusLoading
                                            ? Icons.refresh_rounded
                                            : (isOpen
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded),
                                        key: ValueKey(provider.isStatusLoading),
                                        color: provider.isStatusLoading
                                            ? Colors.grey
                                            : (isOpen
                                            ? Colors.green
                                            : Colors.red),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    sliver: SliverGrid(
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (ctx, index) => MenuCard(item: menuItems[index]),
                        childCount: menuItems.length,
                      ),
                    ),
                  ),
                  if (provider.inventoryStatus != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOpen
                                ? [Colors.green.shade50, Colors.green.shade100]
                                : [Colors.red.shade50, Colors.red.shade100],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOpen
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                isOpen
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                key: ValueKey(isOpen),
                                color: isOpen
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Statut: ${provider.inventoryStatusText}',
                              style: TextStyle(
                                color: isOpen
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOpen
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Type: ${provider.inventoryTypeText}',
                                style: TextStyle(
                                  color: isOpen
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
