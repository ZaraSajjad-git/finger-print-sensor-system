import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class FingerprintService {
  static const String baseUrl = "http://192.168.4.1";

  // ✅ Add User API
  static Future<bool> addUser(String name) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/add"),
        headers: {
          "Content-Type": "application/json",
          ...AuthService.getAuthHeaders(),
        },
        body: jsonEncode({"name": name}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["status"] == "success";
      }
      return false;
    } catch (e) {
      print("Add User Error: $e");
      return false;
    }
  }



  // ✅ Get/List Users API
  static Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/list"),
        headers: AuthService.getAuthHeaders(),
      );

      print("GET /list status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both array format and object with users property
        if (data is List) {
          return List<Map<String, dynamic>>.from(
            data.map((item) => Map<String, dynamic>.from(item)),
          );
        } else if (data["users"] is List) {
          return List<Map<String, dynamic>>.from(
            (data["users"] as List).map((item) => Map<String, dynamic>.from(item)),
          );
        } else {
          print("Unexpected data format: $data");
        }
      } else {
        print("Failed to load users. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error in getUsers: $e");
    }
    return [];
  }

  // ✅ Delete User API (POST method)
  static Future<bool> deleteUser(dynamic id) async {
    try {
      // Check if user is logged in first
      if (!AuthService.isLoggedIn()) {
        print("Error: User not logged in. Cannot delete user.");
        return false;
      }

      // Convert id to int if it's a string
      int userId;
      if (id is String) {
        userId = int.tryParse(id) ?? 0;
        if (userId == 0) {
          print("Error: Invalid user ID format: $id");
          return false;
        }
      } else if (id is int) {
        userId = id;
      } else {
        print("Error: User ID must be int or string, got: ${id.runtimeType}");
        return false;
      }

      final url = Uri.parse("$baseUrl/delete");
      final body = jsonEncode({"id": userId});

      final authHeaders = AuthService.getAuthHeaders();
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        ...authHeaders,
      };

      print("=== DELETE USER DEBUG START ===");
      print("Endpoint: $url");
      print("HTTP Method: POST");
      print("Headers: $headers");
      print("Request Body: $body");
      print("User ID (converted): $userId");
      print("================================");

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("Decoded Response: $data");

        if (data["status"] == "success" || 
            (data["message"]?.toString().toLowerCase() == "success") ||
            data["success"] == true) {
          print("User deleted successfully!");
          return true;
        } else {
          print("API responded but deletion not confirmed. Response: $data");
        }
      } else {
        print("Delete request failed with status: ${response.statusCode}");
        print("Error response: ${response.body}");
      }

      return false;
    } catch (e) {
      print("Exception during deleteUser API call: $e");
      return false;
    }
  }
}
