import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gears_frontend/utils/config.dart';


class RevisionPage extends StatefulWidget {
  final int articleId;
  final String headline;
  final String category;
  final String originalContent;
  final List<dynamic>? mediaFiles;
  final List<dynamic>? highlightedTexts;
  final String? feedback;
  final String authorEmail;
  final bool isMagazine;

  const RevisionPage({
    super.key,
    required this.articleId,
    required this.headline,
    required this.category,
    required this.originalContent,
    required this.mediaFiles,
    required this.highlightedTexts,
    required this.feedback,
    required this.authorEmail,
    required this.isMagazine,
  });

  @override
  State<RevisionPage> createState() => _RevisionPageState();
}

class _RevisionPageState extends State<RevisionPage> {
  final TextEditingController _contentController = TextEditingController();
  Timer? debounce;
  bool showSavedTick = false;
  bool isSaving = false;

  // NEW
  bool fullScreenMode = false;
  int wordCount = 0;

  final PageController _mediaController = PageController();

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.originalContent;

    updateWordCount();

    _contentController.addListener(() {
      updateWordCount();
      scheduleAutosave();
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    _mediaController.dispose();
    super.dispose();
  }

  // ------------------------------------------
  // WORD COUNT
  // ------------------------------------------
  void updateWordCount() {
  String text = _contentController.text.trim();

  if (text.isEmpty) {
    setState(() => wordCount = 0);
    return;
  }

  final words = text
      .split(RegExp(r"\s+"))
      .where((word) => word.trim().isNotEmpty)
      .toList();

  setState(() => wordCount = words.length);
}


  // ------------------------------------------
  // AUTOSAVE
  // ------------------------------------------
  void scheduleAutosave() {
    if (debounce?.isActive ?? false) debounce!.cancel();

    debounce = Timer(const Duration(seconds: 2), () {
      saveDraft();
    });
  }

  Future<void> saveDraft() async {
    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/autosave-article"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "article_id": widget.articleId,
          "email": widget.authorEmail,
          "headline": widget.headline,
          "category": widget.category,
          "content": _contentController.text,
          "is_magazine": widget.isMagazine,
        }),
      );

      if (res.statusCode == 200) {
        showAutosaveToast();
      }
    } catch (_) {}

    setState(() => isSaving = false);
  }

  void showAutosaveToast() {
    Fluttertoast.showToast(
      msg: "Draft saved",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green.shade700,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  // ------------------------------------------
  // HIGHLIGHTED TEXT RENDER
  // ------------------------------------------
  List<InlineSpan> buildHighlightedSpans() {
  final text = widget.originalContent;
  final marks = widget.highlightedTexts ?? [];

  if (marks.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
      )
    ];
  }

  // ✅ Filter out invalid marks + null-safe sort
  final validMarks = marks.where((h) {
    return h is Map &&
        h["start"] != null &&
        h["end"] != null;
  }).toList();

  if (validMarks.isEmpty) {
    return [
      TextSpan(
        text: text,
        style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
      )
    ];
  }

  // ✅ Null-safe sort
  validMarks.sort((a, b) {
    final aStart = (a["start"] as num?)?.toInt() ?? 0;
    final bStart = (b["start"] as num?)?.toInt() ?? 0;
    return aStart.compareTo(bStart);
  });

  List<InlineSpan> spans = [];
  int cursor = 0;

  for (var h in validMarks) {
    int start = (h["start"] as num).toInt();
    int end = (h["end"] as num).toInt();
    String comment = h["comment"]?.toString() ?? "";

    // ✅ Bounds check
    if (start < 0 || end > text.length || start >= end) continue;
    if (cursor > start) continue;

    if (cursor < start) {
      spans.add(TextSpan(
        text: text.substring(cursor, start),
        style: GoogleFonts.poppins(fontSize: 15),
      ));
    }

    spans.add(
      WidgetSpan(
        child: GestureDetector(
          onTap: () => showCommentBubble(comment),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text.substring(start, end),
              style: GoogleFonts.poppins(
                color: AppTheme.primaryRed,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );

    cursor = end;
  }

  if (cursor < text.length) {
    spans.add(TextSpan(
      text: text.substring(cursor),
      style: GoogleFonts.poppins(fontSize: 15),
    ));
  }

  return spans;
}

  void showCommentBubble(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Editor Note",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(text, style: GoogleFonts.poppins()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  // ------------------------------------------
  // SUBMIT REVISION
  // ------------------------------------------
  Future<void> submitRevision() async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/resubmit-article/${widget.articleId}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "author_email": widget.authorEmail,
          "content": _contentController.text,
        }),
      );

      if (res.statusCode == 200) {
        Navigator.pop(context, true);
        Fluttertoast.showToast(
          msg: "Revision submitted!",
          backgroundColor: Colors.green,
        );
      }
    } catch (_) {}
  }

  // ------------------------------------------
  // FULL SCREEN EDITOR
  // ------------------------------------------
  void enterFullScreenEditor() {
    setState(() => fullScreenMode = true);
  }

  void exitFullScreenEditor() {
    setState(() => fullScreenMode = false);
  }

  // ------------------------------------------
  // BUILD UI
  // ------------------------------------------
  @override
  Widget build(BuildContext context) {
    return fullScreenMode
        ? buildFullScreenEditor()
        : buildMainPage();
  }

  // ------------------------------------------
  // FULL-SCREEN EDITOR WIDGET
  // ------------------------------------------
  Widget buildFullScreenEditor() {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          // Top bar with Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // spacer for symmetry
              Text(
                "Full Screen Editor",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 26),
                onPressed: exitFullScreenEditor,
              )
            ],
          ),

          // Expanded Text Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: null,
                expands: true,          // <-- IMPORTANT
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Word Count (Live Updating)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Word Count: $wordCount",
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  // ------------------------------------------
  // MAIN REVISION PAGE
  // ------------------------------------------
  Widget buildMainPage() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            "assets/icons/back.svg",
            width: 22,
            colorFilter:
                const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Revision Needed",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace:
            Container(decoration: BoxDecoration(gradient: AppTheme.titleGradient)),
        actions: [
          if (showSavedTick)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.check_circle, color: Colors.white),
            )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ------------------------------------------
          // EDITOR FEEDBACK (FULL WIDTH)
          // ------------------------------------------
          if (widget.feedback != null && widget.feedback!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EDITOR FEEDBACK",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange.shade900)),
                  const SizedBox(height: 6),
                  Text(widget.feedback!,
                      style: GoogleFonts.poppins(fontSize: 14)),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ------------------------------------------
          // MEDIA SECTION — SMART (1 = full width, many = carousel)
          // ------------------------------------------
          if (widget.mediaFiles != null && widget.mediaFiles!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Media Attachments",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                widget.mediaFiles!.length == 1
                    ? buildSingleMedia(widget.mediaFiles!.first)
                    : buildCarouselMedia(widget.mediaFiles!),
              ],
            ),

          const SizedBox(height: 20),

          // ------------------------------------------
          // ARTICLE TITLE
          // ------------------------------------------
          Text(widget.headline,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 6),
          Text("Category: ${widget.category}",
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade700, fontSize: 14)),

          const SizedBox(height: 20),

          // ------------------------------------------
          // HIGHLIGHTED TEXT
          // ------------------------------------------
          Text("Highlighted Sections",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.shadowBlack)),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText.rich(TextSpan(children: buildHighlightedSpans())),
          ),

          const SizedBox(height: 25),

          // ------------------------------------------
          // REVISED CONTENT INPUT
          // ------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Revised Content",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16)),

              // FULL SCREEN BUTTON
              IconButton(
                icon: const Icon(Icons.open_in_full),
                onPressed: enterFullScreenEditor,
              ),
            ],
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _contentController,
            maxLines: 10,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 8),

          Text("Word Count: $wordCount",
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600)),

          const SizedBox(height: 25),

          // ------------------------------------------
          // SUBMIT BUTTON (GRADIENT)
          // ------------------------------------------
          Container(
            height: 55,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF9A825), Color(0xFFF57C00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: submitRevision,
                child: Center(
                  child: Text(
                    "Submit Revision",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ------------------------------------------
  // MEDIA WIDGETS
  // ------------------------------------------
  // Helper para i-extract ang URL kahit String o Map ang media item
String _extractUrl(dynamic item) {
  if (item is String) return item;
  if (item is Map) return item["url"]?.toString() ?? "";
  return "";
}

String _extractThumb(dynamic item) {
  if (item is String) return item;
  if (item is Map) return item["thumbnail"]?.toString() ?? item["url"]?.toString() ?? "";
  return "";
}

Widget buildSingleMedia(dynamic mediaItem) {
  final url = _extractUrl(mediaItem);
  final thumb = _extractThumb(mediaItem);
  final isVideo = url.toLowerCase().endsWith(".mp4") ||
      url.toLowerCase().endsWith(".mov");

  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: double.infinity,
      height: 220,
      color: Colors.black12,
      child: isVideo
          ? Stack(
              alignment: Alignment.center,
              children: [
                if (thumb.isNotEmpty && thumb != url)
                  Image.network(thumb, fit: BoxFit.cover,
                      width: double.infinity, height: double.infinity,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black))
                else
                  Container(color: Colors.black87),
                Icon(Icons.play_circle_fill,
                    size: 52, color: Colors.white.withOpacity(0.9)),
              ],
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, size: 40)),
            ),
    ),
  );
}

Widget buildCarouselMedia(List<dynamic> media) {
  return Column(
    children: [
      SizedBox(
        height: 230,
        child: PageView.builder(
          controller: _mediaController,
          itemCount: media.length,
          itemBuilder: (_, index) {
            final item = media[index];
            final url = _extractUrl(item);
            final thumb = _extractThumb(item);
            final isVideo = url.toLowerCase().endsWith(".mp4") ||
                url.toLowerCase().endsWith(".mov");

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                color: Colors.black12,
                child: isVideo
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          if (thumb.isNotEmpty && thumb != url)
                            Image.network(thumb, fit: BoxFit.cover,
                                width: double.infinity, height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.black))
                          else
                            Container(color: Colors.black87),
                          Icon(Icons.play_circle_fill,
                              size: 52, color: Colors.white.withOpacity(0.9)),
                        ],
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image, size: 40)),
                      ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      SmoothPageIndicator(
        controller: _mediaController,
        count: media.length,
        effect: WormEffect(
          dotWidth: 10,
          dotHeight: 10,
          spacing: 8,
          activeDotColor: AppTheme.primaryOrange,
          dotColor: Colors.grey.shade400,
        ),
      ),
    ],
  );
}}