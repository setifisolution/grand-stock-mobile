import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product_model.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';


class ProductTransferCard extends StatefulWidget {
  final ProductModel product;
  final int index;
  final String transferId;

  const ProductTransferCard({
    super.key,
    required this.product,
    required this.index,
    required this.transferId,
  });

  @override
  State<ProductTransferCard> createState() => _ProductTransferCardState();
}

class _ProductTransferCardState extends State<ProductTransferCard> {
  late TextEditingController _boxesController;
  late TextEditingController _unitsController;
  bool _isProcessing = false;
  String _status = '';

  /// Units per box (0 / null => boxes not usable)
  int get _conditioning => (widget.product.conditioning ?? 0).toInt();
  bool get _hasBoxes => _conditioning > 0;

  @override
  void initState() {
    super.initState();
    _boxesController = TextEditingController();
    _unitsController = TextEditingController();
    final originalQty = widget.product.receivedQuantity ?? 0;
    final editedQty = widget.product.editedQuantity ?? originalQty;
    _setFromTotal(editedQty);
  }

  @override
  void dispose() {
    _boxesController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  /// Splits a total (in units) into boxes + units and fills the fields.
  void _setFromTotal(int qty) {
    if (_hasBoxes) {
      _boxesController.text = (qty ~/ _conditioning).toString();
      _unitsController.text = (qty % _conditioning).toString();
    } else {
      _boxesController.text = '0';
      _unitsController.text = qty.toString();
    }
  }

  int get _boxes => int.tryParse(_boxesController.text) ?? 0;
  int get _units => int.tryParse(_unitsController.text) ?? 0;

  /// total = boxes * conditioning + units
  int _computeTotal() => _hasBoxes ? _boxes * _conditioning + _units : _units;

  @override
  void didUpdateWidget(ProductTransferCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update fields if product data changes from outside
    if (oldWidget.product.editedQuantity != widget.product.editedQuantity) {
      final qty =
          widget.product.editedQuantity ?? widget.product.receivedQuantity ?? 0;
      if (_computeTotal() != qty) {
        _setFromTotal(qty);
      }
    }
  }

  Future<void> _acceptSingleProduct() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = '';
    });

    try {
      final acceptedQty = _computeTotal();
      final transferProvider = Provider.of<TransferValidationProvider>(
        context,
        listen: false,
      );
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      final success = await transferProvider.acceptSingleProduct(
        transferId: widget.transferId,
        product: widget.product,
        acceptedQuantity: acceptedQty,
        boxes: _hasBoxes ? _boxes : null,
        units: _units,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _status = success ? 'success' : 'error';
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.product.name} accepté'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Échec: ${widget.product.name}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Called whenever boxes or units change: recompute the total and push it.
  void _onFieldChanged(String _) {
    final transferProvider = Provider.of<TransferValidationProvider>(
      context,
      listen: false,
    );
    final total = _computeTotal();
    if (total >= 0) {
      transferProvider.updateQuantity(widget.index, total);
    }
    setState(() {}); // refresh the "Total" label
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.product.isCompleted;
    final originalQty = widget.product.receivedQuantity ?? 0;
    final currentTotal = _computeTotal();
    final qtyChanged = currentTotal != originalQty;
    final fieldsEnabled = !_isProcessing && _status != 'success';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _status == 'success'
              ? Colors.green.shade300
              : _status == 'error'
              ? Colors.red.shade300
              : isCompleted
              ? Colors.green.shade300
              : Colors.grey.shade200,
          width: _status != '' || isCompleted ? 2 : 1,
        ),
      ),
      color: _status == 'success'
          ? Colors.green.shade50
          : _status == 'error'
          ? Colors.red.shade50
          : isCompleted
          ? Colors.green.shade50
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name + Individual Accept Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.3,
                          color: _status == 'success'
                              ? Colors.grey
                              : Colors.black87,
                          decoration: _status == 'success'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildChip('Lot: ${widget.product.lot}', Colors.blue),
                          const SizedBox(width: 6),
                          _buildChip(
                            'Code: ${widget.product.codeLot}',
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Show the accept button only while the product's server
                // status is not yet 'complete'.
                !isCompleted
                    ? SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: _isProcessing || _status == 'success'
                        ? null
                        : _acceptSingleProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _status == 'success'
                          ? Colors.green
                          : _status == 'error'
                          ? Colors.red
                          : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _status == 'success'
                              ? Icons.check_circle
                              : Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _status == 'success'
                              ? 'Accepté'
                              : _status == 'error'
                              ? 'Réessayer'
                              : 'Accepter',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ],
            ),

            const Divider(height: 24, thickness: 1),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetail(
                  'Laboratoire',
                  widget.product.laboratory,
                  Icons.business,
                ),
                _buildDetail(
                  'Expiration',
                  _formatDate(widget.product.expirationDate),
                  Icons.calendar_today,
                ),
                if (widget.product.location != null)
                  _buildDetail(
                    'Emplacement',
                    widget.product.location!,
                    Icons.location_on,
                  ),
                if (widget.product.destination != null)
                  _buildDetail(
                    'Destination',
                    widget.product.destination!,
                    Icons.fax_rounded,
                  ),
                _buildDetail(
                  'PPA',
                  '${widget.product.ppa.toStringAsFixed(2)} DA',
                  Icons.attach_money,
                ),
                _buildDetail(
                  'Conditionnement',
                  '$_conditioning unités/boîte',
                  Icons.padding_outlined,
                ),
              ],
            ),

            const SizedBox(height: 16),

            isCompleted
                ? const Center(child: Text('Valide'))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantité à valider',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_hasBoxes) ...[
                      Expanded(
                        child: _buildNumberField(
                          label: 'Boîtes',
                          controller: _boxesController,
                          enabled: fieldsEnabled,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _buildNumberField(
                        label: 'Unités',
                        controller: _unitsController,
                        enabled: fieldsEnabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hasBoxes
                      ? 'Total : $currentTotal unités ($_boxes × $_conditioning + $_units)'
                      : 'Total : $currentTotal unités',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (qtyChanged && _status != 'success')
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Original: $originalQty',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Status Badge
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      _status == 'success'
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      size: 14,
                      color: _status == 'success'
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _status == 'success'
                          ? 'Produit accepté ✓'
                          : 'Échec de l\'acceptation',
                      style: TextStyle(
                        fontSize: 11,
                        color: _status == 'success'
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          enabled: enabled,
          onTap: () {
            if (controller.text == '0') controller.clear();
          },
          decoration: InputDecoration(
            hintText: '0',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDetail(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    if (dateStr.length < 10) return dateStr;
    final parts = dateStr.split(' ')[0].split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateStr;
  }
}