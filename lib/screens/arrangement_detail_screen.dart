import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/arrangement_provider.dart';
import '../widgets/custom_app_bar.dart';

class ArrangementDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ArrangementDetailScreen({super.key, required this.product});

  @override
  State<ArrangementDetailScreen> createState() => _ArrangementDetailScreenState();
}

class _ArrangementDetailScreenState extends State<ArrangementDetailScreen> {
  static const _accent = Color(0xFF00B894);

  final _locationController = TextEditingController();
  final _quantiteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill quantity with the available stock
    _quantiteController.text = widget.product.stockQty.toString();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _quantiteController.dispose();
    super.dispose();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _confirm() async {
    final location = _locationController.text.trim();
    final quantiteText = _quantiteController.text.trim();

    if (location.isEmpty) {
      HapticFeedback.selectionClick();
      _snack('⚠️ Veuillez saisir un emplacement', Colors.orange.shade600);
      return;
    }

    final quantite = int.tryParse(quantiteText);
    if (quantite == null || quantite <= 0) {
      HapticFeedback.selectionClick();
      _snack('⚠️ Veuillez saisir une quantité valide', Colors.orange.shade600);
      return;
    }

    final provider = context.read<ArrangementProvider>();
    final ok = await provider.submitArrangement(
      product: widget.product,
      location: location,
      quantite: quantite, // ✅ Passed to provider
    );

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      _snack('❌ ${provider.error ?? 'Échec du rangement, réessayez'}', Colors.red.shade600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final expired = p.isExpired;
    final isSubmitting = context.watch<ArrangementProvider>().isSubmitting;

    final rows = <Widget>[
      _InfoRow(icon: Icons.tag_rounded, label: 'Lot', value: p.lot),
      _InfoRow(icon: Icons.qr_code_rounded, label: 'Code', value: p.codeLot),
      _InfoRow(icon: Icons.event_rounded, label: 'Expiration', value: p.formattedExpirationDate, valueColor: expired ? Colors.red : null),
      _InfoRow(icon: Icons.numbers_rounded, label: 'Quantité', value: '${p.stockQty}'),
      if (p.ppa > 0) _InfoRow(icon: Icons.payments_outlined, label: 'PPA', value: '${p.formattedPpa} DA'),
      if (p.entryDate.isNotEmpty) _InfoRow(icon: Icons.login_rounded, label: "Date d'entrée", value: p.entryDate),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: CustomAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF55EFC4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  if (expired) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(20)),
                      child: const Text('PÉRIMÉ', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Column(children: [for (var i = 0; i < rows.length; i++) ...[rows[i], if (i != rows.length - 1) const Divider(height: 1)]]),
            ),
            const SizedBox(height: 20),

            // Emplacement Field
            const Text('Emplacement de destination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF2D3748))),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Ex: A-01-03',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ NEW: Quantity Field
            const Text('Quantité à ranger', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF2D3748))),
            const SizedBox(height: 8),
            TextField(
              controller: _quantiteController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Quantité',
                prefixIcon: const Icon(Icons.inventory_2_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(isSubmitting ? 'Validation...' : 'Confirmer le rangement', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00B894)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
          Flexible(child: Text(value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: valueColor ?? const Color(0xFF2D3748)))),
        ],
      ),
    );
  }
}