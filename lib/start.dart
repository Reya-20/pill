import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register.dart'; // Import your registration screen
import 'user/user_dashboard.dart'; // Import user dashboard
import 'caregiver/caregiver_dashboard.dart'; // Import caregiver dashboard
import 'dart:async'; // For Timer functionality
import 'superadmin/HomePage.dart'; // Superadmin Dashboard
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ValueNotifier<String?> _errorMessage = ValueNotifier<String?>(null);
  Timer? _errorTimer;
  bool _isLoading = false;

  // Email validation
  String? _validateEmail(String? value) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    } else if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    // Check if email and password are provided
    if (email.isEmpty || password.isEmpty) {
      _setErrorMessage('Email and password cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Prepare the API request
    try {
      final response = await http.post(
        Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/login.php'), // Your API URL
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          // Navigate based on role
          if (result['role'] == '0') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()), // User Dashboard
            );
          } else if (result['role'] == '1') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeCareScreen()), // Caregiver Dashboard
            );
          } else if (result['role'] == '2') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen()), // Superadmin Dashboard
            );
          }
        } else {
          _setErrorMessage(result['message']);
        }
      } else {
        _setErrorMessage('Error: ${response.statusCode}');
      }
    } catch (e) {
      _setErrorMessage('Failed to connect to the server');
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  // Function to handle error message reset after delay
  void _setErrorMessage(String message) {
    if (_errorTimer != null && _errorTimer!.isActive) {
      _errorTimer!.cancel();
    }

    _errorMessage.value = message;
    _errorTimer = Timer(Duration(seconds: 5), () {
      setState(() {
        _errorMessage.value = null;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _errorMessage.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF39cdaf), Color(0xFF26394A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or Icon at the top
                Icon(
                  Icons.medical_services, // Medical icon
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),

                // Welcome Text
                Text(
                  'Welcome to PillCare',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Login Prompt
                const Text(
                  'Please log in to continue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Error Message
                ValueListenableBuilder<String?>(
                  valueListenable: _errorMessage,
                  builder: (context, error, child) {
                    return error != null
                        ? Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                        : SizedBox.shrink(); // Return empty widget if no error
                  },
                ),
                const SizedBox(height: 30),

                // Email Input Field
                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Password Input Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 40),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login, // Disable button during loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Color(0xFF26394A)) // Show spinner during loading
                      : const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF26394A),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
