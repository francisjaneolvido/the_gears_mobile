import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:gears_frontend/theme/app_theme.dart';
import 'package:gears_frontend/utils/config.dart';

class ActivityLogPage extends StatefulWidget {
  final String viewerEmail; // SUPERADMIN or ADMIN email

  const ActivityLogPage({super.key, required this.viewerEmail});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  List<dynamic> logs = [];
  bool isLoading = true;
  bool isLoadingMore = false;

  int offset = 0;
  final int limit = 50;
  bool hasMore = true;

  // Filters
  String selectedRole = "All";
  String selectedAction = "All";
  String searchQuery = "";

  DateTime? startDate;
  DateTime? endDate;

  List<String> roleOptions = ["All", "admin", "superadmin", "user"];
  List<String> actionOptions = [
    "All", "approved", "edited", "deleted", "submitted", "promoted", "verified"
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  // ----------------------------------------------------------
  // BACKEND FETCH
  // ----------------------------------------------------------
  Future<void> _fetchLogs() async {
    try {
      final res = await http.get(Uri.parse(
          "$baseUrl/get-activity-logs?viewer_email=${widget.viewerEmail}&limit=$limit&offset=$offset"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          logs.addAll(data["logs"]);
          offset = data["next_offset"];
          hasMore = data["has_more"];
        });
      }
    } catch (e) {
      print("Activity Log Error: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !hasMore) return;

    setState(() => isLoadingMore = true);
    await _fetchLogs();
    setState(() => isLoadingMore = false);
  }
String _formatRelative(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  if (diff.inDays == 1) return "Yesterday";
  if (diff.inDays < 7) return "${diff.inDays}d ago";

  return DateFormat("MMM dd, yyyy • hh:mm a").format(date);
}

  // ----------------------------------------------------------
  // DATE HELPERS
  // ----------------------------------------------------------
DateTime _parseDate(String raw) {
  try {
    // Fix missing end part
    if (raw.length < 19) {
      // Append missing seconds and mark UTC
      raw = raw + ":00Z";
    }

    // Fix missing T
    if (raw.contains(" ") && !raw.contains("T")) {
      raw = raw.replaceFirst(" ", "T");
    }

    // Add Z if missing
    if (!raw.endsWith("Z")) {
      raw = raw + "Z";
    }

    return DateTime.parse(raw).toLocal();
  } catch (e) {
    print("[PARSE ERROR] $raw");
    return DateTime.now();
  }
}



  // ----------------------------------------------------------
  // GROUPING LOGS (SLACK STYLE)
  // ----------------------------------------------------------
  Map<String, List<dynamic>> get groupedLogs {
    Map<String, List<dynamic>> groups = {
      "Today": [],
      "Yesterday": [],
      "This Week": [],
      "Older": [],
    };

    for (var log in filteredLogs) {
      final date = _parseDate(log["created_at"]);
      final now = DateTime.now();

      if (isSameDay(date, now)) {
        groups["Today"]!.add(log);
      } else if (isSameDay(date, now.subtract(Duration(days: 1)))) {
        groups["Yesterday"]!.add(log);
      } else if (now.difference(date).inDays < 7) {
        groups["This Week"]!.add(log);
      } else {
        groups["Older"]!.add(log);
      }
    }

    return groups;
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ----------------------------------------------------------
  // FILTERING
  // ----------------------------------------------------------
  List<dynamic> get filteredLogs {
    return logs.where((log) {
      String role = log["actor"]["role"] ?? "";
      String action = (log["action"] ?? "").toLowerCase();
      String description = (log["description"] ?? "").toLowerCase();
      String actor = (log["actor"]["name"] ?? "").toLowerCase();

      if (searchQuery.isNotEmpty &&
          !description.contains(searchQuery.toLowerCase()) &&
          !actor.contains(searchQuery.toLowerCase())) {
        return false;
      }

      if (selectedRole != "All" &&
          role.toLowerCase() != selectedRole.toLowerCase()) {
        return false;
      }

      if (selectedAction != "All" &&
          !action.contains(selectedAction.toLowerCase())) {
        return false;
      }

      if (startDate != null && endDate != null) {
        DateTime d = _parseDate(log["created_at"]);

        DateTime start = DateTime(startDate!.year, startDate!.month, startDate!.day);
        DateTime end = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59);

        if (d.isBefore(start) || d.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  // ----------------------------------------------------------
  // UI HELPERS
  // ----------------------------------------------------------
  Color _roleColor(String r) {
    switch (r) {
      case "superadmin": return Colors.red;
      case "admin": return Colors.orange;
      default: return Colors.green;
    }
  }

  IconData _iconForAction(String a) {
    a = a.toLowerCase();
    if (a.contains("approved")) return Icons.check_circle;
    if (a.contains("deleted")) return Icons.delete_forever;
    if (a.contains("edited")) return Icons.edit;
    if (a.contains("submitted")) return Icons.upload_file;
    if (a.contains("promoted")) return Icons.arrow_circle_up;
    if (a.contains("verified")) return Icons.verified;
    return Icons.event_note;
  }

  Widget _groupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _logTile(dynamic log) {
    final actor = log["actor"];
    final date = _parseDate(log["created_at"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconForAction(log["action"]), color: _roleColor(actor["role"]), size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log["description"],
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(actor["name"],
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.black87)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _roleColor(actor["role"]).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        actor["role"].toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _roleColor(actor["role"]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRelative(date),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // BUILD UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: SvgPicture.asset("assets/icons/back.svg", width: 24, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryOrange, AppTheme.primaryRed],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Text("Activity Logs",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 22)),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (scroll) {
                if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
                  _loadMore();
                }
                return true;
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  logs.clear();
                  offset = 0;
                  hasMore = true;
                  await _fetchLogs();
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 18),

                    ...groupedLogs.entries.expand((entry) {
                      if (entry.value.isEmpty) return []; // skip empty groups

                      return [
                        _groupHeader(entry.key),
                        ...entry.value.map(_logTile).toList(),
                      ];
                    }).toList(),

                    if (isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child:
                            Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // ----------------------------------------------------------
  // FILTER UI
  // ----------------------------------------------------------

  Widget _buildFilters() {
    return Column(
      children: [
        // Search bar
        TextField(
          onChanged: (v) => setState(() => searchQuery = v),
          decoration: InputDecoration(
            hintText: "Search logs...",
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryRed),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // Role & Action filters
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField(
                value: selectedRole,
                decoration: _dropdownDecoration("Role"),
                items: roleOptions
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField(
                value: selectedAction,
                decoration: _dropdownDecoration("Action"),
                items: actionOptions
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => selectedAction = v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }
}
