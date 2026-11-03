import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth/server_settings_screen.dart';

/// Handles the password that protects the server settings screen.
///
/// Default password: GrandStock@2026  (change it from the settings screen).
/// Only a SHA-256 hash is stored/compared, never the clear text.
class ServerSettingsAuth {
  static const String _prefKey = 'server_settings_password_hash';

  // sha256("GrandStock@2026")
  static const String _defaultHash =
      'cfc8a1673700294eafa75a26412f56f1faea2a7d9f5a8b78ce15f2664f75b58d';

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static Future<String> _currentHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? _defaultHash;
  }

  static Future<bool> verify(String password) async {
    return _hash(password) == await _currentHash();
  }

  static Future<void> changePassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _hash(newPassword));
  }

  /// Asks for the password, and opens the settings screen if it is correct.
  static Future<void> openProtected(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PasswordDialog(),
    );
    if (ok == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
      );
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ServerSettingsAuth.verify(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _checking = false;
        _error = 'Mot de passe incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline),
          SizedBox(width: 8),
          Expanded(child: Text('Paramètres du serveur')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Entrez le mot de passe administrateur pour continuer.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            enabled: !_checking,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _checking ? null : _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
