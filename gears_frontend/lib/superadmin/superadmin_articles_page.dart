// --------------------------------------------------------------
// SUPERADMIN ARTICLES PAGE — FINAL CLEAN VERSION
// Filename: superadmin_articles_page.dart
// --------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

import 'package:gears_frontend/superadmin/superadmin_article_preview_page.dart';
import 'package:gears_frontend/superadmin/superadmin_category_management_page.dart';
import 'package:gears_frontend/widgets/superadmin_nav.dart';

class SuperAdminArticlesPage extends StatefulWidget {
  final String email;

  const SuperAdminArticlesPage({
    super.key,
    required this.email,
  });

  @override
  State<SuperAdminArticlesPage> createState() => _SuperAdminArticlesPageState();
}

class _SuperAdminArticlesPageState extends State<SuperAdminArticlesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> articles = [];
  bool isLoading = true;

  // Counts
  int pendingCount = 0;
  int revisionCount = 0;
  int publishedCount = 0;

  // Filters
  String searchQuery = "";
  String sortOption = "Newest";

  // Bottom nav index
  int currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // FETCH ARTICLES
  // ----------------------------------------------------------
  Future<void> _fetchArticles() async {
  setState(() => isLoading = true);
  try {
    final res = await http.get(Uri.parse("$baseUrl/get-articles"));
    if (res.statusCode == 200) {
      final rawList = jsonDecode(res.body) as List;

      // ✅ Mutable maps
      final parsed = rawList
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();

      setState(() {
        articles = parsed;

        // ✅ "pending" hindi "submitted"
        pendingCount =
            parsed.where((a) => a["status"] == "pending").length;
        revisionCount =
            parsed.where((a) => a["status"] == "needs_revision").length;
        publishedCount =
            parsed.where((a) =>
                a["status"] == "approved" || a["status"] == "published").length;
      });
    }
  } catch (e) {
    debugPrint("Error fetching articles: $e");
  }
  setState(() => isLoading = false);
}
  // ----------------------------------------------------------
  // APPLY SEARCH + SORT
  // ----------------------------------------------------------
  List<dynamic> _applyFilters(List<dynamic> list) {
    List<dynamic> filtered = list;

    // Search filter
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();

      filtered = filtered.where((a) {
        final h = (a["headline"] ?? "").toString().toLowerCase();
        final c = (a["category"] ?? "").toString().toLowerCase();
        final author = (a["author_name"] ?? "").toString().toLowerCase();
        return h.contains(q) || c.contains(q) || author.contains(q);
      }).toList();
    }

    // Sorting
    switch (sortOption) {
      case "Newest":
        filtered.sort((a, b) =>
            b["updated_at"].toString().compareTo(a["updated_at"].toString()));
        break;

      case "Oldest":
        filtered.sort((a, b) =>
            a["updated_at"].toString().compareTo(b["updated_at"].toString()));
        break;

      case "A–Z":
        filtered.sort((a, b) =>
            a["headline"].toString().compareTo(b["headline"].toString()));
        break;

      case "Z–A":
        filtered.sort((a, b) =>
            b["headline"].toString().compareTo(a["headline"].toString()));
        break;

      case "Category":
        filtered.sort((a, b) =>
            a["category"].toString().compareTo(b["category"].toString()));
        break;

      case "Status":
        filtered.sort((a, b) =>
            a["status"].toString().compareTo(b["status"].toString()));
        break;
    }

    return filtered;
  }

  // ----------------------------------------------------------
  // FILTERED TABS
  // ----------------------------------------------------------
  List<dynamic> get pendingArticles =>
    _applyFilters(articles.where((a) => a["status"] == "pending").toList());

List<dynamic> get revisionArticles =>
    _applyFilters(articles.where((a) => a["status"] == "needs_revision").toList());

List<dynamic> get publishedArticles =>
    _applyFilters(articles.where((a) =>
        a["status"] == "approved" || a["status"] == "published").toList());

  // ----------------------------------------------------------
  // TOP TOOLBAR: Search + Sort + Categories
  // ----------------------------------------------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          // SEARCH
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.lightCardShadow,
            ),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: const InputDecoration(
                hintText: "Search articles...",
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              // SORT DROPDOWN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.lightCardShadow,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: sortOption,
                      items: [
                        "Newest",
                        "Oldest",
                        "A–Z",
                        "Z–A",
                        "Category",
                        "Status"
                      ]
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => sortOption = v!),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // CATEGORY BUTTON
              ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryManagementPage(
          email: widget.email, // ✅ siguruhing hindi null ito
        ),
      ),
    );
  },
                icon: const Icon(Icons.category, color: Colors.white),
                label: Text(
                  "Categories",
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // ARTICLE LIST
  // ----------------------------------------------------------
  Widget _buildArticleList(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text("No articles found",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600)),
            Text("Try adjusting your filters",
                style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildArticleCard(items[i]),
    );
  }

  // ----------------------------------------------------------
  // ARTICLE CARD
  // ----------------------------------------------------------
  Widget _buildArticleCard(dynamic article) {
    final authorName = article["author_name"] ?? "Unknown";
    final headline = article["headline"] ?? "Untitled";
    final category = article["category"] ?? "Uncategorized";
    final content = article["content"] ?? "";
    final status = article["status"] ?? "submitted";

    // -------------------------------
// MEDIA PREVIEW (use first thumb)
// -------------------------------
// MEDIA
List media = [];
try {
  final rawMedia = article["media"];
  if (rawMedia is List) {
    media = rawMedia.map((m) {
      if (m is Map) return Map<String, dynamic>.from(m);
      if (m is String && m.isNotEmpty) {
        return {"url": m, "thumbnail": m, "type": "image"};
      }
      return null;
    }).where((e) => e != null).toList();
  }
} catch (_) {}

String thumbnail = "";
String thumbType = "image";

if (media.isNotEmpty) {
  final first = media.first;
  if (first is Map) {
    thumbnail = first["thumbnail"]?.toString() ?? first["url"]?.toString() ?? "";
    thumbType = first["type"]?.toString() ?? "image";
  } else if (first is String) {
    thumbnail = first;
  }
}

final isVideo = thumbType == "video" ||
    thumbnail.toLowerCase().endsWith(".mp4") ||
    thumbnail.toLowerCase().endsWith(".mov");

    Color borderColor = Colors.blue;
    IconData icon = Icons.hourglass_empty;

    switch (status) {
  case "pending":       // ✅ hindi "submitted"
    borderColor = Colors.blue;
    icon = Icons.hourglass_empty;
    break;
  case "needs_revision":
    borderColor = Colors.orange;
    icon = Icons.edit_note;
    break;
  case "approved":      // ✅ dagdag
  case "published":
    borderColor = Colors.green;
    icon = Icons.check_circle;
    break;
}

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SuperAdminArticlePreviewPage(
              articleId: article["id"],
              
              showActions: status != "approved" && status != "published", // ✅ dalawa na
            ),
          ),
        ).then((_) => _fetchArticles());
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor.withOpacity(0.35), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppTheme.categorySelectedGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: borderColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: borderColor),
                        const SizedBox(width: 5),
                        Text(
                          status.toUpperCase().replaceAll("_", " "),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: borderColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // -------------------------------
// MEDIA PREVIEW THUMBNAIL
// -------------------------------
if (thumbnail.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: isVideo
        ? Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                color: Colors.black87,
              ),
              const Icon(
                Icons.play_circle_fill,
                size: 48,
                color: Colors.white,
              ),
            ],
          )
        : Image.network(
            thumbnail,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: Colors.black12,
              child: const Icon(Icons.broken_image, size: 40),
            ),
          ),
  ),
const SizedBox(height: 10),
// Headline
              Text(
                headline,
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Author
              Row(
                children: [
                  Icon(Icons.person,
                      color: AppTheme.primaryOrange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    authorName,
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Snippet
              Text(
                content.length > 180
                    ? "${content.substring(0, 180)}..."
                    : content,
                style: GoogleFonts.poppins(color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // MAIN BUILD
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: AppTheme.titleGradient)),
        title: Text(
          "Review Articles",
          style:
              GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          _buildToolbar(),

          // TAB BAR
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryOrange,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryOrange,
              tabs: [
                _tab("Pending", pendingCount, Colors.blue),
                _tab("Revisions", revisionCount, Colors.orange),
                _tab("Published", publishedCount, Colors.green),
              ],
            ),
          ),

          // TAB CONTENT
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchArticles,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildArticleList(pendingArticles),
                        _buildArticleList(revisionArticles),
                        _buildArticleList(publishedArticles),
                      ],
                    ),
                  ),
          ),
        ],
      ),

      bottomNavigationBar: SuperAdminNav(
        currentIndex: currentIndex,
        role: "superadmin",
        onTap: (i) {
          setState(() => currentIndex = i);

          Navigator.pushReplacementNamed(
            context,
            i == 0
                ? "/dashboard-superadmin"
                : i == 1
                    ? "/articles-superadmin"
                    : i == 2
                        ? "/users-superadmin"
                        : "/profile-superadmin",
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // TAB WIDGET
  // ----------------------------------------------------------
  Widget _tab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                "$count",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
