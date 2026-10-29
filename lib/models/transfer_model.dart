import 'package:flutter/material.dart';

class TransferModel {
  final String id;
  final String reference;
  final String type;
  final String status;
  final String origin;
  final String destination;
  final int warehouseId;
  final String warehouseName;
  final DateTime createdAt;

  TransferModel({
    required this.id,
    required this.reference,
    required this.type,
    required this.status,
    required this.origin,
    required this.destination,
    required this.warehouseId,
    required this.warehouseName,
    required this.createdAt,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id']?.toString() ?? '',
      reference: json['reference'] as String? ?? '',
      type: json['type'] as String? ?? 'internal',
      status: json['status'] as String? ?? 'pending',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      warehouseId: _parseInt(json['warehouse_id']),
      warehouseName: json['warehouse_name'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'type': type,
      'status': status,
      'origin': origin,
      'destination': destination,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ==================== HELPERS ====================

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) {
      // Handle Unix timestamp (in seconds or milliseconds)
      return value > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      try {
        return DateTime.parse(value.replaceAll(' ', 'T'));
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${createdAt.day} ${months[createdAt.month - 1]} ${createdAt.year}';
  }

  String get formattedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime => '$formattedDate, $formattedTime';

  String get relativeTime {
    final now = DateTime.now();

    // ✅ 1. Handle FUTURE dates (Time left)
    if (createdAt.isAfter(now)) {
      final timeLeft = createdAt.difference(now); // This will be positive

      if (timeLeft.inDays > 30) {
        return formattedDate; // Fallback to absolute date if it's too far in the future
      } else if (timeLeft.inDays > 0) {
        return 'Dans ${timeLeft.inDays} jour${timeLeft.inDays > 1 ? 's' : ''}';
      } else if (timeLeft.inHours > 0) {
        return 'Dans ${timeLeft.inHours}h';
      } else if (timeLeft.inMinutes > 0) {
        return 'Dans ${timeLeft.inMinutes} min';
      } else {
        return 'Dans moins d\'une minute';
      }
    }

    // ✅ 2. Handle PAST dates (Original logic)
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'À l\'instant';
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return formattedDate;
    }
  }
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'brouillon': return Colors.orange;
      case 'valide': return Colors.green;
      case 'cancelled':
      case 'rejected': return Colors.red;
      case 'in_progress':
      case 'processing': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toLowerCase()) {
      case 'brouillon': return Icons.schedule_rounded;
      case 'valide': return Icons.check_circle_rounded;
      case 'cancelled':
      case 'rejected': return Icons.cancel_rounded;
      case 'in_progress':
      case 'processing': return Icons.sync_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'internal': return 'Interne';
      case 'external': return 'Externe';
      case 'return': return 'Retour';
      default: return type.toUpperCase();
    }
  }

  bool get isPending => status.toLowerCase() == 'brouillon';
  bool get isCompleted => status.toLowerCase() == 'valide' || status.toLowerCase() == 'done';
  bool get isCancelled => status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'rejected';
}


class TransferResponseModel {
  final bool success;
  final List<TransferModel> transfers;

  TransferResponseModel({
    required this.success,
    required this.transfers,
  });

  factory TransferResponseModel.fromJson(Map<String, dynamic> json) {
    final transfersJson = json['transfers'] as List<dynamic>? ?? [];
    final transfers = transfersJson
        .map((item) => TransferModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return TransferResponseModel(
      success: json['success'] as bool? ?? false,
      transfers: transfers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'transfers': transfers.map((t) => t.toJson()).toList(),
    };
  }

  /// Get pending transfers only
  List<TransferModel> get pendingTransfers =>
      transfers.where((t) => t.isPending).toList();

  /// Get completed transfers only
  List<TransferModel> get completedTransfers =>
      transfers.where((t) => t.isCompleted).toList();

  /// Get transfers sorted by date (newest first)
  List<TransferModel> get sortedByDate {
    final sorted = List<TransferModel>.from(transfers);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Search transfers by reference or destination
  List<TransferModel> search(String query) {
    if (query.isEmpty) return transfers;
    final lowerQuery = query.toLowerCase();
    return transfers.where((t) {
      return t.reference.toLowerCase().contains(lowerQuery) ||
          t.destination.toLowerCase().contains(lowerQuery) ||
          t.origin.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
