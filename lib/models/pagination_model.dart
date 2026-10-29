class PaginationModel {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  PaginationModel({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      currentPage: _parseInt(json['currentPage']) ?? 1,
      totalPages: _parseInt(json['totalPages']) ?? 1,
      totalItems: _parseInt(json['totalItems']) ?? 0,
      itemsPerPage: _parseInt(json['itemsPerPage']) ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'itemsPerPage': itemsPerPage,
    };
  }

  PaginationModel copyWith({
    int? currentPage,
    int? totalPages,
    int? totalItems,
    int? itemsPerPage,
  }) {
    return PaginationModel(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }
}