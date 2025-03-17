import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:galeri/config.dart';

class ApiService {

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("${Config.baseUrl}/login.php"),
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Gagal login");
    }
  }

   Future<Map<String, dynamic>> getUserData(String email) async {
    final response = await http.get(Uri.parse("${Config.baseUrl}/get_user.php?email=$email"));

    if (response.statusCode == 200) {
    var data = json.decode(response.body);
    if (data['success']) {
      return data;
    } else {
      throw Exception(data['message']);
    }
  } else {
    throw Exception("Gagal mengambil data pengguna");
  }
}

  Future<bool> updateUserData(Map<String, dynamic> userData) async {
  var request = http.MultipartRequest("POST", Uri.parse("${Config.baseUrl}/update_user.php"));

  // Tambahkan data ke form-data
  userData.forEach((key, value) {
    if (value != null) {
      request.fields[key] = value.toString();
    }
  });

  if (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty) {
    try {
      request.files.add(await http.MultipartFile.fromPath('profileImage', userData['profileImage']));
    } catch (e) {
      print("Gagal menambahkan file gambar: $e");
    }
  }

  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    return json.decode(response.body)['success'];
  } else {
    throw Exception("Gagal memperbarui data pengguna");
  }

}

Future<int?> getUserIdByEmail(String email) async {
  final response = await http.get(Uri.parse("${Config.baseUrl}/get_user.php?email=$email"));
  
  print("📡 Response dari server: ${response.body}"); // Debugging
  
  if (response.statusCode == 200) {
    var data = json.decode(response.body);
    
    if (data['success']) {
      print("✅ ID User ditemukan: ${data['id_user']}");
      return data['id_user']; // Pastikan tipe data sudah benar
    } else {
      print("❌ User tidak ditemukan: ${data['message']}");
    }
  } else {
    print("❌ HTTP Error: ${response.statusCode}");
  }
  return null;
}

Future<List<String>> getUploadedImages(int userId) async {
  final response = await http.get(Uri.parse("${Config.baseUrl}/get_upload_image.php?userId=$userId"));

  print("📡 Response dari server: ${response.body}"); // Debug respons

  if (response.statusCode == 200) {
    var data = json.decode(response.body);

    if (data['success']) {
      List<String> images = List<String>.from(data['images']);
      print("✅ Gambar ditemukan: $images");
      return images;
    } else {
      print("❌ Tidak ada gambar: ${data['message']}");
    }
  } else {
    print("❌ HTTP Error: ${response.statusCode}");
  }
  
  return [];
}

  Future<bool> uploadImage(File imageFile, String judulFoto, String deskripsi, String idAlbum, String idUser) async {
    var uri = Uri.parse("${Config.baseUrl}/upload_image.php");
    var request = http.MultipartRequest('POST', uri);

    // ✅ Tambahkan data teks
    request.fields['judul_foto'] = judulFoto;
    request.fields['deskripsi'] = deskripsi;
    request.fields['id_user'] = idUser;
    request.fields['id_album'] = idAlbum;

    // ✅ Pastikan file dikirim sebagai MultipartFile
    request.files.add(
      await http.MultipartFile.fromPath(
        'image', imageFile.path,
        contentType: MediaType('image', 'jpeg'), // 🔹 Pastikan tipe file benar
      ),
    );

    try {
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      print("📩 Response dari server: $jsonResponse");

      if (jsonResponse['success'] == true) {
        print("✅ Upload sukses: ${jsonResponse['message']}");
        return true;
      } else {
        print("❌ Upload gagal: ${jsonResponse['message']}");
        return false;
      }
    } catch (e) {
      print("❌ Error saat upload: $e");
      return false;
    }
  }

//   Future<bool> deleteImage(String imageId) async {
//   final response = await http.post(
//     Uri.parse("$baseUrl/delete_image.php"),
//     body: {
//       'id_image': imageId,
//     },
//   );

//   if (response.statusCode == 200) {
//     var data = json.decode(response.body);
//     if (data['success']) {
//       return true;
//     } else {
//       throw Exception(data['message']);
//     }
//   } else {
//     throw Exception("Gagal menghapus gambar");
//   }
// }

Future<int?> getFotoId(String imageUrl) async {
  final response = await http.get(Uri.parse("${Config.baseUrl}/get_foto_id.php?url=$imageUrl"));

  print("📡 Response dari server: ${response.body}"); // Debug respons

  if (response.statusCode == 200) {
    var data = json.decode(response.body);

    if (data['success']) {
      int idFoto = int.tryParse(data['id_foto'].toString()) ?? 0;
      print("✅ ID Foto ditemukan: $idFoto");
      return idFoto;
    } else {
      print("❌ Foto tidak ditemukan: ${data['message']}");
    }
  } else {
    print("❌ HTTP Error: ${response.statusCode}");
  }

  return null; // Jika gagal
}

Future<Map<String, dynamic>?> getFoto(String relativePath) async {
    final url = Uri.parse('${Config.baseUrl}/get_foto.php?path=$relativePath');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['foto'];
        }
      }
    } catch (e) {
      print("❌ Error mengambil foto: $e");
    }
    return null;
  }

  Future<bool> updateFoto({
    required String imagePath,
    required String judulFoto,
    required String deskripsi,
  }) async {
    final url = Uri.parse('${Config.baseUrl}/update_foto.php'); // Sesuaikan dengan backend
    final response = await http.post(
      url,
      body: {
        'image_path': imagePath,
        'judul_foto': judulFoto,
        'deskripsi': deskripsi,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      return false;
    }
  }

  Future<List<String>> getAllUploadedImages() async {
     final response = await http.get(Uri.parse("${Config.baseUrl}/get_all_images.php"));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['success']) {
        return List<String>.from(data['images']);
      }
    }
    return [];
  }

Future<bool> toggleLike(int idFoto, int idUser) async {
  final url = Uri.parse("${Config.baseUrl}/like_foto.php");
  final body = jsonEncode({"id_foto": idFoto, "id_user": idUser});

  print("🔄 Mengirim request ke API: $body");

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: body,
  );

  print("📡 Response dari server: ${response.body}");

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    print("✅ Like berhasil? ${data['liked']}");
    return data['liked'];
  } else {
    print("❌ HTTP Error: ${response.statusCode} - ${response.body}");
    return false;
  }
}



  Future<bool> checkIfLiked(int idFoto, int idUser) async {
  final response = await http.get(Uri.parse("${Config.baseUrl}/cek_like.php?cek_like&id_foto=$idFoto&id_user=$idUser"));
  
  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    return data['liked']; // Mengembalikan true jika sudah like, false jika belum
  }
  return false;
}

Future<int> getLikeCount(int idFoto) async {
  final url = Uri.parse("${Config.baseUrl}/get_like.php?get_like_count&id_foto=$idFoto");

  print("🔄 Mengambil jumlah like dari API: $url");

  final response = await http.get(url);

  print("📡 Response dari server: ${response.body}");

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['like_count'] ?? 0;
  } else {
    print("❌ HTTP Error: ${response.statusCode} - ${response.body}");
    return 0;
  }
}
}

