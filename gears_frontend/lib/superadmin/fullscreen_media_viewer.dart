import 'package:flutter/material.dart';
import 'package:gears_frontend/widgets/video_player_widget.dart';
import 'package:google_fonts/google_fonts.dart';

// Correct conditional import
import 'fullscreen_media_opener_mobile.dart'
    if (dart.library.js) 'fullscreen_media_opener_web.dart';

class FullscreenMediaViewer extends StatelessWidget {
  final String url;
  final String type;

  const FullscreenMediaViewer({
    super.key,
    required this.url,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          type.toUpperCase(),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
      body: Center(
        child: _buildPreview(type),
      ),
    );
  }

  Widget _buildPreview(String type) {
    if (type == "image") {
      return InteractiveViewer(
        child: Image.network(url, fit: BoxFit.contain),
      );
    }

    if (type == "video") {
      return VideoPlayerWidget(videoUrl: url);
    }

    if (type == "pdf") {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 100),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => openPdfUrl(url),
            child: const Text("Open PDF"),
          ),
        ],
      );
    }

    return const Text(
      "Unsupported file type",
      style: TextStyle(color: Colors.white),
    );
  }
}
