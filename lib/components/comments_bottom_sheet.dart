import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final List<Map<String, dynamic>> comments;
  final int commentsCount;
  final VoidCallback onCommentsUpdated;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.comments,
    required this.commentsCount,
    required this.onCommentsUpdated,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'user_id': userId,
        'content': _commentController.text.trim(),
      });

      _commentController.clear();
      widget.onCommentsUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _formatDateTime(String dateTimeString) {
    final dt = DateTime.parse(dateTimeString).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) return '${diff.inDays}d atrás';
    if (diff.inHours > 0) return '${diff.inHours}h atrás';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min atrás';
    return 'Agora';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Comentários (${widget.commentsCount})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              Expanded(
                child: widget.comments.isEmpty
                    ? const Center(child: Text('Nenhum comentário ainda.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: widget.comments.length,
                        itemBuilder: (context, index) {
                          final comment = widget.comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(comment['content'] ?? ''),
                            subtitle: Text(_formatDateTime(comment['created_at'])),
                          );
                        },
                      ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.withAlpha(100)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Escreva um comentário...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: _addComment,
                            icon: Icon(
                              Icons.send,
                              color: Theme.of(context).colorScheme.primary,
                            ),
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
}
