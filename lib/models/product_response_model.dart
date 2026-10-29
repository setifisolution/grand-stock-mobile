import 'pagination_model.dart';
import 'product_model.dart';
import 'summary_model.dart';

class ProductResponseModel {
  final bool success;
  final SummaryModel summary;
  final List<ProductModel> products;
  final PaginationModel pagination;

  ProductResponseModel({
    required this.success,
    required this.summary,
    required this.products,
    required this.pagination,
  });

  factory ProductResponseModel.fromJson(Map<String, dynamic> json) {
    final productsJson = json['products'] as List? ?? [];

    return ProductResponseModel(
      success: json['success'] == true,
      summary: SummaryModel.fromJson(
        json['summary'] is Map<String, dynamic>
            ? json['summary'] as Map<String, dynamic>
            : {},
      ),
      products: productsJson
          .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      pagination: PaginationModel.fromJson(
        json['pagination'] is Map<String, dynamic>
            ? json['pagination'] as Map<String, dynamic>
            : {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'summary': summary.toJson(),
      'products': products.map((p) => p.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }

  ProductResponseModel copyWith({
    bool? success,
    SummaryModel? summary,
    List<ProductModel>? products,
    PaginationModel? pagination,
  }) {
    return ProductResponseModel(
      success: success ?? this.success,
      summary: summary ?? this.summary,
      products: products ?? this.products,
      pagination: pagination ?? this.pagination,
    );
  }
}
