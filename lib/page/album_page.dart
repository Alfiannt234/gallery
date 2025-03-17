import 'package:flutter/material.dart';
import 'package:galeri/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:galeri/page/detail_page.dart';

class AlbumPage extends StatefulWidget {
  final int albumId;
  final String albumName;
  final String albumDescription;

  AlbumPage({
    required this.albumId,
    required this.albumName,
    required this.albumDescription,
  });

  @override
  _AlbumPageState createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late String _albumName;
  late String _albumDescription;
  List<Map<String, dynamic>> _images = [];

  @override
  void initState() {
    super.initState();
    _albumName = widget.albumName;
    _albumDescription = widget.albumDescription;
    _fetchAlbumImages();
  }

  Future<void> _fetchAlbumImages() async {
  final url = Uri.parse("${Config.baseUrl}/get_album_image.php?id_album=${widget.albumId}");
  print("🔍 Fetching: $url");

  final response = await http.get(url);
  print("🔍 Response JSON: ${response.body}");

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data['success']) {
      setState(() {
        _images = List<Map<String, dynamic>>.from(data['images'].map((item) => {
          'imagePath': item['lokasi_file']?.toString() ?? "",
          // 'judulFoto': item['judul_foto']?.toString() ?? "Tanpa Judul",
          'deskripsi': item['deskripsi']?.toString() ?? "Tidak ada deskripsi",
        }));
      });
      print("✅ Data gambar berhasil diambil: $_images");
    } else {
      print("⚠️ Tidak ada gambar ditemukan.");
    }
  } else {
    print("❌ Gagal mengambil gambar: ${response.body}");
  }
}

  Future<void> _updateAlbum() async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/update_album.php"),
      body: {
        'id_album': widget.albumId.toString(),
        'album_name': _albumName,
        'album_description': _albumDescription,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        print("✅ Album berhasil diperbarui");
      } else {
        print("⚠️ Gagal memperbarui album: ${data['message']}");
      }
    } else {
      print("❌ Error: ${response.body}");
    }
  }

  /// ✅ Menampilkan dialog edit album
  void _showEditAlbumDialog() {
    TextEditingController nameController = TextEditingController(text: _albumName);
    TextEditingController descController = TextEditingController(text: _albumDescription);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Album"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Nama Album"),
              ),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: "Deskripsi Album"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _albumName = nameController.text;
                  _albumDescription = descController.text;
                });
                _updateAlbum(); // Simpan ke database
                Navigator.pop(context);
              },
              child: Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_albumName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditAlbumDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text("Edit Album"),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _albumDescription,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailPage(
                            imagePath: _images[index]['imagePath']!,
                            imageUrl: "${Config.baseUrl}/${_images[index]['imagePath']}",
                            // initialTitle: _images[index]['judulFoto']!,
                            initialDescription: _images[index]['deskripsi']!,
                            onDescriptionChanged: (newDescription) {
                              setState(() {
                                _images[index]['deskripsi'] = newDescription;
                              });
                            },
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        "${Config.baseUrl}/${_images[index]['imagePath']?.toString().replaceAll("https://", "http://")}",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 50),
                      )
                    )
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
