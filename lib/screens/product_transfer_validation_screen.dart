import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../manager/assets_manager.dart';
import '../manager/loading_manager.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/empty_widget.dart';
import '../widgets/product_transfer_card.dart';

class ProductTransferValidationScreen extends StatefulWidget {
  final String transferId;
  final String zone;
  final String warehouse;

  const ProductTransferValidationScreen({
    super.key,
    required this.transferId,
    required this.zone,
    required this.warehouse,
  });

  @override
  State<ProductTransferValidationScreen> createState() =>
      _ProductTransferValidationScreenState();
}

class _ProductTransferValidationScreenState
    extends State<ProductTransferValidationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransferValidationProvider>().loadProducts(
        transferId: widget.transferId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transferProvider = context.watch<TransferValidationProvider>();
    final accepted = transferProvider.acceptedCount;
    final completed = transferProvider.completedCount;
    final products = transferProvider.products;
    final total = products.length;
    final successCount = transferProvider.successCount;
    final isLoading = transferProvider.isLoading;
    final allCompleted = products.isNotEmpty && products.every((p) => p.isCompleted);

    return Scaffold(
      appBar: CustomAppBar(),
      body: LoadingManager(
        isLoading: isLoading,
        child: (!isLoading && products.isEmpty)
            ? EmptyWidget(
                imagePath: AssetsManager.noData,
                title: 'Aucun produit trouvé',
                subtitle: 'Aucun produit dans ce transfert',
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.teal.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$completed'
                            ''
                            '/$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Produits à valider',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Transfert: ${widget.transferId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (successCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$successCount accepté(s) ✓',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => ProductTransferCard(
                        product: products[index],
                        index: index,
                        transferId: widget.transferId,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Accept All Button
                        OutlinedButton.icon(
                          onPressed: transferProvider.isSubmitting
                              ? null
                              : transferProvider.toggleAcceptAll,
                          icon: Icon(
                            allCompleted
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: Colors.teal,
                            size: 20,
                          ),
                          label: Text(
                            allCompleted
                                ? 'Tout désélectionner'
                                : 'Tout accepter',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                        const Spacer(),
                        // Submit Button
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed:
                                (accepted == 0 || transferProvider.isSubmitting)
                                ? null
                                : () => _showConfirmationDialog(
                                    context,
                                    transferProvider,
                                  ),
                            icon: transferProvider.isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                  ),
                            label: Text(
                              transferProvider.isSubmitting
                                  ? 'En cours...'
                                  : 'Valider ($accepted)',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
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

  void _showConfirmationDialog(
    BuildContext context,
    TransferValidationProvider provider,
  ) {
    final accepted = provider.products.where((p) => p.isAccepted).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.confirmation_number, color: Colors.teal),
            SizedBox(width: 10),
            Text('Confirmer la validation'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous allez valider ${accepted.length} produit(s) :\n',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              ...accepted
                  .take(4)
                  .map(
                    (product) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${product.name} • Qté: ${product.editedQuantity ?? product.receivedQuantity}',
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (accepted.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... et ${accepted.length - 4} autre(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _submitValidation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitValidation() async {
    final scaffold = ScaffoldMessenger.of(context);
    final user = context.read<UserProvider>().user!;
    final transferProvider = context.read<TransferValidationProvider>();
    final success = await transferProvider.submitAcceptedProducts(
      transferId: widget.transferId,
      zone: user.zone,
      warehouse: user.wareHouse,
    );

    if (!mounted) return;

    if (success) {
      scaffold.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('✅ Validation réussie !'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  scaffold.hideCurrentSnackBar();
                  Navigator.pop(context);
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[100]),
              const SizedBox(width: 12),
              const Text('❌ Échec de la validation'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
