import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/firebase_options.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/owner_auth_provider.dart';
import 'providers/staff_auth_provider.dart';
import 'providers/doctor_auth_provider.dart';
import 'providers/patient_auth_provider.dart';
import 'providers/marketing_provider.dart';
import 'widgets/common/devtools_adaptive_wrapper.dart';

// Import for background message handler (mobile only)
import 'services/notification_service_mobile.dart' as mobile_notifications;

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint('📱 App lifecycle state changed: $state');
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed, checking for pending notifications');
      // App came to foreground - check for pending notifications
      await NotificationService().checkPendingNotifications();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add lifecycle observer for notification handling
  final lifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(lifecycleObserver);

  // Initialize Firebase background message handler BEFORE Firebase initialization (mobile only)
  if (!kIsWeb) {
    try {
      await mobile_notifications.initializeFirebaseMessagingBackground();
    } catch (e) {
      // Background handler initialization failed, continue with app
      debugPrint('Background message handler initialization failed: $e');
    }
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications
  await NotificationService().initialize();

  // Check for pending notifications from background/terminated state
  await NotificationService().checkPendingNotifications();

  // Ensure proper viewport handling
  if (kIsWeb) {
    html.document.body?.style.margin = '0';
    html.document.body?.style.padding = '0';
    html.document.body?.style.overflow = 'hidden';
    html.document.body?.style.height = '100vh';
    html.document.body?.style.width = '100vw';
  }

  // Preload all auth providers
  final authProvider = AuthProvider();
  await authProvider.loadAuthState();
  final ownerAuthProvider = OwnerAuthProvider();
  await ownerAuthProvider.loadAuthState();
  final staffAuthProvider = StaffAuthProvider();
  await staffAuthProvider.loadAuthState();
  final doctorAuthProvider = DoctorAuthProvider();
  await doctorAuthProvider.loadAuthState();
  final patientAuthProvider = PatientAuthProvider();
  await patientAuthProvider.loadAuthState();

  runApp(
    DevToolsAdaptiveWrapper(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: ownerAuthProvider),
          ChangeNotifierProvider.value(value: staffAuthProvider),
          ChangeNotifierProvider.value(value: doctorAuthProvider),
          ChangeNotifierProvider.value(value: patientAuthProvider),
          ChangeNotifierProvider(create: (_) => MarketingProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );

  // Check for notification query parameter on web
  if (kIsWeb) {
    final uri = Uri.parse(html.window.location.href);
    final notification = uri.queryParameters['notification'];
    if (notification != null) {
      Future.delayed(const Duration(seconds: 2), () {
        // Navigate to dashboard with notifications tab
        AppRouter.router.go('/owner/dashboard?tab=notifications');
      });
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBreakpoints.builder(
      child: Builder(
        builder: (context) => MediaQuery(
          // Handle viewport changes for dev tools
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
          child: MaterialApp.router(
            title: 'Medical Lab Management System',
            onGenerateTitle: (context) {
              // Get current route location
              final currentRoute =
                  AppRouter.router.routerDelegate.currentConfiguration.uri.path;

              // Update browser title based on route
              if (currentRoute.startsWith('/owner')) {
                return 'Owner Dashboard - MedLab System';
              } else if (currentRoute.startsWith('/staff')) {
                return 'Staff Dashboard - MedLab System';
              } else if (currentRoute.startsWith('/patient')) {
                return 'Patient Portal - MedLab System';
              } else if (currentRoute.startsWith('/doctor')) {
                return 'Doctor Portal - MedLab System';
              } else if (currentRoute.startsWith('/admin')) {
                return 'Admin Dashboard - MedLab System';
              } else if (currentRoute == '/' || currentRoute == '/marketing') {
                return 'MedLab System - Professional Lab Management';
              }
              return 'Medical Lab Management System';
            },
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      ),
      breakpoints: [
        const Breakpoint(start: 0, end: 480, name: MOBILE),
        const Breakpoint(start: 481, end: 1435, name: TABLET),
        const Breakpoint(start: 1436, end: double.infinity, name: DESKTOP),
      ],
    );
  }
}
