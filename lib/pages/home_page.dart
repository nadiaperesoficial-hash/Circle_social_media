import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../components/post_list_tile.dart';
import '../components/textfield.dart';
import 'profile_page.dart';
import 'users_page.dart';
import 'chat_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const FeedPage(),
    const SearchPage(),
    const ChatListPage(),
    const NotificationsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          border: Border(top: BorderSide(color: const Color(0xFF00E5FF).withAlpha(40))),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Notificações'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// FEED
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final TextEditingController newPostController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  static const teal = Color(0xFF00B4B4);
  static const cyan = Color(0xFF00E5FF);

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final response = await request.send();
    if (response.statusCode == 200) {
      final data = json.decode(await response.stream.bytesToString());
      return data['secure_url'];
    }
    return null;
  }

  void postMessage() async {
    if (newPostController.text.isEmpty && _selectedImage == null) return;
    setState(() => _isUploading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadToCloudinary(_selectedImage!);
      }
      await Supabase.instance.client.from('posts').insert({
        'user_id': userId,
        'content': newPostController.text.isEmpty ? null : newPostController.text,
        'image_url': imageUrl,
      });
      newPostController.clear();
      setState(() => _selectedImage = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: teal,
        elevation: 0,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'C',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              TextSpan(
                text: 'ircle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UsersPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de post
          Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: const Icon(Icons.photo_outlined, color: teal, size: 26),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: TextField(
                          controller: newPostController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration.collapsed(
                            hintText: 'No que você está pensando?',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _isUploading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: teal),
                          )
                        : GestureDetector(
                            onTap: postMessage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
                              child: const Icon(Icons.send, color: Colors.white, size: 18),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFF1A1A2E)),

          // Feed
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('posts')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator(color: teal)),
                );
              }
              if (snapshot.hasError) {
                return Expanded(child: Center(child: Text('Erro: ${snapshot.error}', style: const TextStyle(color: Colors.white))));
              }
              final posts = snapshot.data;
              if (posts == null || posts.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Text('Nenhum post ainda. Seja o primeiro!', style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return PostListTile(
                      title: post['content'] ?? '',
                      subTitle: post['user_id'] ?? '',
                      postedAt: post['created_at'] ?? '',
                      postId: post['id'].toString(),
                      authorId: post['user_id'] ?? '',
                      imageUrl: post['image_url'],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// BUSCA
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B4B4),
        title: const Text('Buscar', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(child: Text('Busca em breve', style: TextStyle(color: Colors.grey))),
    );
  }
}

// NOTIFICAÇÕES
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B4B4),
        title: const Text('Notificações', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(child: Text('Notificações em breve', style: TextStyle(color: Colors.grey))),
    );
  }
}
