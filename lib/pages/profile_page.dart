import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/post_list_tile.dart';
import 'users_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> friends = [];
  bool isLoading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profileData = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final postsData = await supabase
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final friendsData = await supabase
          .from('friendships')
          .select('requester_id, receiver_id, profiles!friendships_receiver_id_fkey(id, username, avatar_url)')
          .eq('requester_id', userId)
          .eq('status', 'accepted')
          .limit(6);

      if (mounted) {
        setState(() {
          profile = profileData;
          posts = List<Map<String, dynamic>>.from(postsData);
          friends = List<Map<String, dynamic>>.from(friendsData);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await supabase.from('comments').delete().eq('post_id', postId);
      await supabase.from('likes').delete().eq('post_id', postId);
      await supabase.from('posts').delete().eq('id', postId);
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e')),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Capa
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                image: profile?['cover_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(profile!['cover_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            // Avatar
            Positioned(
              bottom: -40,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profile?['avatar_url'] != null
                      ? NetworkImage(profile!['avatar_url'])
                      : null,
                  child: profile?['avatar_url'] == null
                      ? Text(
                          (profile?['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 30),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile?['full_name'] ?? profile?['username'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (profile?['bio'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(profile!['bio'], style: TextStyle(color: Colors.grey[600])),
                ),
              const SizedBox(height: 8),
              if (profile?['city'] != null)
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(profile!['city'], style: TextStyle(color: Colors.grey[600])),
                ]),
              if (profile?['work'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.work_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(profile!['work'], style: TextStyle(color: Colors.grey[600])),
                  ]),
                ),
              if (profile?['education'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.school_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(profile!['education'], style: TextStyle(color: Colors.grey[600])),
                  ]),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Amigos
        if (friends.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amigos', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersPage()),
                      ),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: friends.take(6).map((f) {
                    final p = f['profiles'];
                    return CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: p?['avatar_url'] != null
                          ? NetworkImage(p!['avatar_url'])
                          : null,
                      child: p?['avatar_url'] == null
                          ? Text(
                              (p?['username'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Abas
        const Divider(height: 1),
        Row(
          children: ['Posts', 'Fotos', 'Sobre'].asMap().entries.map((e) {
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == e.key
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: _tab == e.key ? FontWeight.bold : FontWeight.normal,
                      color: _tab == e.key
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile?['bio'] != null) ...[
            const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(profile!['bio']),
            const SizedBox(height: 12),
          ],
          if (profile?['city'] != null) ...[
            const Text('Cidade', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(profile!['city']),
            const SizedBox(height: 12),
          ],
          if (profile?['work'] != null) ...[
            const Text('Trabalho', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(profile!['work']),
            const SizedBox(height: 12),
          ],
          if (profile?['education'] != null) ...[
            const Text('Educação', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(profile!['education']),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotos() {
    final photoPosts = posts.where((p) => p['image_url'] != null).toList();
    if (photoPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Nenhuma foto ainda.')),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photoPosts.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            photoPosts[index]['image_url'],
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_tab == 0)
                      posts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('Nenhum post ainda.')),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return Dismissible(
                                  key: Key(post['id'].toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (_) => _deletePost(post['id'].toString()),
                                  child: PostListTile(
                                    title: post['content'] ?? '',
                                    subTitle: post['user_id'] ?? '',
                                    postedAt: post['created_at'] ?? '',
                                    postId: post['id'].toString(),
                                    authorId: post['user_id'] ?? '',
                                    imageUrl: post['image_url'],
                                  ),
                                );
                              },
                            ),
                    if (_tab == 1) _buildPhotos(),
                    if (_tab == 2) _buildAbout(),
                  ],
                ),
              ),
            ),
    );
  }
}
