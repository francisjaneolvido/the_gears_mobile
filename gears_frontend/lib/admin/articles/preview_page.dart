// --------------------------------------------------------------
// PreviewPage — Updated for Unified Media System
// --------------------------------------------------------------

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gears_frontend/widgets/video_player_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/theme/app_theme.dart';

class PreviewPage extends StatefulWidget {
  final String headline;
  final String content;
  final String category;

  /// Unified media structure from CreateArticlePage:
  /// { "type": "url",  "value": "https://..." }
  /// { "type": "file", "value": XFile }
  final List<dynamic> selectedFiles;

  final int? articleId;
  final String authorEmail;

  final bool isEditing;
  final String? currentStatus;
  final bool isMagazine;

  final String? feedback;
  final List<dynamic>? highlightedTexts;

  const PreviewPage({
    super.key,
    required this.headline,
    required this.content,
    required this.category,
    required this.selectedFiles,
    this.articleId,
    required this.authorEmail,
    this.isEditing = false,
    this.currentStatus,
    required this.isMagazine,
    this.feedback,
    this.highlightedTexts,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool isSubmitting = false;

  // --------------------------------------------------------------
  // BUTTON LABEL
  // --------------------------------------------------------------
  String resolveButtonLabel() {
  switch (widget.currentStatus) {
    case "draft":
      return "Submit for Review";
    case "needs_revision":
      return "Submit Revision";
    case "pending":   // ← DAGDAG
    case "approved":  // ← DAGDAG
    case "published":
      return "Close";
    default:
      return "Submit";
  }
}

  // --------------------------------------------------------------
  // UPLOAD MEDIA (ONLY NEW FILES)
  // --------------------------------------------------------------
  Future<bool> saveArticleWithMedia() async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse("$baseUrl/save-article"));

      request.fields["headline"] = widget.headline;
      request.fields["category"] = widget.category;
      request.fields["content"] = widget.content;
      request.fields["email"] = widget.authorEmail;
      request.fields["is_magazine"] = widget.isMagazine ? "1" : "0";

      if (widget.articleId != null) {
        request.fields["article_id"] = widget.articleId.toString();
      }

      // ---- PRESERVE EXISTING URL MEDIA ----
      List<String> preservedUrls = [];

      // ---- PROCESS MEDIA ITEMS ----
      for (var item in widget.selectedFiles) {
        final type = item["type"];
        final value = item["value"];

        if (type == "url") {
  // Handle both String at Map na value
  final val = item["value"];
  if (val is String && val.isNotEmpty) {
    preservedUrls.add(val);
  } else if (val is Map) {
    final u = val["url"]?.toString() ?? "";
    if (u.isNotEmpty) preservedUrls.add(u);
  }
}
      }

      // Send preserved URLs to backend
      request.fields["existing_media"] = jsonEncode(preservedUrls);

      // ---- SEND REQUEST ----
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print("Media successfully uploaded.");
        return true;
      }

      print("Upload failed: ${response.body}");
      return false;
    } catch (e) {
      print("Upload error: $e");
      return false;
    }
  }

  // --------------------------------------------------------------
  // ACTION ROUTER
  // --------------------------------------------------------------
 Future<void> resolveButtonAction() async {
  switch (widget.currentStatus) {
    case "draft":
      return submitArticle();
    case "needs_revision":
      return submitRevision();
    case "pending":   // ← DAGDAG
    case "approved":  // ← DAGDAG
    case "published":
      if (mounted) Navigator.pop(context);
      return;
    default:
      if (mounted) Navigator.pop(context);
  }
}


  // --------------------------------------------------------------
  // SUBMIT FOR REVIEW
  // --------------------------------------------------------------
 Future<void> submitArticle() async {
  if (widget.articleId == null) return;

  setState(() => isSubmitting = true);

  bool ok = await saveArticleWithMedia();
  if (!ok) {
    _showSnack("Failed to upload media", true);
    setState(() => isSubmitting = false);
    return;
  }

  try {
    final res = await http.post(
      Uri.parse("$baseUrl/submit-article-for-approval/${widget.articleId}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"author_email": widget.authorEmail}),
    );

    if (res.statusCode == 200) {
      _showSnack("Article submitted for review!", false);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } else {
      _showSnack("Submit failed: ${res.body}", true);
    }
  } catch (e) {
    _showSnack("Error submitting: $e", true);
  }

  setState(() => isSubmitting = false);
}


  // --------------------------------------------------------------
  // SUBMIT REVISION
  // --------------------------------------------------------------
  Future<void> submitRevision() async {
  if (widget.articleId == null) return;

  setState(() => isSubmitting = true);

  await saveArticleWithMedia();

  try {
    final res = await http.post(
      Uri.parse("$baseUrl/resubmit-article/${widget.articleId}"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "author_email": widget.authorEmail,
        "content": widget.content,
      }),
    );

    if (res.statusCode == 200) {
      _showSnack("Revision submitted!", false);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } else {
      _showSnack("Failed: ${res.body}", true);
    }
  } catch (e) {
    _showSnack("Error: $e", true);
  }

  setState(() => isSubmitting = false);
}


  // --------------------------------------------------------------
  // SNACKBAR
  // --------------------------------------------------------------
  void _showSnack(String msg, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? Colors.red : Colors.green,
        content: Text(msg),
      ),
    );
  }

  // --------------------------------------------------------------
  // MEDIA PREVIEW — Supports URL + File + Video Overlay
  // --------------------------------------------------------------
  // --------------------------------------------------------------
// MEDIA PREVIEW — Supports URL + File + Thumbnail + Video
// --------------------------------------------------------------
// --------------------------------------------------------------
// MEDIA PREVIEW — URL + File + Thumbnail + Video + Tap to Play
// --------------------------------------------------------------
// --------------------------------------------------------------
// FIXED FULL-WIDTH MEDIA PREVIEW (Image + Video + Thumbnail)
// --------------------------------------------------------------
Widget buildMediaPreview() {
  final media = widget.selectedFiles;
  if (media.isEmpty) return const SizedBox();

  return Column(
    children: List.generate(media.length, (index) {
      final item = media[index];

      // -------------------------
      // Extract URL / FILE / Thumbnail
      // -------------------------
      String url = "";
      String thumb = "";
      bool isFile = false;

      // URL TYPE
      if (item["type"] == "url") {
        if (item["value"] is String) {
          url = item["value"];
          thumb = url;
        } else if (item["value"] is Map) {
          final m = item["value"];
          url = m["url"] ?? "";
          thumb = m["thumbnail"] ?? url;
        }
      }

      // FILE TYPE
      if (item["type"] == "file") {
        isFile = true;
        final file = item["value"];
        url = file.path;
        thumb = url;
      }

      final isVideo = url.toLowerCase().endsWith(".mp4") ||
          url.toLowerCase().endsWith(".mov") ||
          url.toLowerCase().contains("video");

      // -------------------------
      // UI CARD (FULL WIDTH)
      // -------------------------
      return GestureDetector(
        onTap: () {
          if (isVideo) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black),
                  body: Center(child: VideoPlayerWidget(videoUrl: url)),
                ),
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          height: 240,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // -------------------------
                // IMAGE / VIDEO THUMBNAIL
                // -------------------------
                isVideo
                    ? (thumb.isNotEmpty
                        ? (isFile
                            ? Image.file(File(thumb), fit: BoxFit.cover)
                            : Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.black),
                              ))
                        : Container(color: Colors.black))
                    : (isFile
                        ? Image.file(File(thumb), fit: BoxFit.cover)
                        : Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black),
                          )),

                // -------------------------
                // VIDEO PLAY ICON OVERLAY
                // -------------------------
                if (isVideo)
                  Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 64,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

  // --------------------------------------------------------------
  // HIGHLIGHTED TEXT FOR REVISION MODE
  // --------------------------------------------------------------
  List<InlineSpan> buildHighlightedContent() {
    final content = widget.content;
    final highlights = widget.highlightedTexts ?? [];

    if (highlights.isEmpty) {
      return [TextSpan(text: content, style: normalStyle())];
    }

    List<InlineSpan> spans = [];
    int cursor = 0;

    highlights.sort((a, b) => a["start"].compareTo(b["start"]));

    for (var h in highlights) {
      int start = h["start"];
      int end = h["end"];
      String comment = h["comment"] ?? "";

      if (cursor < start) {
        spans.add(TextSpan(text: content.substring(cursor, start), style: normalStyle()));
      }

      spans.add(
        WidgetSpan(
          child: GestureDetector(
            onTap: () => showEditorComment(comment),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                content.substring(start, end),
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryRed,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );

      cursor = end;
    }

    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor), style: normalStyle()));
    }

    return spans;
  }

  TextStyle normalStyle() =>
      GoogleFonts.poppins(fontSize: 16, height: 1.5, color: Colors.black87);

  void showEditorComment(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Editor Comment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(text, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // UI
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 55, bottom: 18),
            decoration: const BoxDecoration(gradient: AppTheme.titleGradient),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  "Preview Article",
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),

                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: SvgPicture.asset(
                      "assets/icons/back.svg",
                      width: 26,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildMediaPreview(),
                  const SizedBox(height: 20),

                  // FEEDBACK BANNER
                  if (widget.currentStatus == "needs_revision" &&
                      widget.feedback != null &&
                      widget.feedback!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade700),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.info, size: 18, color: Colors.orange.shade900),
                            const SizedBox(width: 6),
                            Text("Editor's Feedback",
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900)),
                          ]),
                          const SizedBox(height: 6),
                          Text(widget.feedback!, style: GoogleFonts.poppins(fontSize: 13)),
                        ],
                      ),
                    ),

                  // HEADLINE
                  Text(
                    widget.headline,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text("Category: ${widget.category}",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700)),

                  const SizedBox(height: 22),

                  // CONTENT
                  widget.highlightedTexts != null &&
                          widget.highlightedTexts!.isNotEmpty &&
                          widget.currentStatus == "needs_revision"
                      ? RichText(
                          text: TextSpan(children: buildHighlightedContent()),
                        )
                      : Text(widget.content, style: normalStyle()),

                  const SizedBox(height: 35),

                  // ACTION BUTTON
                  ElevatedButton(
                    onPressed: isSubmitting ? null : resolveButtonAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(resolveButtonLabel(),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            )),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
