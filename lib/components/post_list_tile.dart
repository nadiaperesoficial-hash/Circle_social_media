import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
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

  static const cyan = Color(0xFF00E5FF);
  static const teal = Color(0xFF00B4B4);
  static const cardColor = Color(0xFF0D1117);

  bool isLiked = false;
  int likesCount = 0;
  int commentsCount = 0;
  List<Map<String, dynamic>> comments = [];
  String authorName = '';
  String? _extractedUrl;
  PreviewData? _previewData;

  @override
  void initState() {
    super.initState();
    _loadPostData();
    _extractedUrl = _extractUrl(widget.title);
  }

  String? _extractUrl(String text) {
    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30), width: 1),
        color: Colors.white.withAlpha(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: teal, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: cardColor,
                        child: Text(
                          authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                          style: const TextStyle(color: cyan, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName.isNotEmpty ? authorName : widget.subTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatDate(widget.postedAt),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_horiz, color: Colors.grey[500]),
                  ],
                ),
              ),

              if (widget.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),

              if (_extractedUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cyan.withAlpha(40)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinkPreview(
                        enableAnimation: true,
                        onPreviewDataFetched: (data) {
                          if (mounted) setState(() => _previewData = data);
                        },
                        previewData: _previewData,
                        text: _extractedUrl!,
                        width: MediaQuery.of(context).size.width - 56,
                        linkStyle: const TextStyle(color: cyan, fontSize: 13),
                        metadataTextStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                        metadataTitleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.all(12),
                        textWidget: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Image.network(
                    widget.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 100,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Row(
                  children: [
                    _actionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: likesCount > 0 ? '$likesCount' : 'Curtir',
                      color: isLiked ? Colors.red[400]! : Colors.grey[400]!,
                      onTap: _toggleLike,
                    ),
                    _actionButton(
                      icon: Icons.chat_bubble_outline,
                      label: commentsCount > 0 ? '$commentsCount' : 'Comentar',
                      color: Colors.grey[400]!,
                      onTap: _showCommentsBottomSheet,
                    ),
                    _actionButton(
                      icon: Icons.share_outlined,
                      label: 'Compartilhar',
                      color: Colors.grey[400]!,
                      onTap: _share,
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
