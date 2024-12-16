import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../caregiver/add_patient_name.dart';
import '../caregiver/add_pill_dashboard.dart';
import '../caregiver/add_pill_name.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../start.dart';
import '../user/user_dashboard.dart';
import '../caregiver/wifi.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For managing session

class CustomDrawer extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final int userRole; // Add this line

  CustomDrawer({
    required this.scaffoldKey,
    required this.flutterLocalNotificationsPlugin,
    required this.userRole, // Add this line
  });

  Future<void> _logout(BuildContext context) async {
    final url = Uri.parse('http://springgreen-rhinoceros-308382.hostingersite.com/alarm/account_api/logout.php'); // Your logout API endpoint

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Clear session or tokens using SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.clear(); // Remove user data or tokens

          // Logout successful, navigate to login screen and prevent back navigation
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()), // Go to LoginScreen
                (Route<dynamic> route) => false, // This removes all previous routes
          );
        } else {
          // Logout failed, show a message
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['message']),
          ));
        }
      } else {
        // Handle server error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Server error: ${response.statusCode}'),
        ));
      }
    } catch (e) {
      // Handle network error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.grey[200],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('asset/image/5-removebg-preview.png'),
                ),
                const SizedBox(width: 15),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 5),
                  ],
                ),
              ],
            ),
          ),
          // Conditionally render drawer items based on userRole

            _buildDrawerItem(context, Icons.home, 'Home', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) =>  HomeCareScreen()),
              );
            }),


          const Spacer(),
          // Always show the Logout option
          _buildDrawerItem(context, Icons.logout, 'Logout', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  const LoginScreen()),
            );
          }, color: Colors.green),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: onTap,
    );
  }
}
