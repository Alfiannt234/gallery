import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:galeri/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadPage extends StatefulWidget {
  final Function(String) onImageUploaded;

  const UploadPage({Key? key, required this.onImageUploaded}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  final ApiService apiService = ApiService();
  int? userId;

  // Tambahan: Controller untuk input Judul dan Deskripsi
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

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

 void _uploadImage() async {
  if (_selectedImage == null) {
    print("⚠️ Gambar belum dipilih.");
    _showErrorDialog("Silakan pilih gambar terlebih dahulu.");
    return;
  }

  // 🔹 Cek apakah file ada di storage
  bool fileExists = await _selectedImage!.exists();
  print("📂 Apakah file gambar ada? $fileExists");

  if (!fileExists) {
    print("❌ File gambar tidak ditemukan.");
    _showErrorDialog("File gambar tidak ditemukan. Coba pilih ulang.");
    return;
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? savedUserId = prefs.getInt('userId');

  if (savedUserId == null) {
    print("❌ User ID belum tersedia di SharedPreferences.");
    _showErrorDialog("User ID tidak ditemukan. Silakan login ulang.");
    return;
  }

  String judulFoto = _judulController.text.trim();
  String deskripsi = _deskripsiController.text.trim();
  
  if (judulFoto.isEmpty || deskripsi.isEmpty) {
    print("⚠️ Judul atau Deskripsi masih kosong.");
    _showErrorDialog("Judul dan Deskripsi harus diisi.");
    return;
  }

  int idAlbum = 0; // Sesuaikan dengan album yang dipilih

  print("🔹 Data yang akan dikirim ke server:");
  print("   - Path Gambar: ${_selectedImage!.path}");
  print("   - Judul Foto: $judulFoto");
  print("   - Deskripsi: $deskripsi");
  print("   - ID Album: $idAlbum");
  print("   - ID User: $savedUserId");

  bool success = await apiService.uploadImage(
    _selectedImage!, 
    judulFoto, 
    deskripsi, 
    idAlbum.toString(), // ✅ Ubah ke String
    savedUserId.toString() // ✅ Ubah ke String
  );

  if (success) {
    print("✅ Upload berhasil!");
    widget.onImageUploaded("URL_IMAGE_BARU");
    Navigator.pop(context);
  } else {
    print("❌ Upload gagal.");
    _showErrorDialog("Gagal mengunggah gambar. Coba lagi.");
  }
}

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      print("✅ Gambar dipilih: ${_selectedImage!.path}");
    } else {
      print("⚠️ Tidak ada gambar yang dipilih.");
    }
  }

  // Fungsi untuk menampilkan error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Peringatan"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Gambar")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _selectedImage != null
                ? Image.file(_selectedImage!, height: 200)
                : const Icon(Icons.image, size: 100, color: Colors.grey),
            const SizedBox(height: 20),

            // Input untuk Judul Foto
            TextField(
              controller: _judulController,
              decoration: const InputDecoration(
                labelText: "Judul Foto",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Input untuk Deskripsi
            TextField(
              controller: _deskripsiController,
              decoration: const InputDecoration(
                labelText: "Deskripsi",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              child: const Text("Pilih dari Galeri"),
            ),
            ElevatedButton(
              onPressed: () => _pickImage(ImageSource.camera),
              child: const Text("Ambil Foto"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text("Unggah Gambar"),
            ),
          ],
        ),
      ),
    );
  }
}
