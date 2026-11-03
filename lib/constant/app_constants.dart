import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  // ---- Defaults (used until the user changes them in server settings) ----
  static const String defaultScheme = 'http';
  static const String defaultHost = '192.168.36.156';
  static const String defaultPort = ''; // empty = default port (80 / 443)
  static const String apiPath = '/warhouse/wareHouseWorker/';

  static const String _schemeKey = 'api_scheme';
  static const String _hostKey = 'api_host';
  static const String _portKey = 'api_port';

  static String _scheme = defaultScheme;
  static String _host = defaultHost;
  static String _port = defaultPort;

  static String get scheme => _scheme;
  static String get host => _host;
  static String get port => _port;

  /// Full base URL used by the API client.
  static String get baseUrl => buildUrl(_scheme, _host, _port);

  static String buildUrl(String scheme, String host, String port) {
    final p = port.isEmpty ? '' : ':$port';
    return '$scheme://$host$p$apiPath';
  }

  /// Load saved server settings. Call once before runApp().
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _scheme = prefs.getString(_schemeKey) ?? defaultScheme;
    _host = prefs.getString(_hostKey) ?? defaultHost;
    _port = prefs.getString(_portKey) ?? defaultPort;
  }

  static Future<void> saveServer({
    required String scheme,
    required String host,
    required String port,
  }) async {
    _scheme = scheme;
    _host = host;
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schemeKey, scheme);
    await prefs.setString(_hostKey, host);
    await prefs.setString(_portKey, port);
  }

  static Future<void> resetServer() async {
    _scheme = defaultScheme;
    _host = defaultHost;
    _port = defaultPort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_schemeKey);
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
  }
}
