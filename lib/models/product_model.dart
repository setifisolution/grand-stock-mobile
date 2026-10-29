import 'package:intl/intl.dart';

class ProductModel {
  final String name;
  final String lot;
  final String codeLot;
  final String entryDate;
  final int? receivedQuantity;
  final String? location;
  final String laboratory;
  final String? expirationDate;
  final double ppa;
  final String? destination;
  final String? nature;
  final String? warehouse;
  final int? conditioning;
  final String? oid;
  final String? status;
  final int? quantityInv;
  final String? source;
  final bool? isAdded;
  int? editedQuantity;
  bool isAccepted;
  bool get isValidated => status?.toLowerCase() == 'validated';
  bool get isCompleted => status?.toLowerCase() == 'complete';
  bool get isExpired {
    if (expirationDate == null) return false;
    try {
      final expDate = DateTime.parse(expirationDate!);
      return expDate.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String get formattedExpirationDate {
    if (expirationDate == null || expirationDate!.isEmpty) return 'N/A';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(expirationDate!));
    } catch (_) {
      return expirationDate!;
    }
  }


  String get formattedPpa => NumberFormat('#,##0.00').format(ppa);
  ProductModel({
    required this.name,
    required this.lot,
    required this.codeLot,
    required this.entryDate,
    this.receivedQuantity,
    this.location,
    required this.laboratory,
    this.expirationDate,
    required this.ppa,
    this.destination,
    this.nature,
    this.warehouse,
    this.conditioning,
    this.oid,
    this.status,
    this.quantityInv,
    this.source,
    this.isAdded,
    this.editedQuantity,
    this.isAccepted = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      name:
          json['nom'] as String? ??
          json['name'] as String? ??
          json['product'] as String? ??
          'Unknown',
      lot: json['lot']?.toString() ?? json['batch'].toString(),
      codeLot: json['codeLot']?.toString() ?? json['codeLot'].toString(),
      entryDate:
          json['entryDate'] as String? ?? json['EntryDate'] as String? ?? '',
      receivedQuantity: _parseInt(
        json['ReceivedQuantity'] ?? json['receivedQuantity'],
      ),
      location: json['location'] as String?,
      laboratory:
          json['LABO'] as String? ?? json['laboratory'] as String? ?? 'N/A',
      expirationDate:
          json['ExpirationDate'] as String? ??
          json['expirationDate'] as String?,
      ppa: _parseDouble(json['ppa']),
      destination: json['destination'] as String?,
      nature: json['nature'] as String?,
      warehouse:
          json['warhouse'] as String? ??
          json['warehouse'] as String?, // handle typo
      conditioning: _parseInt(json['Conditioning'] ?? json['conditioning']),
      oid: json['Oid'] as String? ?? json['oid'] as String?,
      status: json['status'] as String?,
      quantityInv: _parseInt(json['quantityInv'] ?? json['LogicalQuantity']),
      source: json['source'] as String?,
      isAdded: json['isAdded'] as bool?,
      isAccepted: false,
    );
  }
  Map<String, dynamic> toJson({bool includeUiState = false}) {
    final Map<String, dynamic> data = {
      'nom': name,
      'lot': lot,
      'codeLot': codeLot,
      'entryDate': entryDate,
      if (receivedQuantity != null) 'receivedQuantity': receivedQuantity,
      if (location != null) 'location': location,
      'laboratory': laboratory,
      if (expirationDate != null) 'expirationDate': expirationDate,
      'ppa': ppa,
      if (destination != null) 'destination': destination,
      if (nature != null) 'nature': nature,
      if (warehouse != null) 'warehouse': warehouse,
      if (conditioning != null) 'conditioning': conditioning,
      if (oid != null) 'oid': oid,
      if (status != null) 'status': status,
      if (quantityInv != null) 'quantityInv': quantityInv,
      if (source != null) 'source': source,
      if (isAdded != null) 'isAdded': isAdded,
    };

    if (includeUiState) {
      data['editedQuantity'] = editedQuantity;
      data['isAccepted'] = isAccepted;
    }

    return data;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
