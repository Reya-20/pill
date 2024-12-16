
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'add_pill_dashboard.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'add_patient_name.dart';
import '../include/sidebar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MedicineScreen(),
    );
  }
}

class MedicineScreen extends StatefulWidget {
  @override
  _MedicineScreenState createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _medicineController = TextEditingController();
  final TextEditingController _medicineCountController = TextEditingController();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> _medicineList = [];
  int userRole = 1;
  int? selectedContainer;

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    final url = Uri.parse('http://springgreen-rhinoceros-308382.hostingersite.com/pill_api/get_pill.php');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          _medicineList = responseData.map((pill) {
            return {
              'pill_name': pill['pill_name'],
              'pill_count': pill['pill_count'],
              'container': pill['container_id'],
              'pill_id': pill['pill_id'], // Add pill_id
            };
          }).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error fetching medicine data: ${response.statusCode}'),
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

  void _addMedicine() async {
    if (_medicineController.text.isNotEmpty &&
        _medicineCountController.text.isNotEmpty &&
        selectedContainer != null) {
      String medicineName = _medicineController.text;
      int medicineCount;

      try {
        medicineCount = int.parse(_medicineCountController.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please enter a valid number for medicine count'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      bool success = await uploadMedicines(medicineName, medicineCount, selectedContainer!);

      if (success) {
        setState(() {
          _medicineList.add({
            'pill_name': medicineName,
            'pill_count': medicineCount,
            'container': selectedContainer,
          });
          _medicineController.clear();
          _medicineCountController.clear();
          selectedContainer = null;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter medicine name, count, and select a container'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<bool> uploadMedicines(String medicineName, int pillCount, int container) async {
    final url = Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/post_pill.php');
    try {
      final requestBody = json.encode({
        'medicine_name': medicineName,
        'pill_count': pillCount,
        'container': container,
      });

      final response = await http.post(url, body: requestBody, headers: {
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success']) {
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${responseBody['message']}'),
            backgroundColor: Colors.red,
          ));
          return false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Server error: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ));
        return false;
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ));
      return false;
    }
  }

  void _deleteMedicine(int index) {
    // Get the pill_id from the medicine data and convert it to an integer
    var pillId = _medicineList[index]['pill_id'];

    if (pillId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: pill_id is missing for this medicine'),
        backgroundColor: Colors.red,
      ));
      return;  // Early return if pill_id is null
    }

    // Ensure pillId is an integer (it might be a string from the list)
    pillId = int.tryParse(pillId.toString()) ?? -1;  // Convert to int, or -1 if conversion fails

    if (pillId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: Invalid pill_id format'),
        backgroundColor: Colors.red,
      ));
      return;  // Early return if pillId is invalid
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Delete Medicine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete this medicine?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                // Proceed with deletion
                bool success = await _deleteMedicineFromDB(pillId); // Pass pillId here
                if (success) {
                  setState(() {
                    _medicineList.removeAt(index);  // Remove item from local list
                  });
                }
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _deleteMedicineFromDB(int pillId) async {
    final url = Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/delete_pill.php');

    try {
      final requestBody = json.encode({
        'pill_id': pillId, // Pass the correct pill_id
      });

      final response = await http.post(url, body: requestBody, headers: {
        "Content-Type": "application/json",
      });

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['success']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Medicine deleted successfully'),
            backgroundColor: Colors.green,
          ));
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${responseBody['message']}'),
            backgroundColor: Colors.red,
          ));
          return false;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Server error: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ));
        return false;
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ));
      return false;
    }
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Add Medicine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _medicineController,
                  decoration: InputDecoration(
                    labelText: 'Enter Medicine Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _medicineCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter Medicine Count',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedContainer,
                  hint: Text("Choose container"),
                  isExpanded: true,
                  items: List.generate(5, (index) {
                    return DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    );
                  }),
                  onChanged: (int? newValue) {
                    setState(() {
                      selectedContainer = newValue;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _addMedicine();
                Navigator.of(context).pop();
              },
              child: Text("Add"),
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
        title: Text('Add Medicine'),
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
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF39cdaf),
              Color(0xFF0E4C92),
            ],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 0.75,
          ),
          itemCount: _medicineList.length,
          itemBuilder: (context, index) {
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.4),
              color: Colors.white,
              margin: EdgeInsets.all(8),
              child: InkWell(
                onTap: () {
                  // You can add some interactive functionality here if needed
                },
                borderRadius: BorderRadius.circular(15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      // Centered icon
                      Center(
                        child: Icon(
                          Icons.medication,
                          size: 60,
                          color: Color(0xFF39cdaf),
                        ),
                      ),
                      // Positioned text below the icon
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          children: [
                            Text(
                              _medicineList[index]['pill_name'] ?? 'Unknown',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E4C92),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Count: ${_medicineList[index]['pill_count']}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit and Delete buttons
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _deleteMedicine(index);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDialog,
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF39cdaf),
      ),
    );
  }
}
