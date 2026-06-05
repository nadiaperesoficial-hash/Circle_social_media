import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../components/drawer.dart';
import '../components/post_list_tile.dart';
import '../components/textfield.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController newPostController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

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

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Circle"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: const MyDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Icon(
                        Icons.photo_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MyTextfield(
                        hintText: "No que você está pensando?",
                        obscureText: false,
                        controller: newPostController,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : GestureDetector(
                            onTap: postMessage,
                            child: Icon(
                              Icons.send,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('posts')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Erro: ${snapshot.error}"));
              }
              final posts = snapshot.data;
              if (posts == null || posts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(25.0),
                    child: Text("Nenhum post ainda. Seja o primeiro!"),
                  ),
                );
              }
              return Expanded(
                child: ListView.builder(
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
