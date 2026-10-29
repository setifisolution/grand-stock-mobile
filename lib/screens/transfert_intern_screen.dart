import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constant/app_colors.dart';
import '../constant/app_enums.dart';
import '../constant/app_icons.dart';
import '../constant/app_strings.dart';
import '../models/transfer_intern_model.dart';
import '../providers/transfer_intern_provider.dart';
import '../widgets/custom_app_bar.dart';
import 'transfer_intern_detail_screen.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtShort(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';

class TransferScreen extends StatefulWidget {
  final String? warehouse;
  final String? zone;

  const TransferScreen({super.key, this.warehouse, this.zone});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _searchController = TextEditingController();

  Future<void> _reload() async {
    // load() utilise maintenant automatiquement currentWarehouse et currentZone du provider
    await context.read<TransferInternProvider>().load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final p = context.read<TransferInternProvider>();
      p.setSearch('');
      p.setFilter(TransferFilter.all);
      p.load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransferInternProvider>();
    final items = p.visible;
    final searching = p.search.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: CustomAppBar(),
      body: Column(
        children: [
          _buildHeader(p),
          Expanded(
            child: p.loading && !p.hasData
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
                : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _reload,
              child: items.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(32, 50, 32, 24),
                children: [
                  if (p.error != null)
                    _StateMessage(
                      icon: Icons.wifi_off_rounded,
                      color: AppColors.ink,
                      title: 'Chargement impossible',
                      message: p.error!,
                      actionLabel: 'Réessayer',
                      actionIcon: Icons.refresh_rounded,
                      onAction: _reload,
                    )
                  else if (searching)
                    _StateMessage(
                      icon: Icons.search_off_rounded,
                      color: Colors.grey.shade500,
                      title: 'Aucun résultat',
                      message: 'Aucun transfert ne correspond à votre recherche.',
                      actionLabel: 'Effacer la recherche',
                      actionIcon: Icons.close_rounded,
                      onAction: () {
                        _searchController.clear();
                        p.setSearch('');
                      },
                    )
                  else
                    _StateMessage(
                      icon: Icons.swap_horiz_rounded,
                      color: AppColors.accent,
                      title: 'Aucun transfert',
                      message: widget.warehouse != null
                          ? 'Aucun transfert trouvé pour ${widget.warehouse} (Zone ${widget.zone}).'
                          : 'Les transferts qui vous concernent apparaîtront ici.',
                    ),
                ],
              )
                  : ListView.separated(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                // ✅ CORRECTION ICI : Définition explicite de 't' et utilisation de 'p'
                itemBuilder: (_, i) {
                  final t = items[i];
                  return _TransferTile(
                    t: t,
                    action: p.actionFor(t),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: p, // Utiliser 'p' au lieu de 'provider'
                            child: TransferInternDetailScreen(
                              transferId: t.id, // Utiliser 't.id' au lieu de 't.id' hors portée
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TransferInternProvider p) {
    Widget chip(String label, TransferFilter f, int count) {
      final selected = p.filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => p.setFilter(f),
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: AppColors.accent,
          side: BorderSide(
            color: selected ? AppColors.accent : Colors.grey.shade200,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          if (widget.warehouse != null && widget.zone != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.warehouse} • Zone ${widget.zone}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A202C).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: p.setSearch,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14.5, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Produit, lot, personne, emplacement...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: Colors.grey[500],
                ),
                suffixIcon: p.search.isEmpty
                    ? null
                    : IconButton(
                  splashRadius: 18,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    _searchController.clear();
                    p.setSearch('');
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: border(Colors.transparent),
                enabledBorder: border(Colors.transparent),
                focusedBorder: border(AppColors.ink, 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('Tous', TransferFilter.all, 0),
                chip('À envoyer', TransferFilter.toSend, p.toSendCount),
                chip('À recevoir', TransferFilter.toReceive, p.toReceiveCount),
                chip('Terminés', TransferFilter.done, 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── List tile ─────────────────────────

class _TransferTile extends StatelessWidget {
  final TransferInternModel t;
  final TransferAction action;
  final VoidCallback onTap;

  const _TransferTile({
    required this.t,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(t.status);
    final needsAction = action != TransferAction.none;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A202C).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: needsAction
            ? Border.all(
          color: AppColors.ink.withValues(alpha: 0.55),
          width: 1.2,
        )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        AppIcons.statusIcon(t.status),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.productLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${t.sourceWarehouse}  →  ${t.destWarehouse}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '× ${t.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatusChip(t.status),
                    if (needsAction) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          action == TransferAction.send
                              ? 'À envoyer'
                              : 'À réceptionner',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (t.createdAt != null)
                      Text(
                        _fmtShort(t.createdAt!),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: color),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool large;
  const _StatusChip(this.status, {this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 9,
        vertical: large ? 7 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.statusIcon(status), size: large ? 16 : 13, color: c),
          const SizedBox(width: 5),
          Text(
            AppStrings.statusLabel(status),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: large ? 13 : 11.5,
            ),
          ),
        ],
      ),
    );
  }
}