import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class AppConstants {
  static const String _baseUrlKey = 'api_base_url';
  static const String localUrl = 'http://192.168.1.100:8080/api';
  static const String publicUrl = 'https://api.yourpublicdomain.com';

  static String _baseUrl = publicUrl;
  static String get baseUrl => _baseUrl;
  static bool get isLocal => _baseUrl == localUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? publicUrl;
  }

  static Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, newUrl);
  }
}

class ApiEnvironmentManager extends ChangeNotifier {
  static const String _adminPassword = 'your_secure_password';
  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;
  String get currentUrl => AppConstants.baseUrl;
  bool get isLocal => AppConstants.isLocal;

  Future<(bool, String?)> switchEnvironment({required String password, required bool useLocal}) async {
    // 💡 Dev shortcut: use 'dev' as password in debug mode
    if (kDebugMode && password == 'dev') return await _performSwitch(useLocal);
    if (password != _adminPassword) return (false, 'Incorrect password');
    return await _performSwitch(useLocal);
  }

  Future<(bool, String?)> _performSwitch(bool useLocal) async {
    _isSwitching = true;
    notifyListeners();
    try {
      final newUrl = useLocal ? AppConstants.localUrl : AppConstants.publicUrl;
      await AppConstants.updateBaseUrl(newUrl);
      ApiClient.reconfigure(); // Refresh static Dio instance
      return (true, null);
    } catch (e) {
      return (false, 'Switch failed: ${e.toString()}');
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }
}

class ApiClient {
  static final Dio _dio = Dio();
  static final Logger _logger = Logger();

  ApiClient() {
    _setupDio();
    _setupInterceptors();
  }

  static void reconfigure() {
    _setupDio();
    _logger.i('🔄 ApiClient reconfigured: ${AppConstants.baseUrl}');
  }

  static void _setupDio() {
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

  static void _setupInterceptors() {
    _dio.interceptors.clear();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.i('🚀 ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.i('✅ ${response.statusCode}');
        return handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('❌ ${error.message}');
        return handler.next(error);
      },
    ));
  }

  String _convertToFormData(Map<String, dynamic> data) => data.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
      .join('&');

  Future<Response> get({required String endpoint, Map<String, dynamic>? queryParameters, bool useJson = false}) async {
    try {
      final options = useJson ? Options(contentType: Headers.jsonContentType) : null;
      return await _dio.get(endpoint, queryParameters: queryParameters, options: options);
    } on DioException catch (e) { throw _handleDioException(e); }
  }

  Future<Response> post({required String endpoint, required Map<String, dynamic> data, bool useJson = false}) async {
    try {
      if (useJson) {
        return await _dio.post(endpoint, data: data, options: Options(contentType: Headers.jsonContentType));
      } else {
        return await _dio.post(endpoint, data: _convertToFormData(data), options: Options(contentType: Headers.formUrlEncodedContentType));
      }
    } on DioException catch (e) { throw _handleDioException(e); }
  }

  Future<Response> put({required String endpoint, required Map<String, dynamic> data}) async {
    try {
      return await _dio.put(endpoint, data: _convertToFormData(data), options: Options(contentType: Headers.formUrlEncodedContentType));
    } on DioException catch (e) { throw _handleDioException(e); }
  }

  Future<Response> delete({required String endpoint, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.delete(endpoint, queryParameters: queryParameters);
    } on DioException catch (e) { throw _handleDioException(e); }
  }

  Exception _handleDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) return TimeoutException('Connection timeout. Check your network.');
    if (e.type == DioExceptionType.receiveTimeout) return TimeoutException('Server response timeout.');
    String msg = e.message ?? 'Network error';
    if (e.response?.data is Map<String, dynamic>) {
      final d = e.response!.data as Map<String, dynamic>;
      msg = d['message'] ?? d['error'] ?? msg;
    }
    return ApiException(code: e.response?.statusCode ?? 0, message: msg);
  }
}

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException({required this.code, required this.message});
  @override String toString() => 'ApiException($code): $message';
}

// ============================================================================
// 💬 4. API SWITCH DIALOG (using awesome_dialog)
// ============================================================================
class ApiSwitchDialog {
  static Future<bool?> show(BuildContext context) {
    bool dialogResult = false;
    final passwordController = TextEditingController();

    return AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: 'Switch API Environment',
      desc: 'Enter admin password to change the API endpoint',
      descTextStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      showCloseIcon: true,
      headerAnimationLoop: false,
      body: StatefulBuilder(
        builder: (ctx, setState) {
          bool isLoading = false;
          String? error;
          final envManager = ctx.watch<ApiEnvironmentManager>();

          Future<void> handleSwitch(bool useLocal) async {
            setState(() { isLoading = true; error = null; });
            final manager = ctx.read<ApiEnvironmentManager>();
            final (successSwitch, errorMsg) = await manager.switchEnvironment(
              password: passwordController.text.trim(),
              useLocal: useLocal,
            );
            if (!ctx.mounted) return;

            if (successSwitch) {
              dialogResult = true;
              Navigator.of(ctx, rootNavigator: true).pop(true);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('✅ Switched to ${useLocal ? "Local" : "Public"} API'), backgroundColor: Colors.green),
              );
            } else {
              setState(() { error = errorMsg; isLoading = false; });
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: envManager.isLocal ? Colors.orange[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: envManager.isLocal ? Colors.orange[200]! : Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(envManager.isLocal ? Icons.wifi : Icons.cloud, color: envManager.isLocal ? Colors.orange : Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current: ${envManager.isLocal ? "🔧 Local" : "☁️ Public"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(envManager.currentUrl, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Password Input
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Admin Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: isLoading
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  errorText: error,
                ),
                obscureText: true,
                enabled: !isLoading,
                onSubmitted: (_) => handleSwitch(true),
              ),
              const SizedBox(height: 16),
              // Public Button
              if (!isLoading)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => handleSwitch(false),
                    icon: const Icon(Icons.cloud, size: 18),
                    label: const Text('Switch to Public'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      btnOkText: 'Local',
      btnOkColor: Colors.orange,
      btnOkIcon: Icons.wifi,
      btnOkOnPress: () {
        // Triggered via body's handleSwitch(true) on submit, or we can duplicate here:
        // But to keep state clean, we'll just focus on the body buttons.
        // This acts as a fallback if needed.
      },
      btnCancelText: 'Cancel',
      btnCancelOnPress: () => Navigator.of(context, rootNavigator: true).pop(),
    ).show().then((_) => dialogResult ? true : null);
  }
}

// ============================================================================
// 🏠 5. MAIN APP & HOME SCREEN
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConstants.init(); // Load saved baseUrl before app starts
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiEnvironmentManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Switcher Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _makeTestRequest(BuildContext context) async {
    try {
      final response = await ApiClient().get(endpoint: '/test');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Success: ${response.statusCode}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Environment Switcher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await ApiSwitchDialog.show(context);
              if (result == true) {
                // Optional: Refresh data/caches after successful switch
                // context.read<SomeProvider>().refresh();
              }
            },
          ),
        ],
      ),
      body: Consumer<ApiEnvironmentManager>(
        builder: (context, env, _) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(env.isLocal ? Icons.wifi : Icons.cloud, size: 64, color: env.isLocal ? Colors.orange : Colors.blue),
                const SizedBox(height: 16),
                Text('Current Environment:', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  env.isLocal ? '🔧 Local Server' : '☁️ Public Server',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: env.isLocal ? Colors.orange : Colors.blue),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(env.currentUrl, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: env.isSwitching ? null : () => _makeTestRequest(context),
                  icon: const Icon(Icons.send),
                  label: Text(env.isSwitching ? 'Switching...' : 'Test API Call'),
                ),
                const SizedBox(height: 24),
                Text('💡 Debug shortcut: use password "dev"', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          );
        },
      ),
    );
  }
}

