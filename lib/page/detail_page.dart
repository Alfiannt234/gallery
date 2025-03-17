import 'package:flutter/material.dart';
import 'package:galeri/config.dart';
import 'package:galeri/edit/edit_image_page.dart' show EditImagePage;
import 'package:galeri/services/api_service.dart';
// import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DetailPage extends StatefulWidget {
  final String imageUrl; // Ambil URL gambar
  final String imagePath;
  final String initialDescription;
  final ValueChanged<String> onDescriptionChanged;
  final bool initialIsLiked;
  final Function(String)? onUnlike;


  const DetailPage({
    Key? key,
    required this.imageUrl,
    required this.imagePath,
    required this.initialDescription,
    required this.onDescriptionChanged,
    this.initialIsLiked = false,
    this.onUnlike,
  }) : super(key: key);

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool isLiked = false;
  int likeCount = 0;
  int _commentCount = 0;
  bool isEditing = false;
  late String description;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String imageName;
  final TextEditingController _commentController = TextEditingController();
  final ApiService apiService = ApiService();
  int? userId;
  bool _isLoading = true;

  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();
    _fetchUserId();
    _fetchComments();
    _loadLikeStatus();
    // final fileName = basename(widget.imagePath);
    // final DateTime now = DateTime.now();
    // final String formattedDate = DateFormat('yyyy-MM-dd').format(now);
    // imageName = fileName.startsWith("IMG-") ? fileName : "IMG-$formattedDate";
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _fetchFoto();
    _fetchCommentCount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadLikeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? saveUserId = prefs.getInt('userId');

    if (saveUserId == null) {
      print("❌ User ID tidak ditemukan.");
      return;
    }
    String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    int? fotoId = await apiService.getFotoId(relativePath);
    if (fotoId == null) return;
    bool liked = await apiService.checkIfLiked(fotoId, saveUserId);
    int likes = await apiService.getLikeCount(fotoId);
    setState(() {
      isLiked = liked;
      likeCount = likes;
    });
  }

  Future<void> _toggleLike() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? saveUserId = prefs.getInt('userId');

  if (saveUserId == null) {
    print("❌ User ID tidak ditemukan.");
    return;
  }

  String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
  int? fotoId = await apiService.getFotoId(relativePath);
  if (fotoId == null) return;

  bool liked = await apiService.toggleLike(fotoId, saveUserId);
  int likes = await apiService.getLikeCount(fotoId);

  setState(() {
    isLiked = liked;
    likeCount = likes;
  });

  // 🔥 Hapus dari tab Like jika unlike
  if (!liked && widget.onUnlike != null) {
    widget.onUnlike!(widget.imagePath);
  }
}


  Future<void> _fetchUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('loggedInUser');

    if (email == null) {
      print("⚠️ Email belum tersedia di SharedPreferences.");
      return;
    }

    int? id = await apiService.getUserIdByEmail(email);
    if (id != null) {
      await prefs.setInt('userId', id);
      setState(() {
        userId = id; // Perbarui userId yang digunakan di halaman ini
      });
      print("✅ ID User tersimpan: $id");
    } else {
      print("❌ Gagal mendapatkan ID User.");
    }
  }

  Future<void> _fetchComments() async {
    String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    int? fotoId = await apiService.getFotoId(relativePath);
    if (fotoId == null || fotoId == 0) {
      print("❌ ID Foto tidak ditemukan!");
      return;
    }

  final url = Uri.parse('${Config.baseUrl}/get_comments.php?id_foto=$fotoId');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    if (data['success']) {
      print("✅ Komentar ditemukan: ${data['comments']}");

      setState(() {
        comments = List<Map<String, dynamic>>.from(data['comments']); // Konversi ke List<Map>
      });

      print("🎯 Komentar berhasil disimpan di state: $comments");
    } else {
      print("❌ Gagal mengambil komentar: ${data['message']}");
    }
  } else {
    print('❌ Gagal mengambil komentar. Status code: ${response.statusCode}');
  }
}

Future<void> _addComment(String imageUrl) async {
  if (_commentController.text.isNotEmpty) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? saveUserId = prefs.getInt('userId');

    if (saveUserId == null) {
      print("❌ User ID tidak ditemukan.");
      return;
    }

    // ✅ Ubah URL gambar menjadi path relatif sebelum dikirim ke API
    String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    print("🔥 Mencari ID Foto untuk Path: $relativePath");

    int? fotoId = await apiService.getFotoId(relativePath);
    if (fotoId == null || fotoId == 0) {
      print("❌ ID Foto tidak ditemukan!");
      return;
    }

    final url = Uri.parse('${Config.baseUrl}/add_comments.php');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "id_foto": fotoId, // Ambil ID foto dari API
        "id_user": saveUserId,
        "isi_komentar": _commentController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        _fetchComments(); // Perbarui daftar komentar setelah menambahkan komentar
        _commentController.clear();
      } else {
        print("❌ Gagal menambahkan komentar: ${data['message']}");
      }
    } else {
      print("❌ HTTP Error: ${response.statusCode}");
    }
  }
}

Future<void> _fetchCommentCount() async {
   String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    int? fotoId = await apiService.getFotoId(relativePath);
    if (fotoId == null || fotoId == 0) {
      print("❌ ID Foto tidak ditemukan!");
      return;
    }
  final response = await http.get(
    Uri.parse("${Config.baseUrl}/get_comment_count.php?id_foto=$fotoId")
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['success']) {
      setState(() {
        _commentCount = data['jumlah_komentar'];
      });
    } else {
      print("⚠️ Gagal mengambil jumlah komentar: ${data['message']}");
    }
  } else {
    print("❌ Error mengambil komentar: ${response.body}");
  }
}

void _toggleCommentLike(int index) {
  setState(() {
    if (comments[index]['liked']) {
      // Jika sudah di-like, batalkan like
      comments[index]['liked'] = false;
      comments[index]['likes']--;
    } else {
      // Jika belum di-like, aktifkan like dan batalkan dislike
      comments[index]['liked'] = true;
      comments[index]['likes']++;

      if (comments[index]['disliked']) {
        comments[index]['disliked'] = false;
        comments[index]['dislikes']--;
      }
    }
  });
}

void _toggleCommentDislike(int index) {
  setState(() {
    if (comments[index]['disliked']) {
      // Jika sudah di-dislike, batalkan dislike
      comments[index]['disliked'] = false;
      comments[index]['dislikes']--;
    } else {
      // Jika belum di-dislike, aktifkan dislike dan batalkan like
      comments[index]['disliked'] = true;
      comments[index]['dislikes']++;

      if (comments[index]['liked']) {
        comments[index]['liked'] = false;
        comments[index]['likes']--;
      }
    }
  });
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    resizeToAvoidBottomInset: true, // Menghindari overflow saat keyboard muncul
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black),
           onPressed: () {_showOptionsMenu(context);
          },
        ),
      ],
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16), // Tambah padding agar tidak kepotong
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== GAMBAR ==========
            Center(
              child: widget.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Text("Gagal memuat gambar!"),
                    )
                  : const Text("Gambar tidak tersedia"),
            ),

            const SizedBox(height: 16),

            // ========== JUDUL FOTO ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isLoading
                  ? const CircularProgressIndicator() // Indikator loading
                  : Text(
                      _nameController.text.isNotEmpty ? _nameController.text : "Tidak ada judul",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),



            const SizedBox(height: 8),

            // ========== DESKRIPSI FOTO ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _descriptionController.text.isNotEmpty ? _descriptionController.text : "Tidak ada deskripsi",
                      style: const TextStyle(fontSize: 16),
                    ),
            ),


            const SizedBox(height: 16),
            // ========== TOMBOL LIKE, KOMENTAR, SIMPAN, SHARE ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.black,
                        ),
                        onPressed: _toggleLike,
                      ),
                      Text('$likeCount', style: const TextStyle(fontSize: 16)), // Menampilkan jumlah like
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.comment, color: Colors.black),
                        onPressed: () {
                        },
                      ),
                      Text('$_commentCount', style: const TextStyle(fontSize: 16)), // Menampilkan jumlah komentar
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ========== KOMENTAR ==========
            if (comments.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Komentar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < comments.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=${i + 1}'),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comments[i]['username'] ?? 'Anonim',  // 🛠 Cegah error jika username null
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    comments[i]['timestamp']?.toString() ?? 'Baru saja',  // 🛠 Pastikan tidak error
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(comments[i]['isi_komentar'] ?? 'Tidak ada komentar'),  // 🛠 Cegah error jika null
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  (comments[i]['liked'] ?? false) ? Icons.thumb_up : Icons.thumb_up_alt_outlined,  // 🛠 Default false
                                  color: (comments[i]['liked'] ?? false) ? Colors.blue : Colors.black,
                                ),
                                onPressed: () => _toggleCommentLike(i),
                              ),
                              Text('${comments[i]['likes'] ?? 0}'),  // 🛠 Default 0 jika null
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  (comments[i]['disliked'] ?? false) ? Icons.thumb_down : Icons.thumb_down_alt_outlined,  // 🛠 Default false
                                  color: (comments[i]['disliked'] ?? false) ? Colors.red : Colors.black,
                                ),
                                onPressed: () => _toggleCommentDislike(i),
                              ),
                              Text('${comments[i]['dislikes'] ?? 0}'),  // 🛠 Default 0 jika null
                            ],
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                ],
              ),

            // ========== FORM KOMENTAR ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Tambahkan komentar...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _addComment(widget.imageUrl); // Kirim URL gambar agar bisa cari id_foto
                    },
                    child: Text("Kirim Komentar"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
  void _showOptionsMenu(BuildContext context) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? savedUserId = prefs.getInt('userId');

  print("🔥 Cek userId sebelum fetch: $savedUserId");

   String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    print("🔥 Mencari ID Foto untuk Path: $relativePath");

    int? fotoId = await apiService.getFotoId(relativePath);
    if (fotoId == null || fotoId == 0) {
      print("❌ ID Foto tidak ditemukan!");
      return;
    }

  // Ambil imageUserId dari API berdasarkan idFoto
  final response = await http.get(Uri.parse("${Config.baseUrl}/get_image_user.php?id_foto=$fotoId"));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data['success']) {
      int imageUserId = data['id_user']; // Ambil id_user dari API
      print("📸 Pemilik gambar: $imageUserId");

      if (imageUserId != savedUserId) {
        print("❌ Bukan pemilik gambar, menu tidak ditampilkan.");
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);

                  final updatedData = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditImagePage(
                        imageUrl: widget.imageUrl,
                        imagePath: widget.imagePath,
                        initialTitle: _nameController.text, 
                        initialDescription: _descriptionController.text, 
                      ),
                    ),
                  );

                  if (updatedData != null) {
                    setState(() {
                      _nameController.text = updatedData['judul_foto'] ?? _nameController.text;
                      _descriptionController.text = updatedData['deskripsi'] ?? _descriptionController.text;
                    });

                    // Panggil callback jika ada perubahan
                    widget.onDescriptionChanged(updatedData['deskripsi']);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteImage(context); // Panggil fungsi untuk menghapus gambar
                },
              ),
            ],
          );
        },
      );
    } else {
      print("⚠️ Gagal mendapatkan data pemilik gambar: ${data['message']}");
    }
  } else {
    print("❌ HTTP Error: ${response.statusCode}");
  }
}
void _deleteImage(BuildContext context) async {
  String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
  print("🔥 Mencari ID Foto untuk Path: $relativePath");

  int? fotoId = await apiService.getFotoId(relativePath);
  if (fotoId == null || fotoId == 0) {
    print("❌ ID Foto tidak ditemukan!");
    return;
  }

  final url = Uri.parse("${Config.baseUrl}/delete_foto.php");
  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"id_foto": fotoId}),
  );

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    if (data['success']) {
      print("✅ Gambar berhasil dihapus.");
      Navigator.pop(context, true); // Menggunakan context yang valid
    } else {
      print("❌ Gagal menghapus gambar: ${data['message']}");
    }
  } else {
    print("❌ HTTP Error: ${response.statusCode}");
  }
}

   Future<void> _fetchFoto() async {
    String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    print("🔥 Mengambil data foto untuk: $relativePath");

    final fotoData = await ApiService().getFoto(relativePath);

    if (fotoData != null) {
      setState(() {
        _nameController.text = fotoData['judul_foto'] ?? "Tidak ada judul";
        _descriptionController.text = fotoData['deskripsi'] ?? "Tidak ada deskripsi";
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      print("❌ Data foto tidak ditemukan!");
    }
  }

}