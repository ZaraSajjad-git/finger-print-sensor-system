import 'package:flutter/material.dart';
import 'fingerprint_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = false;
  bool isAdding = false;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final data = await FingerprintService.getUsers();
      setState(() {
        users = data;
        filteredUsers = data;
      });
      // Ensure scroll calculations happen after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    } catch (_) {
      setState(() {
        users = [];
        filteredUsers = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredUsers = users;
        isSearching = false;
      } else {
        isSearching = true;
        filteredUsers = users.where((user) {
          final name = (user["name"] ?? "").toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addUser() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    setState(() => isAdding = true);

    final success = await FingerprintService.addUser(name);

    setState(() => isAdding = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User added successfully!")),
      );
      nameController.clear();
      await _fetchUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add user.")),
      );
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User"),
        content: const Text("Are you sure you want to delete this user?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FingerprintService.deleteUser(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User deleted successfully!")),
        );
        await _fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete user.")),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildUserList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (users.isEmpty) return const Center(child: Text("No users found"));

    final hasSearchQuery = searchController.text.trim().isNotEmpty;
    if (hasSearchQuery && filteredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No such user exists",
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text("Try searching with a different name",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 120), // leave space for the floating button
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: Text(user["name"] ?? "Unknown"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteUser(user["id"]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding so button sits above keyboard if present
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final fabPadding = bottomInset > 0 ? bottomInset + 16.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: SafeArea(
        child: Stack(
          children: [
            // Main column content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Add New User",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration:
                          const InputDecoration(labelText: "Enter name"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isAdding ? null : _addUser,
                        child: isAdding
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text("Add"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Search Users",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    onChanged: (_) => _filterUsers(),
                    decoration: InputDecoration(
                      hintText: "Search by name...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _filterUsers();
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Registered Users",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Expanded list
                  Expanded(child: _buildUserList()),
                ],
              ),
            ),

            // Positioned floating button — placed inside body to guarantee visibility
            Positioned(
              right: 16,
              bottom: fabPadding,
              child: Material(
                // Use Material to get elevation/shadow and ripple
                color: Colors.transparent,
                child: FloatingActionButton(
                  onPressed: _scrollToBottom,
                  tooltip: "Scroll to bottom",
                  backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor ?? Colors.blue,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
