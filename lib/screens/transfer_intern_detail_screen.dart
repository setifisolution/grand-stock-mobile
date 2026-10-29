import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constant/app_colors.dart';
import '../constant/app_enums.dart';
import '../constant/app_icons.dart';
import '../constant/app_strings.dart';
import '../models/transfer_intern_model.dart';
import '../providers/transfer_intern_provider.dart';
import '../widgets/custom_app_bar.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtLong(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} à ${_two(d.hour)}:${_two(d.minute)}';

class TransferInternDetailScreen extends StatelessWidget {
  final int transferId;

  const TransferInternDetailScreen({super.key, required this.transferId});

  Future<void> _confirmTransfer(
    BuildContext context,
    TransferInternModel t,
    TransferAction action,
  ) async {
    final isSend = action == TransferAction.send;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(t: t, isSend: isSend),
    );
    if (ok != true || !context.mounted) return;

    HapticFeedback.mediumImpact();
    final provider = context.read<TransferInternProvider>();
    final error = isSend
        ? await provider.confirmSend(t)
        : await provider.confirmReceive(t);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error == null
              ? AppColors.accent
              : const Color(0xFFE53E3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            error ??
                (isSend
                    ? "Envoi confirmé. Le destinataire peut maintenant réceptionner."
                    : "Réception confirmée. Le stock a été mis à jour."),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TransferInternProvider>();
    final t = p.byId(transferId);

    // Helper pour comparer les IDs en toute sécurité (String vs int)
    final int? currentUserId = int.tryParse(
      p.currentUser?.id?.toString() ?? '0',
    );

    return Scaffold(
      appBar: CustomAppBar(),
      body: t == null
          ? const Center(
              child: _StateMessage(
                icon: Icons.search_off_rounded,
                color: Colors.grey,
                title: 'Transfert introuvable',
                message:
                    "Ce transfert n'existe plus ou ne vous est pas assigné.",
              ),
            )
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => p.load(
                silent: true,
              ), // Recharge avec les filtres de l'utilisateur
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.25),
                                    AppColors.accent.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AppColors.accent,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.productLabel,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (t.productLot != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Lot : ${t.productLot}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatusChip(t.status, large: true),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Quantité',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${t.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Trajet',
                    icon: Icons.alt_route_rounded,
                    child: Column(
                      children: [
                        _RoutePoint(
                          label: 'Source',
                          color: AppColors.blue,
                          icon: Icons.location_on_rounded,
                          warehouse: t.sourceWarehouse,
                          zone: t.sourceZone,
                          location: t.sourceLocation,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 19),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 2,
                              height: 22,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        _RoutePoint(
                          label: 'Destination',
                          color: AppColors.accent,
                          icon: Icons.flag_rounded,
                          warehouse: t.destWarehouse,
                          zone: t.destZone,
                          location: t.destLocation,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Suivi',
                    icon: Icons.timeline_rounded,
                    child: (t.status == 'ANNULE' || t.status == 'CANCELLED')
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: AppColors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Ce transfert a été annulé.',
                                  style: TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _VerticalTimeline(t: t),
                  ),
                  const SizedBox(height: 12),
                  _DetailCard(
                    title: 'Personnes',
                    icon: Icons.people_alt_rounded,
                    child: Column(
                      children: [
                        _PersonRow(
                          role: 'Expéditeur',
                          name: t.senderName,
                          color: AppColors.blue,
                          isMe: t.senderId == currentUserId,
                        ),
                        const SizedBox(height: 12),
                        _PersonRow(
                          role: 'Destinataire',
                          name: t.receiverName,
                          color: AppColors.accent,
                          isMe: t.receiverId == currentUserId,
                        ),
                      ],
                    ),
                  ),
                  if (t.notes != null && t.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _DetailCard(
                      title: 'Remarque',
                      icon: Icons.sticky_note_2_outlined,
                      child: Text(
                        t.notes!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: t == null ? null : _buildBottomBar(context, p, t),
    );
  }

  Widget? _buildBottomBar(
    BuildContext context,
    TransferInternProvider p,
    TransferInternModel t,
  ) {
    final action = p.actionFor(t);

    // Not my turn: show a calm hint instead of a button.
    if (action == TransferAction.none) {
      String? hint;
      // ✅ Correction : Utilisation des chaînes de caractères au lieu de l'enum
      if (t.status == 'BROUILLON' || t.status == 'PENDING') {
        hint = "En attente de l'envoi par ${t.senderName ?? "l'expéditeur"}.";
      } else if (t.status == 'ENVOYE' || t.status == 'SENT') {
        hint =
            'En attente de la réception par ${t.receiverName ?? 'le destinataire'}.';
      }
      if (hint == null) return null;

      return SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: AppColors.amber,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hint,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isSend = action == TransferAction.send;
    final busy = p.isBusy(t.id);
    final color = isSend ? AppColors.blue : AppColors.accent;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: busy ? null : () => _confirmTransfer(context, t, action),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isSend ? Icons.outbox_rounded : Icons.download_done_rounded,
                    size: 22,
                  ),
            label: Text(
              busy
                  ? 'Traitement...'
                  : isSend
                  ? "Confirmer l'envoi"
                  : 'Confirmer la réception',
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;

  const _DetailCard({this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A202C).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  title!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String warehouse;
  final String zone;
  final String location;

  const _RoutePoint({
    required this.label,
    required this.color,
    required this.icon,
    required this.warehouse,
    required this.zone,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
          children: [
            TextSpan(text: '$k '),
            TextSpan(
              text: v,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                warehouse,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [pill('Zone', zone), pill('Emplacement', location)],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String role;
  final String? name;
  final Color color;
  final bool isMe;

  const _PersonRow({
    required this.role,
    required this.name,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final display = name ?? 'Non assigné';
    final initial = display.isEmpty ? '?' : display[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text(
            initial,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 1),
              Text(
                display,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: name == null ? Colors.grey[500] : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (isMe)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Vous',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _VerticalTimeline extends StatelessWidget {
  final TransferInternModel t;
  const _VerticalTimeline({required this.t});

  @override
  Widget build(BuildContext context) {
    // ✅ Correction : Utilisation des chaînes de caractères pour déterminer l'étape
    final isRecu = t.status == 'RECU' || t.status == 'RECEIVED';
    final isEnvoye = t.status == 'ENVOYE' || t.status == 'SENT';
    final reached = isRecu ? 2 : (isEnvoye ? 1 : 0);

    final steps = <({String title, String subtitle})>[
      (
        title: 'Transfert créé',
        subtitle: t.createdAt != null ? _fmtLong(t.createdAt!) : '-',
      ),
      (
        title: 'Envoi confirmé',
        subtitle: reached >= 1
            ? [
                if (t.createdAt != null)
                  _fmtLong(
                    t.createdAt!,
                  ), // Fallback sur createdAt si sentAt est null
                if (t.senderName != null) t.senderName!,
              ].join(' · ')
            : "En attente de ${t.senderName ?? "l'expéditeur"}",
      ),
      (
        title: 'Réception confirmée',
        subtitle: reached >= 2
            ? [
                if (t.createdAt != null)
                  _fmtLong(
                    t.createdAt!,
                  ), // Fallback sur createdAt si receivedAt est null
                if (t.receiverName != null) t.receiverName!,
              ].join(' · ')
            : 'En attente de ${t.receiverName ?? 'le destinataire'}',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: i <= reached ? AppColors.accent : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i <= reached
                                ? AppColors.accent
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: i <= reached
                            ? const Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: i < reached
                                  ? AppColors.accent
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < steps.length - 1 ? 18 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: i <= reached
                                ? AppColors.ink
                                : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// CONFIRM SHEET
// ═════════════════════════════════════════════════════════════════

class _ConfirmSheet extends StatelessWidget {
  final TransferInternModel t;
  final bool isSend;

  const _ConfirmSheet({required this.t, required this.isSend});

  @override
  Widget build(BuildContext context) {
    final color = isSend ? AppColors.blue : AppColors.accent;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSend ? Icons.outbox_rounded : Icons.download_done_rounded,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSend ? "Confirmer l'envoi ?" : 'Confirmer la réception ?',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSend
                ? 'Vous confirmez avoir préparé et remis ce produit pour le transfert.'
                : 'Vous confirmez avoir reçu ce produit. Le stock sera mis à jour et cette action est définitive.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SummaryRow('Produit', t.productLabel),
                _SummaryRow('Quantité', '${t.quantity}'),
                _SummaryRow(
                  'De',
                  '${t.sourceWarehouse} · ${t.sourceZone} · ${t.sourceLocation}',
                ),
                _SummaryRow(
                  'Vers',
                  '${t.destWarehouse} · ${t.destZone} · ${t.destLocation}',
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirmer',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _SummaryRow(this.label, this.value, {this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// EMPTY / ERROR STATE
// ═════════════════════════════════════════════════════════════════

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
