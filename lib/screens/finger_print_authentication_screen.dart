import 'package:finger_print_sensor/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../admin_panel/fingerprint_service.dart';
import 'login_screen.dart';

class FingerPrintAuthenticationScreen extends StatefulWidget {
  const FingerPrintAuthenticationScreen({super.key});

  @override
  State<FingerPrintAuthenticationScreen> createState() =>
      _FingerPrintAuthenticationScreenState();
}

class _FingerPrintAuthenticationScreenState
    extends State<FingerPrintAuthenticationScreen> {
  List<Map<String, String>> users = [];
  String searchQuery = "";
  final TextEditingController _nameController = TextEditingController();

  // Your ESP32 device IP
  final String baseUrl = "http://192.168.4.1";

  @override
  void initState() {
    super.initState();
    _loadUsersFromAPI();
  }

  /// Fetch user list from ESP32 using List API
  Future<void> _loadUsersFromAPI({bool showFeedback = false}) async {
    if (showFeedback) {
      // Show loading indicator in app bar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text("Refreshing user list..."),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      // Use FingerprintService for consistent API calls
      final userList = await FingerprintService.getUsers();
      
      if (userList.isNotEmpty) {
        setState(() {
          users = userList
              .map((e) => {
            "name": e['name'].toString(),
            "id": e['id'].toString(),
          })
              .toList();
        });
        await _saveUsers(); // also save locally
        
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Refreshed! Found ${users.length} users"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        debugPrint('No users returned from API');
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No users found on device"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _loadUsersFromLocal(); // fallback to local if API fails
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      _loadUsersFromLocal(); // fallback to local if no connection
    }
  }

  /// Load users from SharedPreferences (local fallback)
  Future<void> _loadUsersFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedUsers = prefs.getString('users');
    if (storedUsers != null) {
      setState(() {
        users = List<Map<String, String>>.from(
            jsonDecode(storedUsers).map((e) => Map<String, String>.from(e)));
      });
    }
  }

  /// Save users to SharedPreferences
  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users', jsonEncode(users));
  }

  /// Add new user dialog
  void _addUserDialog() {
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Add User"),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Enter Name"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel",style: TextStyle(color: AppColors.red),),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundEnd),
              child: const Text("Next → Authenticate",style: TextStyle(color: AppColors.white),),
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _authenticateFingerprint(_nameController.text);
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Authenticate fingerprint and call Add API
  void _authenticateFingerprint(String name) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Fingerprint Authentication"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.fingerprint, size: 80, color: Colors.blue),
              SizedBox(height: 10),
              Text("Waiting for fingerprint authentication..."),
            ],
          ),
        );
      },
    );

    try {
      // Call Add API
      final url = Uri.parse('$baseUrl/add');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          ...AuthService.getAuthHeaders(),
        },
        body: jsonEncode({"name": name}),
      );

      Navigator.pop(context); // close waiting dialog

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // Add user to list (from API response)
          setState(() {
            users.add({
              "name": name,
              "id": data['id'].toString(),
            });
          });
          await _saveUsers();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "User Added Successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Failed to add user.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.statusCode}")),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Error: $e")),
      );
    }
  }

  /// Confirm remove/deletion
  void _confirmRemove(int index) {
    final userToDelete = users[index];
    final userId = int.tryParse(userToDelete["id"] ?? "");
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid user ID")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Remove User"),
          content: Text("Do you want to remove ${userToDelete["name"]}?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () async {
                Navigator.pop(context); // Close dialog first
                await _deleteUser(index, userId, userToDelete["name"] ?? "User");
              },
              child: const Text("Delete",style: TextStyle(color: AppColors.white),),
            ),
          ],
        );
      },
    );
  }

  /// Delete user from both API and local storage
  Future<void> _deleteUser(int index, int userId, String userName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Deleting User"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Deleting user from device..."),
            ],
          ),
        );
      },
    );

    try {
      // Use FingerprintService for consistent API calls
      final success = await FingerprintService.deleteUser(userId);
      
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Remove from local list only after successful API deletion
        setState(() {
          users.removeAt(index);
        });
        await _saveUsers();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${userName} deleted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete ${userName} from device"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Editable cell widget
  Widget editableCell({
    required String value,
    required Function(String) onChanged,
  }) {
    final controller = TextEditingController(text: value);
    return TextField(
      controller: controller,
      decoration: const InputDecoration(border: InputBorder.none),
      style: const TextStyle(fontSize: 14),
      onSubmitted: (newValue) async {
        onChanged(newValue);
        await _saveUsers();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = users
        .where((user) =>
    user["name"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
        user["id"]!.contains(searchQuery))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fingerprint Authentication"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUsersFromAPI(showFeedback: true), // Refresh list from API with feedback
            tooltip: "Refresh user list from device",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search + Add button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "Search user by name or ID...",
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundEnd),
                  onPressed: _addUserDialog,
                  icon: const Icon(Icons.add,color: AppColors.white,),
                  label: const Text("Add",style: TextStyle(color:AppColors.white),),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Table Header
            Container(
              color: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                children: const [
                  Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Remove", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Scrollable Data Rows
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final actualIndex = users.indexOf(filteredUsers[index]);
                    return Container(
                      color: index % 2 == 0
                          ? Colors.grey.shade100
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text("${index + 1}")),
                          Expanded(
                            flex: 3,
                            child: editableCell(
                              value: filteredUsers[index]["name"]!,
                              onChanged: (val) {
                                setState(() {
                                  users[actualIndex]["name"] = val;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: editableCell(
                              value: filteredUsers[index]["id"]!,
                              onChanged: (val) {
                                setState(() {
                                  users[actualIndex]["id"] = val;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () => _confirmRemove(actualIndex),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
