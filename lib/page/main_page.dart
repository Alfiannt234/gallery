import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:galeri/config.dart';
import 'package:galeri/page/detail_page.dart';
import 'package:galeri/page/profile_page.dart';
import 'package:galeri/page/album_page.dart';
import 'package:galeri/page/upload_page.dart';
import 'package:galeri/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:share_plus/share_plus.dart';
// import 'package:gallery_saver_/gallery_saver.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _imagePaths = [];
  List<int> _albumId = [];
  final Map<String, List<String>> _albums = {};
  final Map<String, String> _albumDescriptions = {};
  final ApiService apiService = ApiService();
  int? userId;

  String _fullName = "";
  String _username = "";
  String _address = "";
  File? _profileImage;
  List<String> _uploadedImages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserData();
    _fetchUploadedImages();
    _fetchAlbums();
  }

  // Fungsi untuk menyimpan gambar ke galeri (memerlukan izin penyimpanan di Android)
  // Future<void> _downloadImage(String imagePath) async {
  //   try {
  //     final directory = await getApplicationDocumentsDirectory();
  //     final File imageFile = File(imagePath);
  //     final String newPath = '${directory.path}/${imageFile.uri.pathSegments.last}';
  //     await imageFile.copy(newPath);
  //     print("Gambar berhasil diunduh ke: $newPath");
  //   } catch (e) {
  //     print("Gagal mengunduh gambar: $e");
  //   }
  // }

  // Fungsi untuk membagikan gambar
    // void _shareImage(String imagePath) {
    //   Share.shareFiles([imagePath], text: 'Lihat gambar ini!');
    // }

  Future<void> _fetchUserData() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('loggedInUser'); // Ambil email yang login

    if (email != null) {
      var userData = await apiService.getUserData(email);

      setState(() {
        _fullName = userData['full_name'] ?? "Nama Lengkap";
        _username = userData['username'] ?? "@username";
        _address = userData['address'] ?? "Alamat user";
        _profileImage = userData['profileImage'] != null ? File(userData['profileImage']) : null;
      });
    } else {
      print("User belum login");
    }
  } catch (e) {
    print("Error: $e");
  }
}

  Future<void> _updateUserProfile(String newFullName, String newUsername, String newAddress, File? newProfileImage) async {
  final prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email'); // Ambil email pengguna

  if (email == null) {
    print("Error: Email tidak ditemukan di SharedPreferences");
    return;
  }

  setState(() {
    _fullName = newFullName;
    _username = newUsername;
    _address = newAddress;
    _profileImage = newProfileImage;
    
  });

  await apiService.updateUserData({
    'email': email, // ✅ Kirim email sebagai identifier
    'fullName': newFullName,
    'username': newUsername,
    'address': newAddress,
    'profileImage': newProfileImage?.path,
  });
}

  Future<void> _fetchUploadedImages() async {
  print("📡 Mengambil semua gambar tanpa filter userId...");

  List<String> images = await apiService.getAllUploadedImages(); // API baru tanpa userId
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

  void _showImageOptions(BuildContext context, String imagePath) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Wrap(
        children: [
             ListTile(
              leading: Icon(Icons.photo_album),
              title: Text('Masukkan ke Album'),
              onTap: () {
                Navigator.pop(context);
                _showAlbumDialog(context, imagePath);
              },
            ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Bagikan Gambar'),
            // onTap: () {
            //   Navigator.pop(context);
            //   _shareImage(imagePath);
            // },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Unduh Gambar'),
            // // onTap: () {
            // //   Navigator.pop(context);
            // //   _downloadImage(imagePath);
            // },
          ),
          ],
        );
      },
    );
  }

  void _showAlbumDialog(BuildContext context, String imagePath) {
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pilih Album"),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(context);
                    _createNewAlbum(context);
                  },
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                children: _albums.keys.map((albumName) {
                  int selectedAlbumId = _albumId[_albums.keys.toList().indexOf(albumName)]; // Ambil ID album yang dipilih

                  return ListTile(
                    title: Text(albumName),
                    onTap: () {
                      print("🛠 Album dipilih: $albumName, ID: $selectedAlbumId"); // Debugging

                      // Pastikan ID album yang benar dikirim
                      _addImageToAlbum(selectedAlbumId, imagePath);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> createAlbum(String albumName, String albumDescription, int userId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print("🔥 Cek userId sebelum fetch: ${prefs.getInt('userId')}");
  int? userId = prefs.getInt('userId');
  final bodyData = {
    'id_user': userId, // Konversi ke String untuk menghindari error
    'nama_album': albumName,
    'deskripsi_album': albumDescription,
  };

  print("📡 Mengirim data: $bodyData");

  final response = await http.post(
    Uri.parse('${Config.baseUrl}/create_album.php'),
    body: bodyData,
  );

  print("📡 Response dari server: ${response.body}");

  final data = jsonDecode(response.body);
  if (data['success']) {
    print("✅ Album berhasil dibuat");
  } else {
    print("❌ Gagal membuat album: ${data['message']}");
  }
}

void _createNewAlbum(BuildContext context) {
  String albumName = '';
  String albumDescription = '';

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Buat Album Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Nama Album'),
              onChanged: (value) => albumName = value,
            ),
            TextField(
              decoration: const InputDecoration(hintText: 'Deskripsi Album'),
              onChanged: (value) => albumDescription = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              print("🔥 Cek userId sebelum fetch: ${prefs.getInt('userId')}");
              int? saveuserId = prefs.getInt('userId');
              if (albumName.isNotEmpty) {
                if (saveuserId == null) {
                  print("⚠️ Error: userId belum didapatkan.");
                  return;
                }

                final requestBody = jsonEncode({
                  "id_user": saveuserId, // Sesuai dengan database
                  "nama_album": albumName, // Sesuai dengan database
                  "deskripsi_album": albumDescription, // Sesuai dengan database
                });

                print("📡 Mengirim data: $requestBody"); // Debugging

                final response = await http.post(
                  Uri.parse('${Config.baseUrl}/create_album.php'),
                  headers: {"Content-Type": "application/json"},
                  body: requestBody,
                );

                print("📡 Response dari server: ${response.body}");

                if (response.statusCode == 200) {
                  final responseData = jsonDecode(response.body);

                  if (responseData['success']) {
                    int albumId = responseData['albumId']; // Ambil ID album

                    setState(() {
                      _albums[albumName] = [];
                      _albumDescriptions[albumName] = albumDescription;
                    });

                    print("✅ Album berhasil dibuat: ID $albumId");
                    Navigator.pop(context);
                  } else {
                    print("❌ Gagal membuat album: ${responseData['message']}");
                  }
                } else {
                  print("❌ Error API: ${response.statusCode} - ${response.body}");
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      );
    },
  );
}

Future<void> _fetchAlbums() async {
  try {
    final response = await http.get(Uri.parse('${Config.baseUrl}/get_album.php'));

    print("📡 Response dari server: ${response.body}"); // Debugging

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success']) {
        setState(() {
          _albums.clear();
          _albumId.clear();
          _albumDescriptions.clear();

          for (var album in data['albums']) {
            int id = album['id_album'];
            String name = album['nama_album'];
            String desc = album['deskripsi_album'];

            print("📌 Album ditemukan: ID=$id, Nama=$name, Deskripsi=$desc"); // Debugging

            _albumId.add(id); // Simpan ID album
            _albums[name] = [];
            _albumDescriptions[name] = desc;
          }
        });
      } else {
        print("❌ Gagal mengambil album: ${data['message']}");
      }
    } else {
      print("❌ Error dari server: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Exception: $e");
  }
}

Future<void> _addImageToAlbum(int albumId, String imagePath) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? saveuserId = prefs.getInt('userId');

  // Pastikan hanya mengambil path relatif dari `imagePath`
  String relativeImagePath = imagePath.replaceFirst(Config.baseUrl2, "");

  final response = await http.post(
    Uri.parse("${Config.baseUrl}/add_to_album.php"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "id_album": albumId,
      "id_user": saveuserId,
      "image_path": relativeImagePath, // Sekarang bisa untuk gambar mana saja
    }),
  );

  print("📡 Response dari server: ${response.body}");

  final data = jsonDecode(response.body);
  if (data['success']) {
    print("✅ Gambar berhasil dimasukkan ke album!");
  } else {
    print("❌ Gagal memasukkan gambar: ${data['message']}");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 100),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Browse'),
                  Tab(text: 'Album'),
                ],
                indicatorColor: Colors.black,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black,
                indicatorWeight: 4,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
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
                                  child:
                                  Image.network(
                                  _uploadedImages[index].replaceAll("https://", "http://"),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print("❌ Gagal memuat gambar: ${_uploadedImages[index]}");
                                    return Column(
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
                            SizedBox(height: 4),
                            IconButton(
                              icon: Icon(Icons.more_horiz, color: Colors.black),
                              onPressed: () {
                                _showImageOptions(context, imagePath);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Tab "Album" - Menampilkan Daftar Album
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: _albums.keys.length,
                      itemBuilder: (context, index) {
                        int albumId = _albumId[index]; // Ambil albumId dari daftar album
                        String albumName = _albums.keys.elementAt(index);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AlbumPage(
                                  albumId: albumId, // 🔹 Tambahkan albumId di sini
                                  albumName: albumName,
                                  albumDescription: _albumDescriptions[albumName] ?? "Tidak ada deskripsi",
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(albumName, style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    ),
                  )
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
                      if (ModalRoute.of(context)?.isFirst ?? false) {
                        // Jika ini halaman pertama, cukup pakai setState()
                        setState(() {});
                      } else {
                        // Jika bukan halaman pertama, refresh dengan pushReplacement
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MainPage()),
                        );
                      }
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
                      ).then((_) => _fetchUploadedImages());
                    },
                  ),
                  Icon(FontAwesomeIcons.magnifyingGlass, color: Theme.of(context).primaryColor),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(
                            fullName: _fullName,
                            username: _username,
                            address: _address,
                            profileImage: _profileImage,
                            onProfileUpdated: _updateUserProfile,
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}