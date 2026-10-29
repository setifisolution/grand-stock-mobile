import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/transfer_service.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'path/to/transfer_service.dart'; // <-- adjust to your project

class PickedProduct {
  final Map<String, dynamic> row; // raw row from the endpoint
  final int quantity;
  PickedProduct(this.row, this.quantity);
}

class ProductPickerDialog extends StatefulWidget {
  final String zone;
  final String warehouse;
  final TransferService service;

  const ProductPickerDialog({
    super.key,
    required this.zone,
    required this.warehouse,
    required this.service,
  });

  static Future<PickedProduct?> show(
      BuildContext context, {
        required String zone,
        required String warehouse,
        required TransferService service,
      }) {
    return showDialog<PickedProduct>(
      context: context,
      builder: (_) => ProductPickerDialog(
        zone: zone,
        warehouse: warehouse,
        service: service,
      ),
    );
  }

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  static const _purple = Color(0xFF6C63FF);
  static const _green = Color(0xFF10B981);
  static const _fieldBg = Color(0xFFF3F6FA);

  final _productCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _productFocus = FocusNode();
  final _lotFocus = FocusNode();

  Timer? _debounce;
  bool _loadingProducts = false;
  bool _loadingLots = false;
  String? _error;

  List<String> _productNames = [];
  List<Map<String, dynamic>> _lots = [];
  String? _selectedName;
  Map<String, dynamic>? _selectedLot;

  @override
  void initState() {
    super.initState();
    _productFocus.addListener(() => setState(() {}));
    _lotFocus.addListener(() => setState(() {}));
    _searchProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _productCtrl.dispose();
    _lotCtrl.dispose();
    _qtyCtrl.dispose();
    _productFocus.dispose();
    _lotFocus.dispose();
    super.dispose();
  }

  String _msg(Object e) {
    String m;
    try {
      m = (e as dynamic).message.toString();
    } catch (_) {
      m = e.toString();
    }
    if (m.trimLeft().startsWith('<')) return 'Serveur introuvable (404)';
    return m;
  }

  String _fmtQty(dynamic v) {
    final d = double.tryParse(v?.toString() ?? '');
    return d == null ? '-' : d.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------- data

  Future<void> _searchProducts() async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });
    try {
      final data = await widget.service.searchInventoryItems(
        page: 1,
        zone: widget.zone,
        warehouse: widget.warehouse,
        search: _productCtrl.text.trim(),
      );
      final names = (data['products'] as List)
          .map((p) => (p['nom'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      if (!mounted) return;
      setState(() => _productNames = names);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _onProductChanged(String _) {
    // typing again invalidates the previous selection
    if (_selectedName != null || _selectedLot != null) {
      setState(() {
        _selectedName = null;
        _selectedLot = null;
        _lots = [];
        _lotCtrl.clear();
      });
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _searchProducts);
  }

  Future<void> _selectProduct(String name) async {
    _productCtrl.text = name;
    _productFocus.unfocus();
    setState(() {
      _selectedName = name;
      _selectedLot = null;
      _lots = [];
      _lotCtrl.clear();
      _loadingLots = true;
      _error = null;
    });
    try {
      final lots = <Map<String, dynamic>>[];
      int page = 1, totalPages = 1;
      do {
        final data = await widget.service.searchInventoryItems(
          page: page,
          zone: widget.zone,
          warehouse: widget.warehouse,
          search: name,
        );
        totalPages = (data['pagination']['totalPages'] as num).toInt();
        for (final p in data['products'] as List) {
          if (p['nom'] == name) lots.add(Map<String, dynamic>.from(p));
        }
        page++;
      } while (page <= totalPages);
      if (!mounted) return;
      setState(() => _lots = lots);
      _lotFocus.requestFocus(); // open the lot list like in the design
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loadingLots = false);
    }
  }

  void _selectLot(Map<String, dynamic> lot) {
    _lotCtrl.text = (lot['lot'] ?? '').toString();
    _lotFocus.unfocus();
    setState(() {
      _selectedLot = lot;
      _error = null;
    });
  }

  void _confirm() {
    if (_selectedName == null) {
      setState(() => _error = 'Veuillez choisir un produit');
      return;
    }
    if (_selectedLot == null) {
      setState(() => _error = 'Veuillez choisir un lot');
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty < 0) {
      setState(() => _error = 'Quantité invalide');
      return;
    }
    Navigator.pop(context, PickedProduct(_selectedLot!, qty));
  }

  // ------------------------------------------------------------------ UI

  InputDecoration _dec({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      disabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(_green, 1.5),
    );
  }

  Widget _label(String text, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            if (hint != null)
              TextSpan(
                text: ' $hint',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color fg, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownBox(Widget child) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _productList() {
    if (_loadingProducts) {
      return _dropdownBox(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ));
    }
    if (_productNames.isEmpty) {
      return _dropdownBox(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Aucun produit')),
      ));
    }
    return _dropdownBox(
      ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _productNames.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => ListTile(
          dense: true,
          leading: const Icon(Icons.inventory_2_outlined, size: 18),
          title: Text(_productNames[i]),
          onTap: () => _selectProduct(_productNames[i]),
        ),
      ),
    );
  }

  Widget _lotList() {
    if (_loadingLots) {
      return _dropdownBox(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ));
    }
    final q = _lotCtrl.text.trim().toLowerCase();
    final filtered = _lots.where((l) {
      if (q.isEmpty || _selectedLot != null) return true;
      return (l['lot'] ?? '').toString().toLowerCase().contains(q) ||
          (l['codeLot'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return _dropdownBox(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Aucun lot')),
      ));
    }
    return _dropdownBox(
      ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final l = filtered[i];
          return InkWell(
            onTap: () => _selectLot(l),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.qr_code_2, size: 18, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              (l['lot'] ?? '-').toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _chip(
                              _fmtQty(l['LogicalQuantity']),
                              const Color(0xFF047857),
                              const Color(0xFFD1FAE5),
                            ),
                            _chip(
                              (l['ExpirationDate'] ?? '-').toString(),
                              const Color(0xFFB91C1C),
                              const Color(0xFFFEE2E2),
                              icon: Icons.calendar_month,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l['codeLot'] ?? '-'}  •  ${l['location'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajouter un produit',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Avez-vous reçu un autre produit, non facturé ?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.blueGrey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _confirm,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showProductList = _productFocus.hasFocus && _selectedName == null;
    final showLotList = _lotFocus.hasFocus && _selectedName != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Produit'),
                    TextField(
                      controller: _productCtrl,
                      focusNode: _productFocus,
                      onChanged: _onProductChanged,
                      decoration: _dec(
                        hint: 'Rechercher un produit...',
                        icon: Icons.inventory_2_outlined,
                        suffix: const Icon(Icons.search, size: 20),
                      ),
                    ),
                    if (showProductList) _productList(),
                    const SizedBox(height: 16),
                    _label(
                      'Lot',
                      hint: _selectedName != null && !_loadingLots
                          ? '(${_lots.length} lot)'
                          : null,
                    ),
                    TextField(
                      controller: _lotCtrl,
                      focusNode: _lotFocus,
                      enabled: _selectedName != null,
                      onChanged: (_) => setState(() => _selectedLot = null),
                      onTap: () => _lotCtrl.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _lotCtrl.text.length,
                      ),
                      decoration: _dec(
                        hint: 'Rechercher un lot...',
                        icon: Icons.qr_code_2,
                        suffix: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                    if (showLotList) _lotList(),
                    const SizedBox(height: 16),
                    _label('Quantité'),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => _confirm(),
                      decoration: _dec(
                        hint: 'Quantité',
                        icon: Icons.tag,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }
}