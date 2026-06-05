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

      // Junta IDs únicos de conversas
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

      // Busca perfis
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
      return const Center(child: Text('Nenhuma conversa.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final conv = items[index];
        final profile = conv['profile'];
        final isRead = conv['is_read'] ?? true;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: profile['avatar_url'] != null
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: profile['avatar_url'] == null
                ? Text(
                    (profile['username'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          title: Text(
            profile['username'] ?? '',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(
            conv['last_message'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isRead ? Colors.grey : Colors.black87,
            ),
          ),
          trailing: isRead
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _conversations.where((c) => c['is_read'] == false).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'New'),
            Tab(text: 'Business'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_conversations),
                _buildList(unread),
                const Center(child: Text('Mensagens de páginas em breve')),
              ],
            ),
    );
  }
}
