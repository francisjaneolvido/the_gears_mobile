import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/utils/notifications/app_toastification.dart';

class CategoryManagementPage extends StatefulWidget {
  final String email;

  const CategoryManagementPage({super.key, required this.email});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  List<dynamic> categories = [];
  bool isLoading = true;

  final List<Color> availableColors = [
    const Color(0xFFFF6B35), // Orange
    const Color(0xFF4285F4), // Blue
    const Color(0xFF34A853), // Green
    const Color(0xFFEA4335), // Red
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF795548), // Brown
    const Color(0xFFFBBC04), // Yellow
    const Color(0xFFE91E63), // Pink
    const Color(0xFFFF5722), // Deep Orange
  ];

  final Map<String, IconData> availableIcons = {
    'home': Icons.home,
    'newspaper': Icons.newspaper,
    'update': Icons.update,
    'forum': Icons.forum,
    'star': Icons.star,
    'book': Icons.book,
    'auto_stories': Icons.auto_stories,
    'palette': Icons.palette,
    'photo_library': Icons.photo_library,
    'video_library': Icons.video_library,
    'article': Icons.article,
    'campaign': Icons.campaign,
    'sports': Icons.sports_soccer,
    'science': Icons.science,
    'business': Icons.business,
    'local_library': Icons.local_library,
    'brush': Icons.brush,
    'photo_camera': Icons.photo_camera,
    'videocam': Icons.videocam,
    'mic': Icons.mic,
    'podcast': Icons.podcasts,
  };

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => isLoading = true);

    try {
      final res = await http.get(Uri.parse('$baseUrl/get-categories'));
      if (res.statusCode == 200) {
        setState(() {
          categories = jsonDecode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        AppToastification.error(context, "Error loading categories");
      }
    }
  }

  Future<void> _addCategory(String name, String icon, Color color) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/add-category'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "admin_email": widget.email,
          "name": name,
          "icon": icon,
          "color": '#${color.value.toRadixString(16).substring(2)}',
        }),
      );

      if (res.statusCode == 200) {
        AppToastification.success(context, "✅ Category added successfully!");
        _fetchCategories();
      } else {
        final error = jsonDecode(res.body)['message'];
        AppToastification.error(context, error);
      }
    } catch (e) {
      AppToastification.error(context, "Error: $e");
    }
  }

  Future<void> _deleteCategory(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Delete Category?",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '$name'? This cannot be undone.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/delete-category/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"admin_email": widget.email}),
      );

      if (res.statusCode == 200) {
        AppToastification.success(context, "✅ Category deleted");
        _fetchCategories();
      } else {
        final error = jsonDecode(res.body)['message'];
        AppToastification.error(context, error);
      }
    } catch (e) {
      AppToastification.error(context, "Error: $e");
    }
  }

Future<void> _onReorder(int oldIndex, int newIndex) async {
  setState(() {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);
  });

  final orderedIds = categories.map((c) => c['id']).toList();

  final res = await http.post(
    Uri.parse('$baseUrl/reorder-categories'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "admin_email": widget.email,
      "category_ids": orderedIds,
    }),
  );

  if (res.statusCode == 200) {
    AppToastification.success(context, "Order updated");
  } else {
    AppToastification.error(context, "Failed to save order");
  }
}

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedIcon = 'article';
    Color selectedColor = availableColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.titleGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_circle, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Add New Category",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Category Name",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "e.g., Layout, Editorial, Sports",
                    hintStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Select Icon",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: availableIcons.entries.map((entry) {
                        final isSelected = selectedIcon == entry.key;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedIcon = entry.key);
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryOrange
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryOrange
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              entry.value,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                              size: 24,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Select Color",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableColors.map((color) {
                    final isSelected = selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedColor = color);
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  AppToastification.warning(context, "Please enter category name");
                  return;
                }
                Navigator.pop(context);
                _addCategory(name, selectedIcon, selectedColor);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                "Add Category",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showEditCategoryDialog(Map<String, dynamic> category) {
  final nameController = TextEditingController(text: category["name"]);

  String selectedIcon = category["icon"];
  Color selectedColor = Color(
    int.parse(category["color"].replaceFirst('#', '0xFF')),
  );

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.titleGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text("Edit Category",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Category Name",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text("Select Icon",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                children: availableIcons.entries.map((entry) {
                  final isSelected = selectedIcon == entry.key;
                  return GestureDetector(
                    onTap: () {
                      setStateDialog(() => selectedIcon = entry.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryOrange
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(entry.value,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade700),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              Text("Select Color",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 12,
                children: availableColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedColor = color),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        actions: [
          TextButton(
            child: Text("Cancel",
                style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
            child: Text("Save",
                style: GoogleFonts.poppins(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _updateCategory(
                category['id'],
                nameController.text.trim(),
                selectedIcon,
                selectedColor,
              );
            },
          ),
        ],
      ),
    ),
  );
}
Future<void> _updateCategory(int id, String name, String icon, Color color) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/update-category/$id'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "admin_email": widget.email,
        "name": name,
        "icon": icon,
        "color": '#${color.value.toRadixString(16).substring(2)}',
      }),
    );

    if (res.statusCode == 200) {
      AppToastification.success(context, "Category updated!");
      _fetchCategories();
    } else {
      AppToastification.error(
        context,
        jsonDecode(res.body)['message'],
      );
    }
  } catch (e) {
    AppToastification.error(context, "Error: $e");
  }
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.backgroundLight,
    appBar: AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppTheme.titleGradient),
      ),
      title: Text(
        "Manage Categories",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),

    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchCategories,
            child: categories.isEmpty
                ? _buildEmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: categories.length,
                    buildDefaultDragHandles: false,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
  final category = categories[index];
  return Container(
    key: ValueKey(category['id']),
    child: _buildCategoryCard(category, index),
  );
},

                  ),
          ),

    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showAddCategoryDialog,
      backgroundColor: AppTheme.primaryOrange,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        "Add Category",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

Widget _buildCategoryCard(dynamic category, int index) {
  final name = category['name'];
  final icon = category['icon'] ?? 'article';
  final colorHex = category['color'] ?? '#FF6B35';
  final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    margin: const EdgeInsets.only(bottom: 14),
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _showEditCategoryDialog(category),

        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
            const SizedBox(width: 8),

            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                availableIcons[icon] ?? Icons.article,
                color: color,
                size: 26,
              ),
            ),
          ],
        ),

        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),

        trailing: name != "Home"
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteCategory(category['id'], name),
              )
            : null,
      ),
    ),
  );
}




 Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.category_outlined,
            size: 70,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "No categories yet",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Tap the button below to add your first category.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  );
}
}