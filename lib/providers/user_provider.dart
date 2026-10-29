import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/api_exception.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLoggedIn = false;
  bool _isLoadingBalance = false;
  late SharedPreferences _prefs;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoadingBalance => _isLoadingBalance;
  final Logger _logger = Logger();
  UserProvider() {
    _initSharedPreferences();
  }
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLoggedInState();
  }

  Future<void> _loadLoggedInState() async {
    final savedState = _prefs.getBool('isLoggedIn') ?? false;
    _isLoggedIn = savedState;

    // Load user data from SharedPreferences
    if (_isLoggedIn) {
      await _loadUserData();
    }

    notifyListeners();
  }

  Future<void> _loadUserData() async {
    try {
      final userJson = _prefs.getString('userData');
      if (userJson != null) {
        final userMap = json.decode(userJson);
        _user = UserModel.fromJson(userMap);
      }
    } catch (e) {
      print('Error loading user data: $e');
      // If there's an error loading saved data, logout
      await logout();
    }
  }

  Future<void> _saveUserData(UserModel user) async {
    _user = user;
    final userJson = json.encode(user.toJson());
    await _prefs.setString('userData', userJson);
  }

  Future<void> _saveLoggedInState(bool value) async {
    _isLoggedIn = value;
    await _prefs.setBool('isLoggedIn', value);
    notifyListeners();
  }

  Future<void> _clearUserData() async {
    await _prefs.remove('isLoggedIn');
    await _prefs.remove('userData');
    // Clear any other user-related data
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> logout() async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Clear persisted user data (tokens, etc.)
      await UserService().clearUserData();

      // Clear SharedPreferences data
      await _clearUserData();

      // Reset all user-related state
      _user = null;
      _isLoggedIn = false;
      _isLoadingBalance = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Déconnexion échouée : ${e.toString()}';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _user = user;
    _saveLoggedInState(true);
    _saveUserData(user);
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      setLoading(true);
      setErrorMessage(null);

      final user = await UserService().login(
        username: username,
        password: password,
      );

      setUser(user);
    } catch (error) {
      setErrorMessage(error.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadLoggedInState();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updatePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      setLoading(true);
      setErrorMessage(null);

      await UserService().updatePassword(
        username: username,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (error) {
      setErrorMessage(error.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    String? username,
    String? email,
    String? viber,
    String? whatsapp,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      await UserService().updateUserProfile(
        userId: userId,
        username: username,
        email: email,
        viber: viber,
        whatsapp: whatsapp,
      );
    } catch (e) {
      _errorMessage = e is ApiException
          ? e.message
          : 'Erreur lors de la mise à jour';
      _logger.e('❌ Profile update failed in provider: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logAppEntry() async {
    if (_user == null) {
      _logger.w('Attempted to log app entry without a logged-in user');
      return;
    }
    final String userId = _user!.id.toString();
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      _logger.e('Cannot log entry: user ID is missing or non-numeric');
      return;
    }

    try {
      await UserService().saveEntreAppTime(userId: userId);
      _logger.i('✅ App entry logged for user ID: $userId');
    } catch (e) {
      _logger.e('❌ Failed to log app entry: $e');
    }
  }
}
