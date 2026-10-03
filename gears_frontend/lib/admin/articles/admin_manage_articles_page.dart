// --------------------------------------------------------------
// AdminManageArticlesPage — Modern Minimalist (Updated for Trash + Restore)
// --------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;


import 'package:gears_frontend/admin/articles/preview_page.dart';
import 'package:gears_frontend/admin/articles/create_article_page.dart';
import 'package:gears_frontend/admin/articles/revision_page.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/video_player_widget.dart';

class AdminManageArticlesPage extends StatefulWidget {
  final String authorEmail;

  const AdminManageArticlesPage({super.key, required this.authorEmail});

  @override
  State<AdminManageArticlesPage> createState() =>
      _AdminManageArticlesPageState();
}

class _AdminManageArticlesPageState extends State<AdminManageArticlesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> allArticles = [];
  String searchQuery = "";
  String sortOption = "Newest";
  bool isLoading = true;

  int draftCount = 0;
  int submittedCount = 0;
  int needsRevisionCount = 0;
  int publishedCount = 0;
  int deletedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    fetchMyArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // FETCH ARTICLES
  // --------------------------------------------------------------
  Future<void> fetchMyArticles() async {
  setState(() => isLoading = true);

  try {
    final res = await http.get(
      Uri.parse("$baseUrl/get-my-articles/${widget.authorEmail}"),
    );

    if (res.statusCode == 200) {
      final rawList = jsonDecode(res.body) as List;

      // ✅ I-convert muna sa List<Map> para mutable
      final List<Map<String, dynamic>> parsed = rawList
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();

      // ✅ Fix media sa bawat article
      for (var a in parsed) {
        final rawMedia = a["media"];
        if (rawMedia is List) {
          a["media"] = rawMedia.map((m) {
            if (m is Map) return Map<String, dynamic>.from(m);
            if (m is String && m.isNotEmpty) {
              return {"url": m, "thumbnail": m, "type": "image"};
            }
            return null;
          }).where((e) => e != null).toList();
        } else {
          a["media"] = [];
        }
      }

      setState(() {
        allArticles = parsed;

        draftCount = parsed
            .where((a) => a["status"] == "draft" && a["is_deleted"] != true)
            .length;

        submittedCount = parsed
            .where((a) => a["status"] == "pending" && a["is_deleted"] != true)
            .length;

        needsRevisionCount = parsed
            .where((a) => a["status"] == "needs_revision" && a["is_deleted"] != true)
            .length;

        publishedCount = parsed
            .where((a) =>
                (a["status"] == "approved" || a["status"] == "published") &&
                a["is_deleted"] != true)
            .length;

        deletedCount = parsed
            .where((a) => a["is_deleted"] == true)
            .length;
      });
    } else {
      _showSnack("Server error: ${res.statusCode}", true);
    }
  } catch (e) {
    _showSnack("Error loading articles: $e", true);
  }

  setState(() => isLoading = false);
}
  // --------------------------------------------------------------
  // FILTERING — Search + Sort
  // --------------------------------------------------------------
  List<dynamic> applySearchSort(List<dynamic> list) {
  // Search
  if (searchQuery.trim().isNotEmpty) {
    list = list.where((a) {
      return (a["headline"] ?? "")
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();
  }

  // Sort — ✅ null-safe na
  switch (sortOption) {
    case "Newest":
      list.sort((a, b) {
        final aDate = a["updated_at"]?.toString() ?? "";
        final bDate = b["updated_at"]?.toString() ?? "";
        return bDate.compareTo(aDate);
      });
      break;
    case "Oldest":
      list.sort((a, b) {
        final aDate = a["updated_at"]?.toString() ?? "";
        final bDate = b["updated_at"]?.toString() ?? "";
        return aDate.compareTo(bDate);
      });
      break;
    case "A–Z":
      list.sort((a, b) {
        final aTitle = a["headline"]?.toString() ?? "";
        final bTitle = b["headline"]?.toString() ?? "";
        return aTitle.compareTo(bTitle);
      });
      break;
    case "Z–A":
      list.sort((a, b) {
        final aTitle = a["headline"]?.toString() ?? "";
        final bTitle = b["headline"]?.toString() ?? "";
        return bTitle.compareTo(aTitle);
      });
      break;
  }

  return list;
}
  // --------------------------------------------------------------
  // SNACKBAR
  // --------------------------------------------------------------
  void _showSnack(String msg, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --------------------------------------------------------------
  // CHECK IF MEDIA IS VIDEO
  // --------------------------------------------------------------
  bool isVideoFile(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".mp4") ||
        u.endsWith(".mov") ||
        u.endsWith(".avi") ||
        u.endsWith(".mkv") ||
        u.endsWith(".webm") ||
        u.contains("video");
  }

  // --------------------------------------------------------------
  // OPEN VIDEO PLAYER PAGE
  // --------------------------------------------------------------
  void openVideoPlayer(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: VideoPlayerWidget(videoUrl: url),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // MEDIA PREVIEW (Image / Video / Carousel)
  // --------------------------------------------------------------
  Widget buildMediaPreview(List<dynamic>? media) {
    if (media == null || media.isEmpty) return const SizedBox();

    // SINGLE MEDIA
    if (media.length == 1) {
      final item = media.first;
      final url = item is Map ? item["url"] ?? "" : item.toString();
      final thumb = item is Map ? item["thumbnail"] ?? url : url;
      final isVideo = isVideoFile(url);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: isVideo ? () => openVideoPlayer(url) : null,
          child: Container(
            height: 180,
            width: double.infinity,
            color: Colors.grey.shade900,
            child: isVideo
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      if (thumb.isNotEmpty && thumb != url)
                        Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade900,
                          ),
                        )
                      else
                        Container(color: Colors.grey.shade900),
                      Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                      Icon(
                        Icons.play_circle_fill,
                        size: 60,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ],
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    // MULTIPLE MEDIA (Horizontal Scroll)
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        itemBuilder: (_, index) {
          final item = media[index];
          final url = item is Map ? item["url"] ?? "" : item.toString();
          final thumb = item is Map ? item["thumbnail"] ?? url : url;
          final isVideo = isVideoFile(url);

          return GestureDetector(
            onTap: isVideo ? () => openVideoPlayer(url) : null,
            child: Container(
              width: 200,
              margin: EdgeInsets.only(right: index < media.length - 1 ? 12 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.grey.shade900,
                  child: isVideo
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            if (thumb.isNotEmpty && thumb != url)
                              Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade900,
                                ),
                              )
                            else
                              Container(color: Colors.grey.shade900),
                            Container(
                              color: Colors.black.withOpacity(0.3),
                            ),
                            Icon(
                              Icons.play_circle_fill,
                              size: 50,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------
  // CATEGORY CHIP
  // --------------------------------------------------------------
  Widget categoryChip(String? category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        (category ?? "UNCATEGORIZED").toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryOrange,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // STATUS CHIP
  // --------------------------------------------------------------
  Widget statusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {

      case "pending":
      color = Colors.orange;
      icon = Icons.pending;
      break;
    case "approved":
      color = Colors.green;
      icon = Icons.check_circle;
      break;
      case "draft":
        color = Colors.blue;
        icon = Icons.edit_note;
        break;
      case "submitted":
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case "needs_revision":
        color = Colors.red;
        icon = Icons.edit;
        break;
      case "published":
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case "deleted":
        color = Colors.grey;
        icon = Icons.delete;
        break;
      default:
        color = Colors.grey;
        icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.replaceAll("_", " ").toUpperCase(),
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // LIST BUILDER
  // --------------------------------------------------------------
  Widget buildList(List<dynamic> list, String status) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No articles found",
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchMyArticles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) => AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: 1,
          child: buildCard(list[i], status),
        ),
      ),
    );
  }

  // --------------------------------------------------------------
  // GRAY OUTLINE BUTTON STYLE
  // --------------------------------------------------------------
  ButtonStyle grayOutlineButton() {
    return OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.grey.shade400, width: 1.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      foregroundColor: Colors.grey.shade800,
      textStyle: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // --------------------------------------------------------------
  // ARTICLE CARD (WITH DELETE & RESTORE)
  // --------------------------------------------------------------
  Widget buildCard(Map<String, dynamic> a, String statusType) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER (Category + Status)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                categoryChip(a["category"]),
                const Spacer(),
                statusChip(statusType),
              ],
            ),
          ),

          // TITLE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              a["headline"] ?? "Untitled Article",
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // CONTENT PREVIEW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              a["content"] ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // MEDIA PREVIEW
          if (a["media"] != null && (a["media"] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: buildMediaPreview(a["media"]),
            ),

          const SizedBox(height: 16),

          // ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // DRAFT ACTIONS: Edit + Delete
                if (statusType == "draft") ...[
                  _primaryButton(
                    "Edit",
                    Icons.edit,
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateArticlePage(
                            authorEmail: widget.authorEmail,
                            draftId: a["id"],
                          ),
                        ),
                      ).then((_) => fetchMyArticles());
                    },
                  ),
                  const SizedBox(width: 10),
                  _grayButton(
                    "Delete",
                    Icons.delete_outline,
                    () => softDeleteArticle(a["id"]),
                  ),
                ],

                // REVIEW ACTION: View
                if (statusType == "pending")
                  _primaryButton(
                    "View",
                    Icons.visibility,
                    AppTheme.primaryOrange,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreviewPage(
                            headline: a["headline"],
                            content: a["content"],
                            category: a["category"],
                            selectedFiles: const [],
                            articleId: a["id"],
                            authorEmail: widget.authorEmail,
                            currentStatus: "submitted",
                            isEditing: false,
                            isMagazine: a["is_magazine"] == true,
                          ),
                        ),
                      );
                    },
                  ),

                // REVISION ACTION
                if (statusType == "needs_revision")
                  _primaryButton(
                    "Revise",
                    Icons.edit_note,
                    Colors.red,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RevisionPage(
                            articleId: a["id"],
                            headline: a["headline"],
                            category: a["category"],
                            originalContent: a["content"],
                            mediaFiles: a["media"],
                            highlightedTexts: a["highlighted_texts"],
                            feedback: a["feedback"],
                            authorEmail: widget.authorEmail,
                            isMagazine: a["is_magazine"] == true,
                          ),
                        ),
                      ).then((_) => fetchMyArticles());
                    },
                  ),

                // PUBLISHED: Comments button
                if (statusType == "approved")
                  _primaryButton(
                    "Comments",
                    Icons.comment,
                    Colors.green,
                    () => debugPrint("Open comments page"),
                  ),

                // TRASH: Restore button
                if (statusType == "deleted")
                  _grayButton(
                    "Restore",
                    Icons.restore,
                    () => restoreArticle(a["id"]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // BUTTON HELPERS
  // --------------------------------------------------------------
  Widget _primaryButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _grayButton(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.grey.shade800),
      label: Text(label),
      style: grayOutlineButton(),
    );
  }

  // --------------------------------------------------------------
  // DELETE Article (Soft Delete → Moves to Trash)
  // --------------------------------------------------------------
  Future<void> softDeleteArticle(int id) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/soft-delete-article/$id"));

      if (res.statusCode == 200) {
        _showSnack("Article moved to Trash.", false);
        fetchMyArticles();
      } else {
        _showSnack("Failed to delete article.", true);
      }
    } catch (e) {
      _showSnack("Error: $e", true);
    }
  }

  // --------------------------------------------------------------
  // RESTORE Article (Moves back to Draft)
  // --------------------------------------------------------------
  Future<void> restoreArticle(int id) async {
    try {
      final res = await http.post(Uri.parse("$baseUrl/restore-article/$id"));

      if (res.statusCode == 200) {
        _showSnack("Article restored!", false);
        fetchMyArticles();
      } else {
        _showSnack("Failed to restore article.", true);
      }
    } catch (e) {
      _showSnack("Error: $e", true);
    }
  }

  // --------------------------------------------------------------
  // BUILD UI
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Column(
        children: [
          // SEARCH + SORT
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => searchQuery = v),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Search articles...",
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortOption,
                      icon: Icon(Icons.sort,
                          color: Colors.grey.shade600, size: 20),
                      items: ["Newest", "Oldest", "A–Z", "Z–A"]
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => sortOption = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TABS
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppTheme.primaryOrange,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppTheme.primaryOrange,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                    child: Row(children: [
                  const Icon(Icons.edit_note, size: 18),
                  const SizedBox(width: 6),
                  Text("Drafts ($draftCount)"),
                ])),
                Tab(
                    child: Row(children: [
                  const Icon(Icons.pending, size: 18),
                  const SizedBox(width: 6),
                  Text("Review ($submittedCount)"),
                ])),
                Tab(
                    child: Row(children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 6),
                  Text("Revision ($needsRevisionCount)"),
                ])),
                Tab(
                    child: Row(children: [
                  const Icon(Icons.check_circle, size: 18),
                  const SizedBox(width: 6),
                  Text("Published ($publishedCount)"),
                ])),
                Tab(
                    child: Row(children: [
                  const Icon(Icons.delete_outline, size: 18),
                  const SizedBox(width: 6),
                  Text("Trash ($deletedCount)"),
                ])),
              ],
            ),
          ),

          // TAB CONTENT
          Expanded(
  child: isLoading
      ? const Center(child: CircularProgressIndicator())
      : TabBarView(
          controller: _tabController,
          children: [
            buildList(
              applySearchSort(allArticles
                  .where((a) =>
                      a["status"] == "draft" &&
                      a["is_deleted"] != true)  // ✅ dito
                  .toList()),
              "draft",
            ),
            buildList(
              applySearchSort(allArticles
                  .where((a) =>
                      a["status"] == "pending" &&
                      a["is_deleted"] != true)  // ✅ dito
                  .toList()),
              "pending",
            ),
            buildList(
              applySearchSort(allArticles
                  .where((a) =>
                      a["status"] == "needs_revision" &&
                      a["is_deleted"] != true)  // ✅ dito
                  .toList()),
              "needs_revision",
            ),
            buildList(
              applySearchSort(allArticles
                  .where((a) =>
                      (a["status"] == "approved" || a["status"] == "published") &&
                      a["is_deleted"] != true)  // ✅ dito
                  .toList()),
              "approved",
            ),
            buildList(
              applySearchSort(allArticles
                  .where((a) => a["is_deleted"] == true)  // ✅ hindi baguhin ito
                  .toList()),
              "deleted",
            ),
          ],
        ),
),
        ],
      ),

      // NEW ARTICLE BUTTON
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryOrange,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "New Article",
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CreateArticlePage(authorEmail: widget.authorEmail),
            ),
          ).then((_) => fetchMyArticles());
        },
      ),
    );
  }
}