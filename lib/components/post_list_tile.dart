import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'comments_bottom_sheet.dart';

class PostListTile extends StatefulWidget {
  final String postId;
  final String title;
  final String subTitle;
  final String postedAt;
  final String authorId;
  final String? imageUrl;

  const PostListTile({
    super.key,
    required this.postId,
    required this.title,
    required this.subTitle,
    required this.postedAt,
    required this.authorId,
    this.imageUrl,
  });

  @override
  State<PostListTile> createState() => _PostListTileState();
}

class _PostListTileState extends State<PostListTile> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLiked = false;
  int likesCount = 0;
  int commentsCount = 0;
  List<Map<String, dynamic>> comments = [];
  String authorName = '';

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  Future<void> _loadPostData() async {
    await Future.wait([
      _checkIfLiked(),
      _loadLikesCount(),
      _loadComments(),
      _loadAuthorName(),
    ]);
  }

  Future<void> _loadAuthorName() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('username')
          .eq('id', widget.authorId)
          .maybeSingle();
      if (mounted && response != null) {
        setState(() => authorName = response['username'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _checkIfLiked() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await supabase
          .from('likes')
          .select()
          .eq('post_id', widget.postId)
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted) setState(() => isLiked = response != null);
    } catch (_) {}
  }

  Future<void> _loadLikesCount() async {
    try {
      final response = await supabase
          .from('likes')
          .select('id')
          .eq('post_id', widget.postId);
      if (mounted) setState(() => likesCount = response.length);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final response = await supabase
          .from('comments')
          .select('id, content, created_at, user_id')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          comments = List<Map<String, dynamic>>.from(response);
          commentsCount = comments.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (isLiked) {
      await supabase
          .from('likes')
          .delete()
          .eq('post_id', widget.postId)
          .eq('user_id', userId);
    } else {
      await supabase.from('likes').insert({
        'post_id': widget.postId,
        'user_id': userId,
      });
    }

    await _loadLikesCount();
    await _checkIfLiked();
  }

  void _share() {
    final text = widget.title.isNotEmpty
        ? '${widget.title}\n\n${widget.imageUrl ?? ''}'
        : widget.imageUrl ?? '';
    Share.share(text);
  }

  void _showCommentsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: widget.postId,
        comments: comments,
        commentsCount: commentsCount,
        onCommentsUpdated: _loadComments,
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} · ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              authorName.isNotEmpty ? authorName : widget.subTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_formatDate(widget.postedAt)),
            trailing: const Icon(Icons.more_horiz),
          ),

          if (widget.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(widget.title, style: const TextStyle(fontSize: 15)),
            ),

          if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 100,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),

          const Divider(height: 1),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(
                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: isLiked
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                label: Text(
                  'Curtir${likesCount > 0 ? ' ($likesCount)' : ''}',
                  style: TextStyle(
                    color: isLiked
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showCommentsBottomSheet,
                icon: const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                label: Text(
                  'Comentar${commentsCount > 0 ? ' ($commentsCount)' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              TextButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                label: const Text('Compartilhar', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
