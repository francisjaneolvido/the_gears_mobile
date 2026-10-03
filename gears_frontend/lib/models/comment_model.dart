class CommentModel {
  final int id;
  final int articleId;
  final int userId;
  final String content;
  final int? parentId;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;

  List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.content,
    required this.parentId,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json["id"],
      articleId: json["article_id"],
      userId: json["user_id"],
      content: json["comment"],
      parentId: json["parent_id"],
      createdAt: DateTime.parse(json["created_at"]),
      userName: json["full_name"] ?? "Unknown User",
      userAvatar: json["profile_picture"],
      replies: (json["replies"] as List<dynamic>? ?? [])
          .map((r) => CommentModel.fromJson(r))
          .toList(),
    );
  }
}
