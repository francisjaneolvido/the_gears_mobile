// -------------------------------------------------------------
// CreateArticlePage — SAFE AUTOSAVE (Debounce + Media Manager)
// -------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/admin/articles/preview_page.dart';

class CreateArticlePage extends StatefulWidget {
  final String authorEmail;
  final int? draftId;

  const CreateArticlePage({
    super.key,
    required this.authorEmail,
    this.draftId,
  });

  @override
  State<CreateArticlePage> createState() => _CreateArticlePageState();
}

class _CreateArticlePageState extends State<CreateArticlePage> {
  // -------------------------------------------------------------
  // CONTROLLERS
  // -------------------------------------------------------------
  final TextEditingController headlineController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  List<dynamic> articleHighlights = [];

  final ImagePicker picker = ImagePicker();

  /// Unified media structure:
  /// { "type": "url", "value": "https://..." }
  /// { "type": "file", "value": XFile }
  List<Map<String, dynamic>> mediaItems = [];

  Timer? debounce; // 🔥 DEBOUNCE TIMER
  bool showSaved = false;

  int? articleId;
  bool isLoadingExisting = false;

  static const int maxFileSize = 8 * 1024 * 1024;

  List<String> categories = [];


  String? selectedCategory;


  bool isMagazine = false;

  @override
void initState() {
  super.initState();

  loadCategories();   // ← LOAD CATEGORIES FIRST

  if (widget.draftId != null) {
    loadExistingDraft(widget.draftId!);
  }
}


Future<void> loadCategories() async {
  try {
    final res = await http.get(Uri.parse("$baseUrl/get-categories?for=admin"));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        categories = data.map<String>((c) => c["name"].toString()).toList();

        // 👉 AUTO-SELECT FIRST CATEGORY if none selected
        if (categories.isNotEmpty && selectedCategory == null) {
  selectedCategory = categories.first;
}

      });
    }
  } catch (e) {
    print("CATEGORY LOAD ERROR: $e");
  }
}

  // -------------------------------------------------------------
  // LOAD EXISTING ARTICLE
  // -------------------------------------------------------------
  Future<void> loadExistingDraft(int id) async {
    setState(() => isLoadingExisting = true);

    try {
      final res = await http.get(Uri.parse("$baseUrl/get-article/$id"));

      if (res.statusCode == 200) {
        final article = jsonDecode(res.body);

        mediaItems.clear();

        // Load existing media URLs
        List existing = article["media"] ?? [];
for (var item in existing) {
  String? url;
  if (item is Map) {
    url = item["url"]?.toString();
  } else if (item is String) {
    url = item;
  }
  if (url != null && url.isNotEmpty) {
    mediaItems.add({"type": "url", "value": url});
  }
}

        setState(() {
          articleId = id;
          headlineController.text = article["headline"] ?? "";
          contentController.text = article["content"] ?? "";
          selectedCategory = article["category"] ?? "Home";
          isMagazine = article["is_magazine"] == true;

          articleHighlights = article["highlighted_texts"] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error loading draft: $e");
    }

    setState(() => isLoadingExisting = false);
  }

  // -------------------------------------------------------------
  // AUTOSAVE (Debounced)
  // -------------------------------------------------------------
  void scheduleAutosave() {
    if (debounce?.isActive ?? false) debounce!.cancel();

    debounce = Timer(const Duration(seconds: 2), () {
      autosaveDraft();
    });
  }

  Future<void> autosaveDraft() async {
    final headline = headlineController.text.trim();
    final content = contentController.text.trim();

    if (headline.isEmpty && content.isEmpty) return;

    final body = {
      "article_id": articleId,
      "email": widget.authorEmail,
      "headline": headline,
      "content": content,
      "category": selectedCategory,
      "is_magazine": isMagazine,

      // Send preserved media URLs (backend ignores for autosave but keeps state)
      "media": mediaItems
          .where((m) => m["type"] == "url")
          .map((m) => m["value"])
          .toList(),
    };

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/autosave-article"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          articleId = data["article_id"];
          showSaved = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => showSaved = false);
        });
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // PICK MEDIA
  // -------------------------------------------------------------
  Future<void> pickMedia() async {
    final images = await picker.pickMultiImage();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    // Add images
    for (var img in images) {
      final size = await img.length();
      if (size <= maxFileSize) {
        mediaItems.add({
          "type": "file",
          "value": img,
        });
      }
    }

    // Add video if any
    if (video != null) {
      final size = await video.length();
      if (size <= maxFileSize) {
        mediaItems.add({
          "type": "file",
          "value": video,
        });
      }
    }

    setState(() {});
    scheduleAutosave();
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: SvgPicture.asset(
            "assets/icons/back.svg",
            width: 26,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.draftId != null ? "Edit Article" : "Create Article",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.titleGradient),
        ),
      ),

      body: isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showSaved)
                        Text("Saved",
                            style: GoogleFonts.poppins(
                                color: Colors.green, fontSize: 12)),

                      // ---------------- HEADLINE ----------------
                      TextField(
                        controller: headlineController,
                        onChanged: (_) => scheduleAutosave(),
                        decoration: InputDecoration(
                          labelText: "Headline *",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ---------------- CATEGORY ----------------
                      DropdownButtonFormField(
                        value: selectedCategory ?? (categories.isNotEmpty ? categories.first : null),

                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedCategory = val);
                            scheduleAutosave();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: "Category *",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: categories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: 16),

                      // ---------------- MAGAZINE SWITCH ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Magazine Layout",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600)),
                          Switch(
                            value: isMagazine,
                            activeColor: AppTheme.primaryOrange,
                            onChanged: (v) {
                              setState(() => isMagazine = v);
                              scheduleAutosave();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ---------------- CONTENT ----------------
                      TextField(
                        controller: contentController,
                        onChanged: (_) => scheduleAutosave(),
                        maxLines: 10,
                        decoration: InputDecoration(
                          labelText: "Content *",
                          filled: true,
                          fillColor: Colors.white,
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ---------------- ADD MEDIA ----------------
                     // -------------------------------------------------------------
// FULL-WIDTH ADD MEDIA BUTTON (END-TO-END)
// -------------------------------------------------------------
// -------------------------------------------------------------
// MODERN GLASS BUTTON — FULL WIDTH
// -------------------------------------------------------------
Container(
  width: double.infinity,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.7),
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 3),
      )
    ],
  ),
  child: TextButton.icon(
    onPressed: pickMedia,
    icon: Icon(Icons.add_photo_alternate,
        color: AppTheme.primaryOrange, size: 24),
    label: Text(
      "Add Media",
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryOrange,
      ),
    ),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  ),
),


                      // ---------------- MEDIA PREVIEW ----------------
                      if (mediaItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: mediaItems.length,
                            itemBuilder: (_, index) {
                              final item = mediaItems[index];
                              final type = item["type"];
                              final value = item["value"];

                              String? path;
                              bool isVideo = false;

                              if (type == "url") {
                                path = value;
                               isVideo = (path ?? "").toLowerCase().endsWith(".mp4");

                              } else if (type == "file") {
                                path = value.path;
                               isVideo = (path ?? "").toLowerCase().endsWith(".mp4");

                              }

                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                  child: isVideo
    ? Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black),
          Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
        ],
      )
    : (type == "url"
        ? Image.network(
  path!,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) => Container(
    color: Colors.grey.shade200,
    child: const Icon(Icons.broken_image, color: Colors.grey),
  ),
)
        : Image.file(File(path!), fit: BoxFit.cover)),

                                  ),

                                  // DELETE BUTTON
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() =>
                                            mediaItems.removeAt(index));
                                        scheduleAutosave();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ---------------- CONTINUE TO PREVIEW ----------------
                      ElevatedButton(
                        onPressed: () {
                          if (headlineController.text.trim().isEmpty ||
                              contentController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Please fill all required fields")),
                            );
                            return;
                          }

                          Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PreviewPage(
      headline: headlineController.text.trim(),
      content: contentController.text.trim(),
      category: selectedCategory ?? "Uncategorized",

      selectedFiles: mediaItems,
      authorEmail: widget.authorEmail,
      articleId: articleId,
      isEditing: true,
      isMagazine: isMagazine,
      highlightedTexts: articleHighlights,

      // 🔥 FIX → allow submitting to superadmin
      currentStatus: "draft",
    ),
  ),
);

                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text(
                          "Continue to Preview",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
