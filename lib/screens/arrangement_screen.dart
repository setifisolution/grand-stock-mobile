import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/arrangement_provider.dart';
import '../widgets/custom_app_bar.dart';
import 'arrangement_detail_screen.dart';

class ArrangementScreen extends StatefulWidget {
  const ArrangementScreen({super.key});

  @override
  State<ArrangementScreen> createState() => _ArrangementScreenState();
}

class _ArrangementScreenState extends State<ArrangementScreen> {
  static const _accent = Color(0xFF00B894);
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ArrangementProvider>();
      provider.updateSearch('');
      provider.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final arrangementProvider = context.watch<ArrangementProvider>();
    final pageItems = arrangementProvider.pagedProducts;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: CustomAppBar(),
      body: RefreshIndicator(
        onRefresh: arrangementProvider.loadProducts,
        color: _accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Produits sans emplacement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      if (arrangementProvider.pendingCount > 0)
                        _CountPill(count: arrangementProvider.pendingCount),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Ces produits sont en stock mais n'ont pas encore de place assignée.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: arrangementProvider.updateSearch,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: arrangementProvider.searchQuery.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          arrangementProvider.updateSearch('');
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Afficher',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<int>(
                          value: arrangementProvider.perPage,
                          underline: const SizedBox(),
                          isDense: true,
                          items: ArrangementProvider.perPageOptions
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) arrangementProvider.setPerPage(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'éléments',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (arrangementProvider.allProducts.isEmpty)
              _buildEmptyState()
            else if (pageItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Aucun produit ne correspond à votre recherche.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              )
            else ...[
              for (final p in pageItems) ...[
                _ProductTile(product: p),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              _buildPaginationFooter(arrangementProvider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 40, color: Colors.green[500]),
          const SizedBox(height: 10),
          Text(
            'Tous les produits ont un emplacement.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(ArrangementProvider provider) {
    return Column(
      children: [
        Text(
          'Affichage de ${provider.startIndex + 1} à ${provider.endIndex} sur ${provider.filteredCount} éléments',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        if (provider.totalPages > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _PageButton(
                child: const Icon(Icons.chevron_left_rounded, size: 18),
                enabled: provider.page > 1,
                onTap: provider.previousPage,
              ),
              for (final p in provider.paginationPages)
                p == -1
                    ? const SizedBox(
                        width: 28,
                        height: 34,
                        child: Center(
                          child: Text(
                            '...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : _PageButton(
                        child: Text('$p'),
                        selected: p == provider.page,
                        onTap: () => provider.goToPage(p),
                      ),
              _PageButton(
                child: const Icon(Icons.chevron_right_rounded, size: 18),
                enabled: provider.page < provider.totalPages,
                onTap: provider.nextPage,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 4),
          Text(
            '$count à ranger',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({
    required this.child,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: selected ? const Color(0xFF00B894) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00B894)
                    : Colors.grey.shade300,
              ),
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700],
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: selected ? Colors.white : Colors.grey[700],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  const _ProductTile({required this.product});
  @override
  Widget build(BuildContext context) {
    final expired = product.isExpired;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ArrangementDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        _meta(Icons.tag_rounded, 'Lot ${product.lot}'),
                        _meta(Icons.qr_code_rounded, product.codeLot),
                        _meta(
                          Icons.event_rounded,
                          product.formattedExpirationDate,
                          color: expired ? Colors.red : null,
                          bold: expired,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.stockQty}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  Text(
                    'Quantité',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color, bool bold = false}) {
    final c = color ?? Colors.grey[600]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: c,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
