import '../models/comment_model.dart';

List<CommentModel> buildThreadedComments(List<CommentModel> flat) {
  final lookup = <int, CommentModel>{};
  final roots = <CommentModel>[];

  // index all comments
  for (var c in flat) {
    lookup[c.id] = c;
    c.replies = [];
  }

  // assign children
  for (var c in flat) {
    if (c.parentId == null) {
      roots.add(c);
    } else {
      lookup[c.parentId]?.replies.add(c);
    }
  }

  return roots;
}
