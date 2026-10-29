import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'detail_row.dart';
import 'status_badge.dart';



class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback? onAcceptToggle;
  final ValueChanged<int>? onQuantityChange;
  final bool readOnly;
  final FocusNode? focusNode;
  final VoidCallback? onValidated;
  final bool isValidating;

  const ProductCard({
    super.key,
    required this.product,
    this.onAcceptToggle,
    this.onQuantityChange,
    this.readOnly = false,
    this.focusNode,
    this.onValidated,
    this.isValidating = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late TextEditingController _boxesController;
  late TextEditingController _unitsController;
  final FocusNode _unitsFocus = FocusNode();

  /// Total quantity in units = boxes * conditioning + units
  late int _currentQuantity;

  int get _conditioning => (widget.product.conditioning ?? 0).toInt();

  @override
  void initState() {
    super.initState();
    _boxesController = TextEditingController();
    _unitsController = TextEditingController();
    _initQuantityController();
  }

  void _initQuantityController() {
    final product = widget.product;
    final isPendingVerification =
        product.status?.toLowerCase() == 'en attente de verification';
    final isValidated = product.status?.toLowerCase() == 'validated';

    int initialQty;
    if (isValidated) {
      initialQty = product.editedQuantity ?? product.quantityInv ?? 0;
    } else if (isPendingVerification) {
      initialQty = product.receivedQuantity ??
          product.editedQuantity ??
          product.quantityInv ??
          1;
    } else {
      initialQty = product.editedQuantity ?? product.quantityInv ?? 0;
    }

    _setFromTotal(initialQty);
  }

  /// Splits a total quantity into boxes + units and updates the fields.
  void _setFromTotal(int qty) {
    final cond = _conditioning;
    if (cond > 0) {
      _boxesController.text = (qty ~/ cond).toString();
      _unitsController.text = (qty % cond).toString();
    } else {
      _boxesController.text = '0';
      _unitsController.text = qty.toString();
    }
    _currentQuantity = qty;
  }

  int _computeTotal() {
    final boxes = int.tryParse(_boxesController.text) ?? 0;
    final units = int.tryParse(_unitsController.text) ?? 0;
    final cond = _conditioning;
    return cond > 0 ? boxes * cond + units : units;
  }

  @override
  void dispose() {
    _boxesController.dispose();
    _unitsController.dispose();
    _unitsFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    final product = widget.product;
    super.didUpdateWidget(oldWidget);
    // Check composite identity to prevent controller resets on wrong duplicates
    if (oldWidget.product.oid != product.oid ||
        oldWidget.product.lot != product.lot ||
        oldWidget.product.location != product.location) {
      _initQuantityController();
    }
    if (oldWidget.product.editedQuantity != product.editedQuantity) {
      final newQty = product.editedQuantity ?? product.quantityInv ?? 0;
      if (_currentQuantity != newQty) {
        _setFromTotal(newQty);
      }
    }
  }

  void _onFieldChanged(String _) {
    final total = _computeTotal();
    setState(() => _currentQuantity = total);
    widget.onQuantityChange?.call(total);
  }

  void _handleValidateTap() {
    final total = _computeTotal();
    if (total != _currentQuantity) {
      _currentQuantity = total;
    }
    widget.onQuantityChange?.call(total);
    widget.onAcceptToggle?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onValidated?.call();
    });
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
    required bool isInteractive,
    required bool effectiveValidating,
    FocusNode? focusNode,
    TextInputAction action = TextInputAction.next,
    VoidCallback? onEditingComplete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          focusNode: focusNode,
          controller: controller,
          readOnly: !isInteractive,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: action,
          onTap: isInteractive
              ? () {
            if (controller.text == '0') controller.clear();
          }
              : null,
          onEditingComplete: isInteractive ? onEditingComplete : null,
          decoration: InputDecoration(
            hintText: '0',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: effectiveValidating
                    ? Colors.blue
                    : Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isInteractive ? Colors.white : Colors.grey[200],
            contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            isDense: true,
          ),
          onChanged: isInteractive ? _onFieldChanged : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final productStatus = product.status ?? '';
    final isAccepted = product.isAccepted;
    final isNoSaisse = productStatus.toLowerCase() == 'no saisse';
    final isValidated = productStatus.toLowerCase() == 'validated';
    final isExpired = product.isExpired;

    final effectiveValidating = widget.readOnly ? false : widget.isValidating;

    final borderColor = isValidated
        ? Colors.green
        : isExpired
        ? Colors.red
        : isNoSaisse
        ? Colors.red
        : Colors.grey[400]!;

    final bgColor = effectiveValidating
        ? Colors.grey[100]
        : isValidated
        ? Colors.green[50]
        : isExpired
        ? Colors.red[50]
        : isNoSaisse
        ? Colors.red[50]
        : Colors.grey[50];

    final isInteractive =
        !widget.readOnly && !isValidated && !effectiveValidating;

    final hasBoxes = _conditioning > 0;

    return Card(
      elevation: isAccepted || isExpired ? 6 : 3,
      color: bgColor,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: effectiveValidating ? Colors.blue : borderColor,
          width: isAccepted || isExpired ? 2.5 : 1.5,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.3,
                              decoration: isValidated
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(status: product.status, isExpired: isExpired),
                  ],
                ),
                const Divider(height: 24, thickness: 1),
                Row(
                  children: [
                    DetailRow(
                      icon: Icons.attach_money_outlined,
                      label: 'PPA',
                      value: '${product.formattedPpa} DA',
                      valueColor: Colors.green[700],
                    ),
                    DetailRow(
                      label: 'Lot:',
                      icon: Icons.info,
                      value: '${product.lot}',
                    ),
                    DetailRow(
                      label: 'Address:',
                      icon: Icons.location_pin,
                      value: '${product.location}',
                    ),
                    DetailRow(
                      icon: Icons.inventory_outlined,
                      label: 'Stock',
                      value: isValidated ? product.quantityInv.toString() : "0",
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    DetailRow(
                      icon: Icons.warehouse_outlined,
                      label: 'Entrepôt',
                      value: product.warehouse ?? 'N/A',
                    ),
                    DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Expiration',
                      value: product.expirationDate != null
                          ? product.formattedExpirationDate
                          : 'N/A',
                      valueColor: isExpired ? Colors.red : Colors.green[700],
                    ),
                    DetailRow(
                      icon: Icons.padding_outlined,
                      label: 'Conditionnement',
                      value: '${product.conditioning ?? 0} unités/boîte',
                    ),
                  ],
                ),
                if (!widget.readOnly && !isValidated) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Boxes field (only when conditioning is known)
                      if (hasBoxes) ...[
                        Expanded(
                          flex: 2,
                          child: _buildNumberField(
                            label: 'Cartone',
                            controller: _boxesController,
                            isInteractive: isInteractive,
                            effectiveValidating: effectiveValidating,
                            focusNode: widget.focusNode,
                            action: TextInputAction.next,
                            onEditingComplete: () =>
                                _unitsFocus.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Units field
                      Expanded(
                        flex: 2,
                        child: _buildNumberField(
                          label: 'Unités',
                          controller: _unitsController,
                          isInteractive: isInteractive,
                          effectiveValidating: effectiveValidating,
                          focusNode:
                          hasBoxes ? _unitsFocus : widget.focusNode,
                          action: TextInputAction.next,
                          onEditingComplete: () => widget.onValidated?.call(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed:
                            isInteractive ? _handleValidateTap : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: effectiveValidating
                                  ? Colors.blue
                                  : isAccepted
                                  ? Colors.green
                                  : Colors.grey[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: isAccepted ? 4 : 2,
                            ),
                            child: effectiveValidating
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                                : Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isAccepted
                                      ? Icons.check_circle
                                      : productStatus.toLowerCase() ==
                                      'en attente de verification'
                                      ? Icons.mode_edit
                                      : Icons.add,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAccepted
                                      ? 'Validé'
                                      : productStatus.toLowerCase() ==
                                      'en attente de verification'
                                      ? 'Modify'
                                      : 'Valider',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasBoxes
                        ? 'Total : $_currentQuantity unités '
                        '(${_boxesController.text.isEmpty ? 0 : _boxesController.text} × $_conditioning + '
                        '${_unitsController.text.isEmpty ? 0 : _unitsController.text})'
                        : 'Total : $_currentQuantity unités',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (effectiveValidating)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}
