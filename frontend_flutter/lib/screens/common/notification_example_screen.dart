// Example of using Notification Service in Medical Lab App

import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationExampleScreen extends StatefulWidget {
  const NotificationExampleScreen({super.key});

  @override
  State<NotificationExampleScreen> createState() =>
      _NotificationExampleScreenState();
}

class _NotificationExampleScreenState extends State<NotificationExampleScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();

    // Subscribe to specific topics based on user type
    await _notificationService.subscribeToTopic('medical_lab_general');
    // await _notificationService.subscribeToTopic('doctor_alerts'); // for doctors
    // await _notificationService.subscribeToTopic('patient_results'); // for patients
  }

  // Example of sending test result notification
  Future<void> _sendTestResultNotification() async {
    await _notificationService.showTestResultNotification(
      'Ahmed Mohamed',
      'Complete Blood Count',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Testing')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _sendTestResultNotification,
              child: const Text('Send Test Result Notification'),
            ),
            const SizedBox(height: 40),
            const Text(
              'Notifications work on Android and iOS only',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// How to send notifications from Backend (Node.js example)

class BackendNotificationExample {
  // Send notification from server
  static Future<void> sendTestResultNotification(
    String userId,
    String patientName,
    String testName,
    String userToken,
  ) async {
    // Get user token from database
    // const userToken = await getUserFCMToken(userId);

    // Create notification message (would be sent via Firebase Admin SDK)
    // final Map<String, dynamic> message = {
    //   'token': userToken, // or 'topic': 'patient_results'
    //   'notification': {
    //     'title': 'Test Results Ready',
    //     'body': 'Hello $patientName, your $testName results are ready to view',
    //   },
    //   'data': {
    //     'type': 'test_result',
    //     'patient_id': userId,
    //     'test_name': testName,
    //     'click_action': 'FLUTTER_NOTIFICATION_CLICK',
    //   },
    // };

    // Send via Firebase Admin SDK
    // await admin.messaging().send(message);
  }
}
