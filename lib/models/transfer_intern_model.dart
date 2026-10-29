class TransferStatus {
  static const pending = 'EN_ATTENTE'; // created by admin, sender must send
  static const sent = 'ENVOYE'; // sender confirmed, receiver must confirm
  static const received = 'RECU'; // receiver confirmed, stock updated
  static const cancelled = 'ANNULE';
}

class TransferInternModel {
  final int id;
  final String productLabel;
  final String? productLot;
  final int quantity;
  final String sourceWarehouse;
  final String sourceZone;
  final String sourceLocation;
  final String destWarehouse;
  final String destZone;
  final String destLocation;
  final int? senderId;
  final String? senderName;
  final int? receiverId;
  final String? receiverName;
  final String status;
  final String? notes;
  final DateTime? createdAt;

  const TransferInternModel({
    required this.id,
    required this.productLabel,
    required this.productLot,
    required this.quantity,
    required this.sourceWarehouse,
    required this.sourceZone,
    required this.sourceLocation,
    required this.destWarehouse,
    required this.destZone,
    required this.destLocation,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  static int? _int(dynamic v) => v == null ? null : int.tryParse('$v');
  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _date(dynamic v) => DateTime.tryParse(_str(v) ?? '');

  factory TransferInternModel.fromJson(Map<String, dynamic> j) => TransferInternModel(
    id: _int(j['id'] ?? j['oid']) ?? 0,
    productLabel: _str(j['product_label']) ?? '(sans nom)',
    productLot: _str(j['product_lot']),
    quantity: _int(j['quantity']) ?? 0,
    sourceWarehouse: _str(j['source_warehouse_name']) ?? '-',
    sourceZone: _str(j['source_zone']) ?? '-',
    sourceLocation: _str(j['source_location']) ?? '-',
    destWarehouse: _str(j['destination_warehouse_name']) ?? '-',
    destZone: _str(j['destination_zone']) ?? '-',
    destLocation: _str(j['destination_location']) ?? '-',
    senderId: _int(j['sender_user_id']),
    senderName: _str(j['sender_name']),
    receiverId: _int(j['receiver_user_id']),
    receiverName: _str(j['receiver_name']),
    status: _str(j['status']) ?? 'ENVOYE',
    notes: _str(j['notes']),
    createdAt: _date(j['created_at']),
  );
}