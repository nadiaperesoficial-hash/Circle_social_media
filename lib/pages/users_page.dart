import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      final response = await supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .neq('id', currentUserId ?? '');

      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await supabase.from('friendships').insert({
        'requester_id': currentUserId,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação enviada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação já enviada.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pessoas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? const Center(child: Text('Nenhum usuário encontrado.'))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage: user['avatar_url'] != null
                            ? NetworkImage(user['avatar_url'])
                            : null,
                        child: user['avatar_url'] == null
                            ? Text(
                                (user['username'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Text(user['username'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add_outlined),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => _sendFriendRequest(user['id']),
                      ),
                    );
                  },
                ),
    );
  }
}
