class InventoryStatusModel {
  final String id;
  final String date;
  final String status;
  final String type;

  InventoryStatusModel({
    required this.id,
    required this.date,
    required this.status,
    required this.type,
  });

  factory InventoryStatusModel.fromJson(Map<String, dynamic> json) {
    return InventoryStatusModel(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'status': status,
      'type': type,
    };
  }

  // ➕ Helper getter: check if status is "open"
  bool get isOpen => status.toLowerCase() == 'open';
}