import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/theme/app_theme.dart';

class MagazineLayoutPage extends StatefulWidget {
  final Map<String, dynamic> article;

  const MagazineLayoutPage({super.key, required this.article});

  @override
  State<MagazineLayoutPage> createState() => _MagazineLayoutPageState();
}

class _MagazineLayoutPageState extends State<MagazineLayoutPage> {
  final PageController _controller = PageController();
  int currentPage = 0;

  late List<String> textPages;
  late List<String> imageUrls;

  @override
  void initState() {
    super.initState();

    /// 1) FIX MEDIA URLS + ENSURE LIST
    final media = widget.article["media"];
    imageUrls = [];

    if (media is List) {
      for (var m in media) {
        imageUrls.add(_fullUrl(m.toString()));
      }
    } else if (media is String) {
      try {
        List parsed = jsonDecode(media);
        imageUrls = parsed.map((m) => _fullUrl(m.toString())).toList();
      } catch (_) {
        imageUrls = [ _fullUrl(media) ];
      }
    }

    /// 2) Split long text into multiple pages
    textPages = _splitArticleText(widget.article['content'] ?? "");
  }

  String _fullUrl(String file) {
    if (file.startsWith("http")) return file;
    return "$baseUrl/uploads/$file"; 
  }

  /// Splits article text into multiple reading pages
  List<String> _splitArticleText(String text) {
    const int charLimit = 1200; // adjust for more / less text per page

    List<String> pages = [];
    for (int i = 0; i < text.length; i += charLimit) {
      pages.add(
        text.substring(i, (i + charLimit > text.length) ? text.length : i + charLimit)
      );
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    /// We interleave pages:
    /// [Image page], [Text page], [Next image], [Next text], etc.

    List<Widget> finalPages = [];

    int maxPages = imageUrls.length > textPages.length
        ? imageUrls.length
        : textPages.length;

    for (int i = 0; i < maxPages; i++) {
      if (i < imageUrls.length) {
        finalPages.add(_buildImagePage(imageUrls[i]));
      }
      if (i < textPages.length) {
        finalPages.add(_buildTextPage(textPages[i], i == 0));
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: finalPages.length,
            onPageChanged: (i) => setState(() => currentPage = i),
            itemBuilder: (_, i) => finalPages[i],
          ),

          /// BACK BUTTON (overlay)
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              ),
            ),
          ),

          /// PAGE COUNTER
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Text(
              "Page ${currentPage + 1} of ${finalPages.length}",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FULLSCREEN IMAGE PAGE WITH OVERLAY TEXT
  Widget _buildImagePage(String url) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          /// image
          Image.network(
            url,
            fit: BoxFit.cover, // No stretching, preserves aspect ratio
            errorBuilder: (_, __, ___) => Container(color: Colors.black26),
          ),

          /// bottom social bar (optional aesthetic)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                "@TheGearsOfficial   |   thegearspublication@gmail.com",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FULLSCREEN TEXT PAGE (Magazine style)
  Widget _buildTextPage(String text, bool firstPage) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 60),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstPage) ...[
              Text(
                widget.article["headline"] ?? "",
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.article["author_name"] ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 25),
            ],

            /// Article content
            Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.poppins(
                fontSize: 18,
                height: 1.55,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
