import 'package:flutter/foundation.dart';
import 'dart:async';
import '../exceptions/api_exception.dart';
import '../models/inventory_status_model.dart';
import '../models/pagination_model.dart';
import '../models/product_model.dart';
import '../models/summary_model.dart';
import '../models/transfer_model.dart';
import '../services/transfer_service.dart';
import 'user_provider.dart';

class TransferValidationProvider extends ChangeNotifier {
  final TransferService _transferService = TransferService();

  // ✅ 1. Inject UserProvider to access the user anywhere in this class
  final UserProvider userProvider;

  // ✅ 2. Add a constructor to require the UserProvider
  TransferValidationProvider({required this.userProvider});

  // 📦 Product State
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  SummaryModel? _summary;
  PaginationModel? _pagination;

  // 🔄 Transfer State
  List<TransferModel> _transfers = [];
  List<TransferModel> _filteredTransfers = [];
  String _transferFilterQuery = '';

  // 🎛️ UI State
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  int _successCount = 0;
  String _searchQuery = '';
  String _filterStatus = 'all';
  String? _lastErrorCode;
  String? _lastSavedProductId;
  InventoryStatusModel? _inventoryStatus;
  bool _isStatusLoading = false;
  Timer? _statusPollingTimer;

  // Getters
  List<ProductModel> get products => _filteredProducts;
  List<ProductModel> get allProducts => _allProducts;
  int get acceptedCount => _filteredProducts.where((p) => p.isAccepted).length;
  int get completedCount => _filteredProducts.where((p) => p.isCompleted).length;
  SummaryModel? get summary => _summary;
  PaginationModel? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get hasError => _error?.isNotEmpty ?? false;
  int get successCount => _successCount;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastSavedProductId => _lastSavedProductId;
  String get searchQuery => _searchQuery;
  String get filterStatus => _filterStatus;

  bool get hasChanges => _filteredProducts.any(
        (p) =>
    (p.editedQuantity ?? p.receivedQuantity) != p.receivedQuantity ||
        p.isAccepted,
  );

  // 📊 Inventory Status Getters
  InventoryStatusModel? get inventoryStatus => _inventoryStatus;
  bool get isStatusLoading => _isStatusLoading;
  bool get isInventoryOpen => _inventoryStatus?.isOpen ?? false;
  String get inventoryStatusText => _inventoryStatus?.status.toUpperCase() ?? 'INCONNU';
  String get inventoryTypeText => _inventoryStatus?.type ?? '—';

  List<TransferModel> get transfers => _filteredTransfers;
  List<TransferModel> get allTransfers => _transfers;
  String get transferFilterQuery => _transferFilterQuery;

  static const _pollingDuration = Duration(seconds: 10);

  // ✅ Fixed syntax error here (removed incomplete "final User")
  final StreamController<bool> _inventoryStatusChangeController =
  StreamController<bool>.broadcast();

  // 🎯 Helper getter to easily access the current user
  dynamic get currentUser => userProvider.user; // Replace 'dynamic' with your actual User model type if needed

  void startStatusPolling({required String warehouse}) {
    stopStatusPolling();
    loadInventoryStatus(warehouse: warehouse);
    _statusPollingTimer = Timer.periodic(_pollingDuration, (_) {
      loadInventoryStatus(warehouse: warehouse);
    });
  }

  void stopStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
  }

  Future<bool> loadInventoryStatus({required String warehouse}) async {
    if (_isStatusLoading) return false;
    _isStatusLoading = true;
    _error = null;
    notifyListeners();

    try {
      final status = await _transferService.getInventoryStatus(warehouse: warehouse);
      if (status != null) {
        final oldIsOpen = _inventoryStatus?.isOpen;
        _inventoryStatus = status;
        notifyListeners();
        if (oldIsOpen != status.isOpen) {
          _inventoryStatusChangeController.add(status.isOpen);
        }
        return true;
      } else {
        _error = 'Impossible de charger le statut de l\'inventaire';
        return false;
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      return false;
    } finally {
      _isStatusLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopStatusPolling();
    _inventoryStatusChangeController.close();
    super.dispose();
  }

  Stream<bool> get inventoryStatusChangeStream => _inventoryStatusChangeController.stream;

  void _resetProductState() {
    _allProducts = [];
    _filteredProducts = [];
    _summary = null;
    _pagination = null;
    _searchQuery = '';
    _filterStatus = 'all';
    _successCount = 0;
    _lastSavedProductId = null;
  }

  String _normalizeStatus(String? status) {
    if (status == null) return '';
    return status.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matchesStatusFilter(ProductModel product, String filter) {
    if (filter == 'all') return true;
    final pStatus = _normalizeStatus(product.status);
    final filterNorm = filter.toLowerCase().trim();
    switch (filterNorm) {
      case 'validated':
      case 'validé':
      case 'valide':
        return pStatus == 'validated' || pStatus == 'validé';
      case 'pending':
      case 'en attente':
      case 'en attente de verification':
        return pStatus == 'en attente de verification' || pStatus == 'pending';
      case 'no saisse':
      case 'not entered':
        return pStatus == 'no saisse';
      case 'missing':
        return pStatus == 'missing';
      default:
        return pStatus == filterNorm;
    }
  }

  void _applyFilters() {
    var result = List<ProductModel>.from(_allProducts);

    if (_filterStatus != 'all') {
      result = result.where((p) => _matchesStatusFilter(p, _filterStatus)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        final nameMatch = p.name.toLowerCase().contains(query);
        final lotMatch = p.lot.toLowerCase().contains(query);
        final codeMatch = p.codeLot.toLowerCase().contains(query);
        return nameMatch || lotMatch || codeMatch;
      }).toList();
    }
    _filteredProducts = result;
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void updateFilter(String status) {
    _filterStatus = status;
    _applyFilters();
  }

  Future<bool> fetchItems({
    required int page,
    String? reOrder,
    String? search,
    String? filterStatus,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _transferService.fetchItems(
        page: page,
        zone: currentUser.zone,
        warehouse: currentUser.warehouse,
        reOrder: reOrder,
        search: search,
        filterStatus: filterStatus,
      );

      if (response != null) {
        _summary = response.summary;
        _pagination = response.pagination;

        _allProducts = List<ProductModel>.from(response.products);
        _applyFilters();

        return true;
      } else {
        _error = 'Aucune donnée reçue';
        return false;
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts({
    required String transferId,
  }) async {
    _isLoading = true;
    _error = null;
    _resetProductState();
    notifyListeners();
    try {
      final result = await _transferService.getProductsByTransfer(
        transferId: transferId,
        zone: currentUser.zone,
        warehouse: currentUser.warehouse,
      );
      if (result != null && result.isNotEmpty) {
        _allProducts = result;
        _applyFilters();
      } else {
        _error = result == null ? 'Erreur de connexion au serveur' : 'Aucun produit trouvé pour ce transfert';
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQuantity(int index, int value) {
    if (index < 0 || index >= _filteredProducts.length) return;
    final filteredProduct = _filteredProducts[index];
    final globalIndex = _allProducts.indexWhere((p) => p.oid == filteredProduct.oid);
    if (globalIndex != -1) {
      _allProducts[globalIndex].editedQuantity = value;
      _applyFilters();
    }
  }

  void toggleAccept(int index) {
    if (index < 0 || index >= _filteredProducts.length) return;
    final filteredProduct = _filteredProducts[index];
    final globalIndex = _allProducts.indexWhere((p) => p.oid == filteredProduct.oid);
    if (globalIndex != -1) {
      final product = _allProducts[globalIndex];
      product.isAccepted = !product.isAccepted;
      _applyFilters();
    }
  }

  void toggleAcceptAll() {
    final allAccepted = _filteredProducts.every((p) => p.isAccepted);
    for (var product in _filteredProducts) {
      final globalIndex = _allProducts.indexWhere((p) => p.oid == product.oid);
      if (globalIndex != -1) {
        _allProducts[globalIndex].isAccepted = !allAccepted;
      }
    }
    _applyFilters();
  }

  Future<bool> acceptSingleProduct({
    required String transferId,
    required ProductModel product,
    required int acceptedQuantity,
    int? boxes,
    int? units,

  }) async {
    try {
      return await _transferService.acceptTransferProduct(
        transferId: transferId,
        product: product,
        given: acceptedQuantity,
        boxes: boxes,
        units: units,
        creationDate: product.entryDate,
        zone: currentUser.zone,
        warehouse: currentUser.wareHouse,
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitAcceptedProducts({
    required String transferId,
    required String zone,
    required String warehouse,
  }) async {
    final accepted = _allProducts.where((p) => p.isAccepted).toList();
    if (accepted.isEmpty) return false;
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      int successCount = 0;
      int failCount = 0;
      for (final product in accepted) {
        try {
          final originalQty = product.receivedQuantity ?? 0;
          final givenQty = product.editedQuantity ?? originalQty;
          final success = await acceptSingleProduct(
            transferId: transferId,
            product: product,
            acceptedQuantity: givenQty,

          );
          if (success) {
            successCount++;
            _successCount++;
            _allProducts.removeWhere((p) => p.oid == product.oid);
          } else {
            failCount++;
          }
          notifyListeners();
        } catch (e) {
          failCount++;
        }
      }
      _applyFilters();
      return failCount == 0;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitAcceptedProductsToInventory({
    required String zone,
    required String warehouse,
    required ProductModel product,
  }) async {
    final validWarehouses = ['Grand Stock', '1er Etage'];
    if (!validWarehouses.contains(warehouse)) {
      _error = 'Entrepôt invalide: "$warehouse"';
      return false;
    }

    _isSubmitting = true;
    _error = null;
    _lastSavedProductId = null;
    notifyListeners();

    try {
      final result = await _transferService.saveSingleProductToInventory(
        zone: zone,
        warehouse: warehouse,
        product: product,
      );

      if (result.success) {
        _successCount += result.savedCount;
        _lastSavedProductId = result.productId;
        _allProducts.removeWhere((p) => p.oid == product.oid);
        _applyFilters();
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors de la sauvegarde: ${e.toString()}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitAcceptedProductsListToInventory({
    required String zone,
    required String warehouse,
    required List<ProductModel> products,
  }) async {
    final validWarehouses = ['Grand Stock', '1er Etage'];
    if (!validWarehouses.contains(warehouse)) {
      _error = 'Entrepôt invalide: "$warehouse"';
      return false;
    }

    if (products.isEmpty) {
      _error = 'Aucun produit à soumettre';
      return false;
    }

    _isSubmitting = true;
    _error = null;
    _lastSavedProductId = null;
    _successCount = 0;
    notifyListeners();

    try {
      final results = <String, bool>{};
      int savedCount = 0;
      String? lastSavedId;

      for (final product in products) {
        try {
          final result = await _transferService.saveSingleProductToInventory(
            zone: zone,
            warehouse: warehouse,
            product: product,
          );

          if (result.success) {
            savedCount++;
            lastSavedId = result.productId;
            results[product.oid!] = true;
          } else {
            results[product.oid!] = false;
            print('⚠️ Échec pour ${product.oid}: ${result.message}');
          }
        } catch (e) {
          results[product.oid!] = false;
          print('⚠️ Exception pour ${product.oid}: ${e.toString()}');
        }
      }

      _successCount += savedCount;
      _lastSavedProductId = lastSavedId;
      _allProducts.removeWhere((p) => results[p.oid] == true);
      _applyFilters();

      if (savedCount == products.length) {
        _error = null;
      } else if (savedCount > 0) {
        _error = '$savedCount/${products.length} produits enregistrés. Vérifiez les échecs.';
      } else {
        _error = 'Aucun produit n\'a pu être enregistré.';
      }

      return savedCount > 0;

    } catch (e) {
      _error = 'Erreur critique lors de la sauvegarde en lot: ${e.toString()}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> refreshInventoryStatus({required String warehouse}) async {
    await loadInventoryStatus(warehouse: warehouse);
  }

  Future<void> loadTransfers({
    required String zone,
    required String warehouse,
    UserProvider? externalUserProvider, // Made optional since we have it injected
  }) async {
    _isLoading = true;
    _error = null;
    _lastErrorCode = null;
    notifyListeners();

    try {
      // ✅ 3. Use the injected userProvider (or the external one if passed)
      final activeUserProvider = externalUserProvider ?? this.userProvider;

      if (!activeUserProvider.isLoggedIn || activeUserProvider.user == null) {
        throw ApiException(code: 400, message: 'Veuillez vous connecter');
      }

      // Example of accessing user data:
      // final userId = activeUserProvider.user.id;
      // final userName = activeUserProvider.user.name;

      final response = await _transferService.getTransfers(
        warehouse: warehouse,
        zone: zone,
      );
      _transfers = response.sortedByDate;
      _filteredTransfers = List.from(_transfers);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _lastErrorCode = e.code?.toString();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Une erreur inattendue est survenue';
      _lastErrorCode = 'UNKNOWN';
      _isLoading = false;
      notifyListeners();
    }
  }
}