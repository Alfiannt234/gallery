import 'package:flutter/material.dart';
import 'package:galeri/config.dart';
import 'main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sign_up_page.dart';
import 'forget_password_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Mengecek status login
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    }
  }

  // Fungsi untuk login
  Future<void> _login() async {
  final response = await http.post(
    Uri.parse('${Config.baseUrl}/login.php'),
    body: {
      'email': _emailController.text,
      'password': _passwordController.text,
    },
  );

  print("Response: ${response.body}");  // Debugging

  final result = jsonDecode(response.body); // Error terjadi di sini

  setState(() {
    // _isLoading = false;
  });

  if (response.statusCode == 200) {
    // final result = jsonDecode(response.body);

    if (result['success']) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', true);
      prefs.setInt('userId', result['id_user']);
      prefs.setString('email', result['email']);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(
       ),
      ),
    );
    } else {
      _showErrorDialog(result['message']);
    }
  } else {
    _showErrorDialog('Error connecting to server. Please try again.');
  }
}
  // Menampilkan dialog error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Gagal'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Navigasi ke halaman Register
  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpPage()),
    );
  }

  // Navigasi ke halaman Forget Password
  void _goToForgetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgetPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/logo.png',
                height: 120,
              ),
              const SizedBox(height: 16),
              // Nama Aplikasi
              const Text(
                'Gallery',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              // Input Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Input Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tombol Login
              ElevatedButton(
                      onPressed: _login,
                      child: const Text("Login"),
                    ),
              const SizedBox(height: 20),
              // Register Here
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: _goToSignUp,
                    child: const Text(
                      'Register',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Forget Password
              GestureDetector(
                onTap: _goToForgetPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
