import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/bottom_nav.dart';
import 'package:gears_frontend/pages/articledetail_page.dart';

class SearchPage extends StatefulWidget {
  final String? email;
  final int? userId;

  const SearchPage({super.key, this.email, this.userId});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> recentSearches = [];
  List<dynamic> allArticles = [];
  List<dynamic> filteredArticles = [];

  bool isLoading = true;
  int _selectedIndex = 1;

  final List<String> recommendations = const [
    "Campus News",
    "Sports Highlights",
    "Technology Trends",
    "Student Achievements",
    "Editorials",
    "Events & Announcements",
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _fetchArticles();
    _searchController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTyping);
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- DATA ----------------

  Future<void> _fetchArticles() async {
    try {
      final response =
          await http.get(Uri.parse("$baseUrl/get-published-articles"));
      if (response.statusCode == 200) {
        setState(() {
          allArticles = jsonDecode(response.body);
          filteredArticles = List.from(allArticles);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load articles");
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading articles: $e")),
      );
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }

  Future<void> _saveSearch(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches.remove(trimmed);
      recentSearches.insert(0, trimmed);
      if (recentSearches.length > 5) {
        recentSearches = recentSearches.sublist(0, 5);
      }
    });
    await prefs.setStringList('recentSearches', recentSearches);
  }

  // ---------------- DYNAMIC RECOMMENDATIONS ----------------

  List<String> getDynamicRecommendations(String query) {
    if (query.isEmpty) return recommendations;

    query = query.toLowerCase();

    return recommendations
        .where((item) => item.toLowerCase().contains(query))
        .toList();
  }

  // ---------------- SEARCH LOGIC ----------------

  void _onTyping() {
    final term = _searchController.text.trim().toLowerCase();

    if (term.isEmpty) {
      setState(() {
        filteredArticles = List.from(allArticles);
      });
      return;
    }

    setState(() {
      filteredArticles = allArticles.where((article) {
        final headline = (article["headline"] ?? "").toString().toLowerCase();
        final category = (article["category"] ?? "").toString().toLowerCase();
        final author = (article["author_name"] ?? "").toString().toLowerCase();
        return headline.contains(term) ||
            category.contains(term) ||
            author.contains(term);
      }).toList();
    });
  }

  void _onSearchSubmit(String term) {
    _saveSearch(term);
    _onTyping();
    FocusScope.of(context).unfocus();
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Search",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryRed,
                      ),
                    )
                  : hasQuery && filteredArticles.isEmpty
                      ? _buildNoResults()
                      : hasQuery
                          ? _buildDynamicRecommendations()
                          : _buildDefaultSections(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _selectedIndex,
        email: widget.email ?? "",
        userId: widget.userId ?? 0,
      ),
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.lightCardShadow,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.poppins(
          fontSize: 14.5,
          color: AppTheme.textDark,
        ),
        decoration: InputDecoration(
          hintText: "Search articles, authors, or categories...",
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.textGrey,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryRed),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      filteredArticles = List.from(allArticles);
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        onSubmitted: _onSearchSubmit,
      ),
    );
  }

  // ---------------- Dynamic Suggestions (NEW FEATURE) ----------------

  Widget _buildDynamicRecommendations() {
    final recs = getDynamicRecommendations(_searchController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: recs
              .map(
                (term) => ActionChip(
                  label: Text(term),
                  labelStyle: GoogleFonts.poppins(
                    color: AppTheme.primaryRed,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor: AppTheme.backgroundLight,
                  onPressed: () {
                    _searchController.text = term;
                    _onTyping();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildResultsList()),
      ],
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: filteredArticles.length,
      itemBuilder: (context, i) => _buildResultCard(filteredArticles[i]),
    );
  }

  Widget _buildNoResults() {
    final term = _searchController.text.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "No results for “$term”",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try searching with different keywords or check out these topics:",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Recommended Topics",
            style: AppTheme.cardTitleText,
          ),
          const SizedBox(height: 10),
          _buildHorizontalList(recommendations),
        ],
      ),
    );
  }

  Widget _buildDefaultSections() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Text("Recent Searches", style: AppTheme.cardTitleText),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: recentSearches
                  .map(
                    (term) => ActionChip(
                      label: Text(term),
                      labelStyle: GoogleFonts.poppins(
                        color: AppTheme.primaryRed,
                        fontSize: 13,
                      ),
                      backgroundColor: AppTheme.backgroundLight,
                      onPressed: () {
                        _searchController.text = term;
                        _onTyping();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          Text("Recommended Topics", style: AppTheme.cardTitleText),
          const SizedBox(height: 10),
          _buildHorizontalList(recommendations),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(List<String> topics) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: topics.length,
        itemBuilder: (context, i) => _buildRecommendationCard(
          topics[i],
          'assets/images/sample_pic${(i % 3) + 1}.jpg',
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(String text, String imagePath) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        _onTyping();
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppTheme.imageOverlayGradient,
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(dynamic article) {
    String? imageUrl;
    if (article["media"] != null && article["media"].toString().isNotEmpty) {
      try {
        final mediaList =
            article["media"] is String ? jsonDecode(article["media"]) : article["media"];
        if (mediaList is List && mediaList.isNotEmpty) {
          imageUrl = mediaList[0]["thumbnail"] ?? mediaList[0]["url"];
        }
      } catch (_) {}
    }

    final displayImage = imageUrl ?? 'assets/images/sample_pic2.jpg';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ArticleDetailPage(article: article, userId: widget.userId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: displayImage.startsWith("http")
                  ? Image.network(
                      displayImage,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      displayImage,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article["headline"] ?? "Untitled",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "By ${article["author_name"] ?? "Unknown"} • ${article["category"] ?? ""}",
                      style: GoogleFonts.poppins(
                        color: AppTheme.textGrey,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
