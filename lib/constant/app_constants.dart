class AppConstants {
 /* static const String _baseUrlKey = 'api_base_url';
  static const String localUrl = 'http://192.168.1.100:8080/api';
  static const int splashDelay = 2;*/
  static const String baseUrl = 'http://192.168.36.156/warhouse/wareHouseWorker/';
  //static const String baseUrl = 'http://192.168.0.135/warehouse/wareHouseWorker/';

/*static String _baseUrl = publicUrl;

  static String get baseUrl => _baseUrl;

  // Initialize on app start
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? publicUrl;
  }

  static Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, newUrl);
  }

  // Helper to check current environment
  static bool get isLocal => _baseUrl == localUrl;*/
}