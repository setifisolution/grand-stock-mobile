class SaveInventoryResponse {
  final bool success;
  final String message;
  final int savedCount;
  final List<Map<String, dynamic>> errors;
  final String? productId;

  SaveInventoryResponse({
    required this.success,
    required this.message,
    this.savedCount = 0,
    this.errors = const [],
    this.productId,
  });

  factory SaveInventoryResponse.fromJson(Map<String, dynamic> json) {
    return SaveInventoryResponse(
      success: json['success'] == true,
      message: json['message'] as String? ?? '',
      savedCount: json['savedCount'] as int? ?? 0,
      productId: json['productId']?.toString(),
      errors: json['errors'] is List
          ? List<Map<String, dynamic>>.from(json['errors'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'savedCount': savedCount,
      'errors': errors,
      'productId': productId,
    };
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get isProductSaved => success && productId != null;
}
