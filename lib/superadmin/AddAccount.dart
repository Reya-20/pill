import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuperAdminScreen extends StatefulWidget {
  @override
  _SuperAdminScreenState createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final List<Map<String, String>> accounts = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> _createAccount(String firstName, String lastName, String username, String password) async {
    setState(() {
      isLoading = true;
    });

    final uri = Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/register.php');
    final Map<String, String> data = {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'password': password,
      'confirm_password': password,
    };

    try {
      final response = await http.post(uri, body: data);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          setState(() {
            accounts.add({
              'first_name': firstName,
              'last_name': lastName,
              'username': username,
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Account created successfully!")),
          );
        } else {
          setState(() {
            errorMessage = "Failed to create account: ${result['message']}";
          });
        }
      } else {
        setState(() {
          errorMessage = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "An error occurred: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showAddAccountDialog() {
    final TextEditingController firstNameController = TextEditingController();
    final TextEditingController lastNameController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Account'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _buildTextField('First Name', firstNameController),
                const SizedBox(height: 10),
                _buildTextField('Last Name', lastNameController),
                const SizedBox(height: 10),
                _buildTextField('Username', usernameController),
                const SizedBox(height: 10),
                _buildTextField('Password', passwordController, isPassword: true),
                const SizedBox(height: 10),
                _buildTextField('Confirm Password', confirmPasswordController, isPassword: true),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                if (passwordController.text != confirmPasswordController.text) {
                  setState(() {
                    errorMessage = "Passwords do not match!";
                  });
                  return;
                }

                _createAccount(
                  firstNameController.text.trim(),
                  lastNameController.text.trim(),
                  usernameController.text.trim(),
                  passwordController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: isLoading
                  ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : Text('Add Account'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Superadmin Dashboard"),
        backgroundColor: Color(0xFF26394A),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: accounts.isEmpty
            ? Center(
          child: Text(
            "No accounts added yet.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        )
            : ListView.builder(
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('${account['first_name']} ${account['last_name']}'),
                subtitle: Text(account['username']!),
                trailing: Icon(Icons.person),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF39cdaf),
      ),
    );
  }
}