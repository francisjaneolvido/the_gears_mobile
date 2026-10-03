// lib/widgets/article_list_base.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class ArticleListBase extends StatefulWidget {
  final String category;
  final Widget Function(dynamic article) builder;

  const ArticleListBase({super.key, required this.category, required this.builder});

  @override
  State<ArticleListBase> createState() => _ArticleListBaseState();
}

class _ArticleListBaseState extends State<ArticleListBase> {
  bool isLoading = true;
  List<dynamic> articles = [];

  @override
  void initState() {
    super.initState();
    fetchArticles();
  }

  Future<void> fetchArticles() async {
    final url = widget.category == "Home"
        ? "$baseUrl/get-articles"
        : "$baseUrl/get-articles/${widget.category}";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      setState(() {
        articles = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return const Center(child: Text("No articles found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 60),
      itemCount: articles.length,
      itemBuilder: (context, index) => widget.builder(articles[index]),
    );
  }
}
