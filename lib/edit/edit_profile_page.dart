import 'package:flutter/material.dart';
import 'package:galeri/config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:galeri/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  final String email;
  final String fullName;
  final String username;
  final String address;
  final File? profileImage;
  final Function(String, String, String, File?) onProfileUpdated;

  const EditProfilePage({
    Key? key,
    required this.email,
    required this.fullName,
    required this.username,
    required this.address,
    required this.onProfileUpdated,
    this.profileImage,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _addressController;
  File? _newProfileImage;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName);
    _usernameController = TextEditingController(text: widget.username);
    _addressController = TextEditingController(text: widget.address);
    _newProfileImage = widget.profileImage;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfileImage = File(pickedFile.path);
      });
    }
  }

  void _saveProfile() async {
  String updatedFullName = _fullNameController.text;
  String updatedUsername = _usernameController.text;
  String updatedAddress = _addressController.text;

  print("Email yang dikirim dari EditProfilePage: ${widget.email}");

  var request = http.MultipartRequest("POST", Uri.parse("${Config.baseUrl}/update_user.php"));

  // Tambahkan data teks ke form-data
  request.fields['email'] = widget.email;
  if (updatedFullName.isNotEmpty && updatedFullName != widget.fullName) {
    request.fields['fullName'] = updatedFullName;
  }
  if (updatedUsername.isNotEmpty && updatedUsername != widget.username) {
    request.fields['username'] = updatedUsername;
  }
  if (updatedAddress.isNotEmpty && updatedAddress != widget.address) {
    request.fields['address'] = updatedAddress;
  }

  // ✅ Kirim gambar sebagai file upload, bukan hanya path
  if (_newProfileImage != null && await _newProfileImage!.exists()) {
  try {
    request.files.add(await http.MultipartFile.fromPath('profileImage', _newProfileImage!.path));
  } catch (e) {
    print("Gagal menambahkan file gambar: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal memuat gambar. Pilih ulang gambar Anda.")),
    );
    return; // Hentikan eksekusi jika terjadi kesalahan
  }
} else {
  print("Tidak ada gambar yang dipilih.");
}

  print("Data dikirim ke API: ${request.fields}");

  // Kirim request
  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    var result = jsonDecode(response.body);
    if (result['success']) {
      widget.onProfileUpdated(
        updatedFullName.isNotEmpty ? updatedFullName : widget.fullName,
        updatedUsername.isNotEmpty ? updatedUsername : widget.username,
        updatedAddress.isNotEmpty ? updatedAddress : widget.address,
        _newProfileImage,
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memperbarui profil")));
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _newProfileImage != null ? FileImage(_newProfileImage!) : null,
                child: _newProfileImage == null ? const Icon(Icons.person, size: 50) : null,
              ),
            ),
            TextField(controller: _fullNameController, decoration: const InputDecoration(labelText: "Nama Lengkap")),
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: "Username")),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: "Alamat")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
