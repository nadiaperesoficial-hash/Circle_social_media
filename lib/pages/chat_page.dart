import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool isLoading = true;

  static const teal = Color(0xFF00B4B4);
  static const cyan = Color(0xFF00E5FF);
  static const amoled = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId,receiver_id.eq.${widget.otherUserId}),and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$userId)')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _subscribeToMessages() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
          final filtered = data.where((m) =>
              (m['sender_id'] == userId && m['receiver_id'] == widget.otherUserId) ||
              (m['sender_id'] == widget.otherUserId && m['receiver_id'] == userId)
          ).toList();

          if (mounted) {
            setState(() => _messages = filtered);
            _scrollToBottom();
          }
        });
  }

  Future<void> _markAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('sender_id', widget.otherUserId)
        .eq('receiver_id', userId);
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final content = _controller.text.trim();
    _controller.clear();

    try {
      await supabase.from('messages').insert({
        'sender_id': userId,
        'receiver_id': widget.otherUserId,
        'content': content,
        'is_read': false,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String dateStr) {
    final dt = DateTime.parse(dateStr).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: amoled,
      appBar: AppBar(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cyan, width: 1.5),
                boxShadow: [BoxShadow(color: cyan.withAlpha(80), blurRadius: 8)],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0D1117),
                child: Text(
                  widget.otherUsername[0].toUpperCase(),
                  style: const TextStyle(color: cyan, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.otherUsername, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text('Nenhuma mensagem ainda.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_id'] == userId;

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? teal.withAlpha(200)
                                            : Colors.white.withAlpha(15),
                                        border: Border.all(
                                          color: isMe
                                              ? cyan.withAlpha(100)
                                              : Colors.white.withAlpha(20),
                                        ),
                                        boxShadow: isMe
                                            ? [BoxShadow(color: teal.withAlpha(60), blurRadius: 8)]
                                            : [],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            msg['content'] ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(msg['created_at']),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isMe ? Colors.white70 : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Campo de mensagem
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    border: Border(top: BorderSide(color: cyan.withAlpha(30))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cyan.withAlpha(40)),
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Mensagem...',
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: teal,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: cyan.withAlpha(100), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
