import 'dart:convert';

import '../models/transfer_intern_model.dart';
import 'api_client.dart';
class TransferInternService {
  final ApiClient _api = ApiClient();

  static const _path = 'transfert_mobile_api.php';
  static const _pathByZone = 'getMyZoneTransfers.php'; // ✅ Endpoint corrigé

  dynamic _decode(dynamic data) => data is String ? jsonDecode(data) : data;

  Future<List<TransferInternModel>> fetchMine(dynamic userId) async {
    final intUid = userId is int ? userId : (int.tryParse(userId.toString()) ?? 0);

    final res = await _api.get(
      endpoint: _path,
      queryParameters: {'action': 'list', 'user_id': intUid},
    );
    final data = _decode(res.data);
    if (data is! Map || data['success'] != true) {
      throw Exception((data is Map ? data['message'] : null) ?? 'Impossible de charger les transferts.');
    }
    final list = (data['transfers'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => TransferInternModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<TransferInternModel>> fetchByLocation({
    required String warehouse,
    required String zone,
  }) async {
    final res = await _api.get(
      endpoint: _pathByZone,
      queryParameters: {'warehouse': warehouse, 'zone': zone},
    );

    final data = _decode(res.data);
    if (data is! Map || data['success'] != true) {
      throw Exception((data is Map ? data['message'] : null) ?? 'Impossible de charger les transferts pour cette zone.');
    }

    final list = (data['transfers'] as List?) ?? const [];
    return list.whereType<Map>().map((e) => TransferInternModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> confirmSend(int transferId, dynamic userId) => _post('confirm_send', transferId, userId);
  Future<void> confirmReceive(int transferId, dynamic userId) => _post('confirm_receive', transferId, userId);

  Future<void> _post(String action, int transferId, dynamic userId) async {
    final intUid = userId is int ? userId : (int.tryParse(userId.toString()) ?? 0);

    final res = await _api.post(
      endpoint: _path,
      data: {'action': action, 'transfer_id': transferId, 'user_id': intUid},
    );
    final data = _decode(res.data);
    if (data is! Map || data['success'] != true) {
      throw Exception((data is Map ? data['message'] : null) ?? 'Action impossible.');
    }
  }
}