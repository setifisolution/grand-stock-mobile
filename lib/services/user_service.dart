import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../exceptions/api_exception.dart';
import '../exceptions/auth_exception.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();
  final Logger _logger = Logger();
  UserModel? _cachedUser;
  Completer<SharedPreferences>? _prefsCompleter;

  Future<SharedPreferences> get _prefs async {
    _prefsCompleter ??= Completer<SharedPreferences>();
    if (!_prefsCompleter!.isCompleted) {
      _prefsCompleter!.complete(await SharedPreferences.getInstance());
    }
    return _prefsCompleter!.future;
  }

  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    try {
      _logger.i('🔐 Login attempt for username: $username');
      final response = await _apiClient.post(
        endpoint: 'checkUser.php',
        data: {'username': username.trim(), 'password': password.trim()},
      );

      _logger.i('📨 Login response received');
      _logger.i('Status Code: ${response.statusCode}');
      _logger.i('Response Data: ${response.data}');

      final responseData = _parseResponse(response);

      // ✅ FIX #1: Check 'success' key (boolean) instead of 'status'
      if (responseData['success'] == true) {
        _logger.i('✅ Login successful');

        // ✅ FIX #2: Handle actual response structure (no 'data' wrapper)
        dynamic userData;

        if (responseData.containsKey('user')) {
          // API returns: {success: true, user: {...}}
          userData = responseData['user'];
        } else if (responseData['data'] is Map<String, dynamic>) {
          // Fallback for other endpoints that wrap data
          final data = responseData['data'] as Map<String, dynamic>;
          userData = data.containsKey('user')
              ? data['user']
              : data.containsKey('thirdPartyInfo')
              ? data['thirdPartyInfo']
              : data;
        } else {
          userData = responseData;
        }

        _logger.i('📦 Parsed userData: $userData');

        final user = UserModel.fromJson(userData);
        await _saveUserData(user);

        _logger.i('👤 User data saved: ${user.id}');
        return user;
      } else {
        final errorCode =
            responseData['code'] ??
            responseData['error_code'] ??
            'UNKNOWN_ERROR';
        final errorMessage =
            responseData['message'] ??
            responseData['error'] ??
            'Authentication failed';

        _logger.w('❌ Login failed: $errorCode - $errorMessage');
        throw AuthException(code: errorCode, message: errorMessage);
      }
    } on ApiException catch (e) {
      _logger.e('🔌 API Exception during login: ${e.code} - ${e.message}');
      if (e.code == 408 || e.message.toLowerCase().contains('timeout')) {
        throw AuthException(code: 'TIMEOUT', message: 'Connection timed out');
      } else if (e.code != null && e.code! >= 500 && e.code! < 600) {
        throw AuthException(
          code: 'SERVER_ERROR',
          message: 'Server error: ${e.message}',
        );
      } else {
        throw AuthException(
          code: 'NETWORK_ERROR',
          message: 'Network error: ${e.message}',
        );
      }
    } catch (e, stack) {
      // ✅ FIX #3: Log the actual error for debugging
      _logger.e('💥 Unexpected login error: $e');
      _logger.e('🔍 Stack trace: $stack');

      throw AuthException(
        code: 'UNKNOWN_ERROR',
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<void> saveEntreAppTime({required String userId}) async {
    // Optional: validate userId is numeric
    if (!RegExp(r'^\d+$').hasMatch(userId)) {
      _logger.w('⚠️ userId is not numeric: $userId');
    }

    try {
      final response = await _apiClient.post(
        endpoint: 'createEntrey.php',
        data: {'userid': userId},
      );

      final responseData = _parseResponse(response);

      if (responseData['status'] != 'success') {
        final msg = responseData['message'] ?? 'Unknown error';
        _logger.e('❌ Log entry failed: $msg');
        throw ApiException(code: 500, message: msg);
      }

      _logger.i('✅ Entry logged for user ID: $userId');
    } catch (e) {
      _logger.e('💥 Error in saveEntreAppTime: $e');
      rethrow;
    }
  }

  Future<bool> generateOtp({required String userNumber, String? userId}) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'generateOtp.php',
        data: {'phone': userNumber, 'user_id': userId},
      );
      final responseData = _parseResponse(response);

      if (responseData['success'] == true) {
        _logger.i('✅ OTP generated for user ID: $userId');
        return true;
      } else {
        final msg = responseData['message'] ?? 'Unknown error';
        _logger.e('❌ OTP generation failed: $msg');
        throw ApiException(code: 500, message: msg);
      }
    } catch (e) {
      _logger.e('💥 Error in generateOtp: $e');
      rethrow;
    }
  }

  Future<bool> verifyOtp({
    required String userNumber,
    required String userId,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        endpoint: 'verifyOTP.php',
        data: {'phone': userNumber, 'user_id': userId, 'otp': otp},
      );
      final responseData = _parseResponse(response);

      if (responseData['success'] == true) {
        _logger.i('✅ OTP verified successfully for user ID: $userId');
        return true;
      } else {
        final msg =
            responseData['message'] ?? 'Échec de la vérification du code OTP';
        _logger.e('❌ OTP verification failed: $msg');
        throw ApiException(code: 400, message: msg);
      }
    } catch (e) {
      _logger.e('💥 Error in verifyOtp: $e');
      rethrow;
    }
  }

  Future<double> getBalance({required String userOid}) async {
    try {
      _logger.i('💰 Fetching balance for user: $userOid');

      final response = await _apiClient.post(
        endpoint: 'getSolde.php',
        data: {'tpOid': userOid},
      );

      final data = _parseResponse(response);

      if (data['solde'] != null) {
        final balance = double.parse(data['solde'].toString());
        _logger.i('✅ Balance fetched: $balance');
        return balance;
      } else {
        _logger.w('❌ Balance data not found in response');
        throw ApiException(code: 404, message: 'Balance data not found');
      }
    } on ApiException catch (e) {
      _logger.e('💸 GetBalance error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('💸 Unexpected GetBalance error: $e');
      rethrow;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final user = await getCachedUser();
      final isLoggedIn = user != null;
      _logger.i('🔍 User login status: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      _logger.e('❌ Error checking login status: $e');
      return false;
    }
  }

  Future<UserModel?> getCachedUser() async {
    if (_cachedUser != null) {
      _logger.i('📦 Returning cached user');
      return _cachedUser;
    }

    try {
      final prefs = await _prefs;
      final userDataString = prefs.getString('userData');

      if (userDataString != null) {
        _cachedUser = UserModel.fromJson(jsonDecode(userDataString));
        _logger.i('📦 Loaded user from storage: ${_cachedUser?.id}');
        return _cachedUser;
      }

      _logger.i('📦 No cached user found');
      return null;
    } catch (e) {
      _logger.e('❌ Error getting cached user: $e');
      await clearUserData();
      return null;
    }
  }

  Future<void> clearUserData() async {
    try {
      final prefs = await _prefs;
      await prefs.remove('userData');
      await prefs.remove('userId');
      await prefs.remove('cached_user');
      _cachedUser = null;
      _logger.i('🧹 User data cleared successfully');
    } catch (e) {
      _logger.e('❌ Error clearing user data: $e');
      throw ApiException(code: 500, message: 'Failed to clear user data');
    }
  }

  Future<void> updatePassword({
    required String username,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      _logger.i('🔑 Attempting to update password for user: $username');

      // Validate new password length client-side (optional but improves UX)
      if (newPassword.length < 8) {
        throw ApiException(
          code: 400,
          message: 'New password must be at least 8 characters',
        );
      }

      final response = await _apiClient.post(
        endpoint:
            'updatePassword.php', // ← Make sure this matches your actual PHP filename
        data: {
          'username': username.trim(),
          'old_password': oldPassword.trim(),
          'new_password': newPassword.trim(),
        },
      );

      final responseData = _parseResponse(response);

      if (responseData['status'] == 'success') {
        _logger.i('✅ Password updated successfully');
        // Optionally, you could force re-login or clear cached credentials here
        // For now, we just log success
      } else {
        final message = responseData['message'] ?? 'Failed to update password';
        final code = responseData['code'] ?? 400;
        _logger.w('❌ Password update failed: $message');
        throw ApiException(code: code as int?, message: message);
      }
    } on ApiException catch (e) {
      _logger.e(
        '🔌 API Exception during password update: ${e.code} - ${e.message}',
      );
      rethrow;
    } catch (e) {
      _logger.e('💥 Unexpected error during password update: $e');
      throw ApiException(
        code: 500,
        message: 'An unexpected error occurred while updating password',
      );
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    String? username,
    String? email,
    String? viber,
    String? whatsapp,
  }) async {
    _logger.i('✏️ Updating profile for user ID: $userId');

    // ===== VALIDATION =====
    // Validate userid is positive integer
    int parsedUserId;
    try {
      parsedUserId = int.parse(userId);
      if (parsedUserId <= 0) throw FormatException();
    } catch (e) {
      throw ApiException(code: 400, message: 'ID utilisateur invalide');
    }

    // Validate username (if provided AND non-empty)
    if (username != null && username.isNotEmpty) {
      if (username.length < 3 || username.length > 50) {
        throw ApiException(
          code: 400,
          message:
              'Le nom d\'utilisateur doit contenir entre 3 et 50 caractères',
        );
      }
      if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(username)) {
        throw ApiException(
          code: 400,
          message: 'Caractères invalides dans le nom d\'utilisateur',
        );
      }
    }

    // Validate email (if provided AND non-empty)
    if (email != null && email.isNotEmpty) {
      if (!RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(email)) {
        throw ApiException(code: 400, message: 'Adresse e-mail invalide');
      }
    }

    // Phone pattern matching PHP: /^\+?[0-9\s\-\(\)]{7,15}$/
    final phonePattern = RegExp(r'^\+?[0-9\s\-()]{7,15}$');

    // Validate viber (if provided AND non-empty)
    if (viber != null && viber.isNotEmpty && !phonePattern.hasMatch(viber)) {
      throw ApiException(code: 400, message: 'Numéro Viber invalide');
    }

    // Validate whatsapp (if provided AND non-empty)
    if (whatsapp != null &&
        whatsapp.isNotEmpty &&
        !phonePattern.hasMatch(whatsapp)) {
      throw ApiException(code: 400, message: 'Numéro WhatsApp invalide');
    }

    // ===== BUILD REQUEST =====
    final Map<String, dynamic> body = {
      'userid': parsedUserId, // SEND AS INTEGER (critical for PHP validation)
    };

    // Include fields ONLY if explicitly provided (null = skip, empty string = clear field)
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (viber != null) body['viber'] = viber;
    if (whatsapp != null) body['whatsapp'] = whatsapp;

    // ===== SEND REQUEST =====
    try {
      final response = await _apiClient.post(
        endpoint: 'updateUserData.php',
        data: body,
        useJson: true,
      );

      final responseData = _parseResponse(response);

      if (responseData['status'] == 'success') {
        _logger.i('✅ Profile updated successfully');
        return true;
      } else {
        final message =
            responseData['message'] ?? 'Échec de la mise à jour du profil';
        _logger.w('❌ Profile update failed: $message');
        throw ApiException(code: 400, message: message);
      }
    } on ApiException catch (e) {
      _logger.e('🔌 API Exception: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('💥 Unexpected error: $e');
      rethrow;
    }
  }

  // -------------------- PRIVATE METHODS --------------------
  Future<void> _saveUserData(UserModel user) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('userData', jsonEncode(user.toJson()));
      await prefs.setString('userId', user.id);
      _cachedUser = user;
      _logger.i('💾 User data saved successfully');
    } catch (e) {
      _logger.e('❌ Error saving user data: $e');
      throw ApiException(
        code: 500,
        message: 'Failed to save user data locally',
      );
    }
  }

  Map<String, dynamic> _parseResponse(Response response) {
    try {
      if (response.statusCode != 200) {
        String errorMessage =
            'Server responded with status ${response.statusCode}';

        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          errorMessage = data['message'] ?? data['error'] ?? errorMessage;
        } else if (response.data is String) {
          errorMessage = response.data;
        }

        throw ApiException(code: response.statusCode!, message: errorMessage);
      }

      dynamic data = response.data;

      // Handle string responses by parsing JSON
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (e) {
          throw ApiException(
            code: 500,
            message: 'Server returned non-JSON response',
          );
        }
      }

      if (data is! Map<String, dynamic>) {
        throw ApiException(
          code: 500,
          message: 'Invalid server response format',
        );
      }

      return data;
    } on FormatException {
      throw ApiException(code: 500, message: 'Failed to parse server response');
    } catch (e) {
      _logger.e('❌ Response parsing error: $e');
      rethrow;
    }
  }
}
