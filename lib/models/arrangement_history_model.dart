import 'package:intl/intl.dart';


class ArrangementHistoryModel {
  final String id;
  final String productName;
  final String lot;
  final String codeLot;
  final String zone;
  final String location;
  final int quantity;
  final String? user;
  final DateTime? arrangedAt;

  const ArrangementHistoryModel({
    required this.id,
    required this.productName,
    required this.lot,
    required this.codeLot,
    required this.zone,
    required this.location,
    required this.quantity,
    this.user,
    this.arrangedAt,
  });

  factory ArrangementHistoryModel.fromJson(Map<String, dynamic> json) {
    return ArrangementHistoryModel(
      id: json['id']?.toString() ?? '',
      productName:
      (json['nom'] ?? json['product'] ?? json['name'] ?? 'Unknown')
          .toString(),
      lot: (json['lot'] ?? '').toString(),
      codeLot: (json['codeLot'] ?? json['code'] ?? '').toString(),
      zone: (json['zone'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      quantity: int.tryParse('${json['quantity'] ?? 0}') ?? 0,
      user: json['user']?.toString(),
      arrangedAt: DateTime.tryParse(json['arrangedAt']?.toString() ?? ''),
    );
  }

  /// Date  → 14/10/2026
  String get formattedDate => arrangedAt == null
      ? '—'
      : DateFormat('dd/MM/yyyy').format(arrangedAt!);

  /// Heure → 10:20
  String get formattedTime =>
      arrangedAt == null ? '—' : DateFormat('HH:mm').format(arrangedAt!);
}