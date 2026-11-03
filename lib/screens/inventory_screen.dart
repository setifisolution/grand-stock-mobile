import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../helper/app_dialogs.dart';
import '../manager/assets_manager.dart';
import '../manager/loading_manager.dart';
import '../models/filter_option.dart';
import '../models/product_model.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';
import '../services/transfer_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_picker_dialog.dart';
import '../widgets/summary_chip.dart';
import '../widgets/product_card.dart';
import '../widgets/pagination_button.dart';
import '../widgets/empty_widget.dart';

class InventoryScreen extends StatefulWidget {
  final bool readOnly;

  const InventoryScreen({super.key, this.readOnly = false});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  int _currentPage = 1;
  bool _hasLoadedInitialData = false;
  String _sortOption = 'Adresse';
  bool _hasShownClosedDialog = false;
  StreamSubscription<bool>? _statusSubscription;
  Timer? _statusCheckTimer;
  Timer? _statusFetchTimer;
  Timer? _debounce;

  // ✅ NEW: service used by the product picker dialog
  final TransferService _transferService = TransferService();

  // ✅ NEW: products added manually (getAddedProducts.php)
  List<Map<String, dynamic>> _addedProducts = [];

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final Map<String, FocusNode> _productFocusNodes = {};

  // ✅ Changed from ID to Key to prevent multiple cards from showing loading spinners
  String? _validatingProductKey;

  String _getUniqueProductKey(ProductModel product) {
    return '${product.oid ?? ''}_${product.lot}_${product.codeLot}_${product.location ?? ''}';
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    final provider = context.read<TransferValidationProvider>();
    _statusSubscription = provider.inventoryStatusChangeStream.listen(
      _onInventoryStatusChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && !_hasLoadedInitialData) {
        _hasLoadedInitialData = true;
        final user = context.read<UserProvider>().user;
        if (user != null) {
          provider.startStatusPolling(warehouse: user.wareHouse);
        }
        _loadAddedProducts();
        await _loadData();
      }
    });
  }

  void _onInventoryStatusChanged(bool isOpen) {
    if (!isOpen && !_hasShownClosedDialog && mounted) {
      Future.microtask(() {
        if (!mounted || _hasShownClosedDialog) return;
        AppDialogs.showInventoryClosedDialog(
          context: context,
          hasShownClosedDialog: _hasShownClosedDialog,
          submitAccepted: () async {
            final provider = context.read<TransferValidationProvider>();
            final user = context.read<UserProvider>().user;
            await submitAccepted(
              context: context,
              provider: provider,
              zone: user!.zone,
              warehouse: user.wareHouse,
              onSuccess: () {
                _hasShownClosedDialog = true;
                Navigator.pop(context);
              },
              onError: () {
                debugPrint('❌ Submission failed: ${provider.error}');
              },
            );
          },
        );
      });
    }
  }

  Future<bool> submitAccepted({
    required BuildContext context,
    required dynamic provider,
    required String zone,
    required String warehouse,
    List<ProductModel>? products,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    final productsToSubmit =
        products ??
        (provider.allProducts as List<ProductModel>)
            .where((p) => p.isAccepted)
            .toList();

    if (productsToSubmit.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Aucun produit accepté à transférer'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    try {
      final success = await provider.submitAcceptedProductsListToInventory(
        zone: zone,
        warehouse: warehouse,
        products: productsToSubmit,
      );

      if (context.mounted) Navigator.of(context).pop();

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${provider.successCount} produit(s) transféré(s) avec succès !',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        onSuccess?.call();
        return true;
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${provider.error ?? 'Erreur inconnue'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        onError?.call();
        return false;
      }

      return success;
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur critique: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      onError?.call();
      return false;
    }
  }

  // ✅ Updated to use ProductModel and composite key
  void _focusNextProduct(
    ProductModel currentProduct,
    List<ProductModel> products,
  ) {
    if (widget.readOnly) return;

    final currentKey = _getUniqueProductKey(currentProduct);
    final currentIndex = products.indexWhere(
      (p) => _getUniqueProductKey(p) == currentKey,
    );

    if (currentIndex != -1 && currentIndex < products.length - 1) {
      final nextProduct = products[currentIndex + 1];
      _navigateToProductAfterReload(
        nextProduct.oid,
        nextProduct.lot,
        nextProduct.codeLot,
        nextProduct.location,
      );
    }
  }

  // ✅ Updated to take all components of the composite key
  void _navigateToProductAfterReload(
    String? targetProductId,
    String? lot,
    String? codeLot,
    String? location,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ✅ Use ?? '' to safely handle nullable strings
      final key =
          '${targetProductId ?? ''}_${lot ?? ''}_${codeLot ?? ''}_${location ?? ''}';
      final targetFocus = _productFocusNodes[key];

      if (targetFocus != null && !targetFocus.hasFocus) {
        FocusScope.of(context).requestFocus(targetFocus);
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
        search: _searchController.text.trim(),
        filterStatus: provider.filterStatus,
      );

      if (mounted) {
        for (var product in provider.products) {
          final key = _getUniqueProductKey(product); // ✅ Use composite key
          if (!_productFocusNodes.containsKey(key)) {
            _productFocusNodes[key] = FocusNode();
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ _loadData error: $e');
      if (mounted) {
        _showSnackBar('Erreur de chargement des données', Colors.red);
      }
    }
  }

  void _backgroundSync() {
    if (!mounted) return;
    final provider = context.read<TransferValidationProvider>();
    final user = context.read<UserProvider>().user;

    if (user == null) return;
    provider.fetchItems(
      page: _currentPage,
      reOrder: _sortOption,
      search: _searchController.text.trim(),
      filterStatus: provider.filterStatus,
    );
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_currentPage != 1) {
        setState(() => _currentPage = 1);
      }
      _loadData();
    });
  }

  void _onSummaryChipTap(String filterKey) {
    final provider = context.read<TransferValidationProvider>();
    final filterMap = {
      'total': 'all',
      'validated': 'validated',
      'pending': 'pending',
      'notEntered': 'no saisse',
    };
    provider.updateFilter(filterMap[filterKey] ?? 'all');

    setState(() => _currentPage = 1);
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

  Future<void> _onRefresh() async {
    await Future.wait([_loadData(), _loadAddedProducts()]);
  }

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
          final addrA = a.location?.toLowerCase() ?? '';
          final addrB = b.location?.toLowerCase() ?? '';
          return addrA.compareTo(addrB);
        });
      }
    } catch (e) {
      debugPrint('❌ Sorting error: $e');
    }
    return sorted;
  }

  Future<void> _validateProductDirectly(ProductModel product) async {
    if (widget.readOnly || _validatingProductKey != null) return;

    final user = context.read<UserProvider>().user;
    final transferProvider = context.read<TransferValidationProvider>();
    if (user == null) {
      _showSnackBar('❌ Données utilisateur incomplètes', Colors.red);
      return;
    }

    final productKey = _getUniqueProductKey(product);
    setState(() => _validatingProductKey = productKey); // ✅ Use Key

    try {
      final success = await transferProvider.submitAcceptedProductsToInventory(
        zone: user.zone,
        warehouse: user.wareHouse,
        product: product,
      );

      if (!mounted) return;

      if (success) {
        final currentIndex = transferProvider.products.indexWhere(
          (p) => _getUniqueProductKey(p) == productKey,
        );

        ProductModel? nextProduct;
        if (currentIndex != -1 &&
            currentIndex < transferProvider.products.length - 1) {
          nextProduct = transferProvider.products[currentIndex + 1];
        }

        if (nextProduct != null && mounted) {
          _navigateToProductAfterReload(
            nextProduct.oid!,
            nextProduct.lot,
            nextProduct.codeLot,
            nextProduct.location,
          );
        }
        _backgroundSync();
      } else {
        _showSnackBar('❌ Échec de la validation', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Direct validation error: $e');
      if (mounted) _showSnackBar('❌ Erreur: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _validatingProductKey = null);
    }
  }

  // ✅ NEW: floating button handler -> dialog (product -> lot -> qty)
  Future<void> _openProductPicker() async {
    if (widget.readOnly) return;

    final user = context.read<UserProvider>().user;
    if (user == null) {
      _showSnackBar('❌ Données utilisateur incomplètes', Colors.red);
      return;
    }

    final picked = await ProductPickerDialog.show(
      context,
      zone: user.zone,
      warehouse: user.wareHouse,
      service: _transferService,
    );
    if (picked == null || !mounted) return;

    final row = picked.row;

    // spinner while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator.adaptive()),
    );

    final result = await _transferService.saveAddedProducts(
      zone: user.zone,
      warehouse: user.wareHouse,
      products: [
        {
          'nom': row['nom'],
          'lot': row['lot'],
          'codeLot': row['codeLot'],
          'quantity': picked.quantity,
        },
      ],
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (result.success) {
      _showSnackBar('✅ Produit ajouté avec succès', Colors.green);
      _loadAddedProducts();
    } else {
      _showSnackBar('❌ ${result.message}', Colors.red);
    }
  }

  // ✅ NEW: load the manually added products
  Future<void> _loadAddedProducts() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    try {
      final list = await _transferService.getAddedProducts(
        zone: user.zone,
        warehouse: user.wareHouse,
      );
      if (mounted) setState(() => _addedProducts = list);
    } catch (e) {
      debugPrint('❌ _loadAddedProducts error: $e');
    }
  }

  // ✅ NEW: converts an added product (getAddedProducts.php) to a ProductModel
  // so it is displayed with the same ProductCard as the other products.
  ProductModel _addedToProduct(Map<String, dynamic> a) {
    final qty = int.tryParse('${a['quantity'] ?? 0}') ?? 0;
    return ProductModel.fromJson({
      'nom': a['nom'],
      'name': a['nom'],
      'lot': a['lot'],
      'codeLot': a['codeLot'],
      'location': 'Produit ajouté',
      'quantity': qty,
      'quantityInv': qty,
      'editedQuantity': qty,
      'isAdded': true,
    });
  }

  // ✅ NEW: added products as ProductModel (filtered by the search text)
  List<ProductModel> _addedAsProducts(String search) {
    final q = search.trim().toLowerCase();
    final out = <ProductModel>[];
    for (final a in _addedProducts) {
      final haystack =
          '${a['nom'] ?? ''} ${a['lot'] ?? ''} ${a['codeLot'] ?? ''}'
              .toLowerCase();
      if (q.isNotEmpty && !haystack.contains(q)) continue;
      try {
        out.add(_addedToProduct(a));
      } catch (e) {
        debugPrint('❌ added product mapping error: $e');
      }
    }
    return out;
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
    final summary = transferProvider.summary;
    final pagination = transferProvider.pagination;
    final totalPages = pagination?.totalPages ?? 1;
    final displayedProducts = transferProvider.products;
    final filterStatus = transferProvider.filterStatus;
    // ✅ NEW: added products are shown in the same list (page 1, "all" filter)
    final addedProducts = (_currentPage == 1 && filterStatus == 'all')
        ? _addedAsProducts(_searchController.text)
        : <ProductModel>[];
    final addedKeys = addedProducts.map(_getUniqueProductKey).toSet();
    final sortedProducts = _applySorting([
      ...addedProducts,
      ...displayedProducts,
    ]);

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
      // ✅ NEW: floating button (hidden in read-only mode)
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: _openProductPicker,
              tooltip: 'Ajouter un produit',
              child: const Icon(Icons.add),
            ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: LoadingManager(
          isLoading: transferProvider.isLoading,
          child: Column(
            children: [
              if (summary != null && !readOnly)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.7,
                    children: [
                      SummaryChip(
                        onTap: () => _onSummaryChipTap('total'),
                        label: 'Total',
                        value: summary.total.toString(),
                        color: Colors.blue,
                        icon: Icons.inventory_2,
                        isSelected: filterStatus == 'all',
                        unselectedBg: Colors.blueAccent,
                      ),
                      SummaryChip(
                        label: 'Validés',
                        value: summary.validated.toString(),
                        color: Colors.green,
                        icon: Icons.check_circle,
                        isSelected: filterStatus == 'validated',
                        unselectedBg: Colors.greenAccent,
                        onTap: () => _onSummaryChipTap('validated'),
                      ),
                      SummaryChip(
                        label: 'En attente',
                        value: summary.pending.toString(),
                        color: Colors.orange,
                        icon: Icons.pending,
                        isSelected: filterStatus == 'pending',
                        unselectedBg: Colors.orangeAccent,
                        onTap: () => _onSummaryChipTap('pending'),
                      ),
                      SummaryChip(
                        label: 'Non saisis',
                        value: summary.notEntered.toString(),
                        color: Colors.red,
                        icon: Icons.warning_amber_rounded,
                        isSelected: filterStatus == 'no saisse',
                        unselectedBg: Colors.redAccent,
                        onTap: () => _onSummaryChipTap('notEntered'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: CustomTextField(
                  textEditingController: _searchController,
                  hintText: 'Rechercher (nom, lot, code)...',
                  labelText: 'Rechercher',
                  isSearchTextField: true,
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    if (_currentPage != 1) setState(() => _currentPage = 1);
                    _loadData();
                  },
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
                        // ✅ bottom: 80 so the FAB doesn't cover the last card
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: sortedProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = sortedProducts[index];
                          final productKey = _getUniqueProductKey(product);

                          final originalIndex = transferProvider.products
                              .indexWhere(
                                (p) => _getUniqueProductKey(p) == productKey,
                              );

                          final focusNode =
                              _productFocusNodes[productKey] ?? FocusNode();

                          if (!_productFocusNodes.containsKey(productKey)) {
                            _productFocusNodes[productKey] = focusNode;
                          }

                          // ✅ Use Key to prevent multiple cards from showing loading spinners
                          final isValidating =
                              _validatingProductKey == productKey;

                          // added products are display-only
                          final locked =
                              readOnly || addedKeys.contains(productKey);

                          return ProductCard(
                            product: product,
                            focusNode: focusNode,
                            onValidated: () =>
                                _focusNextProduct(product, sortedProducts),
                            onAcceptToggle: locked
                                ? null
                                : () => _validateProductDirectly(product),
                            onQuantityChange: locked
                                ? null
                                : (qty) => transferProvider.updateQuantity(
                                    originalIndex,
                                    qty,
                                  ),
                            readOnly: locked,
                            isValidating: isValidating,
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
