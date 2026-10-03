import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/bottom_nav.dart';
import 'articledetail_page.dart';

class BookmarkPage extends StatefulWidget {
  final String? email;
  final int? userId;

  const BookmarkPage({super.key, this.email, this.userId});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  final int _bottomNavIndex = 2;

  List<Map<String, dynamic>> bookmarkedArticles = [];
  List<Map<String, dynamic>> filteredArticles = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = "All";
  String _sortMode = "Newest";

  bool _isGrid = false;
  bool _multiSelect = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------ MEDIA URL FIX ------------------------------
  String buildMediaUrl(String filename) {
    if (filename.startsWith("http://") || filename.startsWith("https://")) {
      return filename;
    }
    return "$baseUrl/uploads/$filename";
  }

  // ------------------------------ LOAD BOOKMARKS ------------------------------
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList("bookmarkedArticles");

    if (saved != null) {
      bookmarkedArticles = saved
          .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
          .toList();
    }

    _sortBookmarks();
    filteredArticles = [...bookmarkedArticles];

    setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        bookmarkedArticles.map((a) => jsonEncode(a)).toList();
    await prefs.setStringList("bookmarkedArticles", encoded);
  }

  // ------------------------------ FILTERING + SORTING ------------------------------
  void _sortBookmarks() {
    bookmarkedArticles.sort((a, b) {
      DateTime da = DateTime.tryParse(a["created_at"] ?? "") ?? DateTime(2000);
      DateTime db = DateTime.tryParse(b["created_at"] ?? "") ?? DateTime(2000);

      if (_sortMode == "Newest") return db.compareTo(da);
      if (_sortMode == "Oldest") return da.compareTo(db);

      return (a["category"] ?? "").compareTo(b["category"] ?? "");
    });
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();

    filteredArticles = bookmarkedArticles.where((a) {
      final headline = (a["headline"] ?? "").toString().toLowerCase();
      final author = (a["author_name"] ?? "").toString().toLowerCase();
      final content = (a["content"] ?? "").toString().toLowerCase();
      final category = (a["category"] ?? "").toString().toLowerCase();

      final matchText =
          headline.contains(q) || author.contains(q) || content.contains(q);

      final matchCat =
          _selectedCategory == "All" ||
              category == _selectedCategory.toLowerCase();

      return matchText && matchCat;
    }).toList();

    setState(() {});
  }

  // ------------------------------ REMOVE BOOKMARK ------------------------------
  void _removeBookmark(int id) async {
    bookmarkedArticles.removeWhere((a) => a["id"] == id);
    filteredArticles.removeWhere((a) => a["id"] == id);

    await _saveBookmarks();
    setState(() {});
  }

  void _removeMultiple() async {
    bookmarkedArticles.removeWhere((a) => _selectedIds.contains(a["id"]));
    filteredArticles.removeWhere((a) => _selectedIds.contains(a["id"]));
    _selectedIds.clear();
    _multiSelect = false;

    await _saveBookmarks();
    setState(() {});
  }

  // ------------------------------ CATEGORIES ------------------------------
  List<String> _getCategories() {
    final cats = bookmarkedArticles
        .map((a) => (a["category"] ?? "").toString())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    cats.insert(0, "All");
    return cats;
  }

  // ------------------------------ UI ------------------------------
  @override
  Widget build(BuildContext context) {
    final categories = _getCategories();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      // ==================== APP BAR ====================
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Text(
          "Saved Articles",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
       
        
      ),

      // ==================== MASS DELETE BUTTON ====================
      floatingActionButton: _multiSelect && _selectedIds.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppTheme.primaryRed,
              child: const Icon(Icons.delete, color: Colors.white),
              onPressed: _removeMultiple,
            )
          : null,

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==================== SEARCH ====================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: _buildSearchBar(),
          ),

          // ==================== CATEGORY FILTER ====================
          if (categories.length > 1)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final selected = _selectedCategory == cat;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _applyFilters();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                              )
                            : null,
                        color: selected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: selected
                              ? Colors.transparent
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          color:
                              selected ? Colors.white : AppTheme.textDark,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          Expanded(
            child: filteredArticles.isEmpty
                ? _buildEmptyState()
                : _isGrid
                    ? _buildGridView()
                    : _buildListView(),
          ),
        ],
      ),

      bottomNavigationBar: BottomNav(
        currentIndex: _bottomNavIndex,
        userId: widget.userId,
        email: widget.email,
      ),
    );
  }

  // ------------------------------ SEARCH BAR ------------------------------
  Widget _buildSearchBar() {
    return Column(
  children: [
    // SEARCH BAR
    Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search bookmarks...",
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryOrange),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 14),
        ),
      ),
    ),

    const SizedBox(height: 8),

    // SORT + GRID + MULTI BUTTONS (RIGHT SIDE)
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.sort, color: AppTheme.primaryOrange),
          onPressed: _showSortSheet,
        ),
        IconButton(
          icon: Icon(
            _isGrid ? Icons.grid_view : Icons.view_agenda,
            color: AppTheme.primaryOrange,
          ),
          onPressed: () => setState(() => _isGrid = !_isGrid),
        ),
        IconButton(
          icon: Icon(
            _multiSelect ? Icons.close : Icons.checklist,
            color: AppTheme.primaryOrange,
          ),
          onPressed: () {
            setState(() {
              _multiSelect = !_multiSelect;
              _selectedIds.clear();
            });
          },
        ),
      ],
    ),
  ],
);

  }

  // ------------------------------ SORT MODAL ------------------------------
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption("Newest"),
            _buildSortOption("Oldest"),
            _buildSortOption("Category"),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String mode) {
    return ListTile(
      title: Text(
        mode,
        style: GoogleFonts.poppins(),
      ),
      trailing:
          _sortMode == mode ? const Icon(Icons.check, color: AppTheme.primaryRed) : null,
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortMode = mode;
          _sortBookmarks();
          _applyFilters();
        });
      },
    );
  }

  // ------------------------------ EMPTY STATE ------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Text(
        "No saved articles",
        style: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
    );
  }

  // ------------------------------ LIST VIEW (SLIDE TO DELETE) ------------------------------
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredArticles.length,
      itemBuilder: (context, index) {
        final article = filteredArticles[index];
        final id = article["id"];

        return Slidable(
          key: ValueKey(id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => _removeBookmark(id),
                backgroundColor: AppTheme.primaryRed,
                icon: Icons.delete,
                foregroundColor: Colors.white,
              ),
            ],
          ),
          child: _buildCard(article),
        );
      },
    );
  }

  // ------------------------------ GRID VIEW ------------------------------
  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        itemCount: filteredArticles.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          final article = filteredArticles[index];
          final id = article["id"];

          return Stack(
            children: [
              _buildCard(article),

              // DELETE BUTTON
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _removeBookmark(id),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primaryRed,
                    radius: 18,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                ),
              ),

              // MULTI SELECT CHECKMARK
              if (_multiSelect)
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedIds.contains(id)) {
                          _selectedIds.remove(id);
                        } else {
                          _selectedIds.add(id);
                        }
                      });
                    },
                    child: CircleAvatar(
                      backgroundColor:
                          _selectedIds.contains(id) ? AppTheme.primaryRed : Colors.white,
                      radius: 18,
                      child: Icon(
                        _selectedIds.contains(id)
                            ? Icons.check
                            : Icons.circle_outlined,
                        color: _selectedIds.contains(id)
                            ? Colors.white
                            : AppTheme.primaryRed,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------ CARD (LIST + GRID) ------------------------------
  Widget _buildCard(Map<String, dynamic> article) {
  List<String> media = [];

  // --- FIXED MEDIA PARSING ---
  try {
    if (article["media"] is List) {
      media = (article["media"] as List)
          .map((e) => e is Map<String, dynamic>
              ? (e["thumbnail"] ?? e["url"] ?? "").toString()
              : e.toString())
          .toList();
    } else if (article["media"] is String) {
      final decoded = jsonDecode(article["media"]);
      if (decoded is List) {
        media = decoded
            .map((e) => e is Map<String, dynamic>
                ? (e["thumbnail"] ?? e["url"] ?? "").toString()
                : e.toString())
            .toList();
      }
    }
  } catch (_) {}

  final first = media.isNotEmpty ? buildMediaUrl(media.first) : null;

  // --- DATE ---
  final createdAt = article["created_at"] ?? "";
  String formatted = "Saved date unknown";
  try {
    final d = DateTime.parse(createdAt);
    formatted = "Saved on ${d.day}/${d.month}/${d.year}";
  } catch (_) {}

  return GestureDetector(
    onLongPress: () {
      setState(() {
        _multiSelect = true;
        _selectedIds.add(article["id"]);
      });
    },
    onTap: () {
      if (_multiSelect) {
        setState(() {
          if (_selectedIds.contains(article["id"])) {
            _selectedIds.remove(article["id"]);
          } else {
            _selectedIds.add(article["id"]);
          }
        });
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleDetailPage(
              article: article,
              userId: widget.userId,
            ),
          ),
        );
      }
    },
    child: Hero(
      tag: "article_${article["id"]}",
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // THUMBNAIL
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: first != null && first.trim().isNotEmpty
                  ? Image.network(
                      first,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 140,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                    )
                  : Container(
                      height: 140,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 40),
                    ),
            ),

            // TEXT
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article["headline"] ?? "Untitled",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "By ${article["author_name"] ?? "Unknown"}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatted,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}