import 'package:flutter/material.dart';
import 'package:galeri/config.dart';
import 'package:galeri/services/api_service.dart'; // Ganti dengan lokasi file API service

class EditImagePage extends StatefulWidget {
  final String imageUrl;
  final String imagePath;
  final String initialTitle;
  final String initialDescription;

  const EditImagePage({
    Key? key,
    required this.imageUrl,
    required this.imagePath,
    required this.initialTitle,
    required this.initialDescription,
  }) : super(key: key);

  @override
  _EditImagePageState createState() => _EditImagePageState();
}

class _EditImagePageState extends State<EditImagePage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isSaving = false; // Indikator loading saat menyimpan

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    // Kirim data ke API untuk update ke database
    String relativePath = widget.imageUrl.replaceFirst(RegExp("^${RegExp.escape(Config.baseUrl2)}"), "");
    final response = await ApiService().updateFoto(
      imagePath: relativePath,
      judulFoto: _titleController.text,
      deskripsi: _descriptionController.text,
    );

    setState(() {
      _isSaving = false;
    });

    if (response) {
      // Jika sukses, kembalikan data yang diperbarui
      Navigator.pop(context, {
        'judul_foto': _titleController.text,
        'deskripsi': _descriptionController.text,
      });
    } else {
      // Jika gagal, tampilkan pesan error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan perubahan!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Gambar'),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _saveChanges,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Image.network(widget.imageUrl, fit: BoxFit.cover),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Edit Judul Foto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Edit Deskripsi',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
