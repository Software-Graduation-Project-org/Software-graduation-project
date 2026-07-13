import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/marketing/home_screen.dart';
import '../screens/marketing/about_screen.dart';
import '../screens/marketing/services_screen.dart';
import '../screens/marketing/contact_screen.dart';
import '../screens/marketing/owner_registration_screen.dart';
import '../screens/common/merged_login_screen.dart';
import '../screens/public/public_registration_screen.dart';
import '../screens/public/lab_finder_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/staff/staff_dashboard_screen.dart';
import '../screens/staff/staff_invoice_reports_screen.dart';
import '../screens/patient/patient_dashboard_screen.dart';
import '../screens/patient/patient_order_report_screen.dart';
import '../screens/patient/patient_bill_details_screen.dart';
import '../screens/doctor/doctor_dashboard_screen.dart';
import '../screens/doctor/patient_details_screen.dart';
import '../screens/doctor/doctor_feedback_screen.dart';
import '../screens/doctor/doctor_patient_report_screen.dart';
import '../screens/patient/patient_feedback_screen.dart';
import '../screens/staff/staff_feedback_screen.dart';
import '../screens/owner/owner_dashboard_screen.dart';
import '../screens/owner/owner_staff_screen.dart';
import '../screens/owner/owner_doctors_screen.dart';
import '../screens/owner/owner_tests_screen.dart';
import '../screens/owner/owner_devices_screen.dart';

import '../screens/owner/inventory_management_screen.dart';
import '../screens/owner/owner_order_management_screen.dart';
import '../screens/owner/owner_order_details_screen.dart';
import '../screens/owner/owner_invoice_details_screen.dart';
import '../screens/owner/owner_invoice_reports_screen.dart';
import '../screens/owner/owner_result_reports_screen.dart';
import '../screens/owner/notifications_screen.dart';
import '../screens/owner/audit_logs_screen.dart';
import '../screens/owner/owner_profile_screen.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    navigatorKey: navigatorKey,
    routes: [
      // Marketing Pages
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/contact',
        name: 'contact',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/lab-finder',
        name: 'lab-finder',
        builder: (context, state) => const LabFinderScreen(),
      ),
      GoRoute(
        path: '/register-owner',
        name: 'register-owner',
        builder: (context, state) => const OwnerRegistrationScreen(),
      ),

      // Admin Routes
      // Unified Login Route
      GoRoute(
        path: '/login',
        name: 'merged-login',
        builder: (context, state) => const MergedLoginScreen(),
      ),

      // Admin Dashboard Route
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Admin Dashboard with Tab Route
      GoRoute(
        path: '/admin/dashboard/:tab',
        name: 'admin-dashboard-tab',
        builder: (context, state) {
          final tab = state.pathParameters['tab'];
          return AdminDashboardScreen(initialTab: tab);
        },
      ),

      // Staff Dashboard Route
      GoRoute(
        path: '/staff/dashboard',
        name: 'staff-dashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),

      // Staff Dashboard with Tab Route
      GoRoute(
        path: '/staff/dashboard/:tab',
        name: 'staff-dashboard-tab',
        builder: (context, state) {
          final tab = state.pathParameters['tab'];
          return StaffDashboardScreen(initialTab: tab);
        },
      ),

      // Staff Feedback Route
      GoRoute(
        path: '/staff/feedback',
        name: 'staff-feedback',
        builder: (context, state) => const StaffFeedbackScreen(),
      ),

      // Staff Invoice Reports Route
      GoRoute(
        path: '/staff/invoice-reports',
        name: 'staff-invoice-reports',
        builder: (context, state) => const StaffInvoiceReportsScreen(),
      ),

      // Patient Dashboard Route
      GoRoute(
        path: '/patient-dashboard',
        name: 'patient-dashboard',
        builder: (context, state) => const PatientDashboardScreen(),
        routes: [
          // Patient Order Report Route
          GoRoute(
            path: 'order-report/:orderId',
            name: 'patient-order-report',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return PatientOrderReportScreen(orderId: orderId);
            },
          ),
          // Patient Bill Details Route
          GoRoute(
            path: 'bill-details/:orderId',
            name: 'patient-bill-details',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return PatientBillDetailsScreen(orderId: orderId);
            },
          ),
        ],
      ),

      // Patient Feedback Route
      GoRoute(
        path: '/patient/feedback',
        name: 'patient-feedback',
        builder: (context, state) => const PatientFeedbackScreen(),
      ),

      // Doctor Dashboard Route
      GoRoute(
        path: '/doctor-dashboard',
        name: 'doctor-dashboard',
        builder: (context, state) => const DoctorDashboardScreen(),
        routes: [
          // Doctor Patient Report Route
          GoRoute(
            path: 'patient-report/:orderId',
            name: 'doctor-patient-report',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return DoctorPatientReportScreen(orderId: orderId);
            },
          ),
        ],
      ),

      // Doctor Feedback Route
      GoRoute(
        path: '/doctor/feedback',
        name: 'doctor-feedback',
        builder: (context, state) => const DoctorFeedbackScreen(),
      ),

      // Doctor Patient Details Route
      GoRoute(
        path: '/doctor/patient/:id',
        name: 'doctor-patient-details',
        builder: (context, state) {
          final patientId = state.pathParameters['id'];
          // For now, pass empty patient data - will be loaded in the screen
          return PatientDetailsScreen(patient: {'_id': patientId});
        },
      ),

      // Owner Dashboard Route
      GoRoute(
        path: '/owner/dashboard',
        name: 'owner-dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),

      // Owner Dashboard with Tab Route
      GoRoute(
        path: '/owner/dashboard/:tab',
        name: 'owner-dashboard-tab',
        builder: (context, state) {
          final tab = state.pathParameters['tab'];
          return OwnerDashboardScreen(initialTab: tab);
        },
      ),

      // Owner Staff Route
      GoRoute(
        path: '/owner/staff',
        name: 'owner-staff',
        builder: (context, state) => const OwnerStaffScreen(),
      ),

      // Owner Doctors Route
      GoRoute(
        path: '/owner/doctors',
        name: 'owner-doctors',
        builder: (context, state) => const OwnerDoctorsScreen(),
      ),

      // Owner Tests Route
      GoRoute(
        path: '/owner/tests',
        name: 'owner-tests',
        builder: (context, state) => const OwnerTestsScreen(),
      ),

      // Owner Devices Route
      GoRoute(
        path: '/owner/devices',
        name: 'owner-devices',
        builder: (context, state) => const OwnerDevicesScreen(),
      ),

      // Owner Inventory Route
      GoRoute(
        path: '/owner/inventory',
        name: 'owner-inventory',
        builder: (context, state) => const InventoryManagementScreen(),
      ),

      // Owner Orders Route
      GoRoute(
        path: '/owner/orders',
        name: 'owner-orders',
        builder: (context, state) => const OwnerOrderManagementScreen(),
      ),

      // Owner Order Details Route
      GoRoute(
        path: '/owner/order-details',
        name: 'owner-order-details',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] ?? '';
          return OwnerOrderDetailsScreen(orderId: orderId);
        },
      ),

      // Owner Invoice Details Route
      GoRoute(
        path: '/owner/invoice-details',
        name: 'owner-invoice-details',
        builder: (context, state) {
          final orderId = state.uri.queryParameters['orderId'] ?? '';
          return OwnerInvoiceDetailsScreen(orderId: orderId);
        },
      ),

      // Owner Result Reports Route
      GoRoute(
        path: '/owner/result-reports',
        name: 'owner-result-reports',
        builder: (context, state) => const OwnerResultReportsScreen(),
      ),

      // Owner Invoice Reports Route
      GoRoute(
        path: '/owner/invoice-reports',
        name: 'owner-invoice-reports',
        builder: (context, state) => const OwnerInvoiceReportsScreen(),
      ),

      // Owner Notifications Route
      GoRoute(
        path: '/owner/notifications',
        name: 'owner-notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Owner Audit Logs Route
      GoRoute(
        path: '/owner/audit-logs',
        name: 'owner-audit-logs',
        builder: (context, state) => const AuditLogsScreen(),
      ),

      // Owner Profile Route
      GoRoute(
        path: '/owner/profile',
        name: 'owner-profile',
        builder: (context, state) => const OwnerProfileScreen(),
      ),

      // Dashboards and other routes remain
      // Public Routes
      GoRoute(
        path: '/public/register',
        name: 'public-register',
        builder: (context, state) => const PublicRegistrationScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
