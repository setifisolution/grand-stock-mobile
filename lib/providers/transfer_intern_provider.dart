import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../constant/app_enums.dart';
import '../models/transfer_intern_model.dart';
import '../services/transfer_intern_service.dart';
import 'user_provider.dart';


class TransferInternProvider extends ChangeNotifier {
  final TransferInternService _transferService = TransferInternService();
  final UserProvider userProvider;

  List<TransferInternModel> _transfers = [];

  TransferInternProvider({required this.userProvider});

  dynamic get currentUser => userProvider.user;

  int get _currentUserId {
    final id = currentUser?.id;
    if (id == null) return 0;
    if (id is int) return id;
    return int.tryParse(id.toString()) ?? 0;
  }

  bool _loading = false;
  String? _error;
  String _search = '';
  TransferFilter _filter = TransferFilter.all;
  final Set<int> _busy = {};

  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;
  TransferFilter get filter => _filter;
  bool get hasData => _transfers.isNotEmpty;
  bool isBusy(int id) => _busy.contains(id);

  String? get currentWarehouse => currentUser?.wareHouse;
  String? get currentZone => currentUser?.zone;

  // ✅ MÉTHODE AJOUTÉE : Permet de retrouver un transfert par son ID
  TransferInternModel? byId(int id) {
    for (final t in _transfers) {
      if (t.id == id) return t;
    }
    return null;
  }

  TransferAction actionFor(TransferInternModel t) {
    final isSender = t.senderId == _currentUserId;
    final isReceiver = t.receiverId != null && t.receiverId! > 0 && t.receiverId == _currentUserId;

    if (isSender && (t.status == 'BROUILLON' || t.status == 'PENDING')) {
      return TransferAction.send;
    }

    if (isReceiver && (t.status == 'ENVOYE' || t.status == 'SENT')) {
      return TransferAction.receive;
    }

    return TransferAction.none;
  }

  int get toSendCount => _transfers.where((t) => actionFor(t) == TransferAction.send).length;
  int get toReceiveCount => _transfers.where((t) => actionFor(t) == TransferAction.receive).length;
  int get doneCount => _transfers.where((t) => t.status == 'RECU' || t.status == 'ANNULE' || t.status == 'CANCELLED').length;

  List<TransferInternModel> get visible {
    final q = _search.trim().toLowerCase();
    return _transfers.where((t) {
      final okFilter = switch (_filter) {
        TransferFilter.all => true,
        TransferFilter.toSend => actionFor(t) == TransferAction.send,
        TransferFilter.toReceive => actionFor(t) == TransferAction.receive,
        TransferFilter.done => t.status == 'RECU' || t.status == 'ANNULE' || t.status == 'CANCELLED',
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;

      final haystack = [
        t.productLabel, t.productLot ?? '', t.senderName ?? '',
        t.receiverName ?? '', t.sourceLocation, t.destLocation, '#${t.id}',
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  void setSearch(String v) {
    _search = v;
    notifyListeners();
  }

  void setFilter(TransferFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      List<TransferInternModel> list;

      if (currentWarehouse != null && currentZone != null) {
        list = await _transferService.fetchByLocation(
            warehouse: currentWarehouse!,
            zone: currentZone!
        );
      } else {
        list = await _transferService.fetchMine(_currentUserId);
      }

      list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
      _transfers = list;
      _error = null;
    } catch (e) {
      _error = _errorText(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> confirmSend(TransferInternModel t) =>
      _run(t, () => _transferService.confirmSend(t.id, _currentUserId));

  Future<String?> confirmReceive(TransferInternModel t) =>
      _run(t, () => _transferService.confirmReceive(t.id, _currentUserId));

  Future<String?> _run(TransferInternModel t, Future<void> Function() action) async {
    if (_busy.contains(t.id)) return null;
    _busy.add(t.id);
    notifyListeners();
    try {
      await action();
      await load(silent: true);
      return null;
    } catch (e) {
      return _errorText(e);
    } finally {
      _busy.remove(t.id);
      notifyListeners();
    }
  }

  String _errorText(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      try {
        final m = d is String ? jsonDecode(d) : d;
        if (m is Map && m['message'] != null) return '${m['message']}';
      } catch (_) {}
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return 'Connexion impossible. Vérifiez votre réseau.';
      }
      return 'Erreur réseau (${e.response?.statusCode ?? '-'}).';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}