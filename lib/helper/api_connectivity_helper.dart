import 'package:dio/dio.dart';

import '../constant/app_constants.dart';

class ApiConnectivityHelper {
  static const Duration _pingTimeout = Duration(seconds: 3);

  /// Test if local API is reachable by pinging a lightweight endpoint
  static Future<bool> isLocalApiReachable() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConstants.localUrl,
          connectTimeout: _pingTimeout,
          receiveTimeout: _pingTimeout,
        ),
      );

      // Try a lightweight HEAD or GET request to a health endpoint
      // Adjust '/health' or '/ping' to match your API's actual endpoint
      final response = await dio.get(
        '/health',
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      // Connection timeout, refused, or network unreachable = local is down
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException) {
        return false;
      }
      // Other errors (404, 500) might mean server is up but endpoint missing → consider reachable
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Auto-switch to public if local is unreachable
  static Future<bool> ensureApiAvailable() async {
    // Only auto-switch if currently on local AND local is unreachable
    if (AppConstants.isLocal) {
      final reachable = await isLocalApiReachable();
      if (!reachable) {
        debugPrint('🔌 Local API unreachable → Auto-switching to Public');
        await AppConstants.updateBaseUrl(AppConstants.publicUrl);
        ApiClient.reconfigure();
        return true; // Switched
      }
    }
    return false; // No switch needed
  }
}
