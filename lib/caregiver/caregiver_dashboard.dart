import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../include/sidebar.dart';
import 'Alarm_History.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'add_patient_name.dart';
import 'add_pill_name.dart';
import 'add_pill_dashboard.dart';
import 'package:intl/intl.dart';
import 'dart:async';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeCareScreen(),
      theme: ThemeData(
        primaryColor: Color(0xFF0E4C92),
        hintColor: Colors.white,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(background: Color(0xFF0E4C92)),
      ),
    );
  }
}

class HomeCareScreen extends StatefulWidget {
  @override
  _HomeCareScreenState createState() => _HomeCareScreenState();
}

class _HomeCareScreenState extends State<HomeCareScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int userRole = 1;
  List<Map<String, dynamic>> alarmData = [];
  bool hasNoAlarms = false;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> _alarms = [];
  int newNotificationCount = 0; // Tracks new notifications
  AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  late Timer _notificationTimer; // Timer for periodic checks

  @override
  void initState() {
    super.initState();
    _fetchAlarmData();
    _fetchNotificationCount(); // Fetch the notification count on init
    _startNotificationTimer(); // Start the periodic check
  }
  @override
  void dispose() {
    _notificationTimer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _fetchNotificationCount(); // Call this method periodically to check for new notifications
    });
  }
  Future<void> _fetchAlarmData() async {
    try {
      final response = await http.get(Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/get_alarm.php'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] is List) {
          setState(() {
            _alarms = List<Map<String, dynamic>>.from(data['data']).map((alarm) {
              String time = alarm['formatted_time'] ?? '00:00 AM';
              String reminderMessage = alarm['reminder_message'] ?? '';
              String patientName = alarm['patient_name'] ?? 'Unknown';
              String pillName = alarm['pill_name'] ?? 'Unknown Pill';

              return {
                'id': alarm['id'],
                'time': time,
                'reminder_message': reminderMessage,
                'patient_name': patientName,
                'pill_name': pillName,
                'status_remark': alarm['status_remark'],
              };
            }).toList();
          });
        } else {
          setState(() {
            _alarms = [];
          });
        }
      } else {
        setState(() {
          _alarms = [];
        });
      }
    } catch (e) {
      setState(() {
        _alarms = [];
      });
    }
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final response = await http.get(Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/get_pill_count.php'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['pill_data'] is List) {
          int count = 0;
          for (var pill in data['pill_data']) {
            int pillQuantity = int.tryParse(pill['pill_quantity']?.toString() ?? '0') ?? 0;
            if (pillQuantity <= 2) {
              count++;
            }
          }
          if (count > 0 && count != newNotificationCount) {
            setState(() {
              newNotificationCount = count; // Update the notification count
            });

            try {
              // Play the sound for the new notification
              await _audioPlayer.setSource(AssetSource('music/notif.mp3'));
              await _audioPlayer.play(AssetSource('music/notif.mp3'));
            } catch (e) {
              print('Error playing sound: $e');
            }

            // Show the notification dialog
            await _showNotificationDialog();
          }
        }
      }
    } catch (e) {
      print('Error fetching notification count: $e');
    }
  }


  Future<void> _showNotificationDialog() async {
    try {
      final pillDataResponse = await http.get(
        Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/get_pill_count.php'),
      );

      final takenPillResponse = await http.get(
        Uri.parse('https://springgreen-rhinoceros-308382.hostingersite.com/get_alarm_with_patient_pill.php'),
      );

      if (pillDataResponse.statusCode == 200 && takenPillResponse.statusCode == 200) {
        final Map<String, dynamic> pillData = json.decode(pillDataResponse.body);
        final Map<String, dynamic> takenPillData = json.decode(takenPillResponse.body);

        if (pillData['success'] == true && pillData['pill_data'] is List &&
            takenPillData['success'] == true && takenPillData['data'] is List) {

          List<Map<String, dynamic>> notifications = [];
          final List takenPills = takenPillData['data'];

          for (var pill in pillData['pill_data']) {
            String pillQuantityStr = pill['pill_quantity']?.toString() ?? '0';
            int pillQuantity = int.tryParse(pillQuantityStr) ?? 0;
            String pillName = pill['pill_name'] ?? 'Unknown Pill';
            String containerId = pill['container'] ?? 'Unknown Container';
            bool isNew = pill['is_new'] ?? false;

            bool isTaken = takenPills.any((takenPill) {
              return takenPill['pill_name'] == pillName && takenPill['status_remark'] == 'taken';
            });

            if (pillQuantity <= 2 && pillQuantity > 0) {
              notifications.add({
                'message': '$pillName in Container $containerId needs to be refilled because its pill count is already $pillQuantity.',
                'isNew': isNew,
              });
            } else if (pillQuantity == 0) {
              notifications.add({
                'message': '$pillName in Container $containerId is out of stock.',
                'isNew': isNew,
              });
            }

            if (isTaken) {
              final takenPill = takenPills.firstWhere((takenPill) =>
              takenPill['pill_name'] == pillName && takenPill['status_remark'] == 'taken');
              String patientName = takenPill['patient_name'] ?? 'Unknown Patient';

              notifications.add({
                'message': '$pillName has already been taken by $patientName.',
                'isNew': isNew,
              });
            }
          }

          if (notifications.isEmpty) {
            notifications.add({
              'message': 'All pills are well stocked!',
              'isNew': false,
            });
          }

          notifications.sort((a, b) => (b['isNew'] as bool) ? 1 : -1);

          showDialog(
            context: context,
            builder: (BuildContext context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.height * 0.6,
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PillCare System Notification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 20.0,
                            ),
                          ),
                          SizedBox(height: 10.0),
                          Expanded(
                            child: ListView.builder(
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                final isNew = notification['isNew'] as bool;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Card(
                                    color: isNew ? Colors.yellow[100] : Colors.white,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        notification['message'] as String,
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          color: Colors.black87,
                                          fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 10.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                child: Text('Clear'),
                                onPressed: () {
                                  setState(() {
                                    notifications.clear();
                                  });
                                },
                              ),
                              TextButton(
                                child: Text('OK'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        } else {
          print('Error: Pill data or taken pill data is missing or malformed.');
        }
      } else {
        print('Failed to fetch data. HTTP status: ${pillDataResponse.statusCode}, ${takenPillResponse.statusCode}');
      }
    } catch (e) {
      print('Error fetching pill data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40, left: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications, color: Colors.white),
                        onPressed: _showNotificationDialog,
                      ),
                      if (newNotificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$newNotificationCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 5),
            TableCalendar(
              firstDay: DateTime.utc(2000),
              lastDay: DateTime.utc(2100),
              focusedDay: selectedDate,
              calendarFormat: CalendarFormat.month,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  selectedDate = selectedDay;
                });
              },
              selectedDayPredicate: (day) => isSameDay(day, selectedDate),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF26394A),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Color(0xFF39cdaf),
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: TextStyle(color: Colors.white),
                todayTextStyle: TextStyle(color: Colors.white),
                selectedTextStyle: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: hasNoAlarms
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 150, color: Colors.blue),
                    SizedBox(height: 20),
                    Text(
                      "You don’t have any medicine",
                      style: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                  color: Color(0xEAEBEBEF),
                ),
                child: ListView.builder(
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    return _buildAlarmCard(_alarms[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        backgroundColor: Color(0xFF26394A),
        children: [
          SpeedDialChild(
            child: Icon(Icons.medical_information),
            label: 'Add Pill',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MedicineScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.person_add),
            label: 'Add Patient',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PatientScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.lock_clock),
            label: 'Create Reminder',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AlarmScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: Icon(Icons.book),
            label: 'View History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AlarmHistoryScreen()),
              );
            },
          ),
        ],
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
            // Time display
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Color(0xFF006D77),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                alarm['time'] ?? '00:00 AM',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 20),
            // Expanded content for pill name and reminder message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm['pill_name'] ?? 'Unknown Pill',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'To: ${alarm['patient_name'] ?? 'Unknown'} - ${alarm['reminder_message'] ?? 'No Reminder Message'}',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Status Remark display on the right
            Text(
              alarm['status_remark'],
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _parseTime(String time) {
    try {
      // Ensure the time is not empty and valid
      if (time.isNotEmpty) {
        var format = DateFormat("h:mm a"); // 12-hour format (e.g., 11:30 AM)
        var parsedTime = format.parse(time);
        return DateFormat("HH:mm").format(parsedTime); // Convert to 24-hour format
      } else {
        return '00:00 AM'; // Return default time if input is invalid or empty
      }
    } catch (e) {
      print('Error parsing time: $e');
      return '00:00 AM'; // Fallback to default time
    }
  }

  bool _isToday(String alarmTime) {
    try {
      // Parse the alarm time with the correct format
      var format = DateFormat("h:mm a"); // 12-hour format (e.g., 11:30 AM)
      DateTime alarmDate = format.parse(alarmTime);
      DateTime currentDate = DateTime.now();

      // Compare date without time
      return currentDate.year == alarmDate.year &&
          currentDate.month == alarmDate.month &&
          currentDate.day == alarmDate.day;
    } catch (e) {
      print('Error comparing dates: $e');
      return false;
    }
  }
}
