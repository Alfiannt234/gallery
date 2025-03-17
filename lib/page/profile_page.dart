import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:galeri/config.dart';
import 'package:galeri/edit/edit_profile_page.dart';
import 'package:galeri/page/detail_page.dart';
import 'package:galeri/page/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:galeri/services/api_service.dart';
import 'package:galeri/page/upload_page.dart';


class ProfilePage extends StatefulWidget {
  final String fullName;
  final String username;
  final String address;
  final File? profileImage;
  final Function(String, String, String, File?) onProfileUpdated;

  const ProfilePage({Key? key, required this.fullName,
    required this.username,
    required this.address,
    this.profileImage,
    required this.onProfileUpdated,}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService apiService = ApiService();
  final List<String> _imagePaths = [];
  List<String> _uploadedImages = [];
  List<String> _likedImages = [];
  String _email = "";
  String _fullName = "";
  String _username = "";
  String _address = "";
  File? _profileImage;
  int? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserId();
    _initializeUser();
    _fetchUserProfile();
    _fetchLikedImages();
  }

  Future<void> _fetchUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');
  if (email == null) {
    print("⚠️ Email belum tersedia di SharedPreferences.");
    return;
  }

  int? id = await apiService.getUserIdByEmail(email);
  if (id != null) {
    await prefs.setInt('userId', id);
    setState(() {
      userId = id; // Perbarui userId
    });
    print("✅ ID User tersimpan: $id");
  } else {
    print("❌ Gagal mendapatkan ID User.");
  }
}

  Future<void> _initializeUser() async {
  await _fetchUserId();
  if (userId != null) {
    _fetchUserImages(); // Panggil hanya setelah userId tersedia
  }
}

  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedEmail = prefs.getString('email');

    if (storedEmail == null) return;

    final response = await http.get( 
    Uri.parse('${Config.baseUrl}/get_user.php?email=$storedEmail'),
  );

    if (response.statusCode == 200) {
      print("Response dari server: ${response.body}");
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _email = storedEmail;
          _fullName = data['full_name'];
          _username = data['username'];
          _address = data['address'];
          _profileImage = data['profileImage'] != null ? File(data['profileImage']) : null;
        });
      }
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          email: _email,
          fullName: _fullName,
          username: _username,
          address: _address,
          profileImage: _profileImage,
          onProfileUpdated: (String newFullName, String newUsername, String newAddress, File? newProfileImage) {
            setState(() {
              _fullName = newFullName;
              _username = newUsername;
              _address = newAddress;
              _profileImage = newProfileImage;
            });
          },
        ),
      ),
    );
  }

Future<void> _fetchUserImages() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print("🔥 Cek userId sebelum fetch: ${prefs.getInt('userId')}");
  int? userId = prefs.getInt('userId');
  
  if (userId == null) {
    print("❌ User ID tidak ditemukan.");
    return;
  }

  print("✅ User ID: $userId");

  List<String> images = await apiService.getUploadedImages(userId);
  print("📡 Gambar diterima dari API: $images");

  if (images.isNotEmpty) {
    setState(() {
      _uploadedImages = images;
    });
  } else {
    print("⚠️ Tidak ada gambar ditemukan!");
  }
}

void _onImageUploaded(String imageUrl) {
  setState(() {
    _imagePaths.add(imageUrl);
  });
}

Future<void> _fetchLikedImages() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print("🔥 Cek userId sebelum fetch: ${prefs.getInt('userId')}");
  int? saveUserId = prefs.getInt('userId');
  
  if (saveUserId == null) {
    print("❌ User ID tidak ditemukan.");
    return;
  }
  final response = await http.get(
    Uri.parse("${Config.baseUrl}/get_liked_images.php?id_user=${saveUserId}")
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['success']) {
      setState(() {
        _likedImages = List<String>.from(data['images']);
      });
    } else {
      print("⚠️ Tidak ada gambar yang disukai: ${data['message']}");
    }
  } else {
    print("❌ Gagal mengambil foto yang disukai: ${response.body}");
  }
}


  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              const Text("Pengaturan", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Pengaturan"),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text("Log Out", style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildUserImagesTab() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      key: ValueKey(_uploadedImages.length), 
      itemCount: _uploadedImages.length,
      itemBuilder: (context, index) {
        String imagePath = _uploadedImages[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPage(
                      imageUrl: _uploadedImages[index],
                      imagePath: imagePath,
                      initialDescription: "", // Deskripsi bisa diisi dari database
                      onDescriptionChanged: (newDescription) {},
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 200, // Atur tinggi gambar agar seragam
                  width: double.infinity,
                  child: Image.network(
                    _uploadedImages[index].replaceAll("https://", "http://"),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("❌ Gagal memuat gambar: ${_uploadedImages[index]}");
                      return const Column(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          Text(
                            "Gagal memuat gambar",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildUserLikeImagesTab() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      key: ValueKey(_likedImages.length), 
      itemCount: _likedImages.length,
      itemBuilder: (context, index) {
        String imagePath = _likedImages[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailPage(
                      imageUrl: "${Config.baseUrl}/$imagePath",
                      imagePath: imagePath,
                      initialDescription: "", 
                      onDescriptionChanged: (newDescription) {},
                      initialIsLiked: true,
                      onUnlike: (String removedImagePath) { 
                        // 🔥 Hapus gambar dari _likedImages setelah unlike
                        setState(() {
                          _likedImages.remove(removedImagePath);
                        });
                      },
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Image.network(
                    "${Config.baseUrl}/$imagePath",
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print("❌ Gagal memuat gambar: $imagePath");
                      return const Column(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          Text(
                            "Gagal memuat gambar",
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsModal,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(_fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('@$_username', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _navigateToEditProfile,
            child: const Text("Edit Profil"),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "Dibuat"),
              Tab(text: "Like"),
              Tab(text: "Kolase"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserImagesTab(),
                _buildUserLikeImagesTab(),
                const Center(child: Text("Kolase")),
              ],
            ),
          ),
          Container(
            height: 30,
            color: const Color.fromARGB(255, 233, 221, 221),
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(FontAwesomeIcons.house),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Icon(FontAwesomeIcons.heart, color: Theme.of(context).primaryColor),
                IconButton(
                    icon: Icon(FontAwesomeIcons.plus, color: Theme.of(context).primaryColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UploadPage(
                          onImageUploaded: _onImageUploaded,
                        )),
                      ).then((_) => _fetchUserImages());
                    },
                  ),
                Icon(FontAwesomeIcons.magnifyingGlass, color: Theme.of(context).primaryColor),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
