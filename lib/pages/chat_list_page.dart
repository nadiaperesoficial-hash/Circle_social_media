import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _conversations = [];
  bool isLoading = true;

  static const teal = Color(0xFF00B4B4);
  static const cyan = Color(0xFF00E5FF);
  static const amoled = Color(0xFF000000);
  static const cardColor = Color(0xFF0D1117);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final sent = await supabase
          .from('messages')
          .select('receiver_id, content, created_at, is_read')
          .eq('sender_id', userId)
          .order('created_at', ascending: false);

      final received = await supabase
          .from('messages')
          .select('sender_id, content, created_at, is_read')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> convMap = {};

      for (final m in sent) {
        final otherId = m['receiver_id'];
        if (!convMap.containsKey(otherId)) {
          convMap[otherId] = {
            'other_id': otherId,
            'last_message': m['content'],
            'created_at': m['created_at'],
            'is_read': true,
          };
        }
      }

      for (final m in received) {
        final otherId = m['sender_id'];
        if (!convMap.containsKey(otherId)) {
          convMap[otherId] = {
            'other_id': otherId,
            'last_message': m['content'],
            'created_at': m['created_at'],
            'is_read': m['is_read'],
          };
        }
      }

      final List<Map<String, dynamic>> result = [];
      for (final entry in convMap.entries) {
        final profile = await supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .eq('id', entry.key)
            .maybeSingle();
        if (profile != null) {
          result.add({...entry.value, 'profile': profile});
        }
      }

      if (mounted) {
        setState(() {
          _conversations = result;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Nenhuma conversa.', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final conv = items[index];
        final profile = conv['profile'];
        final isRead = conv['is_read'] ?? true;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isRead ? Colors.grey.withAlpha(60) : cyan, width: 2),
                boxShadow: isRead ? [] : [BoxShadow(color: cyan.withAlpha(80), blurRadius: 8)],
              ),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF1A1A2E),
                backgroundImage: profile['avatar_url'] != null
                    ? NetworkImage(profile['avatar_url'])
                    : null,
                child: profile['avatar_url'] == null
                    ? Text(
                        (profile['username'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: cyan, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
            ),
            title: Text(
              profile['username'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              conv['last_message'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isRead ? Colors.grey[600] : Colors.grey[300]),
            ),
            trailing: isRead
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cyan,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: cyan.withAlpha(150), blurRadius: 6)],
                    ),
                  ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  otherUserId: profile['id'],
                  otherUsername: profile['username'] ?? '',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _conversations.where((c) => c['is_read'] == false).toList();

    return Scaffold(
      backgroundColor: amoled,
      appBar: AppBar(
        backgroundColor: teal,
        elevation: 0,
        title: const Text('Mensagens', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: cyan,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'New'),
            Tab(text: 'Business'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: teal))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_conversations),
                _buildList(unread),
                const Center(
                  child: Text('Mensagens de páginas em breve', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
    );
  }
}
