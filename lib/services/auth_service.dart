import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = "http://192.168.4.1";
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'username';
  
  static String? _currentToken;
  static String? _currentUsername;

  /// Login with username and password, returns JWT token
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey("token")) {
          _currentToken = data["token"];
          _currentUsername = username;
          await _saveTokenToStorage(data["token"], username);
          return {"success": true, "token": data["token"]};
        }
      }
      
      return {
        "success": false, 
        "error": response.statusCode == 200 
          ? (jsonDecode(response.body)["error"] ?? "Login failed")
          : "Network error: ${response.statusCode}"
      };
    } catch (e) {
      return {"success": false, "error": "Connection error: $e"};
    }
  }

  /// Get current JWT token
  static String? getToken() {
    return _currentToken;
  }

  /// Get current username
  static String? getUsername() {
    return _currentUsername;
  }

  /// Check if user is logged in
  static bool isLoggedIn() {
    return _currentToken != null;
  }

  /// Load token from storage on app start
  static Future<void> loadTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    
    if (token != null && username != null) {
      _currentToken = token;
      _currentUsername = username;
    }
  }

  /// Save token to storage
  static Future<void> _saveTokenToStorage(String token, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, username);
  }

  /// Logout and clear token
  static Future<void> logout() async {
    _currentToken = null;
    _currentUsername = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
  }

  /// Get authorization header for API calls
  static Map<String, String> getAuthHeaders() {
    if (_currentToken == null) {
      throw Exception("No authentication token available");
    }
    return {"Authorization": "Bearer $_currentToken"};
  }

  /// Change password
  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/changepassword"),
        headers: {
          "Content-Type": "application/json",
          ...getAuthHeaders(),
        },
        body: jsonEncode({
          "oldpassword": oldPassword,
          "newpassword": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": data["status"] == "Password changed",
          "message": data["status"] ?? data["error"] ?? "Unknown response"
        };
      }
      
      return {
        "success": false,
        "message": "Network error: ${response.statusCode}"
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  /// Factory reset
  static Future<Map<String, dynamic>> factoryReset() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reset"),
        headers: {
          "Content-Type": "application/json",
          ...getAuthHeaders(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": data["status"] == "Factory Reset Done",
          "message": data["status"] ?? "Unknown response"
        };
      }
      
      return {
        "success": false,
        "message": "Network error: ${response.statusCode}"
      };
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }
}
