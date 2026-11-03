import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../constant/app_constants.dart';
import '../../helper/server_settings_auth.dart';
import '../../services/api_client.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  late String _scheme;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scheme = AppConstants.scheme;
    _hostController = TextEditingController(text: AppConstants.host);
    _portController = TextEditingController(text: AppConstants.port);
    _hostController.addListener(_refreshPreview);
    _portController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  /// Accepts "192.168.1.10", "http://192.168.1.10" or "https://server.com".
  /// Returns (scheme, host); scheme is null when the user did not type one.
  (String?, String) _parseHost(String input) {
    var value = input.trim();
    String? scheme;
    final lower = value.toLowerCase();
    if (lower.startsWith('https://')) {
      scheme = 'https';
      value = value.substring(8);
    } else if (lower.startsWith('http://')) {
      scheme = 'http';
      value = value.substring(7);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return (scheme, value);
  }

  String get _previewUrl {
    final (typedScheme, host) = _parseHost(_hostController.text);
    return AppConstants.buildUrl(
      typedScheme ?? _scheme,
      host.isEmpty ? '...' : host,
      _portController.text.trim(),
    );
  }

  String? _validateHost(String? v) {
    if (v == null || v.trim().isEmpty) return "Entrez l'adresse du serveur";
    final (_, host) = _parseHost(v);
    if (host.isEmpty || host.contains(' ') || host.contains('/')) {
      return 'Adresse invalide (ex: 192.168.1.10)';
    }
    if (host.contains(':')) {
      return 'Saisissez le port dans le champ Port';
    }
    return null;
  }

  String? _validatePort(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final port = int.tryParse(v.trim());
    if (port == null || port < 1 || port > 65535) {
      return 'Port invalide (1 - 65535)';
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _testing = true);
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _previewUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          // any HTTP answer means the server is reachable
          validateStatus: (_) => true,
        ),
      );
      final response = await dio.get('');
      _toast('Serveur joignable (HTTP ${response.statusCode})', ok: true);
    } on DioException catch (e) {
      _toast('Serveur injoignable : ${e.message ?? e.type.name}', ok: false);
    } catch (e) {
      _toast('Erreur : $e', ok: false);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final (typedScheme, host) = _parseHost(_hostController.text);
    await AppConstants.saveServer(
      scheme: typedScheme ?? _scheme,
      host: host,
      port: _portController.text.trim(),
    );
    ApiClient.reconfigure();
    if (!mounted) return;
    setState(() => _saving = false);
    _toast('Paramètres enregistrés', ok: true);
    Navigator.pop(context);
  }

  Future<void> _resetDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text(
          'Revenir aux paramètres du serveur par défaut ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AppConstants.resetServer();
    ApiClient.reconfigure();
    if (!mounted) return;
    setState(() {
      _scheme = AppConstants.scheme;
      _hostController.text = AppConstants.host;
      _portController.text = AppConstants.port;
    });
    _toast('Paramètres réinitialisés', ok: true);
  }

  Future<void> _changePassword() async {
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;
    if (newPass.length < 6) {
      _toast('Le mot de passe doit contenir au moins 6 caractères', ok: false);
      return;
    }
    if (newPass != confirm) {
      _toast('Les mots de passe ne correspondent pas', ok: false);
      return;
    }
    await ServerSettingsAuth.changePassword(newPass);
    _newPassController.clear();
    _confirmPassController.clear();
    _toast('Mot de passe modifié', ok: true);
  }

  void _toast(String msg, {required bool ok}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: ok ? Colors.green : Colors.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _testing || _saving;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Paramètres du serveur')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'http', label: Text('HTTP')),
                        ButtonSegment(value: 'https', label: Text('HTTPS')),
                      ],
                      selected: {_scheme},
                      onSelectionChanged: (s) =>
                          setState(() => _scheme = s.first),
                    ),
                    TextFormField(
                      controller: _hostController,
                      keyboardType: TextInputType.url,
                      validator: _validateHost,
                      decoration: InputDecoration(
                        labelText: 'Adresse du serveur (endpoint)',
                        hintText: '192.168.1.10',
                        prefixIcon: const Icon(Icons.dns),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ).withTopPadding(16),
                    TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      validator: _validatePort,
                      decoration: InputDecoration(
                        labelText: 'Port (optionnel)',
                        hintText: '80',
                        prefixIcon: const Icon(Icons.settings_ethernet),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ).withTopPadding(16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'URL utilisée :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(_previewUrl),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: const Text('Tester la connexion'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
              TextButton(
                onPressed: busy ? null : _resetDefaults,
                child: const Text('Rétablir les valeurs par défaut'),
              ),
              const Divider(height: 32),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_reset),
                title: const Text("Changer le mot de passe d'accès"),
                children: [
                  TextField(
                    controller: _newPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _changePassword,
                    child: const Text('Modifier'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget withTopPadding(double top) =>
      Padding(padding: EdgeInsets.only(top: top), child: this);
}
