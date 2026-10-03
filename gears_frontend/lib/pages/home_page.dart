import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gears_frontend/utils/notifications/app_toastification.dart';
import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';
import 'package:gears_frontend/widgets/bottom_nav.dart';
import 'package:gears_frontend/pages/articledetail_page.dart';
import 'package:gears_frontend/pages/notification_page.dart';

class HomePage extends StatefulWidget {
  final String email;
  final int userId;
  final String userStatus;

  const HomePage({
    super.key,
    required this.email,
    required this.userId,
    required this.userStatus,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _unreadCount = 0;
  late RealtimeChannel notifChannel;

  int _selectedCategoryIndex = 0;
  final int _bottomNavIndex = 0;

  bool isLoading = true;
  bool showScrollButton = false;
  bool showRefreshBanner = false;
  bool hasError = false;
  String errorMessage = '';

  late String _userStatus;

  List<dynamic> articles = [];
  List<dynamic> filteredArticles = [];
  List<Map<String, dynamic>> categories = [];

  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;
  late AnimationController _bannerController;
  late AnimationController _errorShakeController;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _userStatus = widget.userStatus;
    _listenToNotifications();
    _loadUnreadCount();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _errorShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scrollController.addListener(_scrollListener);

    _initializeData();

    _refreshUserStatus().then((_) {
      if (mounted) _showStatusNotification();
    });
  }

  @override
  void dispose() {
    notifChannel.unsubscribe();
    _fadeController.dispose();
    _bannerController.dispose();
    _errorShakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchCategories();
    await fetchArticles();
  }

  // ===========================================================================
  // MEDIA HELPER
  // ===========================================================================

  /// Parses any media format from the backend into a clean list of maps.
  /// Backend's resolve_media_url() always returns List<Map> with url/thumbnail/type.
  List<Map<String, dynamic>> safeMediaList(dynamic raw) {
    if (raw == null) return [];

    List items = [];

    if (raw is List) {
      items = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) items = decoded;
      } catch (_) {}
    } else if (raw is Map) {
      // Tkinter dict fallback: {"file_paths": ["photo.jpg"]}
      final fps = raw["file_paths"];
      if (fps is List) {
        return fps
            .map((f) => f.toString().trim())
            .where((f) => f.isNotEmpty)
            .map((f) => {"url": f, "thumbnail": f, "type": "image"})
            .toList();
      }
      return [];
    }

    return items
        .whereType<Map>()
        .map((e) => {
              "url": (e["url"] ?? "").toString(),
              "thumbnail": (e["thumbnail"] ?? e["url"] ?? "").toString(),
              "type": (e["type"] ?? "image").toString(),
            })
        .where((e) => e["url"]!.isNotEmpty)
        .toList();
  }

  /// Returns true if the media item is a video
  bool _isVideo(Map<String, dynamic> item) {
    final type = (item["type"] ?? "").toString().toLowerCase();
    if (type == "video") return true;
    // Fallback: check URL extension
    final url = (item["url"] ?? "").toString().toLowerCase().split("?").first;
    return url.endsWith(".mp4") ||
        url.endsWith(".mov") ||
        url.endsWith(".avi") ||
        url.endsWith(".mkv") ||
        url.endsWith(".webm");
  }

  /// Gets the best display URL: for videos uses thumbnail, for images uses url.
  /// Falls back gracefully if thumbnail is empty.
  String _displayUrl(Map<String, dynamic> item) {
    final thumb = (item["thumbnail"] ?? "").toString().trim();
    final url = (item["url"] ?? "").toString().trim();
    // For videos, prefer thumbnail (generated by backend FFmpeg)
    if (_isVideo(item)) {
      return thumb.isNotEmpty ? thumb : url;
    }
    // For images, thumbnail and url are usually the same
    return thumb.isNotEmpty ? thumb : url;
  }

  // ===========================================================================
  // VIDEO THUMBNAIL WIDGET
  // ===========================================================================

  /// Builds a media item with a play icon overlay for videos.
  /// Works for both images and videos — videos show a thumbnail + play badge.
  Widget _buildMediaItem(
    Map<String, dynamic> item, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    final displayUrl = _displayUrl(item);
    final isVideo = _isVideo(item);

    if (displayUrl.isEmpty) {
      return _buildImagePlaceholder(height: height, width: width);
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Thumbnail or image
        CachedNetworkImage(
          imageUrl: displayUrl,
          fit: fit,
          height: height,
          width: width ?? double.infinity,
          placeholder: (_, __) => Container(
            height: height,
            width: width,
            color: Colors.grey.shade200,
          ),
          errorWidget: (_, __, ___) => _buildImagePlaceholder(
            height: height,
            width: width,
          ),
        ),
        // Video play badge overlay
        if (isVideo)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.35),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.85),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  void _listenToNotifications() {
    final supabase = Supabase.instance.client;
    notifChannel = supabase.channel("home-notif-stream")
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: "public",
        table: "notifications",
        callback: (payload) {
          final data = payload.newRecord;
          if (data["user_id"] == widget.userId) {
            if (mounted) setState(() => _unreadCount++);
            AppToastification.info(
              context,
              data["title"] ?? "New notification",
            );
            if (data["type"] == "system") {
              _refreshUserStatus();
            }
          }
        },
      )
      ..subscribe();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await http.get(
          Uri.parse("$baseUrl/notifications/unread-count/${widget.userId}"));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() => _unreadCount = data["count"] ?? 0);
      }
    } catch (e) {
      print("Unread notif error: $e");
    }
  }

  // ===========================================================================
  // CATEGORIES
  // ===========================================================================

  Future<void> _fetchCategories() async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/get-categories"))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        List<dynamic> data;
        if (body is List) {
          data = body;
        } else if (body is Map && body["categories"] is List) {
          data = body["categories"];
        } else {
          data = [];
        }

        setState(() {
          categories = [
            {"name": "Home", "icon": Icons.home},
            ...data
                .where((cat) =>
                    cat["name"] != null &&
                    cat["name"].toString().toLowerCase() != "home")
                .map((cat) => {
                      "name": cat["name"],
                      "icon": _getIconFromString(cat["icon"] ?? "article"),
                    })
                .toList(),
          ];
        });
      } else {
        _setDefaultCategories();
      }
    } catch (e) {
      print("CATEGORY ERROR: $e");
      _setDefaultCategories();
    }
  }

  void _setDefaultCategories() {
    setState(() {
      categories = [
        {"name": "Home", "icon": Icons.home},
        {"name": "News", "icon": Icons.newspaper},
        {"name": "Updates", "icon": Icons.update},
        {"name": "Opinion", "icon": Icons.forum},
        {"name": "Feature", "icon": Icons.star},
        {"name": "Literary", "icon": Icons.book},
        {"name": "Komiks", "icon": Icons.auto_stories},
        {"name": "Arts", "icon": Icons.palette},
        {"name": "Photos", "icon": Icons.photo_library},
        {"name": "Videos", "icon": Icons.video_library},
      ];
    });
  }

  IconData _getIconFromString(String iconName) {
    const iconMap = {
      'home': Icons.home,
      'newspaper': Icons.newspaper,
      'update': Icons.update,
      'forum': Icons.forum,
      'star': Icons.star,
      'book': Icons.book,
      'auto_stories': Icons.auto_stories,
      'palette': Icons.palette,
      'photo_library': Icons.photo_library,
      'video_library': Icons.video_library,
      'article': Icons.article,
    };
    return iconMap[iconName.toLowerCase()] ?? Icons.article;
  }

  // ===========================================================================
  // USER STATUS
  // ===========================================================================

  Future<void> _refreshUserStatus() async {
    if (widget.userId == 0) return;
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/get-user-status/${widget.userId}"));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final newStatus =
            (data["status"] ?? "").toString().trim().toLowerCase();
        setState(() => _userStatus = newStatus);
      }
    } catch (e) {
      print("Failed to refresh status: $e");
    }
  }

  void _showStatusNotification() {
    if (_userStatus.isEmpty) return;
    if (_userStatus == "pending") {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          AppToastification.warning(
            context,
            "Your account is pending. You cannot comment until approved.",
          );
        }
      });
    }
  }

  // ===========================================================================
  // ARTICLES
  // ===========================================================================

  Future<void> fetchArticles({bool showBanner = false}) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse("$baseUrl/get-published-articles"))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> data;
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map && decoded["articles"] is List) {
          data = decoded["articles"];
        } else {
          data = [];
        }

        // Sort newest first
        data.sort((a, b) {
          DateTime parseDate(dynamic raw) {
            if (raw == null) return DateTime(2000);
            final fixed = raw.toString().replaceFirst(" ", "T");
            return DateTime.tryParse(fixed) ?? DateTime(2000);
          }
          return parseDate(b["created_at"])
              .compareTo(parseDate(a["created_at"]));
        });

        setState(() {
          articles = data;
          filteredArticles = data;
          isLoading = false;
          hasError = false;
        });

        if (showBanner && mounted) _triggerRefreshBanner();
      } else {
        throw Exception("Status ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage =
            "Unable to load articles. Please check your connection.";
      });
      _errorShakeController
          .forward()
          .then((_) => _errorShakeController.reverse());
      AppToastification.error(context, "Error loading articles: $e");
    }
  }

  void _triggerRefreshBanner() async {
    setState(() => showRefreshBanner = true);
    _bannerController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _bannerController.reverse();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) setState(() => showRefreshBanner = false);
    }
  }

  // ===========================================================================
  // UTILITY
  // ===========================================================================

  void _scrollListener() {
    if (_scrollController.offset > 400 && !showScrollButton) {
      setState(() => showScrollButton = true);
    } else if (_scrollController.offset <= 400 && showScrollButton) {
      setState(() => showScrollButton = false);
    }
  }

  String normalizeCategory(String? x) {
    return (x ?? "")
        .toLowerCase()
        .trim()
        .replaceAll("-", " ")
        .replaceAll("_", " ");
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return "Unknown date";
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.isNegative) return "Just now";
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return "Just now";
        return "${diff.inMinutes}m ago";
      }
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return DateFormat("MMM dd, yyyy • hh:mm a").format(dt);
    } catch (_) {
      return "Unknown date";
    }
  }

  void _openArticle(dynamic article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(
          article: article,
          userId: widget.userId,
          userStatus: _userStatus,
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeIn,
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchCategories();
                await fetchArticles(showBanner: true);
              },
              color: AppTheme.primaryRed,
              child: _buildHomeContent(),
            ),
          ),
          if (showRefreshBanner) _buildRefreshBanner(),
        ],
      ),
      floatingActionButton: _buildScrollTopButton(),
      bottomNavigationBar: BottomNav(
        currentIndex: _bottomNavIndex,
        email: widget.email,
        userId: widget.userId,
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/gears_logo.png', height: 34),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              "The Gears",
              style: GoogleFonts.hedvigLettersSerif(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: SvgPicture.asset(
                  'assets/icons/notification.svg',
                  height: 26,
                  color: Colors.white,
                ),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) =>
                        NotificationPage(userId: widget.userId),
                  ),
                );
                _loadUnreadCount();
              },
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey.shade300),
      ),
    );
  }

  // ===========================================================================
  // HOME CONTENT
  // ===========================================================================

  Widget _buildHomeContent() {
    if (categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedCategory =
        categories[_selectedCategoryIndex]["name"] as String;
    final selected = normalizeCategory(selectedCategory);

    final visibleArticles = selected == "home"
        ? filteredArticles
        : filteredArticles.where((a) {
            return normalizeCategory(a["category"]) == selected;
          }).toList();

    return ListView(
      controller: _scrollController,
      children: [
        const SizedBox(height: 12),
        _buildCategoryTabs(),
        const SizedBox(height: 20),

        if (hasError) ...[
          const SizedBox(height: 40),
          _buildErrorState(),
        ] else if (isLoading) ...[
          _buildLoadingShimmers(),
        ] else if (visibleArticles.isEmpty) ...[
          const SizedBox(height: 60),
          _buildEmptyState(selectedCategory),
        ] else ...[
          if (selectedCategory == "Home") ...[
            const SizedBox(height: 10),
            _buildFeaturedArticle(visibleArticles.first),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Latest Articles",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    "${visibleArticles.length} articles",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildArticleList(selectedCategory, visibleArticles),
          ),
          const SizedBox(height: 80),
        ],
      ],
    );
  }

  // ===========================================================================
  // CATEGORY TABS
  // ===========================================================================

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final bool selected = _selectedCategoryIndex == index;
          final category = categories[index];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryIndex = index);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient:
                    selected ? AppTheme.categorySelectedGradient : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppTheme.borderGrey,
                ),
                boxShadow:
                    selected ? AppTheme.selectedTabShadow : const [],
              ),
              child: Row(
                children: [
                  Icon(
                    category["icon"] as IconData,
                    size: 18,
                    color: selected ? Colors.white : AppTheme.textGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category["name"] as String,
                    style: selected
                        ? AppTheme.categoryTextSelected
                        : AppTheme.categoryTextUnselected,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // ARTICLE LIST & SMART CARD ROUTER
  // ===========================================================================

  Widget _buildArticleList(
      String category, List<dynamic> visibleArticles) {
    if (visibleArticles.isEmpty) return const SizedBox();
    final items = (category == "Home" && visibleArticles.length > 1)
        ? visibleArticles.skip(1).toList()
        : visibleArticles;
    return Column(
      children: [for (var article in items) _buildSmartCard(article)],
    );
  }

  Widget _buildSmartCard(dynamic article) {
    final cat = normalizeCategory(article["category"]);
    if (cat == "news") return _buildNewsCard(article);
    if (cat == "feature") return _buildFeatureCard(article);
    if (["photos", "videos", "arts", "komiks"].contains(cat)) {
      return _buildMediaCard(article);
    }
    return _buildSimpleCard(article);
  }

  // ===========================================================================
  // IMAGE HELPERS
  // ===========================================================================

  Widget _buildImagePlaceholder({double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      color: Colors.grey.shade200,
      child: Icon(Icons.image_outlined,
          size: 50, color: Colors.grey.shade400),
    );
  }

  /// Builds an image/video collage from a media list.
  /// Each item shows a thumbnail; videos get a play icon overlay.
  Widget _buildImageCollage(List<Map<String, dynamic>> media) {
    if (media.isEmpty) return _buildImagePlaceholder();

    Widget tile(int index) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(0),
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: _buildMediaItem(media[index]),
        ),
      );
    }

    if (media.length == 1) {
      return AspectRatio(aspectRatio: 16 / 9, child: tile(0));
    }

    if (media.length == 2) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(children: [
          Expanded(child: AspectRatio(aspectRatio: 1, child: tile(0))),
          const SizedBox(width: 2),
          Expanded(child: AspectRatio(aspectRatio: 1, child: tile(1))),
        ]),
      );
    }

    if (media.length == 3) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(children: [
          Expanded(
              flex: 2,
              child: AspectRatio(aspectRatio: 1, child: tile(0))),
          const SizedBox(width: 2),
          Expanded(
            child: Column(children: [
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(1))),
              const SizedBox(height: 2),
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(2))),
            ]),
          ),
        ]),
      );
    }

    if (media.length == 4) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Column(children: [
          Expanded(
            child: Row(children: [
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(0))),
              const SizedBox(width: 2),
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(1))),
            ]),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(children: [
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(2))),
              const SizedBox(width: 2),
              Expanded(
                  child:
                      AspectRatio(aspectRatio: 1, child: tile(3))),
            ]),
          ),
        ]),
      );
    }

    // 5+ media items
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Column(children: [
        Expanded(
          child: Row(children: [
            Expanded(child: tile(0)),
            const SizedBox(width: 2),
            Expanded(child: tile(1)),
          ]),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(children: [
            Expanded(child: tile(2)),
            const SizedBox(width: 2),
            Expanded(child: tile(3)),
            const SizedBox(width: 2),
            Expanded(
              child: Stack(children: [
                tile(4),
                if (media.length > 5)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        "+${media.length - 5}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  // ===========================================================================
  // CARD WIDGETS
  // ===========================================================================

  Widget _buildFeaturedArticle(dynamic article) {
    final media = safeMediaList(article["media"]);
    final hasMedia = media.isNotEmpty;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              hasMedia
                  ? _buildImageCollage(media)
                  : AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildImagePlaceholder(),
                    ),
              // Extra video badge for featured (larger, centered)
              if (hasMedia && media.length == 1 && _isVideo(media.first))
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.9),
                            width: 2.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            article["category"] ?? "",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Media type indicator badge
                        if (hasMedia) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isVideo(media.first)
                                      ? Icons.videocam_rounded
                                      : Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                if (media.length > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    "${media.length}",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article["headline"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "By ${article["author_name"] ?? "Unknown"}",
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(dynamic article) {
    final media = safeMediaList(article["media"]);

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: media.isNotEmpty
                  ? _buildImageCollage(media)
                  : _buildImagePlaceholder(height: 200),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          article["headline"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      // Media count badge (shows video icon for video-first articles)
                      if (media.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isVideo(media.first)
                                    ? Icons.videocam_rounded
                                    : Icons.photo_library,
                                size: 14,
                                color: AppTheme.primaryOrange,
                              ),
                              if (media.length > 1) ...[
                                const SizedBox(width: 4),
                                Text(
                                  "${media.length}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "By ${article["author_name"] ?? "Unknown"}",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(dynamic article) {
    final media = safeMediaList(article["media"]);
    final hasMedia = media.isNotEmpty;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: SizedBox(
                height: 100,
                width: 120,
                child: hasMedia
                    ? _buildMediaItem(
                        media.first,
                        height: 100,
                        width: 120,
                      )
                    : _buildImagePlaceholder(height: 100, width: 120),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article["headline"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "By ${article["author_name"] ?? "Unknown"}",
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.textGrey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article["created_at"]),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600),
                        ),
                        if (hasMedia && _isVideo(media.first)) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.videocam_rounded,
                              size: 13,
                              color: AppTheme.primaryOrange),
                        ],
                      ],
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

  Widget _buildMediaCard(dynamic article) {
    final media = safeMediaList(article["media"]);
    final hasMedia = media.isNotEmpty;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            article["category"] ?? "",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // Video indicator for media cards
                        if (hasMedia && _isVideo(media.first)) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article["headline"] ?? "",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(14)),
              child: SizedBox(
                width: 120,
                height: 110,
                child: hasMedia
                    ? _buildMediaItem(
                        media.first,
                        height: 110,
                        width: 120,
                      )
                    : _buildImagePlaceholder(height: 110, width: 120),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(dynamic article) {
    final media = safeMediaList(article["media"]);
    final hasMedia = media.isNotEmpty;

    return GestureDetector(
      onTap: () => _openArticle(article),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          boxShadow: AppTheme.lightCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasMedia)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: _buildImageCollage(media),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          article["category"] ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                      ),
                      if (media.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                // Show video icon if first item is video
                                _isVideo(media.first)
                                    ? Icons.videocam_rounded
                                    : Icons.photo_library,
                                size: 12,
                                color: Colors.grey.shade700,
                              ),
                              if (media.length > 1) ...[
                                const SizedBox(width: 4),
                                Text(
                                  "${media.length}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article["headline"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "By ${article["author_name"] ?? "Unknown"}",
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textGrey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article["content"] ?? "",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(article["created_at"]),
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SHIMMER / ERROR / EMPTY
  // ===========================================================================

  Widget _buildLoadingShimmers() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildShimmerCard(height: 280),
          const SizedBox(height: 20),
          ...List.generate(3, (_) => _buildShimmerCard(height: 200)),
        ],
      ),
    );
  }

  Widget _buildShimmerCard({required double height}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return AnimatedBuilder(
      animation: _errorShakeController,
      builder: (context, child) {
        final offset = Tween<double>(begin: 0, end: 10)
            .chain(CurveTween(curve: Curves.elasticIn))
            .animate(_errorShakeController);
        return Transform.translate(
          offset: Offset(
              offset.value * 2 * (_errorShakeController.value * 2 - 1),
              0),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              "Oops! Something went wrong",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => fetchArticles(),
              icon: const Icon(Icons.refresh),
              label: Text("Try Again",
                  style:
                      GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.textDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.article_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            "No articles in $category",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later for new content",
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _bannerController,
          curve: Curves.easeOut,
        )),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "Articles refreshed successfully!",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollTopButton() {
    if (!showScrollButton) return const SizedBox.shrink();
    return FloatingActionButton(
      onPressed: () => _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ),
      backgroundColor: AppTheme.primaryRed,
      child: const Icon(Icons.arrow_upward, color: Colors.white),
    );
  }
}