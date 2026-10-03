// -----------------------------------------------------------------------------
// SUPERADMIN ARTICLE PREVIEW PAGE — GOOGLE DOCS STYLE HIGHLIGHTING
// -----------------------------------------------------------------------------
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gears_frontend/superadmin/fullscreen_media_viewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:gears_frontend/superadmin/superadmin_edit_article.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/superadmin_nav.dart';

// -----------------------------------------------------------------------------
// DATA MODEL for highlighted comments
// -----------------------------------------------------------------------------
class HighlightData {
  final int paragraph;
  final int start;
  final int end;
  final String selectedText;
  final String comment;

  HighlightData({
    required this.paragraph,
    required this.start,
    required this.end,
    required this.selectedText,
    required this.comment,
  });
}

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class SuperAdminArticlePreviewPage extends StatefulWidget {
  final int articleId;
  final bool showActions;

  const SuperAdminArticlePreviewPage({
    super.key,
    required this.articleId,

    this.showActions = true,
  });

  @override
  State<SuperAdminArticlePreviewPage> createState() =>
      _SuperAdminArticlePreviewPageState();
}

class _SuperAdminArticlePreviewPageState
    extends State<SuperAdminArticlePreviewPage> {
  bool isLoading = true;

  String? approverEmail;


  String headline = "";
  String authorName = "";
  String category = "";
  String content = "";
  List<String> paragraphs = [];

  List<dynamic> media = [];
  List<dynamic>? comments = [];

  // Highlight comments
  List<HighlightData> highlights = [];

  // Bottom navigation
  int currentIndex = 1;

  @override
void initState() {
  super.initState();
  _init();
}

Future<void> _init() async {
  await _loadSuperAdminEmail();   // MUST finish first
  await _loadArticle();           // Load article after email
}

  Future<void> _loadSuperAdminEmail() async {
  final prefs = await SharedPreferences.getInstance();

  print("🔍 PREFS CONTENTS:");

  print("email = ${prefs.getString("email")}");
  print("user_email = ${prefs.getString("user_email")}");
  print("id = ${prefs.getInt("id")}");
  print("role = ${prefs.getString("user_role")}");

  setState(() {
    approverEmail = prefs.getString("email") ??
                    prefs.getString("user_email");
  });

  print("✅ Loaded approverEmail = $approverEmail");
}


  // ---------------------------------------------------------------------------
  // ARCHIVE ARTICLE
  // ---------------------------------------------------------------------------
  Future<void> _archiveArticle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Archive Article?"),
        content: const Text("This will hide the article but keep it stored."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.patch(
        Uri.parse("$baseUrl/archive-article/${widget.articleId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_deleted": true}),
      );

      if (res.statusCode == 200) {
        _showSnack("Article archived ✓", false);
        Navigator.pop(context);
      } else {
        _showSnack("Failed to archive", true);
      }
    } catch (e) {
      _showSnack("Error: $e", true);
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD ARTICLE DATA
  // ---------------------------------------------------------------------------
  Future<void> _loadArticle() async {
  try {
    final res = await http.get(
      Uri.parse("$baseUrl/get-article/${widget.articleId}"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      setState(() {
        headline = data["headline"] ?? "";
        authorName = data["author_name"] ?? "";
        category = data["category"] ?? "";
        content = data["content"] ?? "";

        // ✅ Fix media — i-normalize sa List<Map>
        final rawMedia = data["media"];
        if (rawMedia is List) {
          media = rawMedia.map((m) {
            if (m is Map) return Map<String, dynamic>.from(m);
            if (m is String && m.isNotEmpty) {
              return {"url": m, "thumbnail": m, "type": "image"};
            }
            return null;
          }).where((e) => e != null).toList();
        } else {
          media = [];
        }

        final raw = data["comments"];
        comments = raw is List ? raw : [];

        paragraphs = content
            .split("\n")
            .where((p) => p.trim().isNotEmpty)
            .toList();
      });
    }
  } catch (e) {
    debugPrint("Load article error: $e");
  }

  setState(() => isLoading = false);
}

  // ---------------------------------------------------------------------------
  // COMMENT BOTTOM SHEET (GOOGLE DOCS STYLE)
  // ---------------------------------------------------------------------------
  void _openCommentSheet({
    required int paragraphIndex,
    required int start,
    required int end,
    required String selectedText,
  }) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.90,
          minChildSize: 0.40,
          initialChildSize: 0.60,
          builder: (context, scrollController) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      selectedText,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Add Comment",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: "Write a detailed comment...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryOrange,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
  onPressed: () {
    final text = controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write a comment first.")),
      );
      return;
    }

    setState(() {
      highlights.add(
        HighlightData(
          paragraph: paragraphIndex,
          start: start,
          end: end,
          selectedText: selectedText,
          comment: text,
        ),
      );
    });

    Navigator.pop(context);
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryOrange,
    padding: const EdgeInsets.symmetric(vertical: 12),
  ),
  child: const Text("Save Comment"),
),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // ---------------------------------------------------------------------------
  // RENDER PARAGRAPH WITH HIGHLIGHTS + CONTEXT MENU
  // ---------------------------------------------------------------------------
  Widget _buildParagraph(int index, String text) {
  if (!widget.showActions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  final marks = highlights.where((h) => h.paragraph == index).toList();

  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: GestureDetector(
      // ✅ Long press para mag-trigger ng comment dialog sa web
      onLongPress: () {
        _openManualCommentSheet(paragraphIndex: index, fullText: text);
      },
      child: SelectableText.rich(
        _buildHighlightedSpan(text, index, marks),
        style: GoogleFonts.poppins(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.textDark,
        ),
        contextMenuBuilder: (context, editableTextState) {
          final value = editableTextState.textEditingValue;
          final selection = value.selection;

          if (!selection.isValid || selection.isCollapsed) {
            return const SizedBox.shrink();
          }

          final selectedText = selection.textInside(value.text);
          if (selectedText.trim().isEmpty) return const SizedBox.shrink();

          final start = selection.start;
          final end = selection.end;

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: [
              ContextMenuButtonItem(
                onPressed: () {
                  editableTextState.copySelection(SelectionChangedCause.toolbar);
                  ContextMenuController.removeAny();
                },
                type: ContextMenuButtonType.copy,
              ),
              ContextMenuButtonItem(
                onPressed: () {
                  ContextMenuController.removeAny();
                  if (start >= 0 && end > start && end <= text.length) {
                    _openCommentSheet(
                      paragraphIndex: index,
                      start: start,
                      end: end,
                      selectedText: selectedText,
                    );
                  }
                },
                label: '💬 Add Comment',
              ),
            ],
          );
        },
      ),
    ),
  );
}

void _openManualCommentSheet({
  required int paragraphIndex,
  required String fullText,
}) {
  final selectedTextCtrl = TextEditingController();
  final commentCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) {
      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DRAG HANDLE
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                "Paste or type the exact text to highlight:",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),

              // ✅ User i-type ang text na gusto niyang i-highlight
              TextField(
                controller: selectedTextCtrl,
                decoration: InputDecoration(
                  hintText: "Exact text to highlight...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                "Your comment:",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Write your comment...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final selectedText = selectedTextCtrl.text.trim();
                        final comment = commentCtrl.text.trim();

                        if (selectedText.isEmpty || comment.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Both fields are required."),
                            ),
                          );
                          return;
                        }

                        // ✅ Hanapin ang exact position sa paragraph
                        final start = fullText.indexOf(selectedText);
                        if (start == -1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Text not found in paragraph. Check spelling/capitalization.",
                              ),
                            ),
                          );
                          return;
                        }

                        final end = start + selectedText.length;

                        setState(() {
                          highlights.add(HighlightData(
                            paragraph: paragraphIndex,
                            start: start,
                            end: end,
                            selectedText: selectedText,
                            comment: comment,
                          ));
                        });

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                      child: const Text("Save Comment"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    },
  );
}
  // ---------------------------------------------------------------------------
  // BUILD TEXTSPAN WITH HIGHLIGHT COLORS
  // ---------------------------------------------------------------------------
  TextSpan _buildHighlightedSpan(
      String text, int paragraphIndex, List<HighlightData> marks) {
    if (marks.isEmpty) {
      return TextSpan(
        text: text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          height: 1.6,
          color: AppTheme.textDark,
        ),
      );
    }

    marks.sort((a, b) => a.start.compareTo(b.start));

    List<InlineSpan> spans = [];
    int cursor = 0;

    for (final h in marks) {
      if (cursor < h.start) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, h.start),
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.6,
              color: AppTheme.textDark,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: h.selectedText,
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryOrange,
            backgroundColor: AppTheme.primaryOrange.withOpacity(0.25),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openViewCommentPopup(h),
        ),
      );

      cursor = h.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.6,
            color: AppTheme.textDark,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  // ---------------------------------------------------------------------------
  // VIEW COMMENT POPUP
  // ---------------------------------------------------------------------------
  void _openViewCommentPopup(HighlightData h) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Comment",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                h.selectedText,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Comment:",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              h.comment,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => highlights.remove(h));
              Navigator.pop(context);
            },
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Close",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMMENTS LIST (NORMAL USER COMMENTS)
  // ---------------------------------------------------------------------------
  Widget _buildCommentsSection() {
    final list = comments;

    if (list == null || list.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       Text(
  "Reader Comments (${comments?.length ?? 0})",

          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 10),

        for (var c in list)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.lightCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (c["author_name"] ?? "User").toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (c["comment"] ?? "").toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (c["created_at"] ?? "").toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MEDIA PREVIEW HELPERS
  // ---------------------------------------------------------------------------
  String _detectMediaType(String url) {
    final u = url.toLowerCase();
    if (u.endsWith(".png") ||
        u.endsWith(".jpg") ||
        u.endsWith(".jpeg") ||
        u.endsWith(".gif")) return "image";
    if (u.endsWith(".mp4") || u.endsWith(".mov")) return "video";
    if (u.endsWith(".pdf")) return "pdf";
    return "file";
  }

  Widget _buildMediaSection() {
  if (media.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Media Attachments",
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
      const SizedBox(height: 10),

      // ✅ Single media — full width
      if (media.length == 1)
        _buildSingleMediaItem(media.first)
      else
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            itemBuilder: (context, index) {
              return Container(
                width: 200,
                margin: EdgeInsets.only(
                    right: index < media.length - 1 ? 12 : 0),
                child: _buildSingleMediaItem(media[index]),
              );
            },
          ),
        ),

      const SizedBox(height: 20),
    ],
  );
}

// ✅ Helper para sa bawat media item
Widget _buildSingleMediaItem(dynamic item) {
  String url = "";
  String thumb = "";
  String type = "image";

  if (item is Map) {
    url   = item["url"]?.toString() ?? "";
    thumb = item["thumbnail"]?.toString() ?? url;
    type  = item["type"]?.toString() ?? _detectMediaType(url);
  } else if (item is String) {
    url   = item;
    thumb = item;
    type  = _detectMediaType(item);
  }

  if (url.isEmpty) return const SizedBox.shrink();

  final isVideo = type == "video" ||
      url.toLowerCase().endsWith(".mp4") ||
      url.toLowerCase().endsWith(".mov");

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullscreenMediaViewer(
            url: url,
            type: isVideo ? "video" : type,
          ),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black12,
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
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.black87),
                    )
                  else
                    Container(color: Colors.black87),
                  Container(color: Colors.black.withOpacity(0.3)),
                  Icon(
                    Icons.play_circle_fill,
                    size: 52,
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
                    child: const Center(
                        child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image,
                      size: 40, color: Colors.grey),
                ),
              ),
      ),
    ),
  );
}

  Widget _buildMediaPreview(String type, String url) {
    if (type == "image") {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, size: 40),
      );
    }

    if (type == "video") {
      return Stack(
        children: const [
          Positioned.fill(child: ColoredBox(color: Colors.black12)),
          Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 50,
              color: Colors.orange,
            ),
          )
        ],
      );
    }

    if (type == "pdf") {
      return const Center(
        child: Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
      );
    }

    return const Center(
      child: Icon(Icons.insert_drive_file, size: 40),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT
  // ---------------------------------------------------------------------------
  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < paragraphs.length; i++)
          _buildParagraph(i, paragraphs[i]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION BUTTONS (PUBLISH / REQUEST REVISION)
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
          Expanded(
              child: ElevatedButton.icon(
                onPressed: _publishArticle,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  "Publish",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: OutlinedButton.icon(
                onPressed: _requestRevision,
                icon: const Icon(Icons.edit_note, color: Colors.orange),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                label: Text(
                  "Request Revision",
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          "Your comments will be included for the author's revision.",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  // ---------------------------------------------------------------------------
  // SEND REVISION REQUEST TO BACKEND
  // ---------------------------------------------------------------------------
  void _requestRevision() {
    if (highlights.isEmpty) {
      _showSnack("Add at least one highlighted comment first.", true);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "Send Revision Request?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "This will send ${highlights.length} comment(s) to the author.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendRevisionToBackend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRevisionToBackend() async {
  if (approverEmail == null) {
    _showSnack("Cannot send revision — superadmin email missing.", true);
    return;
  }

  try {
    final revisionList = highlights.map((h) => {
          "paragraph": h.paragraph,
          "start": h.start,
          "end": h.end,
          "text": h.selectedText,
          "comment": h.comment,
        }).toList();

    final res = await http.post(
      Uri.parse("$baseUrl/reject-article-for-revision/${widget.articleId}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "approver_email": approverEmail, // ✅ FIXED
        "feedback": "Please check the highlighted sections.",
        "highlighted_texts": revisionList,
      }),
    );

    if (res.statusCode == 200) {
      _showSnack("Revision request sent ✓", false);
      Navigator.pop(context);
    } else {
      _showSnack("Failed to send revision request", true);
    }
  } catch (e) {
    _showSnack(e.toString(), true);
  }
}


  // ---------------------------------------------------------------------------
  // PUBLISH ARTICLE
  // ---------------------------------------------------------------------------
  Future<void> _publishArticle() async {
  if (approverEmail == null) {
    _showSnack("Cannot publish — superadmin email missing.", true);
    return;
  }

  try {
    final res = await http.post(
      Uri.parse("$baseUrl/approve-and-publish-article/${widget.articleId}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "approver_email": approverEmail, // ✅ FIXED
      }),
    );

    if (res.statusCode == 200) {
      _showSnack("Article Published ✓", false);
      Navigator.pop(context);
    } else {
      _showSnack("Failed to publish article", true);
    }
  } catch (e) {
    _showSnack(e.toString(), true);
  }
}


  // ---------------------------------------------------------------------------
  // HEADER UI
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.toUpperCase(),
          style: GoogleFonts.poppins(
            color: AppTheme.primaryOrange,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          headline,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            height: 1.3,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.person, color: AppTheme.primaryOrange),
            const SizedBox(width: 8),
            Text(
              authorName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------
  void _showSnack(String msg, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      // -----------------------------------------------------------------------
      // APP BAR
      // -----------------------------------------------------------------------
      appBar: AppBar(
  elevation: 0,
  automaticallyImplyLeading: false, // disable default back button
  flexibleSpace: Container(
    decoration: const BoxDecoration(
      gradient: AppTheme.titleGradient,
    ),
  ),
  leading: IconButton(
    icon: SvgPicture.asset(
      "assets/icons/back.svg",
      height: 22,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    ),
    onPressed: () => Navigator.pop(context),
  ),
  title: Text(
    "Article Review",
    style: GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
  centerTitle: true,


        actions: [
          // Show three dots ONLY if article is already published (showActions == false)
          if (!widget.showActions)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == "edit") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SuperAdminEditArticlePage(
                        articleId: widget.articleId,
                      ),
                    ),
                  ).then((refresh) {
                    if (refresh == true) _loadArticle();
                  });
                }

                if (value == "archive") {
                  _archiveArticle();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "edit",
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 10),
                      Text("Edit Article"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "archive",
                  child: Row(
                    children: [
                      Icon(Icons.archive, size: 18),
                      SizedBox(width: 10),
                      Text("Archive Article"),
                    ],
                  ),
                ),
              ],
            ),

          // Highlight count bubble
          if (highlights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${highlights.length} comment${highlights.length > 1 ? 's' : ''}",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // -----------------------------------------------------------------------
      // BODY
      // -----------------------------------------------------------------------
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Banner
                if (widget.showActions)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: AppTheme.primaryOrange.withOpacity(0.1),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: AppTheme.primaryOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Select text → right-click → Add Comment.  Or long-press a paragraph to manually highlight.",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.primaryOrange,
            ),
          ),
        ),
      ],
    ),
  ),

                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildMediaSection(),
                        _buildContent(),
                        const SizedBox(height: 30),

                        if (!widget.showActions) _buildCommentsSection(),
                        const SizedBox(height: 30),

                        if (widget.showActions) _buildActions(),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),

      // -----------------------------------------------------------------------
      // BOTTOM NAVIGATION BAR
      // -----------------------------------------------------------------------
      bottomNavigationBar: SuperAdminNav(
        currentIndex: currentIndex,
        role: "superadmin",
        onTap: (i) {
          setState(() => currentIndex = i);

          switch (i) {
            case 0:
              Navigator.pushReplacementNamed(
                  context, "/dashboard-superadmin");
              break;
            case 1:
              Navigator.pushReplacementNamed(
                  context, "/articles-superadmin");
              break;
            case 2:
              Navigator.pushReplacementNamed(
                  context, "/users-superadmin");
              break;
            case 3:
              Navigator.pushReplacementNamed(
                  context, "/profile-superadmin");
              break;
          }
        },
      ),
    );
  }
}
