import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../components/post_list_tile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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

      if (mounted) {
        setState(() {
          profile = profileData;
          posts = List<Map<String, dynamic>>.from(postsData);
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
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        profile?['cover_url'] != null
                            ? Image.network(
                                profile!['cover_url'],
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
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
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?['full_name'] ?? profile?['username'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (profile?['bio'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(profile!['bio']),
                          ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Meus posts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                posts.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Nenhum post ainda.'),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
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
                          childCount: posts.length,
                        ),
                      ),
              ],
            ),
    );
  }
}
