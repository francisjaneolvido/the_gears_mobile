import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../utils/config.dart'; // adjust path if needed

class SuperAdminEditArticlePage extends StatefulWidget {
  final int articleId;

  const SuperAdminEditArticlePage({
    super.key,
    required this.articleId,
  });

  @override
  State<SuperAdminEditArticlePage> createState() =>
      _SuperAdminEditArticlePageState();
}

class _SuperAdminEditArticlePageState
    extends State<SuperAdminEditArticlePage> {
  final TextEditingController headlineCtrl = TextEditingController();
  final TextEditingController contentCtrl = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  // ----------------------------------------------------------
  // LOAD EXISTING ARTICLE
  // ----------------------------------------------------------
  Future<void> _loadArticle() async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/get-article/${widget.articleId}"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        headlineCtrl.text = data["headline"] ?? "";
        contentCtrl.text = data["content"] ?? "";
      }
    } catch (e) {
      debugPrint("Load edit article error: $e");
    }

    setState(() => loading = false);
  }

  // ----------------------------------------------------------
  // SAVE CHANGES (PATCH)
  // ----------------------------------------------------------
  Future<void> _saveChanges() async {
    try {
      final res = await http.patch(
        Uri.parse("$baseUrl/edit-article/${widget.articleId}"),  // <--- FIXED
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "headline": headlineCtrl.text.trim(),
          "content": contentCtrl.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        Navigator.pop(context, true); // return success
      } else {
        debugPrint("Save failed: ${res.body}");
      }
    } catch (e) {
      debugPrint("Save edit article error: $e");
    }
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Article"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: headlineCtrl,
                    decoration: const InputDecoration(labelText: "Headline"),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TextField(
                      controller: contentCtrl,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        labelText: "Content",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text("Save Changes"),
                  ),
                ],
              ),
            ),
    );
  }
}
