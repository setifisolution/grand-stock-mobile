import 'package:flutter/foundation.dart';
import '../exceptions/api_exception.dart';
import '../models/arrangement_history_model.dart';
import '../models/product_model.dart';
import '../services/arrangement_service.dart';
import 'user_provider.dart';

extension ProductStockQty on ProductModel {
  int get stockQty => quantityInv ?? receivedQuantity ?? 0;
}

class ArrangementProvider extends ChangeNotifier {
  final ArrangementService _service = ArrangementService();
  final UserProvider userProvider;

  ArrangementProvider({required this.userProvider});

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  List<ArrangementHistoryModel> _history = [];
  List<ArrangementHistoryModel> _filteredHistory = [];

  bool _isHistoryLoading = false;
  String? _historyError;
  String _historyQuery = '';
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  String _searchQuery = '';
  int _page = 1;
  int _perPage = 10;

  static const perPageOptions = [10, 25, 50, 100];

  List<ProductModel> get allProducts => _allProducts;
  List<ProductModel> get products => _filteredProducts;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  bool get hasError => _error?.isNotEmpty ?? false;
  String get searchQuery => _searchQuery;
  int get pendingCount => _allProducts.length;

  List<ArrangementHistoryModel> get allHistory => _history;
  List<ArrangementHistoryModel> get history => _filteredHistory;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get historyError => _historyError;
  bool get hasHistoryError => _historyError?.isNotEmpty ?? false;
  String get historyQuery => _historyQuery;

  int get page => _page;
  int get perPage => _perPage;
  int get filteredCount => _filteredProducts.length;
  int get totalPages => _filteredProducts.isEmpty ? 1 : (_filteredProducts.length / _perPage).ceil();
  int get startIndex => (_page - 1) * _perPage;
  int get endIndex => (startIndex + _perPage).clamp(0, _filteredProducts.length);
  List<ProductModel> get pagedProducts => _filteredProducts.isEmpty ? <ProductModel>[] : _filteredProducts.sublist(startIndex, endIndex);

  List<int> get paginationPages {
    final total = totalPages;
    if (total <= 7) return List.generate(total, (i) => i + 1);
    if (_page <= 4) return [1, 2, 3, 4, 5, -1, total];
    if (_page >= total - 3) return [1, -1, total - 4, total - 3, total - 2, total - 1, total];
    return [1, -1, _page - 1, _page, _page + 1, -1, total];
  }

  dynamic get currentUser => userProvider.user;
  String _keyOf(ProductModel p) => p.oid ?? '${p.codeLot}-${p.lot}';

  void _applyFilters() {
    var result = List<ProductModel>.from(_allProducts);
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.lot.toLowerCase().contains(query) ||
            p.codeLot.toLowerCase().contains(query);
      }).toList();
    }
    _filteredProducts = result;
    if (_page > totalPages) _page = totalPages;
    if (_page < 1) _page = 1;
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _page = 1;
    _applyFilters();
  }

  void setPerPage(int value) {
    _perPage = value;
    _page = 1;
    notifyListeners();
  }

  void goToPage(int value) {
    if (value < 1 || value > totalPages) return;
    _page = value;
    notifyListeners();
  }

  void nextPage() => goToPage(_page + 1);
  void previousPage() => goToPage(_page - 1);

  Future<bool> loadProducts() async {
    if (_isLoading) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getUnplacedProducts();
      _allProducts = result;
      _page = 1;
      _applyFilters();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadProducts();

  /// ✅ UPDATED: Now accepts quantite and passes user data to the service
  Future<bool> submitArrangement({
    required ProductModel product,
    required String location,
    required int quantite,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.submitArrangement(
        product: product,
        location: location,
        zone: currentUser?.zone ?? 'Non spécifiée',
        warehouse: currentUser?.wareHouse ?? 'Entrepôt Principal',
        quantite: quantite,
        effectuePar: currentUser?.username ?? 'Système',
      );

      if (result.success) {
        _allProducts.removeWhere((p) => _keyOf(p) == _keyOf(product));
        _applyFilters();
        return true;
      } else {
        _error = result.message.isNotEmpty ? result.message : 'Échec du rangement';
        return false;
      }
    } catch (e) {
      _error = 'Erreur lors du rangement: ${e.toString()}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _applyHistoryFilter() {
    var result = List<ArrangementHistoryModel>.from(_history);
    if (_historyQuery.isNotEmpty) {
      final q = _historyQuery.toLowerCase();
      result = result.where((h) {
        return h.productName.toLowerCase().contains(q) ||
            h.lot.toLowerCase().contains(q) ||
            h.codeLot.toLowerCase().contains(q) ||
            h.zone.toLowerCase().contains(q) ||
            h.location.toLowerCase().contains(q) ||
            (h.user ?? '').toLowerCase().contains(q);
      }).toList();
    }
    _filteredHistory = result;
    notifyListeners();
  }

  void updateHistorySearch(String query) {
    _historyQuery = query;
    _applyHistoryFilter();
  }

  Future<bool> loadHistory() async {
    if (_isHistoryLoading) return false;
    _isHistoryLoading = true;
    _historyError = null;
    notifyListeners();

    try {
      final result = await _service.getArrangementHistory(warehouse: currentUser?.wareHouse);
      result.sort((a, b) {
        final da = a.arrangedAt;
        final db = b.arrangedAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      _history = result;
      _applyHistoryFilter();
      return true;
    } on ApiException catch (e) {
      _historyError = e.message;
      return false;
    } catch (e) {
      _historyError = 'Erreur: ${e.toString()}';
      return false;
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }
}