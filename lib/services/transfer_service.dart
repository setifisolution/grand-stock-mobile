import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions/api_exception.dart';
import '../models/inventory_status_model.dart';
import '../models/product_model.dart';
import '../models/product_response_model.dart';
import '../models/save_inventory_response.dart' show SaveInventoryResponse;
import '../models/transfer_model.dart';
import 'api_client.dart';

// Add at the top of your file (keep your existing imports):
// import 'dart:convert';

class TransferService {
  final ApiClient _apiClient = ApiClient();

  // ✅ NEW: used by the product picker dialog (product -> lot -> qty).
  // ✅ NEW: decodes a body that should be JSON but may contain PHP warnings
  dynamic _decodeLoose(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {}
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        return jsonDecode(body.substring(start, end + 1));
      } catch (_) {}
    }
    final snippet = body
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    throw ApiException(
      code: 500,
      message:
      'Réponse non JSON: ${snippet.length > 200 ? snippet.substring(0, 200) : snippet}',
    );
  }

  // Loads products/lots for the picker dialog (fetchItemsShouldntExist.php).
  Future<Map<String, dynamic>> searchInventoryItems({
    required int page,
    required String zone,
    required String warehouse,
    String search = '',
  }) async {
    final response = await _apiClient.post(
      endpoint: 'fetchItemsShouldntExist.php',
      useJson: true,
      rawResponse: true,
      data: {
        'page': page,
        'zone': zone,
        'warehouse': warehouse,
        'search': search,
      },
    );

    // The server may answer with a String if PHP printed a warning/notice
    dynamic data = response.data;
    if (data is String) data = _decodeLoose(data);

    if (data is Map<String, dynamic> && data['success'] == true) {
      if (data['products'] is! List) {
        throw ApiException(
          code: 500,
          message:
          'Réponse inattendue: "products" manquant (mauvais endpoint ?)',
        );
      }
      return data;
    }
    final serverCode = data is Map ? data['code'] : null;
    throw ApiException(
      code: serverCode is int ? serverCode : 500,
      message: (data is Map ? data['message'] : null)?.toString() ??
          'Erreur serveur',
    );
  }


  Future<List<Map<String, dynamic>>> getAddedProducts({
    required String zone,
    required String warehouse,
  }) async {
    final response = await _apiClient.post(
      endpoint: 'getAddedProducts.php',
      useJson: true,
      rawResponse: true,
      data: {'zone': zone, 'warehouse': warehouse},
    );

    dynamic data = response.data;
    if (data is String) data = _decodeLoose(data);

    if (data is Map && data['success'] == true) {
      final list = data['data'];
      if (list is List) {
        return list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    }
    throw ApiException(
      code: 500,
      message: (data is Map ? data['message'] : null)?.toString() ??
          'Erreur serveur',
    );
  }

  // ✅ NEW: saves a manually added product (saveAddedProducts.php)
  Future<({bool success, String message})> saveAddedProducts({
    required String zone,
    required String warehouse,
    required List<Map<String, dynamic>> products,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'saveAddedProducts.php',
        useJson: true,
        rawResponse: true,
        data: {'zone': zone, 'warehouse': warehouse, 'products': products},
      );

      dynamic data = response.data;

      // Old plain-text answer of the PHP script
      if (data is String) {
        if (data.contains('Successfully processed')) {
          return (success: true, message: 'Produit ajouté');
        }
        data = _decodeLoose(data); // throws a readable error if not JSON
      }

      if (data is Map) {
        return (
        success: data['success'] == true,
        message: (data['message'] ?? '').toString(),
        );
      }
      return (success: false, message: 'Réponse invalide du serveur');
    } catch (e) {
      String msg;
      try {
        msg = (e as dynamic).message.toString();
      } catch (_) {
        msg = e.toString();
      }
      return (success: false, message: msg);
    }
  }

  Future<TransferResponseModel> getTransfers({
    String? warehouse,
    String? zone,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'getTransfers.php',
        data: {'warehouse': ?warehouse, 'zone': ?zone},
        useJson: true,
      );

      final data = response.data;

      if (data['success'] == true) {
        return TransferResponseModel.fromJson(data);
      } else {
        throw ApiException(
          code: data['code'] ?? 'FETCH_ERROR',
          message: data['message'] ?? 'Failed to fetch transfers',
        );
      }
    } on DioException catch (e) {
      throw ApiException(
        code: e.response?.statusCode ?? 500,
        message: 'Network error: ${e.message}',
      );
    }
  }

  Future<List<TransferModel>> getPendingTransfers() async {
    final response = await getTransfers();
    return response.pendingTransfers;
  }

  Future<List<ProductModel>?> getProductsByTransfer({
    required String transferId,
    required String zone,
    required String warehouse,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'fetchTransferItems.php',
        useJson: true,
        data: {'transferid': transferId, 'zone': zone, 'warehouse': warehouse},
      );

      final data = response.data;

      if (data['success'] == true && data['products'] is List) {
        final productsJson = data['products'] as List;
        return productsJson
            .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return null;
    } on DioException catch (e) {
      print('Error fetching products: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }
  Future<bool> acceptTransferProduct({
    required String transferId,
    required ProductModel product,
    required int given, // total in units = boxes * conditioning + units
    required String creationDate,
    required String zone,
    required String warehouse,
    int? boxes, // NEW: number of boxes typed by the user
    int? units, // NEW: loose units typed by the user
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'addTransferedData.php',
        useJson: true,
        data: {
          'documentid': int.tryParse(transferId) ?? 0,
          'product': product.name,
          'batch': product.lot,
          'code': product.codeLot,
          'requested': product.receivedQuantity?.toDouble() ?? 0.0,
          'given': given.toDouble(),
          // Server recomputes "given" from these when they are present
          if (boxes != null) 'boxes': boxes,
          if (units != null) 'units': units,
          'creation': creationDate,
          'zone': zone,
          'warehouse': warehouse,
        },
      );

      final data = response.data;

      if (data['success'] != true) {
        print('⚠️ Server refused: ${data['message']}');
        return false;
      }

      if (data['duplicate'] == true) {
        print('⚠️ Duplicate transfer entry skipped');
      }
      if (data['redirect'] != null) {
        print('🔄 Document complete: ${data['redirect']}');
        // You could trigger navigation here via callback
      }

      print('✅ Transfer response: ${data['message']}');
      return true;
    } on DioException catch (e) {
      print('❌ Dio error: ${e.message}');
      if (e.response?.data != null) {
        print('📄 Server error: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('❌ Unexpected error: $e');
      return false;
    }
  }
  /*Future<bool> acceptTransferProduct({
    required String transferId,
    required ProductModel product,
    required int given,
    required String creationDate,
    required String zone,
    required String warehouse,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'addTransferedData.php',
        useJson: true,
        data: {
          'documentid': int.tryParse(transferId) ?? 0,
          'product': product.name,
          'batch': product.lot,
          'code': product.codeLot,
          'requested': product.receivedQuantity?.toDouble() ?? 0.0,
          'given': given.toDouble(),
          'creation': creationDate,
          'zone': zone,
          'warehouse': warehouse,
        },
      );

      final data = response.data;

      // Optional: handle special cases
      if (data['duplicate'] == true) {
        print('⚠️ Duplicate transfer entry skipped');
      }
      if (data['redirect'] != null) {
        print('🔄 Document complete: ${data['redirect']}');
        // You could trigger navigation here via callback
      }

      print('✅ Transfer response: ${data['message']}');
      return data['success'] == true;
    } on DioException catch (e) {
      print('❌ Dio error: ${e.message}');
      if (e.response?.data != null) {
        print('📄 Server error: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('❌ Unexpected error: $e');
      return false;
    }
  }*/

  Future<ProductResponseModel?> fetchItems({
    required int page,
    required String zone,
    required String warehouse,
    String? reOrder,
    String? search,
    String? filterStatus, // ✅ 1. Added parameter
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'fetchItems.php',
        useJson: true,
        data: {
          'page': page,
          'zone': zone,
          'warehouse': warehouse,
          'reorder': reOrder,
          'search': search ?? '',
          'filterStatus': filterStatus ?? 'all', // ✅ 2. Added to JSON payload
        },
      );

      final data = response.data;

      if (data['success'] == true) {
        return ProductResponseModel.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      print('Error fetching products: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<SaveInventoryResponse> saveSingleProductToInventory({
    required String zone,
    required String warehouse,
    required ProductModel product,
  }) async {
    try {
      final productJson = {
        'nom': product.name,
        'lot': product.lot,
        'codeLot': product.codeLot,
        'quantity': product.editedQuantity ?? product.quantityInv ?? 0,
        'isAdded': product.isAdded,
        'oid': product.oid,
      };

      final response = await _apiClient.post(
        endpoint: 'saveProductToInventory.php',
        useJson: true,
        data: {'zone': zone, 'warehouse': warehouse, 'product': productJson},
      );

      final responseData = response.data;

      if (responseData['success'] == true) {
        return SaveInventoryResponse(
          success: true,
          message: responseData['message'] ?? 'Produit sauvegardé avec succès',
          errors: [],
          productId: product.oid,
        );
      } else {
        return SaveInventoryResponse(
          success: false,
          message: responseData['message'] ?? 'Échec de la sauvegarde',
          errors: responseData['errors'] ?? [],
          productId: product.oid,
        );
      }
    } on DioException catch (e) {
      print('❌ Dio error saving single product: ${e.message}');
      return SaveInventoryResponse(
        success: false,
        message: 'Erreur réseau: ${e.message}',
        errors: [],
        productId: product.oid,
      );
    } catch (e) {
      print('❌ Unexpected error: $e');
      return SaveInventoryResponse(
        success: false,
        message: 'Erreur: ${e.toString()}',
        errors: [],
        productId: product.oid,
      );
    }
  }

  Future<InventoryStatusModel?> getInventoryStatus({
    required String warehouse,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'getInventoryStatus.php',
        useJson: true,
        data: {'warehouse': warehouse},
      );

      final data = response.data;

      // Adjust this condition if your API returns the object directly without 'success' wrapper
      if (data['success'] == true && data['data'] != null) {
        return InventoryStatusModel.fromJson(
          data['data'] as Map<String, dynamic>,
        );
      }
      // Fallback: if API returns the object directly at root level
      else if (data['id'] != null) {
        return InventoryStatusModel.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      print(
        '❌ Dio error fetching inventory status for id $warehouse: ${e.message}',
      );
      return null;
    } catch (e) {
      print(
        '❌ Unexpected error fetching inventory status for id $warehouse: $e',
      );
      return null;
    }
  }
}