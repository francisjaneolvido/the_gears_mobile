class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final String createdAt;
  final bool isRead;

  final int? articleId;
  final int? commentId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.articleId,
    this.commentId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json["id"],
      type: json["type"] ?? "system", // default fallback
      title: json["title"] ?? "",
      message: json["message"] ?? "",
      createdAt: json["created_at"] ?? "",
      isRead: json["is_read"] == true,  // converts 0/1 or bool
      articleId: json["article_id"],
      commentId: json["comment_id"],
    );
  }
}
