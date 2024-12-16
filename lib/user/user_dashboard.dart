import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../include/sidebar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Import for date formatting
import 'dart:async'; // Import for Timer

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int userRole = 0; // Set user role (0 or 1)
  List<dynamic> alarmData = [];
  bool hasNoAlarms = true; // Flag for no alarms
  bool _isDialogShowing = false; // Flag for dialog display
  Timer? _timer; // Timer for checking alarms
  Timer? _soundLoopTimer; // Timer for looping sound
  List<Map<String, dynamic>> _alarms = []; // List to hold fetched alarms
  TimeOfDay _selectedTime = TimeOfDay.now(); // Selected time for alarms

  @override
  void initState() {
    super.initState();
    _startCheckingTime(); // Start checking time immediately
    _fetchAlarmData(); // Fetch alarms on initialization
  }

  @override
  void dispose() {
    _timer?.cancel();
    _soundLoopTimer?.cancel(); // Stop looping sound timer on dispose
    super.dispose();
  }

  Future<void> _fetchAlarmData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://springgreen-rhinoceros-308382.hostingersite.com/get_alarm.php'));

      if (response.statusCode == 200) {
        // Log the response body to see the structure
        print('Response body: ${response.body}');

        // Decode the JSON response into a Map
        final Map<String, dynamic> data = json.decode(response.body);

        // Check if the 'success' key exists and if the 'data' key is a list
        if (data['success'] == true && data['data'] is List) {
          setState(() {
            // Format the time for each alarm to 12-hour format with AM/PM
            _alarms =
                List<Map<String, dynamic>>.from(data['data']).map((alarm) {
                  // Ensure no null values are being used, provide default values where necessary

                  String time = alarm['formatted_time'] ?? '00:00 AM'; // Provide default time if null
                  String reminderMessage = alarm['reminder_message'] ?? ''; // Provide empty string if null
                  String patientName = alarm['patient_name'] ?? 'Unknown'; // Provide default name if null
                  String pillName = alarm['pill_name'] ?? 'Unknown Pill'; // Provide default pill name if null

                  return {
                    'id': alarm['id'],
                    'time': time, // Time is already formatted in the response
                    'reminder_message': reminderMessage,
                    'patient_name': patientName,
                    'pill_name': pillName,
                  };
                }).toList();
            alarmData = _alarms;
            hasNoAlarms = alarmData.isEmpty;
          });
        } else {
          // Handle the case where the response data doesn't match the expected format
          print(
              'Error: Expected a list of alarms but found something else or success is false.');
          setState(() {
            _alarms = []; // Reset the alarms list if the data is not valid
          });
        }
      } else {
        print('Failed to load reminders. HTTP status: ${response.statusCode}');
        setState(() {
          _alarms = []; // Reset the alarms list in case of failure
        });
      }
    } catch (e) {
      print('Error fetching reminders: $e');
      setState(() {
        _alarms = []; // Reset the alarms list in case of error
      });
    }
  }


  Future<void> _startCheckingTime() async {
    print('Start checking time...'); // This line will output to the terminal
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      await _checkAlarms();
    });
  }

  Future<void> _checkAlarms() async {
    final now = DateTime.now();
    final currentTime = DateFormat('h:mm a').format(now).trim(); // Current time in 12-hour format, trimmed

    print('Current time: $currentTime'); // Debugging: print current time

    if (_alarms.isEmpty) {
      print('No alarms available');
    } else {
      print('Checking alarms...');
      for (var alarm in _alarms) {
        final alarmTime = alarm['time'] as String?;  // Time from the alarm data (assumed to be in 12-hour format)
        if (alarmTime != null) {
          final formattedAlarmTime = alarmTime.trim(); // Format alarm time to remove extra spaces

          print('Checking alarm with time: $formattedAlarmTime');

          // Normalize both times by parsing them to DateTime objects
          try {
            final currentTimeDate = DateFormat('h:mm a').parse(currentTime);
            final alarmTimeDate = DateFormat('h:mm a').parse(formattedAlarmTime);

            // Compare the DateTime objects directly
            if (currentTimeDate == alarmTimeDate && !_isDialogShowing) {
              print('Time matches! Triggering alarm.');

              // Show the modal (dialog)
              _showAlarmDialog(alarm);

              // Play alarm sound
              _playAlarmSound();

              // Set a timer to mark the alarm as missed after a specified duration (if not dismissed)
              _timer = Timer(Duration(minutes: 3), () async {
                if (_isDialogShowing) {
                  // If the dialog is still showing, mark the alarm as missed
                  await _updateAlarmStatusToMissed(alarm['id']);
                }
              });

              break; // Exit the loop once the alarm is triggered
            } else {
              print('Time does not match');
            }
          } catch (e) {
            print('Error parsing time: $e');
          }
        }
      }
    }
  }


  Future<void> _showAlarmDialog(Map<String, dynamic> alarm) async {
    setState(() {
      _isDialogShowing = true; // Mark the dialog as showing
    });

    print('Displaying alarm dialog for alarm: ${alarm['id']}');

    try {
      await showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissal by tapping outside
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0), // Smooth rounded corners
            ),
            backgroundColor: Colors.white, // White background for the dialog
            title: Row(
              children: [
                Icon(
                  Icons.notification_important,
                  color: Colors.redAccent, // Red color for the alarm icon
                  size: 30.0,
                ),
                SizedBox(width: 10),
                Text(
                  'Alarm Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display the patient and pill details with enhanced styling
                  Text(
                    'Patient: ${alarm['patient_name']}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pill: ${alarm['pill_name']}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Reminder: ${alarm['reminder_message']}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  // A separator line to improve the UI
                  Divider(color: Colors.grey),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // "Taken" button
                      ElevatedButton(
                        onPressed: () {
                          // Ensure alarmId is passed as an integer
                          _updateAlarmStatus(int.parse(alarm['id'].toString()));
                          _dismissAlarmDialog(alarm['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Green color for "Taken"
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // Rounded corners for the button
                          ),
                        ),
                        child: Text(
                          'Taken',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 20), // Space between buttons
                      // "Dismiss" button
                      ElevatedButton(
                        onPressed: () {
                          // Close the dialog
                          Navigator.of(context).pop(); // This will close the dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey, // Grey color for "Dismiss"
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Dismiss',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing alarm dialog: $e');
    }
  }


  void _dismissAlarmDialog(int alarmId) {
    Navigator.of(context).pop();
    setState(() {
      _isDialogShowing = false; // Mark the dialog as dismissed
    });

    // Update the alarm status to "dismissed"
    _updateAlarmStatusToDismissed(alarmId);
  }


  Future<void> _updateAlarmStatusToMissed(int alarmId) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-api-url/update_alarm_status.php'),
        body: {
          'id': alarmId.toString(),
          'status': 'missed',
        },
      );

      if (response.statusCode == 200) {
        print('Alarm marked as missed');
      } else {
        print('Failed to mark alarm as missed');
      }
    } catch (e) {
      print('Error updating alarm status to missed: $e');
    }
  }

  Future<void> _updateAlarmStatusToDismissed(int alarmId) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-api-url/update_alarm_status.php'),
        body: {
          'id': alarmId.toString(),
          'status': 'dismissed',
        },
      );

      if (response.statusCode == 200) {
        print('Alarm marked as dismissed');
      } else {
        print('Failed to mark alarm as dismissed');
      }
    } catch (e) {
      print('Error updating alarm status to dismissed: $e');
    }
  }

  Future<void> _scheduleNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true, // Play the default notification sound
      ticker: 'ticker',
      ongoing: true, // Keeps the notification active
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    // Trigger the notification initially
    await flutterLocalNotificationsPlugin.show(
      0,
      'Alarm',
      'Time to take your medicine',
      platformChannelSpecifics,
      payload: 'alarm_payload',
    );

    // Start a loop to continuously play sound every 5 seconds
    _soundLoopTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await flutterLocalNotificationsPlugin.show(
        0,
        'Alarm',
        'Time to take your medicine',
        platformChannelSpecifics,
        payload: 'alarm_payload',
      );
    });
  }


  Future<void> _playAlarmSound() async {
    final player = AudioPlayer();

    // Use setSource to load sound from assets (no need for setSourceAsset in 6.1.0)
    await player.setSource(AssetSource('music/alarm.mp3'));

    // Play the sound after setting the source
    await player.play(AssetSource('music/alarm.mp3'));
  }

  Future<void> _updateAlarmStatus(int alarmId) async {
    try {
      final response = await http.put(
        Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/alarm_api/alarm_update.php'), // Ensure this URL is correct
        headers: {'Content-Type': 'application/x-www-form-urlencoded'}, // Use correct content type
        body: {'id': alarmId.toString(), 'status': '1'}, // Send as form data
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success']) {
          print('Alarm status updated to 1 (meds taken) successfully');

          // Start a timer to reset the status to 0 after 3 seconds
          Timer(Duration(seconds: 5), () async {
            final resetResponse = await http.put(
              Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/alarm_api/alarm_update.php'), // Use consistent URL
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'id': alarmId.toString(), 'status': '0'}, // Reset to status 0
            );

            print('Reset response status: ${resetResponse.statusCode}');
            print('Reset response body: ${resetResponse.body}');
          });
        } else {
          print('Failed to update alarm status: ${responseData['message']}');
        }
      } else {
        print('Failed to update alarm status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating alarm status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight), // AppBar height
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF39cdaf), Color(0xFF26394A)], // Gradient colors
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            leading: IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                _scaffoldKey.currentState!.openDrawer();
              },
            ),

            backgroundColor: Colors.transparent, // Make AppBar background transparent for gradient
            elevation: 0, // Remove shadow/elevation
          ),
        ),
      ),
      drawer: CustomDrawer(
        scaffoldKey: _scaffoldKey,
        flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
        userRole: userRole,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF39cdaf), Color(0xFF26394A)], // Gradient colors
            begin: Alignment.topLeft, // Gradient start point
            end: Alignment.bottomRight, // Gradient end point
          ),
        ),
        child: Column(
          children: [


            // Alarm content
            hasNoAlarms
                ? Center(child: Text("No alarms found", style: TextStyle(color: Colors.white)))
                : Expanded(
              child: ListView.builder(
                itemCount: alarmData.length,
                itemBuilder: (context, index) {
                  return _buildAlarmCard(alarmData[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmCard(Map<String, dynamic> alarm) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.blue.shade50, // Lighter shade for a softer background
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Add some padding inside the card
          child: Row(
            children: [
              // Icon for Pill
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF39cdaf), // Matching color with the theme
                ),
                child: Icon(
                  Icons.medical_services,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 16), // Space between the icon and the text

              // Main Text Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alarm['pill_name']} for ${alarm['patient_name']}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6), // Space between title and subtitle
                    Text(
                      'Reminder: ${alarm['reminder_message']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Time Text
              Text(
                _formatTime(alarm['time']),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF39cdaf), // Matching time color to theme
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String time) {
    try {
      // Trim any leading or trailing spaces
      time = time.trim();

      // Use the DateFormat("h:mm a") to parse the time in 12-hour AM/PM format
      DateFormat format = DateFormat("h:mm a");

      // Parse the time string to DateTime
      DateTime alarmDate = format.parse(time);

      // Return the formatted time in the desired format (if you want to display it differently)
      return DateFormat('h:mm a').format(alarmDate);
    } catch (e) {
      print('Error formatting time: $e');
      return 'Invalid Time';
    }
  }
}