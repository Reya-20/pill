import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF006D77),
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Roboto',
      ),
      home: AlarmScreen(),
    );
  }
}

class AlarmScreen extends StatefulWidget {
  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _reminderMessageController = TextEditingController();
  String? _selectedPillId;
  String? _selectedPatientId;
  List<Map<String, dynamic>> _medicineData = [];
  List<Map<String, dynamic>> _patientData = [];
  List<Map<String, dynamic>> _alarms = [];
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  @override
  void initState() {
    super.initState();
    _fetchMedicineNames();
    _fetchPatientNames();
    _fetchReminders();
  }

  @override
  void dispose() {
    _reminderMessageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMedicineNames() async {
    try {
      final response = await http.get(
        Uri.parse('http://springgreen-rhinoceros-308382.hostingersite.com/pill_api/get_pill.php'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _medicineData = data.map((item) => {
            'pill_id': item['pill_id'],
            'pill_name': item['pill_name']
          }).toList();
        });
      } else {
        print('Failed to load medicine names: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching medicine names: $e');
    }
  }

  Future<void> _fetchPatientNames() async {
    try {
      final response = await http.get(
        Uri.parse('http://springgreen-rhinoceros-308382.hostingersite.com/get_patient.php'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _patientData = data.map((item) => {
            'patient_id': item['patient_id'],
            'patient_name': item['patient_name']
          }).toList();
        });
      } else {
        print('Failed to load patient names: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching patient names: $e');
    }
  }

  Future<void> _fetchReminders() async {
    try {
      final response = await http.get(
        Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/get_alarm.php'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _alarms = List<Map<String, dynamic>>.from(data['data']).map((alarm) {
              return {
                ...alarm,
                'time': _formatTimeFromString(alarm['formatted_time'] ?? '00:00 AM'),
                'pill_name': alarm['pill_name'] ?? 'Unknown Pill',
                'patient_name': alarm['patient_name'] ?? 'Unknown Patient',
                'reminder_message': alarm['reminder_message'] ?? 'No Reminder Message',
              };
            }).toList();
          });
        } else {
          print('Error: Invalid data structure.');
        }
      } else {
        print('Failed to load reminders. HTTP status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching reminders: $e');
    }
  }

  String _formatTimeFromString(String time) {
    try {
      final timeParts = time.split(' ');
      final formattedTime = '${timeParts[0]} ${timeParts[1]}';
      return formattedTime;
    } catch (e) {
      return 'Invalid time';
    }
  }

  Future<void> _submitData() async {
    final pillId = _selectedPillId;
    final patientId = _selectedPatientId;
    final reminderMessage = _reminderMessageController.text.trim();
    final time = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    if (pillId == null || patientId == null || reminderMessage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final uri = Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/add_reminder.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'pill_id': pillId,
          'patient_id': patientId,
          'message': reminderMessage,
          'time': time,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder added successfully')),
          );

          setState(() {
            _selectedPillId = null;
            _selectedPatientId = null;
            _reminderMessageController.clear();
            _selectedTime = TimeOfDay.now();
          });

          _fetchReminders();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(responseData['message'] ?? 'Failed to add reminder')),
          );
        }
      } else {
        print('Failed to add reminder. HTTP status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting reminder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred. Please check your internet connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Medicine Reminder',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_alarm,
              color: Colors.white,
            ),

            onPressed: () => _showBottomSheet(context), // For adding a new reminder
          ),
        ],

        backgroundColor: Color(0xFF006D77),
        elevation: 0,
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
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            ..._alarms.map((alarm) => _buildAlarmCard(alarm)).toList(),
            SizedBox(height: 20),
            Center(
              child: Text(
                'Manage Your Medicine Reminders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: Colors.white),
              ),
            ),
          ],
        ),
      ),

    );
  }

  Widget _buildAlarmCard(Map<String, dynamic> alarm) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Alarm Time Container
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Color(0xFF006D77),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                alarm['time'] ?? '00:00 AM',  // Default time if null
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 20),
            // Alarm Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm['pill_name'] ?? 'Unknown Pill',  // Default pill name if null
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'To: ${alarm['patient_name'] ?? 'Unknown'} - ${alarm['reminder_message'] ?? 'No Reminder Message'}',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            // Delete Button
            IconButton(
              onPressed: () {
                final alarmId = alarm['id'];  // Check if 'alarm_id' exists
                if (alarmId != null && alarmId is String) {
                  _confirmDelete(alarmId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid Alarm ID')),
                  );
                }
              },
              icon: Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

// Function to show a confirmation dialog before deleting
  void _confirmDelete(String alarmId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Alarm'),
          content: Text('Are you sure you want to delete this alarm?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteAlarmFromDatabase(alarmId);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteAlarmFromDatabase(String alarmId) async {
    if (alarmId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid Alarm ID')),
      );
      return;
    }

    final url = 'https://springgreen-rhinoceros-308382.hostingersite.com/delete_alarm.php';
    final response = await http.post(
      Uri.parse(url),
      body: {
        'id': alarmId,
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['success']) {
        setState(() {
          _alarms.removeWhere((alarm) => alarm['id'] == alarmId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alarm deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete alarm: ${responseData['message']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${response.statusCode}, ${response.body}')),
      );
    }

  }

  void _showBottomSheet(BuildContext context) {
    // Controllers for Start Date and End Date fields
    TextEditingController startDateController = TextEditingController(
      text: _selectedStartDate == null
          ? ''
          : '${_selectedStartDate!.toLocal()}'.split(' ')[0],
    );
    TextEditingController endDateController = TextEditingController(
      text: _selectedEndDate == null
          ? ''
          : '${_selectedEndDate!.toLocal()}'.split(' ')[0],
    );

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedPillId,
                      items: _medicineData.map((medicine) {
                        return DropdownMenuItem<String>(
                          value: medicine['pill_id'],
                          child: Text(medicine['pill_name']),
                        );
                      }).toList(),
                      onChanged: (value) => setModalState(() {
                        _selectedPillId = value!;
                      }),
                      decoration: InputDecoration(
                        labelText: 'Select Pill',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedPatientId,
                      items: _patientData.map((patient) {
                        return DropdownMenuItem<String>(
                          value: patient['patient_id'],
                          child: Text(patient['patient_name']),
                        );
                      }).toList(),
                      onChanged: (value) => setModalState(() {
                        _selectedPatientId = value!;
                      }),
                      decoration: InputDecoration(
                        labelText: 'Select Patient',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _reminderMessageController,
                      decoration: InputDecoration(
                        labelText: 'Reminder Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (pickedTime != null) {
                          setModalState(() {
                            _selectedTime = pickedTime;
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: _selectedTime.format(context),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        DateTime? pickedStartDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (pickedStartDate != null) {
                          setModalState(() {
                            _selectedStartDate = pickedStartDate;
                            startDateController.text =
                            '${_selectedStartDate!.toLocal()}'.split(' ')[0];
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                          ),
                          controller: startDateController,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        DateTime? pickedEndDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (pickedEndDate != null) {
                          setModalState(() {
                            _selectedEndDate = pickedEndDate;
                            endDateController.text =
                            '${_selectedEndDate!.toLocal()}'.split(' ')[0];
                          });
                        }
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                          ),
                          controller: endDateController,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _submitData();
                        Navigator.of(context).pop(); // Close the bottom sheet
                      },
                      child: Text('Save Reminder'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

}