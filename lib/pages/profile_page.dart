import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:convert';
import '../components/post_list_tile.dart';
import 'users_page.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HexagonPainter extends CustomPainter {
  final Color color;
  HexagonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final w = size.width;
    final h = size.height;
    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w, h * 0.25);
    path.lineTo(w, h * 0.75);
    path.lineTo(w * 0.5, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(0, h * 0.25);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> friends = [];
  bool isLoading = true;
  int _tab = 0;

  static const cyan = Color(0xFF00E5FF);
  static const amoled = Color(0xFF000000);
  static const cardColor = Color(0xFF0D1117);

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
          .from('profiles').select().eq('id', userId).maybeSingle();
      final postsData = await supabase
          .from('posts').select().eq('user_id', userId)
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

  Future<void> _changeAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final url = await _uploadToCloudinary(File(image.path));
    if (url == null) return;
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
    await _loadAll();
  }

  Future<void> _changeCover() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final url = await _uploadToCloudinary(File(image.path));
    if (url == null) return;
    await supabase.from('profiles').update({'cover_url': url}).eq('id', userId);
    await _loadAll();
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
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _editDetails() async {
    final cityController = TextEditingController(text: profile?['city'] ?? '');
    final workController = TextEditingController(text: profile?['work'] ?? '');
    final educationController = TextEditingController(text: profile?['education'] ?? '');
    final ageController = TextEditingController(text: profile?['age']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cyan.withAlpha(60)),
        ),
        title: const Text('Editar informações', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(cityController, 'Cidade', Icons.location_on_outlined),
              const SizedBox(height: 12),
              _dialogField(workController, 'Profissão', Icons.work_outline),
              const SizedBox(height: 12),
              _dialogField(educationController, 'Faculdade', Icons.school_outlined),
              const SizedBox(height: 12),
              _dialogField(ageController, 'Idade', Icons.cake_outlined, isNumber: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          GestureDetector(
            onTap: () async {
              final userId = supabase.auth.currentUser?.id;
              if (userId == null) return;
              await supabase.from('profiles').update({
                'city': cityController.text.isEmpty ? null : cityController.text,
                'work': workController.text.isEmpty ? null : workController.text,
                'education': educationController.text.isEmpty ? null : educationController.text,
                'age': ageController.text.isEmpty ? null : int.tryParse(ageController.text),
              }).eq('id', userId);
              if (mounted) Navigator.pop(context);
              await _loadAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cyan,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Salvar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cyan.withAlpha(40)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: cyan, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHexAvatar() {
    return GestureDetector(
      onTap: _changeAvatar,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: cyan.withAlpha(150), blurRadius: 24, spreadRadius: 4),
                ],
              ),
            ),
            ClipPath(
              clipper: HexagonClipper(),
              child: profile?['avatar_url'] != null
                  ? Image.network(profile!['avatar_url'], width: 100, height: 100, fit: BoxFit.cover)
                  : Container(
                      width: 100,
                      height: 100,
                      color: cardColor,
                      child: Center(
                        child: Text(
                          (profile?['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: cyan, fontSize: 38, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
            CustomPaint(size: const Size(100, 100), painter: HexagonPainter(cyan)),
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: cyan, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: _changeCover,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: profile?['cover_url'] != null
                      ? DecorationImage(image: NetworkImage(profile!['cover_url']), fit: BoxFit.cover)
                      : null,
                  gradient: profile?['cover_url'] == null
                      ? const LinearGradient(
                          colors: [Color(0xFF0D1B2A), Color(0xFF000000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: profile?['cover_url'] == null
                    ? const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.white30, size: 32))
                    : null,
              ),
            ),
            Positioned(bottom: -50, child: _buildHexAvatar()),
          ],
        ),

        const SizedBox(height: 60),

        Text(
          profile?['full_name'] ?? profile?['username'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),

        if (profile?['bio'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 24, right: 24),
            child: Text(
              profile!['bio'],
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Sobre', 'Fotos', 'Posts'].asMap().entries.map((e) {
              final selected = _tab == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = e.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? cyan.withAlpha(30) : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: selected ? cyan : Colors.grey[800]!, width: 1.5),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? cyan : Colors.grey[500],
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cyan, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: cyan, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cyan.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Basic Details',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    GestureDetector(
                      onTap: _editDetails,
                      child: Row(
                        children: const [
                          Text('Edit', style: TextStyle(color: cyan, fontSize: 13)),
                          SizedBox(width: 4),
                          Icon(Icons.edit, color: cyan, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (profile?['age'] != null)
                  _buildDetailRow(Icons.cake_outlined, 'Idade', '${profile!['age']} anos'),
                if (profile?['city'] != null)
                  _buildDetailRow(Icons.location_on_outlined, 'Cidade', profile!['city']),
                if (profile?['work'] != null)
                  _buildDetailRow(Icons.work_outline, 'Profissão', profile!['work']),
                if (profile?['education'] != null)
                  _buildDetailRow(Icons.school_outlined, 'Faculdade', profile!['education']),
                if (profile?['age'] == null && profile?['city'] == null &&
                    profile?['work'] == null && profile?['education'] == null)
                  GestureDetector(
                    onTap: _editDetails,
                    child: const Text(
                      'Toque para adicionar informações',
                      style: TextStyle(color: cyan, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cyan.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Friends',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersPage()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cyan.withAlpha(100)),
                        ),
                        child: const Text('View All Friends >', style: TextStyle(color: cyan, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                friends.isEmpty
                    ? const Text('Nenhum amigo ainda.', style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: friends.take(6).map((f) {
                          final p = f['profiles'];
                          return Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: cyan.withAlpha(100), blurRadius: 8)],
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: cardColor,
                                  backgroundImage: p?['avatar_url'] != null
                                      ? NetworkImage(p!['avatar_url'])
                                      : null,
                                  child: p?['avatar_url'] == null
                                      ? Text((p?['username'] ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: cyan))
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (p?['username'] ?? '').length > 6
                                    ? '${p!['username'].substring(0, 6)}.'
                                    : p?['username'] ?? '',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPhotos() {
    final photoPosts = posts.where((p) => p['image_url'] != null).toList();
    if (photoPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Nenhuma foto ainda.', style: TextStyle(color: Colors.grey))),
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
          child: Image.network(photoPosts[index]['image_url'], fit: BoxFit.cover),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amoled,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: cyan))
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_tab == 0) _buildAbout(),
                    if (_tab == 1) _buildPhotos(),
                    if (_tab == 2)
                      posts.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text('Nenhum post ainda.', style: TextStyle(color: Colors.grey)),
                              ),
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
