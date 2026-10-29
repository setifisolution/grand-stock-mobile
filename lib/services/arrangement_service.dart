import 'dart:convert';
import '../exceptions/api_exception.dart';
import '../models/arrangement_history_model.dart';
import '../models/product_model.dart';
import 'api_client.dart';

class ArrangementService {
  final ApiClient _apiClient = ApiClient();

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
      message: 'Réponse non JSON: ${snippet.length > 200 ? snippet.substring(0, 200) : snippet}',
    );
  }

  ProductModel _fromBatch(Map<String, dynamic> r) {
    final rawQty = r['Quantity'] ?? r['quantity'] ?? r['qty'];
    final rawPpa = r['PPA'] ?? r['ppa'];
    final rawExp = r['experationDate'] ?? r['ExpirationDate'];
    final rawEntry = r['entryDate'] ?? r['EntryDate'];

    return ProductModel(
      name: (r['ITEM'] ?? r['nom'] ?? 'Unknown').toString(),
      lot: (r['BatchNum'] ?? '').toString(),
      codeLot: (r['Code'] ?? '').toString(),
      entryDate: rawEntry?.toString() ?? '',
      laboratory: 'N/A',
      expirationDate: rawExp?.toString(),
      ppa: double.tryParse('${rawPpa ?? 0}') ?? 0.0,
      quantityInv: int.tryParse('${rawQty ?? ''}'),
      oid: r['Oid']?.toString(),
    );
  }

  Future<List<ProductModel>> getUnplacedProducts() async {
    final response = await _apiClient.post(
      endpoint: 'getProductsWithoutLocation.php',
      useJson: true,
      rawResponse: true,
      data: {},
    );

    dynamic data = response.data;
    if (data is String) data = _decodeLoose(data);

    if (data is Map && data['success'] == true && data['batches'] is List) {
      return (data['batches'] as List)
          .map((e) => _fromBatch(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    throw ApiException(
      code: 500,
      message: (data is Map ? (data['error'] ?? data['message']) : null)?.toString() ?? 'Erreur serveur',
    );
  }

  Future<List<ArrangementHistoryModel>> getArrangementHistory({String? warehouse}) async {
    final response = await _apiClient.post(
      endpoint: 'getArrangementHistory.php',
      useJson: true,
      rawResponse: true,
      data: {if (warehouse != null) 'warehouse': warehouse},
    );

    dynamic data = response.data;
    if (data is String) data = _decodeLoose(data);

    if (data is Map && data['success'] == true && data['history'] is List) {
      return (data['history'] as List)
          .map((e) => ArrangementHistoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    throw ApiException(
      code: 500,
      message: (data is Map ? (data['error'] ?? data['message']) : null)?.toString() ?? 'Erreur serveur',
    );
  }

  /// ✅ UPDATED: Now includes quantite and effectuePar
  Future<({bool success, String message})> submitArrangement({
    required ProductModel product,
    required String location,
    required String zone,
    required String warehouse,
    required int quantite,
    required String effectuePar,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'arrangement_submit.php',
        useJson: true,
        rawResponse: true,
        data: {
          'oid': product.oid,
          'location': location,
          'zone': zone,
          'warehouse': warehouse,
          'quantite': quantite,
          'effectue_par': effectuePar,
        },
      );

      dynamic data = response.data;
      if (data is String) data = _decodeLoose(data);

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
}