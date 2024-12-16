import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../include/sidebar.dart';

class PatientScreen extends StatefulWidget {
  @override
  _PatientScreenState createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> _patientList = [];
  int userRole = 1; // Set user role (0 or 1) based on your logic

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    final url = Uri.parse(
        'https://springgreen-rhinoceros-308382.hostingersite.com/get_patient.php');

    try {
      final response = await http.get(url);
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _patientList = (responseData as List<dynamic>).map((patient) =>
          {
            'name': patient['patient_name'] ?? '',
            'username': patient['username'] ?? '',
            'password': patient['password'] ?? '',

          }).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error fetching patient data: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _addPatient() async {
    if (_nameController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      String name = _nameController.text;
      String username = _usernameController.text;
      String password = _passwordController.text;

      setState(() {
        _patientList.add({
          'name': name,
          'username': username,
          'password': password,
          'isActive': true, // Default to active
        });
        _nameController.clear();
        _usernameController.clear();
        _passwordController.clear();
      });

      await _uploadPatient(name, username, password);
    }
  }

  Future<void> _uploadPatient(String name, String username,
      String password) async {
    final url = Uri.parse(
        'https://springgreen-rhinoceros-308382.hostingersite.com/post_patient.php'); // Ensure this URL is correct.

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'patient_name': name,
          'username': username,
          'password': password,
        }), // Properly encoding the body to JSON
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Patient added successfully!'),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${responseBody['message']}'),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Server error: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _deletePatient(int index) {
    setState(() {
      _patientList.removeAt(index);
    });
  }

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Patient'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(hintText: 'Patient Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(hintText: 'Username'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(hintText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _addPatient();
                Navigator.of(context).pop();
              },
              child: Text('Add Patient'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState!.openDrawer();
          },
        ),
        title: Text('Patient List'),
        backgroundColor: Color(0xFF0E4C92),
      ),
      drawer: CustomDrawer(
        scaffoldKey: _scaffoldKey,
        flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
        userRole: userRole,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF39cdaf), Color(0xFF26394A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: _patientList.isEmpty
                    ? Center(
                  child: Text(
                    "No patients added yet.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                )
                    : ListView.builder(
                  itemCount: _patientList.length,
                  itemBuilder: (context, index) {
                    final patient = _patientList[index];
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFF0E4C92),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.person,
                              size: 20), // Circle icon for patient
                        ),
                        title: Text(
                          patient['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF26394A),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deletePatient(index);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${patient['name']} deleted successfully'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPatientDialog,
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF0E4C92),
      ),
    );
  }
}