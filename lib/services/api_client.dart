import "package:dio/dio.dart";
import 'package:logger/logger.dart';
import "../constant/app_constants.dart";
import "../exceptions/api_exception.dart";
import "../exceptions/timeout_exception.dart";
import "../manager/assets_manager.dart";

class ApiClient {
  static final Dio _dio = Dio();
  static final Logger _logger = Logger();

  static bool _initialized = false;

  ApiClient() {
    if (_initialized) return;
    _initialized = true;
    _setupDio();
    _setupInterceptors();
  }

  /// Re-applies the current AppConstants.baseUrl to the shared Dio instance.
  /// Call this after the server endpoint/port has been changed.
  static void reconfigure() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _logger.i('🔄 ApiClient reconfigured: ${AppConstants.baseUrl}');
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
    );
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          _logger.i('🚀 API Request: ${options.method} ${options.uri}');
          _logger.i('📦 Request Data: ${options.data}');
          _logger.i('📋 Request Headers: ${options.headers}');
          return handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          _logger.i(
            '✅ API Response: ${response.statusCode} ${response.statusMessage}',
          );
          _logger.i('📨 Response Data: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          _logger.e(
            '❌ API Error: type=${error.type} | message=${error.message} | error=${error.error}',
          );
          _logger.e('📨 Error Response: ${error.response?.data}');
          return handler.next(error);
        },
      ),
    );
  }

  String _convertToFormData(Map<String, dynamic> data) {
    return data.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}',
        )
        .join('&');
  }

  Future<Response> get({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    bool useJson = false,
  }) async {
    try {
      if (useJson) {
        return await _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: Options(contentType: Headers.jsonContentType),
        );
      } else {
        return await _dio.get(endpoint, queryParameters: queryParameters);
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Response> post({
    required String endpoint,
    required Map<String, dynamic> data,
    bool useJson = false,
    bool rawResponse = false,
  }) async {
    try {
      if (useJson) {
        // Send as raw JSON
        return await _dio.post(
          endpoint,
          data: data,
          options: Options(
            contentType: Headers.jsonContentType,
            responseType: rawResponse ? ResponseType.plain : null,
          ),
        );
      } else {
        final formData = _convertToFormData(data);
        return await _dio.post(
          endpoint,
          data: formData,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Response> put({
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    try {
      final formData = _convertToFormData(data);

      return await _dio.put(
        endpoint,
        data: formData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Response> delete({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Exception _handleDioException(DioException e) {
    // Handle timeouts specifically
    if (e.type == DioExceptionType.connectionTimeout) {
      return TimeoutException(
        message:
            'Unable to connect to server. Please check your internet connection.',
        imageAsset: AssetsManager.noInternet,
      );
    }

    if (e.type == DioExceptionType.receiveTimeout) {
      return TimeoutException(
        message:
            'Server is taking too long to respond. Please try again later.',
        imageAsset: AssetsManager.serverDown,
      );
    }


    String errorMessage =
        e.message ?? e.error?.toString() ?? 'Network error occurred';
    int statusCode = e.response?.statusCode ?? 0;

    if (e.response != null && e.response!.data != null) {
      if (e.response!.data is Map<String, dynamic>) {
        final responseData = e.response!.data as Map<String, dynamic>;
        errorMessage =
            responseData['message'] ??
            responseData['error'] ??
            responseData['status'] ??
            errorMessage;
      } else if (e.response!.data is String) {
        errorMessage = e.response!.data.toString();
      }
    }

    return ApiException(code: statusCode, message: errorMessage);
  }
}
