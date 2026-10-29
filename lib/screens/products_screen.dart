import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../manager/assets_manager.dart';
import '../manager/loading_manager.dart';
import '../models/filter_option.dart';
import '../models/product_model.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/empty_widget.dart';
import '../widgets/pagination_button.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends StatefulWidget {
  final bool readOnly;
  const ProductsScreen({super.key, required this.readOnly});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  int _currentPage = 1;
  bool _hasLoadedInitialData = false;
  String _sortOption = 'Adresse';
  StreamSubscription<bool>? _statusSubscription;
  Timer? _statusCheckTimer;
  Timer? _statusFetchTimer;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final Map<String, FocusNode> _productFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    final provider = context.read<TransferValidationProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_hasLoadedInitialData) {
        _hasLoadedInitialData = true;
        final user = context.read<UserProvider>().user;
        if (user != null) {
          provider.startStatusPolling(warehouse: user.wareHouse);
        }
        await _loadData();
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<TransferValidationProvider>().stopStatusPolling();
    } catch (_) {}

    _statusSubscription?.cancel();
    _statusCheckTimer?.cancel();
    _statusFetchTimer?.cancel();

    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();

    for (var node in _productFocusNodes.values) {
      node.dispose();
    }
    _productFocusNodes.clear();

    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      final provider = context.read<TransferValidationProvider>();
      final user = context.read<UserProvider>().user;

      if (user == null) {
        debugPrint('⚠️ User data incomplete');
        return;
      }

      for (var node in _productFocusNodes.values) {
        node.dispose();
      }
      _productFocusNodes.clear();

      await provider.fetchItems(
        page: _currentPage,
        reOrder: _sortOption,
      );

      if (mounted) {
        for (var product in provider.products) {
          if (!_productFocusNodes.containsKey(product.oid)) {
            _productFocusNodes[product.oid!] = FocusNode();
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ _loadData error: $e');
      if (mounted)
        _showSnackBar('Erreur de chargement des données', Colors.red);
    }
  }

  void _onSearchChanged() {
    if (_currentPage != 1) setState(() => _currentPage = 1);
    context.read<TransferValidationProvider>().updateSearch(
      _searchController.text,
    );
    _loadData();
  }

  void _onSortChanged(String value) {
    if (_currentPage != 1) setState(() => _currentPage = 1);
    setState(() => _sortOption = value);
    _loadData();

    if (mounted) {
      final label = value == 'Alphabet' ? 'Alphabet' : 'Adresse A-Z';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔤 Trié par: $label'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPageChanged(int page) {
    if (page == _currentPage) return;
    setState(() => _currentPage = page);
    _loadData();
  }

  Future<void> _onRefresh() async => _loadData();

  List<ProductModel> _applySorting(List<ProductModel> products) {
    final sorted = List<ProductModel>.from(products);
    try {
      if (_sortOption == 'Alphabet') {
        sorted.sort((a, b) {
          final nameA = a.name.toLowerCase();
          final nameB = b.name.toLowerCase();
          return nameA.compareTo(nameB);
        });
      } else if (_sortOption == 'Adresse') {
        sorted.sort((a, b) {
          final addrA =
              a.location?.toLowerCase() ?? a.location?.toLowerCase() ?? '';
          final addrB =
              b.location?.toLowerCase() ?? b.location?.toLowerCase() ?? '';
          return addrA.compareTo(addrB);
        });
      }
    } catch (e) {
      debugPrint('❌ Sorting error: $e');
    }
    return sorted;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transferProvider = Provider.of<TransferValidationProvider>(context);
    final pagination = transferProvider.pagination;
    final totalPages = pagination?.totalPages ?? 1;
    final displayedProducts = transferProvider.products;
    final sortedProducts = _applySorting(displayedProducts);
    final sortFilterOptions = [
      FilterOption(
        value: 'Alphabet',
        label: 'Alphabet',
        icon: Icons.sort_by_alpha,
        iconColor: Colors.blue,
      ),
      FilterOption(
        value: 'Adresse',
        label: 'Adresse',
        icon: Icons.location_on,
        iconColor: Colors.green,
      ),
    ];
    final readOnly = widget.readOnly;
    return Scaffold(
      appBar: CustomAppBar(
        onFilter: _onSortChanged,
        filterOptions: sortFilterOptions,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: LoadingManager(
          isLoading: transferProvider.isLoading,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: CustomTextField(
                  textEditingController: _searchController,
                  hintText: 'Rechercher (nom, lot, code)...',
                  labelText: 'Rechercher',
                  isSearchTextField: true,
                  onSubmitted: (value) => transferProvider.updateSearch(value),
                ),
              ),

              sortedProducts.isEmpty
                  ? EmptyWidget(
                      imagePath: _searchController.text.isNotEmpty
                          ? AssetsManager.emptySearch
                          : AssetsManager.noData,
                      title: 'Aucun produit trouvé',
                      subtitle: _searchController.text.isNotEmpty
                          ? 'Essayez de modifier votre recherche'
                          : 'Aucun produit sur cette page',
                    )
                  : Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = sortedProducts[index];
                          final focusNode =
                              _productFocusNodes[product.oid] ?? FocusNode();

                          if (!_productFocusNodes.containsKey(product.oid)) {
                            _productFocusNodes[product.oid!] = focusNode;
                          }
                          return ProductCard(
                            product: product,
                            readOnly: readOnly,
                          );
                        },
                      ),
                    ),

              if (pagination != null && pagination.totalPages > 1)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaginationButton(
                        icon: Icons.chevron_left,
                        enabled: _currentPage > 1,
                        onTap: () => _onPageChanged(_currentPage - 1),
                      ),
                      ...List.generate(totalPages, (index) {
                        final page = index + 1;
                        final isActive = page == _currentPage;
                        final showEllipsis =
                            totalPages > 7 &&
                            page != 1 &&
                            page != totalPages &&
                            (page < _currentPage - 1 ||
                                page > _currentPage + 1);

                        if (showEllipsis) {
                          return (page == _currentPage - 2 ||
                                  page == _currentPage + 2)
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '...',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: isActive
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _onPageChanged(page),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Text(
                                  '$page',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey[800],
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      PaginationButton(
                        icon: Icons.chevron_right,
                        enabled: _currentPage < pagination.totalPages,
                        onTap: () => _onPageChanged(_currentPage + 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
