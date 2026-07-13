// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../utils/page_title_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../services/notification_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_dialog.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/system_feedback_form.dart';
import '../../utils/responsive_utils.dart' as app_responsive;
import '../../widgets/owner_sidebar.dart';
import 'owner_profile_screen.dart';
import 'owner_dashboard_widgets.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final String? initialTab;

  const OwnerDashboardScreen({super.key, this.initialTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _orders = [];

  // Loading states for tabs
  bool _isStaffLoading = false;
  bool _isDoctorsLoading = false;
  bool _isTestsLoading = false;
  bool _isDevicesLoading = false;
  bool _isOrdersLoading = false;

  // Reports data
  Map<String, dynamic>? _reportsData;
  bool _isReportsLoading = false;
  String _selectedReportPeriod = 'monthly';

  // Audit logs data
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isAuditLogsLoading = false;
  int _auditLogsPage = 1;
  int _auditLogsTotalPages = 1;

  // Notifications data
  List<Map<String, dynamic>> _notifications = [];
  bool _isNotificationsLoading = false;
  String _notificationFilter = 'all'; // 'all' or 'unread'

  // Error states
  String? _ordersError;

  // Tab controller for sidebar navigation
  late TabController _tabController;

  // Sidebar state
  bool _isSidebarOpen = true;

  // Tab routes for URL navigation
  static const Map<int, String> _tabRoutes = {
    0: 'dashboard',
    1: 'staff',
    2: 'doctors',
    3: 'orders',
    4: 'tests',
    5: 'devices',
    6: 'inventory',
    7: 'notifications',
    8: 'reports',
    9: 'audit-logs',
    10: 'profile',
  };

  // Reverse map for getting index from tab name
  static const Map<String, int> _tabIndices = {
    'dashboard': 0,
    'staff': 1,
    'doctors': 2,
    'orders': 3,
    'tests': 4,
    'devices': 5,
    'inventory': 6,
    'notifications': 7,
    'reports': 8,
    'audit-logs': 9,
    'profile': 10,
  };

  // Auth loading state
  bool _isAuthLoading = true;

  // Feedback tracking
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  // Periodic refresh timer for real-time updates
  Timer? _refreshTimer;

  // Search and filter controllers for orders
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  // Search controllers for staff and doctors
  final TextEditingController _staffSearchController = TextEditingController();
  final TextEditingController _doctorSearchController = TextEditingController();

  // Search controllers for tests and devices
  final TextEditingController _testSearchController = TextEditingController();
  final TextEditingController _deviceSearchController = TextEditingController();

  final List<String> _menuItems = [
    'Dashboard',
    'Staff',
    'Doctors',
    'Orders',
    'Tests',
    'Devices',
    'Inventory',
    'Notifications',
    'Reports',
    'Audit Logs',
    'My Profile',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.medical_services,
    Icons.assignment,
    Icons.science,
    Icons.devices,
    Icons.inventory,
    Icons.notifications,
    Icons.analytics,
    Icons.history,
    Icons.person,
  ];

  String _safeGetString(dynamic data, [String fallback = 'N/A']) {
    if (data is String) {
      return data;
    } else if (data is Map<String, dynamic>) {
      // Try common keys that might contain the string value
      return data['name'] ?? data['first'] ?? data.toString();
    }
    return fallback;
  }

  double _convertToHours(double value, String unit) {
    switch (unit) {
      case 'minutes':
        return value / 60; // Convert minutes to hours
      case 'hours':
        return value; // Already in hours
      case 'days':
        return value * 24; // Convert days to hours
      default:
        return value; // Default to hours
    }
  }

  String _formatTurnaroundTime(dynamic turnaroundHours) {
    if (turnaroundHours == null) return '-';

    final hours = turnaroundHours.toDouble();

    if (hours < 1) {
      // Show in minutes if less than 1 hour
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else if (hours < 24) {
      // Show in hours if less than 24 hours
      return '${hours.round()}h';
    } else {
      // Show in days if 24 hours or more
      final days = (hours / 24).round();
      return '${days}d';
    }
  }

  @override
  void initState() {
    super.initState();
    PageTitleHelper.updateTitle('Owner Dashboard - MedLab System');

    // Set initial tab based on URL parameter
    final initialIndex = widget.initialTab != null
        ? _tabIndices[widget.initialTab] ?? 0
        : 0;

    _selectedIndex = initialIndex;

    // Initialize TabController
    _tabController = TabController(length: 11, vsync: this);
    _tabController.index = _selectedIndex;
    _tabController.addListener(_handleTabChange);

    _initializeAuthAndDashboard();
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await OwnerApiService.getMyFeedback();
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted =
              (response['feedbacks'] as List?)?.isNotEmpty ?? false;
          _showFeedbackReminder = !_hasFeedbackSubmitted;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted = false;
          _showFeedbackReminder = true;
        });
      }
    }
  }

  Future<void> _initializeAuthAndDashboard() async {
    // Ensure auth state is loaded
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    await authProvider.loadAuthState();

    if (mounted) {
      setState(() => _isAuthLoading = false);

      // Only load dashboard if authenticated
      if (authProvider.isAuthenticated) {
        _loadDashboard();
        _checkFeedbackStatus();
        _setupNotificationCallbacks();

        // Load data for initial tab if not dashboard
        _loadDataForCurrentTab();

        // Start periodic refresh timer (every 30 seconds for real-time updates)
        _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) {
            _loadDashboard(); // Refresh subscription status and dashboard data
            if (_selectedIndex == 7) {
              _loadNotifications(); // Refresh notifications if on that tab
            }
          }
        });
      }
    }
  }

  /// Load data for the currently selected tab
  void _loadDataForCurrentTab() {
    switch (_selectedIndex) {
      case 1: // Staff tab
        if (_staff.isEmpty && !_isStaffLoading) {
          _loadStaff();
        }
        break;
      case 2: // Doctors tab
        if (_doctors.isEmpty && !_isDoctorsLoading) {
          _loadDoctors();
        }
        break;
      case 3: // Orders tab
        if (_orders.isEmpty && !_isOrdersLoading) {
          _loadOrders();
        }
        break;
      case 4: // Tests tab
        if (_tests.isEmpty && !_isTestsLoading) {
          _loadTests();
        }
        break;
      case 5: // Devices tab
        if (_devices.isEmpty && !_isDevicesLoading) {
          _loadDevices();
        }
        break;
      case 7: // Notifications tab
        if (_notifications.isEmpty && !_isNotificationsLoading) {
          _loadNotifications();
        }
        break;
      case 8: // Reports tab
        if (_reportsData == null && !_isReportsLoading) {
          _loadReports();
        }
        break;
      case 9: // Audit Logs tab
        if (_auditLogs.isEmpty && !_isAuditLogsLoading) {
          _loadAuditLogs();
        }
        break;
    }
  }

  void _setupNotificationCallbacks() {
    NotificationService().setNotificationCallback(_handleNotification);
  }

  void _handleNotification(String type, Map<String, dynamic> data) {
    debugPrint(
      'ًں”” Owner dashboard received notification: $type, data: $data',
    );

    // Handle subscription-related notifications
    if (type == 'subscription') {
      final renewalApproved = data['renewal_approved'];
      if (renewalApproved == true) {
        // Refresh dashboard data to show updated subscription status
        _loadDashboard();
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('âœ… Subscription renewed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadStaff() async {
    if (_isStaffLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isStaffLoading = true);
    try {
      final response = await OwnerApiService.getStaff();
      if (mounted) {
        setState(() {
          _staff = response['staff'] != null
              ? List<Map<String, dynamic>>.from(response['staff'])
              : [];
          _isStaffLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStaffLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading staff: $e')));
      }
    }
  }

  Future<void> _loadDoctors() async {
    if (_isDoctorsLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isDoctorsLoading = true);
    try {
      final response = await OwnerApiService.getDoctors();
      if (mounted) {
        setState(() {
          _doctors = response['doctors'] != null
              ? List<Map<String, dynamic>>.from(response['doctors'])
              : [];
          _isDoctorsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDoctorsLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading doctors: $e')));
      }
    }
  }

  Future<void> _loadTests() async {
    if (_isTestsLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isTestsLoading = true);
    try {
      final response = await OwnerApiService.getTests();
      if (mounted) {
        setState(() {
          _tests = response['tests'] != null
              ? List<Map<String, dynamic>>.from(response['tests'])
              : [];
          _isTestsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTestsLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tests: $e')));
      }
    }
  }

  Future<void> _loadDevices() async {
    if (_isDevicesLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isDevicesLoading = true);
    try {
      final response = await OwnerApiService.getDevices();
      if (mounted) {
        setState(() {
          _devices = response['devices'] != null
              ? List<Map<String, dynamic>>.from(response['devices'])
              : [];
          _isDevicesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDevicesLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading devices: $e')));
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      // Only load dashboard statistics initially - no background loading
      final dashboardResponse = await OwnerApiService.getDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = dashboardResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Dashboard loading error: $e');
        // Don't show error snackbar for now to avoid confusion
        // The dashboard will still show with empty data
      }
    }
  }

  // Background loading methods to avoid overwhelming the server
  Future<void> _loadStaffInBackground() async {
    if (_staff.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 1600),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getStaff();
      if (mounted) {
        setState(() {
          _staff = response['staff'] != null
              ? List<Map<String, dynamic>>.from(response['staff'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background staff loading failed: $e');
    }
  }

  Future<void> _loadDoctorsInBackground() async {
    if (_doctors.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 2400),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getDoctors();
      if (mounted) {
        setState(() {
          _doctors = response['doctors'] != null
              ? List<Map<String, dynamic>>.from(response['doctors'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background doctors loading failed: $e');
    }
  }

  Future<void> _loadTestsInBackground() async {
    if (_tests.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 3200),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getTests();
      if (mounted) {
        setState(() {
          _tests = response['tests'] != null
              ? List<Map<String, dynamic>>.from(response['tests'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background tests loading failed: $e');
    }
  }

  Future<void> _loadDevicesInBackground() async {
    if (_devices.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 4000),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getDevices();
      if (response['devices'] != null && mounted) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(response['devices']);
        });
      }
    } catch (e) {
      debugPrint('Background devices loading failed: $e');
      debugPrint('Background devices loading failed: $e');
    }
  }

  void _toggleSidebar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final canShowSidebar =
        !ResponsiveBreakpoints.of(context).isMobile && screenWidth > 600;

    if (_isSidebarOpen || canShowSidebar) {
      setState(() => _isSidebarOpen = !_isSidebarOpen);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    NotificationService().removeNotificationCallback();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    setState(() {
      _selectedIndex = _tabController.index;
    });

    // Update URL when tab changes
    final tabRoute = _tabRoutes[_tabController.index];
    if (tabRoute != null) {
      final targetPath = '/owner/dashboard/$tabRoute';
      final currentPath = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.path;
      if (currentPath != targetPath) {
        GoRouter.of(context).go(targetPath);
      }
    }

    // Load data for the current tab
    _loadDataForCurrentTab();
  }

  void _logout(BuildContext context) async {
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    await authProvider.logout();
    if (context.mounted) {
      // Small delay to ensure logout is complete before navigation
      await Future.delayed(const Duration(milliseconds: 50));
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;

    // Show loading while auth state is being determined
    if (_isAuthLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Open menu',
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  app_responsive.ResponsiveText(
                    'Lab Owner Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  app_responsive.ResponsiveText(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? 'Owner'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            )
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _isSidebarOpen
                      ? const AlwaysStoppedAnimation(1.0)
                      : const AlwaysStoppedAnimation(0.0),
                ),
                onPressed: _toggleSidebar,
                tooltip: _isSidebarOpen ? 'Close sidebar' : 'Open sidebar',
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  app_responsive.ResponsiveText(
                    'Lab Owner Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  app_responsive.ResponsiveText(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? 'Owner'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  padding: app_responsive.ResponsiveUtils.getResponsivePadding(
                    context,
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        color: AppTheme.primaryBlue,
                        size: app_responsive
                            .ResponsiveUtils.getResponsiveIconSize(context, 20),
                      ),
                      SizedBox(
                        width: app_responsive
                            .ResponsiveUtils.getResponsiveSpacing(context, 8),
                      ),
                      app_responsive.ResponsiveText(
                        'Lab Owner',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
      drawer: isMobile
          ? OwnerSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                Navigator.pop(context); // Close drawer
                if (index >= 0 && index < _tabController.length) {
                  _tabController.animateTo(index);
                } else if (index == -1) {
                  _logout(context);
                }
              },
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile && _isSidebarOpen && screenWidth > 600)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: OwnerSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      if (index >= 0 && index < _tabController.length) {
                        _tabController.animateTo(index);
                      } else if (index == -1) {
                        // Handle logout
                        _logout(context);
                      }
                    },
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? AppAnimations.pulse(
                        const Center(child: CircularProgressIndicator()),
                      )
                    : AppAnimations.fadeIn(
                        _buildDashboardContent(),
                        delay: 300.ms,
                      ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  Widget _buildSpeedDial() {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: app_responsive.ResponsiveUtils.getResponsivePadding(
              context,
              horizontal: 20,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(
                    bottom: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                      context,
                      20,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showContactAdminDialog();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.support_agent,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Contact Admin',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Send a message to system admin',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      tooltip: 'Quick Actions',
      child: const Icon(Icons.add),
    );
  }

  void _showContactAdminDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.support_agent, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Contact Admin', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send a message to the system administrator',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Enter message subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 5,
                  enabled: !isSubmitting,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a subject'),
                          ),
                        );
                        return;
                      }

                      if (messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a message'),
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        await OwnerApiService.contactAdmin(
                          title: titleController.text.trim(),
                          message: messageController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ Message sent successfully to admin',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send message: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(isSubmitting ? 'Sending...' : 'Send Message'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is completely closed
      titleController.dispose();
      messageController.dispose();
    });
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await OwnerApiService.provideFeedback(
              targetType: feedbackData['target_type'],
              targetId: feedbackData['target_id'],
              rating: feedbackData['rating'],
              message: feedbackData['message'],
              isAnonymous: feedbackData['is_anonymous'],
            );
            if (mounted) {
              Navigator.pop(context);
              setState(() {
                _hasFeedbackSubmitted = true;
                _showFeedbackReminder = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to submit feedback: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showRenewalRequestDialog() {
    final renewalPeriodController = TextEditingController(text: '12');
    final messageController = TextEditingController(
      text: 'Please renew my subscription for another year.',
    );
    bool isSubmitting = false;
    bool isSuccess = false;
    String? successMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isSuccess ? 'Request Submitted' : 'Request Subscription Renewal',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isSuccess
                  ? [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        successMessage ??
                            'Your renewal request has been submitted successfully!',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'The admin will review your request and respond soon.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ]
                  : [
                      Text(
                        'Request a renewal for your subscription. The admin will review and approve your request.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: renewalPeriodController,
                        label: 'Renewal Period (Months)',
                        hint: 'Enter number of months',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter renewal period';
                          }
                          final months = int.tryParse(value);
                          if (months == null || months <= 0) {
                            return 'Please enter a valid number of months';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: messageController,
                        label: 'Message (Optional)',
                        hint: 'Additional message for admin',
                        maxLines: 3,
                      ),
                    ],
            ),
          ),
          actions: isSuccess
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final renewalPeriod = int.tryParse(
                              renewalPeriodController.text,
                            );
                            if (renewalPeriod == null || renewalPeriod <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a valid renewal period',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() => isSubmitting = true);

                            try {
                              await OwnerApiService.requestRenewal(
                                renewalPeriodMonths: renewalPeriod,
                                message: messageController.text.isNotEmpty
                                    ? messageController.text
                                    : null,
                              );

                              setState(() {
                                isSuccess = true;
                                successMessage =
                                    'Renewal request submitted successfully!';
                                isSubmitting = false;
                              });

                              // Refresh dashboard data
                              _loadDashboard();
                            } catch (e) {
                              setState(() => isSubmitting = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to submit renewal request: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Submit Request'),
                  ),
                ],
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is completely closed
      renewalPeriodController.dispose();
      messageController.dispose();
    });
  }

  Widget _buildFeedbackReminderBanner() {
    return AnimatedCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.1),
              AppTheme.secondaryTeal.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.feedback_outlined,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share Your Experience',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Help us improve by sharing your feedback',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showFeedbackDialog(),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showFeedbackReminder = false;
                      });
                    },
                    child: const Text('Later', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppTheme.cardColor,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  const Icon(Icons.business, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Lab Owner',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: List.generate(_menuItems.length, (index) {
                  final isSelected = _selectedIndex == index;
                  return AnimatedCard(
                    onTap: () {
                      if (index >= 0 && index < _tabController.length) {
                        setState(() => _selectedIndex = index);
                        _tabController.animateTo(index);
                        Navigator.of(context).pop(); // Close drawer
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _menuIcons[index],
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textLight,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _menuItems[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.primaryBlue
                                      : AppTheme.textDark,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildStaffView();
      case 2:
        return _buildDoctorsView();
      case 3:
        return _buildOrdersView();
      case 4:
        return _buildTestsView();
      case 5:
        return _buildDevicesView();
      case 6:
        return _buildInventoryView();
      case 7:
        return _buildNotificationsView();
      case 8:
        return _buildReportsView();
      case 9:
        return _buildAuditLogsView();
      case 10:
        return const OwnerProfileScreen();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = ResponsiveBreakpoints.of(context).isMobile;
          final screenWidth = MediaQuery.of(context).size.width;
          final isVerySmall = screenWidth < 500;

          return SingleChildScrollView(
            child: Column(
              children: [
                if (_showFeedbackReminder)
                  Padding(
                    padding:
                        app_responsive.ResponsiveUtils.getResponsivePadding(
                          context,
                          horizontal: 16,
                          vertical: 16,
                        ),
                    child: AppAnimations.elasticSlideIn(
                      _buildFeedbackReminderBanner(),
                      delay: 50.ms,
                    ),
                  ),
                // Hero Section
                AppAnimations.blurFadeIn(
                  _buildHeroSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                ),
                // Subscription Status Section
                AppAnimations.elasticSlideIn(
                  _buildSubscriptionStatusSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  delay: 150.ms,
                ),
                // Charts Section
                AppAnimations.elasticSlideIn(
                  _buildChartsSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  delay: 400.ms,
                ),
                // Activity Section
                AppAnimations.elasticSlideIn(
                  _buildActivitySection(context, isMobile, isVerySmall),
                  delay: 600.ms,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    final orders = _dashboardData?['orders'] ?? {};
    final financials = _dashboardData?['financials'] ?? {};
    final resources = _dashboardData?['resources'] ?? {};

    final totalRevenue = financials['monthlyRevenue'] ?? 0;
    final totalOrders = orders['total'] ?? 0;
    final totalStaff = _staff.isNotEmpty
        ? _staff.length
        : (resources['staff'] ?? 0);
    final totalPatients = resources['patients'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: EdgeInsets.only(
        left: isMobile ? 24 : 48,
        right: isMobile ? 24 : 48,
        top: isVerySmall ? 48 : (isMobile ? 80 : 120),
        bottom: isVerySmall ? 48 : (isMobile ? 80 : 120),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAnimations.liquidMorph(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAnimations.rotateIn(
                  Icon(
                    Icons.business,
                    size: isVerySmall ? 40 : (isMobile ? 48 : 64),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  delay: 200.ms,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAnimations.typingEffect(
                        'Welcome to Your Lab Dashboard',
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: isVerySmall ? 24 : (isMobile ? 32 : 42),
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ) ??
                            const TextStyle(),
                      ),
                      const SizedBox(height: 8),
                      AppAnimations.fadeIn(
                        Text(
                          'Manage your laboratory operations efficiently with real-time insights',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: isVerySmall
                                    ? 12
                                    : (isMobile ? 16 : 20),
                                height: 1.4,
                              ),
                          softWrap: true,
                        ),
                        delay: 800.ms,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          AppAnimations.elasticSlideIn(
            Wrap(
              spacing: isMobile ? 16 : 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Monthly Revenue',
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    AppTheme.successGreen,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.successGreen,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.shopping_cart,
                    AppTheme.primaryBlue,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Staff',
                    totalStaff.toString(),
                    Icons.people,
                    AppTheme.secondaryTeal,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.secondaryTeal,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Patients',
                    totalPatients.toString(),
                    Icons.person,
                    AppTheme.errorRed,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.errorRed,
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      width: isMobile ? double.infinity : (isVerySmall ? 200 : 240),
      padding: EdgeInsets.all(isVerySmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVerySmall ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isVerySmall ? 24 : 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionStatusSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    final subscription = _dashboardData?['subscription'];

    if (subscription == null) {
      return const SizedBox.shrink();
    }

    final status = subscription['status'] ?? 'active';
    final warning = subscription['warning'];
    final daysRemaining = subscription['daysRemaining'] ?? 0;
    final fee = subscription['fee'] ?? 0;
    final endDate = subscription['endDate'];

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'expired':
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.error_outline;
        statusText = 'EXPIRED';
        break;
      case 'expiring_soon':
        statusColor = AppTheme.accentOrange;
        statusIcon = Icons.warning_amber;
        statusText = 'EXPIRING SOON';
        break;
      case 'expiring_within_month':
        statusColor = AppTheme.secondaryTeal;
        statusIcon = Icons.info_outline;
        statusText = 'ACTIVE';
        break;
      default:
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle_outline;
        statusText = 'ACTIVE';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 20 : (isMobile ? 30 : 40),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Subscription Status',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 18 : (isMobile ? 24 : 32),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 20 : 30),
          AnimatedCard(
            child: Container(
              padding: EdgeInsets.all(isVerySmall ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.1),
                    statusColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Status Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusText,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    fontSize: isVerySmall ? 16 : 20,
                                  ),
                            ),
                            if (warning != null)
                              Text(
                                warning,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: statusColor.withValues(alpha: 0.8),
                                      fontSize: isVerySmall ? 12 : 14,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Subscription Details Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final isSmallScreen = availableWidth < 600;

                      if (isSmallScreen) {
                        // Stack vertically on small screens
                        return Column(
                          children: [
                            // Monthly Fee
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    color: AppTheme.primaryBlue,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Monthly Fee',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                          fontSize: isVerySmall ? 10 : 12,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${fee.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                          fontSize: isVerySmall ? 14 : 16,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Days Remaining
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: statusColor,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Days Remaining',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                          fontSize: isVerySmall ? 10 : 12,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    daysRemaining.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          fontSize: isVerySmall ? 14 : 16,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // End Date
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event,
                                    color: AppTheme.secondaryTeal,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'End Date',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                          fontSize: isVerySmall ? 10 : 12,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    endDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(DateTime.parse(endDate))
                                        : 'N/A',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryTeal,
                                          fontSize: isVerySmall ? 14 : 16,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Use Row with Expanded on larger screens
                        return Row(
                          children: [
                            // Monthly Fee
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      color: AppTheme.primaryBlue,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Monthly Fee',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: isVerySmall ? 10 : 12,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${fee.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                            fontSize: isVerySmall ? 14 : 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Days Remaining
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: statusColor,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Days Remaining',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: isVerySmall ? 10 : 12,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      daysRemaining.toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                            fontSize: isVerySmall ? 14 : 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // End Date
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.event,
                                      color: AppTheme.secondaryTeal,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'End Date',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: isVerySmall ? 10 : 12,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      endDate != null
                                          ? DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(DateTime.parse(endDate))
                                          : 'N/A',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.secondaryTeal,
                                            fontSize: isVerySmall ? 14 : 16,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Request Renewal Button
                  if (daysRemaining <= 30)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showRenewalRequestDialog,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Request Renewal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    final resources = _dashboardData?['resources'] ?? {};
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine cross axis count based on screen size
    // Mobile (< 800px): 1 column
    // Tablet/Desktop (>= 800px): 2 columns
    // Use a higher threshold to ensure enough space for content
    final crossAxisCount = screenWidth < 800 ? 1 : 2;

    final stats = [
      {
        'title': 'Total Staff',
        'value': _staff.isNotEmpty
            ? _staff.length.toString()
            : (resources['staff']?.toString() ?? '0'),
        'change': '${resources['staff'] ?? 0} members',
        'icon': Icons.people,
        'color': AppTheme.secondaryTeal,
        'description': 'Your team members',
      },
      {
        'title': 'Total Patients',
        'value': resources['patients']?.toString() ?? '0',
        'change': '${resources['patients'] ?? 0} registered',
        'icon': Icons.person,
        'color': AppTheme.errorRed,
        'description': 'Patient records',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'System Overview' : 'System Overview & Statistics',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: stats.map((stat) {
              return AnimatedCard(
                child: Padding(
                  padding: EdgeInsets.all(isVerySmall ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isVerySmall ? 8 : 12),
                            decoration: BoxDecoration(
                              color: (stat['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              stat['icon'] as IconData,
                              color: stat['color'] as Color,
                              size: isVerySmall ? 20 : 32,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat['title'] as String,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isVerySmall ? 14 : null,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    stat['change'] as String,
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isVerySmall ? 9 : 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isVerySmall ? 12 : 20),
                      SelectableText(
                        stat['value'] as String,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: stat['color'] as Color,
                              fontSize: isVerySmall ? 20 : null,
                            ),
                      ),
                      SizedBox(height: isVerySmall ? 4 : 8),
                      SelectableText(
                        stat['description'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 11 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final screenWidth = MediaQuery.of(context).size.width;
        final isVerySmall = screenWidth < 500;

        return RefreshIndicator(
          onRefresh: () async {
            if (_orders.isEmpty) {
              await _loadOrdersInBackground();
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAnimations.fadeIn(
                  Text(
                    'Order Management',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmall ? 24 : (isMobile ? 32 : 40),
                    ),
                  ),
                ),
                SizedBox(height: isVerySmall ? 20 : 32),

                // Orders List
                ...(_isOrdersLoading
                    ? [
                        AppAnimations.fadeIn(
                          const Center(child: CircularProgressIndicator()),
                        ),
                      ]
                    : _ordersError != null
                    ? [
                        AppAnimations.fadeIn(
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.errorRed,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load orders',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _ordersError!,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  onPressed: _loadOrdersInBackground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : _orders.isEmpty
                    ? [
                        AppAnimations.fadeIn(
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No orders found',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Orders will appear here once patients place them.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return AppAnimations.slideInFromRight(
                              _buildOrderCardWithInvoice(order),
                              delay: Duration(milliseconds: 50 * index),
                            );
                          },
                        ),
                      ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCardWithInvoice(dynamic order) {
    final orderDate = DateTime.parse(order['order_date']);
    final status = order['status'] ?? 'unknown';
    final testCount = order['test_count'] ?? 0;
    // Get lab name from auth provider or use default
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    final labName = authProvider.user?.labName ?? 'Medical Lab';
    // Safely extract string values that might be Maps
    final patientName = _safeGetString(order['patient_name'], 'N/A');
    final doctorName = _safeGetString(order['doctor_name'], 'Not Assigned');

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'processing':
        statusColor = AppTheme.warningYellow;
        statusIcon = Icons.hourglass_top;
        break;
      case 'pending':
        statusColor = AppTheme.primaryBlue;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and lab name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(orderDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        labName,
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Order info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.science,
                    '$testCount Test${testCount != 1 ? 's' : ''}',
                    'Medical tests ordered',
                  ),
                ),
                if (order['total_cost'] != null)
                  Expanded(
                    child: _buildInfoItem(
                      Icons.attach_money,
                      'ILS ${order['total_cost'].toStringAsFixed(2)}',
                      'Total cost',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Patient & Doctor Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Patient',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 14,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Doctor',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Handle doctor_name which could be a string or a map
                      Text(
                        doctorName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: doctorName != 'Not Assigned'
                              ? AppTheme.textDark
                              : Colors.grey[500],
                          fontStyle: doctorName != 'Not Assigned'
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (order['order_details'] != null &&
                order['order_details'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tests & Assigned Staff:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildTestListWithStaff(order['order_details']),
            ],
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final orderId = order['order_id'] ?? order['_id'];
                      if (orderId != null) {
                        context.go('/owner/order-details?orderId=$orderId');
                      }
                    },
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go(
                        '/owner/invoice-details?orderId=${order['order_id'] ?? order['_id']}',
                      );
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Invoice'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTestListWithStaff(List<dynamic> orderDetails) {
    return orderDetails.take(5).map((detail) {
      // Handle test_name which could be a string or extracted from test_id
      String testName;
      final testNameData = detail['test_name'];
      if (testNameData is String) {
        testName = testNameData;
      } else {
        // Fallback to extracting from test_id if it's populated
        final testId = detail['test_id'];
        if (testId is Map<String, dynamic>) {
          testName = testId['test_name'] ?? 'Unknown Test';
        } else {
          testName = 'Unknown Test';
        }
      }

      // Handle staff_name which could be a string or a map
      String staffName;
      final staffNameData = detail['staff_name'];
      if (staffNameData is String) {
        staffName = staffNameData;
      } else if (staffNameData is Map<String, dynamic>) {
        staffName =
            '${staffNameData['first'] ?? ''} ${staffNameData['last'] ?? ''}'
                .trim();
      } else {
        staffName = 'Unassigned';
      }

      if (staffName.isEmpty) {
        staffName = 'Unassigned';
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.science, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                testName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: staffName != 'Unassigned'
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : AppTheme.warningYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                staffName != 'Unassigned' ? 'Assigned' : 'Unassigned',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: staffName != 'Unassigned'
                      ? AppTheme.successGreen
                      : AppTheme.warningYellow,
                ),
              ),
            ),
            if (staffName != 'Unassigned') ...[
              const SizedBox(width: 8),
              Icon(Icons.person, size: 14, color: AppTheme.primaryBlue),
              const SizedBox(width: 4),
              Text(
                staffName,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  // ignore: unused_element
  void _showOrderDetailsWithInvoice(dynamic order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Order #${order['_id']?.toString().substring(0, 8) ?? 'N/A'}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Patient',
                _safeGetString(order['patient_name'], 'N/A'),
              ),
              _buildDetailRow(
                'Doctor',
                _safeGetString(order['doctor_name'], 'Not Assigned'),
              ),
              _buildDetailRow(
                'Status',
                _getStatusText(order['status'] ?? 'pending'),
              ),
              _buildDetailRow(
                'Order Date',
                order['order_date'] != null
                    ? DateTime.parse(
                        order['order_date'],
                      ).toString().split(' ')[0]
                    : 'N/A',
              ),
              _buildDetailRow('Test Count', '${order['test_count'] ?? 0}'),
              if (order['total_cost'] != null)
                _buildDetailRow(
                  'Total Cost',
                  'ILS ${order['total_cost'].toStringAsFixed(2)}',
                ),
              const SizedBox(height: 16),
              const Text(
                'Test Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildDetailedTestList(order['order_details'] ?? []),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(dynamic order) {
    // For now, show a placeholder. In a real implementation, this would
    // navigate to or show invoice details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: ${order['_id']?.toString().substring(0, 8) ?? 'N/A'}',
            ),
            const SizedBox(height: 8),
            Text('Patient: ${order['patient_name'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ILS ${order['total_cost']?.toStringAsFixed(2) ?? 'N/A'}',
            ),
            const SizedBox(height: 8),
            Text('Status: ${order['status'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            const Text(
              'Invoice functionality coming soon...',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailedTestList(List<dynamic> orderDetails) {
    return orderDetails.map((detail) {
      final testName = detail['test_name'] ?? 'Unknown Test';
      final assignedStaff = detail['staff_id'];
      final staffName = assignedStaff != null
          ? '${assignedStaff['full_name']?['first'] ?? ''} ${assignedStaff['full_name']?['last'] ?? ''}'
                .trim()
          : 'Unassigned';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              testName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: assignedStaff != null
                      ? AppTheme.primaryBlue
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Staff: $staffName',
                  style: TextStyle(
                    fontSize: 12,
                    color: assignedStaff != null
                        ? AppTheme.primaryBlue
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Revenue Analytics' : 'Revenue Analytics & Trends',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revenue Overview',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              'Revenue from lab operations and test services',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: isVerySmall ? 200 : 250,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 5,
                        minY: 0,
                        maxY: 8,
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 3),
                              const FlSpot(1, 4),
                              const FlSpot(2, 3.5),
                              const FlSpot(3, 5),
                              const FlSpot(4, 4.5),
                              const FlSpot(5, 6),
                            ],
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final notifications = _dashboardData?['notifications']?['recent'] ?? [];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Recent Activity' : 'Recent Activity & Updates',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity Feed',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              'Recent updates and notifications',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (notifications.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: AppTheme.textLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    )
                  else
                    ...notifications
                        .take(5)
                        .map(
                          (notification) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.info,
                                    color: AppTheme.primaryBlue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification['title'] ?? 'Activity',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        softWrap: true,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(
                                        notification['message'] ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification['createdAt'] != null
                                            ? DateTime.parse(
                                                notification['createdAt'],
                                              ).toString().split(' ')[0]
                                            : '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffView() {
    // Filter staff based on search query
    final filteredStaff = _staff.where((staff) {
      if (_staffSearchController.text.isEmpty) return true;
      final searchLower = _staffSearchController.text.toLowerCase();
      final fullName =
          '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['last'] ?? ''}'
              .toLowerCase();
      final employeeNumber = (staff['employee_number'] ?? '')
          .toString()
          .toLowerCase();
      final email = (staff['email'] ?? '').toString().toLowerCase();
      final phone = (staff['phone_number'] ?? '').toString().toLowerCase();

      return fullName.contains(searchLower) ||
          employeeNumber.contains(searchLower) ||
          email.contains(searchLower) ||
          phone.contains(searchLower);
    }).toList();

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 80,
          vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff Members',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage and view all registered staff members',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 14 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Staff'),
                  onPressed: () => _showStaffDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Total Staff Members: ${_staff.length}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_staff.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _staffSearchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search staff by name, employee number, email, or phone...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _staffSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _staffSearchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  if (_staffSearchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Found: ${filteredStaff.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            if (_staff.isNotEmpty) const SizedBox(height: 24),
            if (_isStaffLoading)
              const Center(child: CircularProgressIndicator())
            else if (_staff.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No staff members found',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first staff member to get started',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else ...[
              if (filteredStaff.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No staff members match your search',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredStaff.length,
                      itemBuilder: (context, index) {
                        final staff = filteredStaff[index];
                        return _buildStaffCard(staff);
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final fullName =
        '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['middle'] != null && staff['full_name']?['middle'].isNotEmpty ? '${staff['full_name']?['middle']} ' : ''}${staff['full_name']?['last'] ?? ''}';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
    final status = staff['status'] ?? 'active';
    final isActive = status == 'active';

    // Format birthday
    final birthday = staff['birthday'] != null
        ? _formatDate(staff['birthday'])
        : 'N/A';

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? AppTheme.successGreen : AppTheme.errorRed,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          fullName.isNotEmpty ? fullName : 'Staff Member',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(staff['employee_number'] ?? 'Staff'),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: isActive ? AppTheme.successGreen : AppTheme.errorRed,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStaffDetailRow(
                  Icons.person,
                  'Full Name',
                  fullName.isNotEmpty ? fullName : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.badge,
                  'Employee Number',
                  staff['employee_number'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.email,
                  'Email',
                  staff['email'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.phone,
                  'Phone',
                  staff['phone_number'] ?? staff['phone'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.perm_identity,
                  'Identity Number',
                  staff['identity_number'] ?? 'N/A',
                ),
                const Divider(height: 24),
                _buildStaffDetailRow(Icons.cake, 'Birthday', birthday),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.wc,
                  'Gender',
                  staff['gender'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.family_restroom,
                  'Social Status',
                  staff['social_status'] ?? staff['socialStatus'] ?? 'N/A',
                ),
                const Divider(height: 24),
                _buildStaffDetailRow(
                  Icons.school,
                  'Qualification',
                  staff['qualification'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.card_membership,
                  'Profession License',
                  staff['profession_license'] ?? 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.attach_money,
                  'Salary',
                  staff['salary'] != null ? 'ILS ${staff['salary']}' : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildStaffDetailRow(
                  Icons.account_balance,
                  'Bank IBAN',
                  staff['bank_iban'] ?? staff['bankIban'] ?? 'N/A',
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => _showStaffDialog(staff),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () => _deleteStaff(staff['_id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final fullName =
        '${doctor['name']?['first'] ?? ''} ${doctor['name']?['middle'] ?? ''} ${doctor['name']?['last'] ?? ''}'
            .replaceAll('  ', ' ')
            .trim();
    final isActive = (doctor['status'] ?? 'active') == 'active';
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 16),
          childrenPadding: EdgeInsets.all(isVerySmall ? 8 : 16),
          leading: CircleAvatar(
            radius: isVerySmall ? 20 : 24,
            backgroundColor: isActive
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
            child: Icon(
              Icons.medical_services,
              color: isActive ? Colors.green : Colors.red,
              size: isVerySmall ? 20 : 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  fullName.isNotEmpty ? fullName : 'Doctor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isVerySmall ? 14 : 16,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: isVerySmall ? 10 : 12,
                  ),
                ),
                backgroundColor: isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 4 : 8),
              ),
            ],
          ),
          subtitle: Text(
            doctor['specialty'] ?? doctor['specialization'] ?? 'No specialty',
            style: TextStyle(
              fontSize: isVerySmall ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor Info Section
                  Text(
                    'Doctor Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmall ? 14 : 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isMobile || isVerySmall)
                    Column(
                      children: [
                        _buildDoctorDetailRow(
                          Icons.person,
                          'Full Name',
                          fullName.isNotEmpty ? fullName : 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.badge,
                          'Doctor ID',
                          doctor['doctor_id']?.toString() ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.email,
                          'Email',
                          doctor['email'] ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.phone,
                          'Phone',
                          doctor['phone_number'] ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.fingerprint,
                          'Identity Number',
                          doctor['identity_number'] ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.cake,
                          'Birthday',
                          _formatDate(doctor['birthday']),
                        ),
                        _buildDoctorDetailRow(
                          Icons.wc,
                          'Gender',
                          _capitalizeFirst(doctor['gender'] ?? 'N/A'),
                        ),
                        _buildDoctorDetailRow(
                          Icons.medical_services,
                          'Specialty',
                          doctor['specialty'] ??
                              doctor['specialization'] ??
                              'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.card_membership,
                          'License Number',
                          doctor['license_number'] ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.work_history,
                          'Years of Experience',
                          doctor['years_of_experience']?.toString() ?? 'N/A',
                        ),
                        _buildDoctorDetailRow(
                          Icons.account_circle,
                          'Username',
                          doctor['username'] ?? 'N/A',
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 32,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.person,
                            'Full Name',
                            fullName.isNotEmpty ? fullName : 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.badge,
                            'Doctor ID',
                            doctor['doctor_id']?.toString() ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.email,
                            'Email',
                            doctor['email'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.phone,
                            'Phone',
                            doctor['phone_number'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.fingerprint,
                            'Identity Number',
                            doctor['identity_number'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.cake,
                            'Birthday',
                            _formatDate(doctor['birthday']),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.wc,
                            'Gender',
                            _capitalizeFirst(doctor['gender'] ?? 'N/A'),
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.medical_services,
                            'Specialty',
                            doctor['specialty'] ??
                                doctor['specialization'] ??
                                'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.card_membership,
                            'License Number',
                            doctor['license_number'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.work_history,
                            'Years of Experience',
                            doctor['years_of_experience']?.toString() ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDoctorDetailRow(
                            Icons.account_circle,
                            'Username',
                            doctor['username'] ?? 'N/A',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _showDoctorDialog(doctor),
                        child: const Text('Edit'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _deleteDoctor(doctor['_id']),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final DateTime dateTime = date is String ? DateTime.parse(date) : date;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty || text == 'N/A') return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final testName = test['test_name'] ?? 'Test';
    // Use is_active field from backend, fallback to status for compatibility
    final isActive =
        test['is_active'] ?? (test['status'] ?? 'active') == 'active';
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    // Get turnaround time - it's a simple number (hours) in the backend
    final turnaroundTime = test['turnaround_time'];
    String turnaroundDisplay = 'N/A';
    if (turnaroundTime != null) {
      turnaroundDisplay = '$turnaroundTime hours';
    }

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 16),
          childrenPadding: EdgeInsets.all(isVerySmall ? 8 : 16),
          leading: CircleAvatar(
            radius: isVerySmall ? 20 : 24,
            backgroundColor: isActive
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.2),
            child: Icon(
              Icons.science,
              color: isActive ? Colors.green : Colors.red,
              size: isVerySmall ? 20 : 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  testName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isVerySmall ? 14 : 16,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.red,
                    fontSize: isVerySmall ? 10 : 12,
                  ),
                ),
                backgroundColor: isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 4 : 8),
              ),
            ],
          ),
          subtitle: Text(
            'Code: ${test['test_code'] ?? 'N/A'} • Price: \$${test['price'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: isVerySmall ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test Info Section
                  Text(
                    'Test Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmall ? 14 : 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isMobile || isVerySmall)
                    Column(
                      children: [
                        _buildTestDetailRow(
                          Icons.science,
                          'Test Name',
                          testName,
                        ),
                        _buildTestDetailRow(
                          Icons.qr_code,
                          'Test Code',
                          test['test_code'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.attach_money,
                          'Price',
                          '\$${test['price'] ?? 'N/A'}',
                        ),
                        _buildTestDetailRow(
                          Icons.straighten,
                          'Units',
                          test['units'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.timer,
                          'Turnaround Time',
                          turnaroundDisplay,
                        ),
                        _buildTestDetailRow(
                          Icons.colorize,
                          'Sample Type',
                          test['sample_type'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.science_outlined,
                          'Tube Type',
                          test['tube_type'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.build,
                          'Method',
                          test['method'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.compare_arrows,
                          'Reference Range',
                          test['reference_range'] ?? 'N/A',
                        ),
                        _buildTestDetailRow(
                          Icons.medication,
                          'Reagent',
                          test['reagent'] ?? 'N/A',
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 32,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.science,
                            'Test Name',
                            testName,
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.qr_code,
                            'Test Code',
                            test['test_code'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.attach_money,
                            'Price',
                            '\$${test['price'] ?? 'N/A'}',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.straighten,
                            'Units',
                            test['units'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.timer,
                            'Turnaround Time',
                            turnaroundDisplay,
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.colorize,
                            'Sample Type',
                            test['sample_type'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.science_outlined,
                            'Tube Type',
                            test['tube_type'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.build,
                            'Method',
                            test['method'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.compare_arrows,
                            'Reference Range',
                            test['reference_range'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildTestDetailRow(
                            Icons.medication,
                            'Reagent',
                            test['reagent'] ?? 'N/A',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.list, size: 18),
                        label: const Text('Components'),
                        onPressed: () => _showComponentsDialog(test),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        onPressed: () => _showTestDialog(test),
                      ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 18,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () => _deleteTest(test['_id']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label: ',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final deviceName = device['name'] ?? device['device_name'] ?? 'Device';
    final status = device['status'] ?? 'active';
    final isActive = status == 'active';
    final isMaintenance = status == 'maintenance';
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    Color statusColor = isActive
        ? Colors.green
        : (isMaintenance ? Colors.orange : Colors.red);

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isVerySmall ? 8 : 16),
          childrenPadding: EdgeInsets.all(isVerySmall ? 8 : 16),
          leading: CircleAvatar(
            radius: isVerySmall ? 20 : 24,
            backgroundColor: statusColor.withValues(alpha: 0.2),
            child: Icon(
              Icons.precision_manufacturing,
              color: statusColor,
              size: isVerySmall ? 20 : 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  deviceName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isVerySmall ? 14 : 16,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: isVerySmall ? 10 : 12,
                  ),
                ),
                backgroundColor: statusColor.withValues(alpha: 0.1),
                side: BorderSide.none,
                padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 4 : 8),
              ),
            ],
          ),
          subtitle: Text(
            'S/N: ${device['serial_number'] ?? 'N/A'} • ${device['manufacturer'] ?? 'N/A'}',
            style: TextStyle(
              fontSize: isVerySmall ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Info Section
                  Text(
                    'Device Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmall ? 14 : 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isMobile || isVerySmall)
                    Column(
                      children: [
                        _buildDeviceDetailRow(
                          Icons.precision_manufacturing,
                          'Device Name',
                          deviceName,
                        ),
                        _buildDeviceDetailRow(
                          Icons.numbers,
                          'Serial Number',
                          device['serial_number'] ?? 'N/A',
                        ),
                        _buildDeviceDetailRow(
                          Icons.business,
                          'Manufacturer',
                          device['manufacturer'] ?? 'N/A',
                        ),
                        _buildDeviceDetailRow(
                          Icons.cleaning_services,
                          'Cleaning Reagent',
                          device['cleaning_reagent'] ?? 'N/A',
                        ),
                        _buildDeviceDetailRow(
                          Icons.storage,
                          'Sample Capacity',
                          device['capacity_of_sample']?.toString() ?? 'N/A',
                        ),
                        _buildDeviceDetailRow(
                          Icons.schedule,
                          'Maintenance Schedule',
                          device['maintenance_schedule'] ?? 'N/A',
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 32,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.precision_manufacturing,
                            'Device Name',
                            deviceName,
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.numbers,
                            'Serial Number',
                            device['serial_number'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.business,
                            'Manufacturer',
                            device['manufacturer'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.cleaning_services,
                            'Cleaning Reagent',
                            device['cleaning_reagent'] ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.storage,
                            'Sample Capacity',
                            device['capacity_of_sample']?.toString() ?? 'N/A',
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _buildDeviceDetailRow(
                            Icons.schedule,
                            'Maintenance Schedule',
                            device['maintenance_schedule'] ?? 'N/A',
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        onPressed: () => _showDeviceDialog(device),
                      ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 18,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () => _deleteDevice(device['_id']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsView() {
    // Filter doctors based on search query
    final filteredDoctors = _doctors.where((doctor) {
      if (_doctorSearchController.text.isEmpty) return true;
      final searchLower = _doctorSearchController.text.toLowerCase();
      final fullName =
          '${doctor['name']?['first'] ?? ''} ${doctor['name']?['last'] ?? ''}'
              .toLowerCase();
      final email = (doctor['email'] ?? '').toString().toLowerCase();
      final phone = (doctor['phone_number'] ?? '').toString().toLowerCase();
      final specialty = (doctor['specialty'] ?? '').toString().toLowerCase();

      return fullName.contains(searchLower) ||
          email.contains(searchLower) ||
          phone.contains(searchLower) ||
          specialty.contains(searchLower);
    }).toList();

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 80,
          vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctors',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage and view all registered doctors',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 14 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Doctor'),
                  onPressed: () => _showDoctorDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Total Doctors: ${_doctors.length}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_doctors.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _doctorSearchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search doctors by name, email, phone, or specialty...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _doctorSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _doctorSearchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  if (_doctorSearchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Found: ${filteredDoctors.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            if (_doctors.isNotEmpty) const SizedBox(height: 24),
            if (_isDoctorsLoading)
              const Center(child: CircularProgressIndicator())
            else if (_doctors.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No doctors found',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first doctor to get started',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else ...[
              if (filteredDoctors.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No doctors match your search',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredDoctors.length,
                      itemBuilder: (context, index) {
                        final doctor = filteredDoctors[index];
                        return _buildDoctorCard(doctor);
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestsView() {
    // Filter tests based on search query
    final filteredTests = _tests.where((test) {
      if (_testSearchController.text.isEmpty) return true;
      final searchLower = _testSearchController.text.toLowerCase();
      final testName = (test['test_name'] ?? '').toString().toLowerCase();
      final testCode = (test['test_code'] ?? '').toString().toLowerCase();
      final price = (test['price'] ?? '').toString().toLowerCase();
      final category = (test['category'] ?? '').toString().toLowerCase();

      return testName.contains(searchLower) ||
          testCode.contains(searchLower) ||
          price.contains(searchLower) ||
          category.contains(searchLower);
    }).toList();

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 80,
          vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tests',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage and view all laboratory tests',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 14 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Test'),
                  onPressed: () => _showTestDialog(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Total Tests: ${_tests.length}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_tests.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testSearchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search tests by name, code, price, or category...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _testSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _testSearchController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  if (_testSearchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Found: ${filteredTests.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            if (_tests.isNotEmpty) const SizedBox(height: 24),
            if (_isTestsLoading)
              const Center(child: CircularProgressIndicator())
            else if (_tests.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tests found',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first test to get started',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else ...[
              if (filteredTests.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tests match your search',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTests.length,
                      itemBuilder: (context, index) {
                        final test = filteredTests[index];
                        return _buildTestCard(test);
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesView() {
    // Filter devices based on search query
    final filteredDevices = _devices.where((device) {
      if (_deviceSearchController.text.isEmpty) return true;
      final searchLower = _deviceSearchController.text.toLowerCase();
      final name = (device['name'] ?? '').toString().toLowerCase();
      final serialNumber = (device['serial_number'] ?? '')
          .toString()
          .toLowerCase();
      final model = (device['model'] ?? '').toString().toLowerCase();
      final manufacturer = (device['manufacturer'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(searchLower) ||
          serialNumber.contains(searchLower) ||
          model.contains(searchLower) ||
          manufacturer.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Devices: ${_devices.isNotEmpty ? _devices.length : (_dashboardData?['resources']?['devices'] ?? 0)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Device'),
                    onPressed: () => _showDeviceDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deviceSearchController,
                decoration: InputDecoration(
                  hintText:
                      'Search by name, serial number, model, or manufacturer...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _deviceSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _deviceSearchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) => setState(() {}),
              ),
              if (_deviceSearchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Found: ${filteredDevices.length} device(s)',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isDevicesLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredDevices.isEmpty
              ? Center(
                  child: Text(
                    _deviceSearchController.text.isNotEmpty
                        ? 'No devices found matching "${_deviceSearchController.text}"'
                        : 'No devices found. Add your first device!',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    final device = filteredDevices[index];
                    return _buildDeviceCard(device);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryView() {
    // Display inventory management content directly in the dashboard
    return InventoryManagementWidget();
  }

  void _showStaffDialog([Map<String, dynamic>? staff]) async {
    final firstNameController = TextEditingController(
      text: staff?['full_name']?['first'],
    );
    final middleNameController = TextEditingController(
      text: staff?['full_name']?['middle'],
    );
    final lastNameController = TextEditingController(
      text: staff?['full_name']?['last'],
    );
    final identityNumberController = TextEditingController(
      text: staff?['identity_number'],
    );
    final emailController = TextEditingController(text: staff?['email']);
    final phoneController = TextEditingController(
      text: staff?['phone_number'] ?? staff?['phone'],
    );
    final usernameController = TextEditingController(text: staff?['username']);
    final passwordController = TextEditingController();
    final employeeNumberController = TextEditingController(
      text: staff?['employee_number'],
    );
    final qualificationController = TextEditingController(
      text: staff?['qualification'],
    );
    final professionLicenseController = TextEditingController(
      text: staff?['profession_license'],
    );
    final salaryController = TextEditingController(
      text: staff?['salary']?.toString(),
    );
    final bankIbanController = TextEditingController(text: staff?['bank_iban']);

    DateTime? selectedBirthday = staff?['birthday'] != null
        ? DateTime.parse(staff!['birthday'])
        : null;
    String gender = staff?['gender'] ?? 'Male';
    String socialStatus = staff?['social_status'] ?? 'Single';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: firstNameController,
                    label: 'First Name *',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: middleNameController,
                    label: 'Middle Name',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: lastNameController,
                    label: 'Last Name *',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: identityNumberController,
                    label: 'Identity Number *',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 16),

                  // Birthday picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedBirthday ?? DateTime(1990),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedBirthday = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Birthday *',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedBirthday != null
                            ? '${selectedBirthday!.day}/${selectedBirthday!.month}/${selectedBirthday!.year}'
                            : 'Select birthday',
                        style: TextStyle(
                          color: selectedBirthday != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: InputDecoration(
                      labelText: 'Gender *',
                      prefixIcon: const Icon(Icons.wc),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setDialogState(() => gender = value!),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: socialStatus,
                    decoration: InputDecoration(
                      labelText: 'Social Status',
                      prefixIcon: const Icon(Icons.family_restroom),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Single', child: Text('Single')),
                      DropdownMenuItem(
                        value: 'Married',
                        child: Text('Married'),
                      ),
                      DropdownMenuItem(
                        value: 'Divorced',
                        child: Text('Divorced'),
                      ),
                      DropdownMenuItem(
                        value: 'Widowed',
                        child: Text('Widowed'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => socialStatus = value!),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: emailController,
                    label: 'Email *',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: phoneController,
                    label: 'Phone Number *',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Account & Employment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: usernameController,
                    label: 'Username *',
                    prefixIcon: Icons.account_circle,
                  ),
                  const SizedBox(height: 16),

                  if (staff == null) ...[
                    CustomTextField(
                      controller: passwordController,
                      label: 'Password *',
                      prefixIcon: Icons.lock,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    controller: employeeNumberController,
                    label: 'Employee Number',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: qualificationController,
                    label: 'Qualification',
                    prefixIcon: Icons.school,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: professionLicenseController,
                    label: 'Profession License',
                    prefixIcon: Icons.card_membership,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: salaryController,
                    label: 'Salary',
                    prefixIcon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: bankIbanController,
                    label: 'Bank IBAN',
                    prefixIcon: Icons.account_balance,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    '* Required fields',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate required fields
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    identityNumberController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    selectedBirthday == null ||
                    (staff == null && passwordController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields (*)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'full_name': {
                      'first': firstNameController.text,
                      if (middleNameController.text.isNotEmpty)
                        'middle': middleNameController.text,
                      'last': lastNameController.text,
                    },
                    'identity_number': identityNumberController.text,
                    'birthday': selectedBirthday!.toIso8601String(),
                    'gender': gender,
                    'social_status': socialStatus,
                    'email': emailController.text,
                    'phone_number': phoneController.text,
                    'username': usernameController.text,
                    if (staff == null && passwordController.text.isNotEmpty)
                      'password': passwordController.text,
                    if (employeeNumberController.text.isNotEmpty)
                      'employee_number': employeeNumberController.text,
                    if (qualificationController.text.isNotEmpty)
                      'qualification': qualificationController.text,
                    if (professionLicenseController.text.isNotEmpty)
                      'profession_license': professionLicenseController.text,
                    if (salaryController.text.isNotEmpty)
                      'salary': double.tryParse(salaryController.text) ?? 0,
                    'bank_iban': bankIbanController.text,
                  };

                  final response = staff == null
                      ? await OwnerApiService.createStaff(data)
                      : await OwnerApiService.updateStaff(staff['_id'], data);

                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    Navigator.pop(context, true);
                    _loadStaff();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          staff == null
                              ? '✅ Staff created successfully'
                              : '✅ Staff updated successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(staff == null ? 'Create Staff' : 'Update Staff'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadStaff();
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: const Text(
          'Are you sure you want to delete this staff member?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteStaff(staffId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDoctorDialog([Map<String, dynamic>? doctor]) async {
    final firstNameController = TextEditingController(
      text: doctor?['name']?['first'],
    );
    final middleNameController = TextEditingController(
      text: doctor?['name']?['middle'],
    );
    final lastNameController = TextEditingController(
      text: doctor?['name']?['last'],
    );
    final emailController = TextEditingController(text: doctor?['email']);
    final phoneController = TextEditingController(
      text: doctor?['phone_number'],
    );
    final usernameController = TextEditingController(text: doctor?['username']);
    final passwordController = TextEditingController();
    final identityController = TextEditingController(
      text: doctor?['identity_number'],
    );
    DateTime? selectedBirthday = doctor?['birthday'] != null
        ? DateTime.parse(doctor!['birthday'])
        : null;
    String selectedGender = doctor?['gender'] ?? 'Male';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(doctor == null ? 'Add Doctor' : 'Edit Doctor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: firstNameController,
                  label: 'First Name *',
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: middleNameController,
                  label: 'Middle Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: lastNameController,
                  label: 'Last Name *',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: identityController,
                  label: 'Identity Number *',
                  prefixIcon: Icons.badge,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedBirthday ?? DateTime(1990),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedBirthday = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthday *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      selectedBirthday != null
                          ? '${selectedBirthday!.day}/${selectedBirthday!.month}/${selectedBirthday!.year}'
                          : 'Select birthday',
                      style: TextStyle(
                        color: selectedBirthday != null
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Male', 'Female', 'Other'].map((gender) {
                    return DropdownMenuItem(value: gender, child: Text(gender));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: emailController,
                  label: 'Email *',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: phoneController,
                  label: 'Phone *',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: usernameController,
                  label: 'Username *',
                  prefixIcon: Icons.account_circle,
                ),
                if (doctor == null) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: passwordController,
                    label: 'Password *',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    identityController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    selectedBirthday == null ||
                    (doctor == null && passwordController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields (*)'),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = doctor == null
                      ? {
                          'full_name': {
                            'first': firstNameController.text,
                            'middle': middleNameController.text,
                            'last': lastNameController.text,
                          },
                          'identity_number': identityController.text,
                          'birthday':
                              '${selectedBirthday!.year}-${selectedBirthday!.month.toString().padLeft(2, '0')}-${selectedBirthday!.day.toString().padLeft(2, '0')}',
                          'gender': selectedGender,
                          'email': emailController.text,
                          'phone': phoneController.text,
                          'username': usernameController.text,
                          'password': passwordController.text,
                        }
                      : {
                          'name': {
                            'first': firstNameController.text,
                            'middle': middleNameController.text,
                            'last': lastNameController.text,
                          },
                          'identity_number': identityController.text,
                          'birthday':
                              '${selectedBirthday!.year}-${selectedBirthday!.month.toString().padLeft(2, '0')}-${selectedBirthday!.day.toString().padLeft(2, '0')}',
                          'gender': selectedGender,
                          'email': emailController.text,
                          'phone_number': phoneController.text,
                          'username': usernameController.text,
                        };

                  final response = doctor == null
                      ? await OwnerApiService.createDoctor(data)
                      : await OwnerApiService.updateDoctor(doctor['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);

                  if (response['message'] != null &&
                      !response['message'].toString().contains('⚠️') &&
                      !response['message'].toString().contains('❌')) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadDoctors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            doctor == null
                                ? 'Doctor created successfully'
                                : 'Doctor updated successfully',
                          ),
                        ),
                      );
                    }
                  } else {
                    // Show error message from server
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response['message'] ?? 'Error occurred',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(doctor == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadDoctors();
    }
  }

  Future<void> _deleteDoctor(String doctorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Doctor'),
        content: const Text('Are you sure you want to delete this doctor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDoctor(doctorId);
      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadDoctors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor deleted successfully')),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showTestDialog([Map<String, dynamic>? test]) async {
    final nameController = TextEditingController(text: test?['test_name']);
    final testCodeController = TextEditingController(text: test?['test_code']);
    final priceController = TextEditingController(
      text: test?['price']?.toString(),
    );
    // turnaround_time is a simple number (hours) in the backend
    final turnaroundController = TextEditingController(
      text: test?['turnaround_time']?.toString() ?? '',
    );
    String selectedTimeUnit = 'hours'; // Default unit
    final unitController = TextEditingController(text: test?['units']);
    final methodController = TextEditingController(text: test?['method']);
    final referenceRangeController = TextEditingController(
      text: test?['reference_range'],
    );
    final tubeTypeController = TextEditingController(text: test?['tube_type']);
    final reagentController = TextEditingController(text: test?['reagent']);
    final sampleTypeController = TextEditingController(
      text: test?['sample_type'],
    );

    // Extract device_id - might be an object with _id or a string
    final deviceIdData = test?['device_id'];
    String? selectedDevice;
    if (deviceIdData != null) {
      if (deviceIdData is Map) {
        selectedDevice = deviceIdData['_id']?.toString();
      } else {
        selectedDevice = deviceIdData.toString();
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(test == null ? 'Add Test' : 'Edit Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Test Name',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                if (test == null) ...[
                  CustomTextField(
                    controller: testCodeController,
                    label: 'Test Code',
                    prefixIcon: Icons.code,
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: priceController,
                  label: 'Price',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: turnaroundController,
                        label: 'Turnaround Time',
                        prefixIcon: Icons.access_time,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedTimeUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'minutes',
                            child: Text('Minutes'),
                          ),
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text('Hours'),
                          ),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => selectedTimeUnit = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: unitController,
                  label: 'Units',
                  prefixIcon: Icons.straighten,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: methodController,
                  label: 'Method',
                  prefixIcon: Icons.biotech,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: referenceRangeController,
                  label: 'Reference Range',
                  prefixIcon: Icons.assessment,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: tubeTypeController,
                  label: 'Tube Type',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: reagentController,
                  label: 'Reagent',
                  prefixIcon: Icons.liquor,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: sampleTypeController,
                  label: 'Sample Type (e.g., Blood, Urine)',
                  prefixIcon: Icons.bloodtype,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDevice,
                  decoration: InputDecoration(
                    labelText: 'Device (Optional)',
                    prefixIcon: const Icon(Icons.devices),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Device'),
                    ),
                    ..._devices.map(
                      (device) => DropdownMenuItem<String>(
                        value: device['_id'],
                        child: Text(
                          device['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedDevice = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    (test == null && testCodeController.text.isEmpty) ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Test name, test code (for new tests), and price are required',
                      ),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'test_name': nameController.text,
                    if (test == null) 'test_code': testCodeController.text,
                    'price': double.tryParse(priceController.text) ?? 0,
                    'turnaround_time': _convertToHours(
                      double.tryParse(turnaroundController.text) ?? 24,
                      selectedTimeUnit,
                    ),
                    'units': unitController.text,
                    'method': methodController.text,
                    'reference_range': referenceRangeController.text,
                    'tube_type': tubeTypeController.text,
                    'reagent': reagentController.text,
                    'sample_type': sampleTypeController.text.isNotEmpty
                        ? sampleTypeController.text
                        : 'Blood',
                    if (selectedDevice != null) 'device_id': selectedDevice,
                  };

                  final response = test == null
                      ? await OwnerApiService.createTest(data)
                      : await OwnerApiService.updateTest(test['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadTests();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            test == null
                                ? 'Test created successfully'
                                : 'Test updated successfully',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(test == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadTests();
    }
  }

  Future<void> _deleteTest(String testId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Test'),
        content: const Text('Are you sure you want to delete this test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTest(testId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadTests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDeviceDialog([Map<String, dynamic>? device]) async {
    final nameController = TextEditingController(text: device?['name']);
    final manufacturerController = TextEditingController(
      text: device?['manufacturer'],
    );
    final serialController = TextEditingController(
      text: device?['serial_number'],
    );
    final cleaningReagentController = TextEditingController(
      text: device?['cleaning_reagent'],
    );
    final capacityController = TextEditingController(
      text: device?['capacity_of_sample']?.toString() ?? '',
    );

    // Extract staff_id - might be an object with _id or a string
    final staffIdData = device?['staff_id'];
    String? selectedStaff;
    if (staffIdData != null) {
      if (staffIdData is Map) {
        selectedStaff = staffIdData['_id']?.toString();
      } else {
        selectedStaff = staffIdData.toString();
      }
    }

    // Verify selectedStaff exists in _staff list, otherwise set to null
    if (selectedStaff != null) {
      final staffExists = _staff.any((s) => s['_id'] == selectedStaff);
      if (!staffExists) {
        selectedStaff = null;
      }
    }

    String status = device?['status']?.toString() ?? 'active';
    // Ensure status is a valid value
    if (!['active', 'inactive', 'maintenance'].contains(status)) {
      status = 'active';
    }

    String maintenanceSchedule =
        device?['maintenance_schedule']?.toString() ?? 'monthly';
    if (!['daily', 'weekly', 'monthly'].contains(maintenanceSchedule)) {
      maintenanceSchedule = 'monthly';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(device == null ? 'Add Device' : 'Edit Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Device Name',
                  prefixIcon: Icons.devices,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: manufacturerController,
                  label: 'Manufacturer',
                  prefixIcon: Icons.business,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: serialController,
                  label: 'Serial Number',
                  prefixIcon: Icons.qr_code,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: cleaningReagentController,
                  label: 'Cleaning Reagent',
                  prefixIcon: Icons.cleaning_services,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: capacityController,
                  label: 'Sample Capacity',
                  prefixIcon: Icons.storage,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: maintenanceSchedule,
                  decoration: InputDecoration(
                    labelText: 'Maintenance Schedule',
                    prefixIcon: const Icon(Icons.schedule),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => maintenanceSchedule = value!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedStaff,
                  decoration: InputDecoration(
                    labelText: 'Assigned Staff (Optional)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._staff.map(
                      (s) => DropdownMenuItem<String>(
                        value: s['_id'],
                        child: Text(
                          '${s['full_name']?['first']} ${s['full_name']?['last']}'
                              .trim(),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedStaff = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(Icons.info),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => status = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device name is required')),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'name': nameController.text,
                    'manufacturer': manufacturerController.text,
                    'serial_number': serialController.text,
                    'cleaning_reagent': cleaningReagentController.text,
                    'capacity_of_sample':
                        int.tryParse(capacityController.text) ?? 0,
                    'maintenance_schedule': maintenanceSchedule,
                    'staff_id': selectedStaff,
                    'status': status,
                  };

                  final response = device == null
                      ? await OwnerApiService.createDevice(data)
                      : await OwnerApiService.updateDevice(device['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadDevices();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            device == null
                                ? 'Device created successfully'
                                : 'Device updated successfully',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(device == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadDevices();
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: const Text('Are you sure you want to delete this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDevice(deviceId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Orders management methods
  Future<void> _loadOrders() async {
    if (_isOrdersLoading) return; // Prevent multiple simultaneous loads

    setState(() => _isOrdersLoading = true);
    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getAllOrders(
        status: _selectedStatus?.isNotEmpty == true ? _selectedStatus : null,
      );

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
          _ordersError = null;
          _isOrdersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = 'Failed to load orders: $e';
          _isOrdersLoading = false;
        });
      }
    }
  }

  Future<void> _loadOrdersInBackground() async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getAllOrders(
        status: _selectedStatus?.isNotEmpty == true ? _selectedStatus : null,
      );

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
          _ordersError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = 'Failed to load orders: $e';
        });
      }
    }
  }

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() => _isReportsLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getReports(
        period: _selectedReportPeriod,
      );

      if (mounted) {
        // Transform backend response to frontend expected structure
        final transformedData = _transformReportsData(response);
        setState(() {
          _reportsData = transformedData;
          _isReportsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReportsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _transformReportsData(Map<String, dynamic> backendData) {
    final orders = backendData['orders'] ?? {};
    final revenue = backendData['revenue'] ?? {};
    final expenses = backendData['expenses'] ?? {};

    // Calculate additional metrics
    final totalExpenses =
        (expenses['salaries'] ?? 0) +
        (expenses['subscriptions'] ?? 0) +
        (expenses['inventory'] ?? 0);
    final netProfit = (revenue['paid'] ?? 0) - totalExpenses;

    return {
      'financial': {
        'totalRevenue': revenue['total'] ?? 0,
        'monthlyRevenue': revenue['paid'] ?? 0, // Using paid as monthly for now
        'totalExpenses': totalExpenses,
        'netProfit': netProfit,
      },
      'orders': {
        'totalOrders': orders['total'] ?? 0,
        'completedOrders': orders['completed'] ?? 0,
        'pendingOrders': orders['processing'] ?? 0,
      },
    };
  }

  Future<void> _loadAuditLogs({bool loadMore = false}) async {
    if (!mounted) return;

    if (!loadMore) {
      setState(() => _isAuditLogsLoading = true);
    }

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getAuditLogs(
        page: loadMore ? _auditLogsPage + 1 : 1,
        limit: 50,
      );

      if (mounted) {
        final newLogs = List<Map<String, dynamic>>.from(
          response['auditLogs'] ?? [],
        );
        final pagination = response['pagination'] ?? {};

        setState(() {
          if (loadMore) {
            _auditLogs.addAll(newLogs);
            _auditLogsPage = pagination['page'] ?? _auditLogsPage;
          } else {
            _auditLogs = newLogs;
            _auditLogsPage = 1;
          }
          _auditLogsTotalPages = pagination['pages'] ?? 1;
          _isAuditLogsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAuditLogsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audit logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() => _isNotificationsLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await ApiService.get(ApiConfig.ownerNotifications);

      if (mounted) {
        final notifications = response?['notifications'] as List? ?? [];

        setState(() {
          _notifications = List<Map<String, dynamic>>.from(notifications);
          _isNotificationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isNotificationsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNotificationsView() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Header with filters
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: AppTheme.primaryBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Notifications: ${_notifications.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filter dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _notificationFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Notifications'),
                          ),
                          DropdownMenuItem(
                            value: 'unread',
                            child: Text('Unread Only'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _notificationFilter = value);
                          }
                        },
                        underline: const SizedBox(),
                        icon: const Icon(Icons.filter_list),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notifications list
          Expanded(
            child: _isNotificationsLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? 'system';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt = notification['createdAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _markNotificationAsRead(notification['_id']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'subscription':
        return Colors.green;
      case 'system':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'test_result':
        return Colors.purple;
      case 'payment':
        return Colors.teal;
      case 'inventory':
        return Colors.brown;
      case 'feedback':
        return Colors.pink;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'subscription':
        return Icons.subscriptions;
      case 'system':
        return Icons.info;
      case 'maintenance':
        return Icons.build;
      case 'test_result':
        return Icons.assignment_turned_in;
      case 'payment':
        return Icons.payment;
      case 'inventory':
        return Icons.inventory;
      case 'feedback':
        return Icons.feedback;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      await ApiService.put(ApiConfig.ownerNotificationRead(notificationId), {});

      // Update local state
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['_id'] == notificationId,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark notification as read: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAuditLogsView() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Header with filters
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: AppTheme.primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Audit Logs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Monitor all system activities and staff actions',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Audit logs list
          Expanded(
            child: _isAuditLogsLoading && _auditLogs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _auditLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No Audit Logs Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Audit logs will appear here when staff perform actions',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadAuditLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount:
                        _auditLogs.length +
                        (_auditLogsPage < _auditLogsTotalPages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _auditLogs.length) {
                        // Load more button
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton(
                              onPressed: _isAuditLogsLoading
                                  ? null
                                  : () => _loadAuditLogs(loadMore: true),
                              child: _isAuditLogsLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Load More'),
                            ),
                          ),
                        );
                      }

                      final log = _auditLogs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _getActionColor(
                                      log['action'],
                                    ),
                                    child: Icon(
                                      _getActionIcon(log['action']),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log['staff_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Employee #: ${log['employee_number'] ?? 'N/A'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(log['timestamp']),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getActionColor(
                                    log['action'],
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log['action'] ?? 'Unknown Action',
                                  style: TextStyle(
                                    color: _getActionColor(log['action']),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                log['message'] ?? 'No details available',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (log['table_name'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Table: ${log['table_name']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String? action) {
    switch (action?.toLowerCase()) {
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.grey;
      case 'create':
        return Colors.blue;
      case 'update':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      case 'view':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String? action) {
    switch (action?.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'create':
        return Icons.add;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'view':
        return Icons.visibility;
      default:
        return Icons.history;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> filtered = _orders;

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        final patientName =
            order['patient_name']?.toString().toLowerCase() ?? '';
        final orderId = order['_id']?.toString().toLowerCase() ?? '';
        final doctorName = order['doctor_name']?.toString().toLowerCase() ?? '';
        return patientName.contains(query) ||
            orderId.contains(query) ||
            doctorName.contains(query);
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered
          .where(
            (order) =>
                order['status']?.toString().toLowerCase() ==
                _selectedStatus!.toLowerCase(),
          )
          .toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Widget _buildReportsView() {
    return Container(
      color: Colors.grey[50],
      child: _isReportsLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportsData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Reports Data Available',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reports data will be displayed here once available',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadReports,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Made responsive
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 400;
                      if (isSmall) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reports & Analytics',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedReportPeriod,
                                underline: const SizedBox(),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('Today'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('This Week'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('This Month'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('This Year'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(
                                      () => _selectedReportPeriod = value,
                                    );
                                    _loadReports();
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Reports & Analytics',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedReportPeriod,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'daily',
                                  child: Text('Today'),
                                ),
                                DropdownMenuItem(
                                  value: 'weekly',
                                  child: Text('This Week'),
                                ),
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('This Month'),
                                ),
                                DropdownMenuItem(
                                  value: 'yearly',
                                  child: Text('This Year'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedReportPeriod = value);
                                  _loadReports();
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Financial Reports Section
                  _buildFinancialReportsSection(),

                  const SizedBox(height: 32),

                  // Order Statistics Section
                  _buildOrderStatisticsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildFinancialReportsSection() {
    final financialData = _reportsData?['financial'] ?? {};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: AppTheme.primaryBlue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Financial Reports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Revenue Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Revenue',
                    '\$${(financialData['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Monthly Revenue',
                    '\$${(financialData['monthlyRevenue'] ?? 0).toStringAsFixed(2)}',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Expenses',
                    '\$${(financialData['totalExpenses'] ?? 0).toStringAsFixed(2)}',
                    Icons.money_off,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Net Profit',
                    '\$${(financialData['netProfit'] ?? 0).toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    (financialData['netProfit'] ?? 0) >= 0
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Net Profit Calculation Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Net Profit Calculation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Net Profit = Total Revenue - Total Expenses\n\nTotal Expenses include:\n• Staff Salaries\n• Inventory Costs\n• Subscription Fees',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Financial Chart
            const Text(
              'Revenue vs Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY:
                        [
                          (financialData['totalRevenue'] ?? 0).toDouble(),
                          (financialData['totalExpenses'] ?? 0).toDouble(),
                          (financialData['netProfit'] ?? 0).abs().toDouble(),
                        ].reduce((a, b) => a > b ? a : b) *
                        1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String label;
                          switch (groupIndex) {
                            case 0:
                              label = 'Revenue';
                              break;
                            case 1:
                              label = 'Expenses';
                              break;
                            case 2:
                              label = 'Net Profit';
                              break;
                            default:
                              label = '';
                          }
                          return BarTooltipItem(
                            '$label\n\$${rod.toY.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const titles = ['Revenue', 'Expenses', 'Profit'];
                            if (value.toInt() >= 0 &&
                                value.toInt() < titles.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  titles[value.toInt()],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('\$0');
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval:
                          ([
                                (financialData['totalRevenue'] ?? 0).toDouble(),
                                (financialData['totalExpenses'] ?? 0)
                                    .toDouble(),
                                (financialData['netProfit'] ?? 0)
                                    .abs()
                                    .toDouble(),
                              ].reduce((a, b) => a > b ? a : b) *
                              1.2) /
                          5,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: (financialData['totalRevenue'] ?? 0)
                                .toDouble(),
                            color: Colors.green,
                            width: 30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: (financialData['totalExpenses'] ?? 0)
                                .toDouble(),
                            color: Colors.red,
                            width: 30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: (financialData['netProfit'] ?? 0)
                                .abs()
                                .toDouble(),
                            color: (financialData['netProfit'] ?? 0) >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                            width: 30,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatisticsSection() {
    final orderData = _reportsData?['orders'] ?? {};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: AppTheme.primaryBlue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Order Statistics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Status Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Orders',
                    '${orderData['totalOrders'] ?? 0}',
                    Icons.receipt_long,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Completed Orders',
                    '${orderData['completedOrders'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Pending Orders',
                    '${orderData['pendingOrders'] ?? 0}',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showComponentsDialog(Map<String, dynamic> test) async {
    List<Map<String, dynamic>> components = [];
    bool isLoading = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            OwnerApiService.getTestComponents(test['_id'])
                .then((response) {
                  if (response['components'] != null) {
                    setDialogState(() {
                      components = List<Map<String, dynamic>>.from(
                        response['components'],
                      );
                      isLoading = false;
                    });
                  }
                })
                .catchError((e) {
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error loading components: $e')),
                    );
                  }
                });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.view_list, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Components',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Text(
                        test['test_name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : components.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No components yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add components for multi-parameter tests',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: components.length,
                      itemBuilder: (context, index) {
                        final component = components[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  radius: 18,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        component['component_name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Code: ${component['component_code'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Units: ${component['units'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Range: ${component['reference_range'] ?? 'N/A'}',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                        _showComponentFormDialog(
                                          test,
                                          component,
                                        ).then(
                                          (_) => _showComponentsDialog(test),
                                        );
                                      },
                                      tooltip: 'Edit Component',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      onPressed: () =>
                                          _deleteComponent(
                                            test['_id'],
                                            component['_id'],
                                          ).then((_) {
                                            setDialogState(
                                              () => components.removeAt(index),
                                            );
                                          }),
                                      tooltip: 'Delete Component',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showComponentFormDialog(
                    test,
                  ).then((_) => _showComponentsDialog(test));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Component'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showComponentFormDialog(
    Map<String, dynamic> test, [
    Map<String, dynamic>? component,
  ]) async {
    final nameController = TextEditingController(
      text: component?['component_name'],
    );
    final codeController = TextEditingController(
      text: component?['component_code'],
    );
    final unitsController = TextEditingController(text: component?['units']);
    final rangeController = TextEditingController(
      text: component?['reference_range'],
    );
    final minController = TextEditingController(
      text: component?['min_value']?.toString(),
    );
    final maxController = TextEditingController(
      text: component?['max_value']?.toString(),
    );
    final orderController = TextEditingController(
      text: component?['display_order']?.toString(),
    );
    final descController = TextEditingController(
      text: component?['description'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(component == null ? 'Add Component' : 'Edit Component'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Component Name *',
                prefixIcon: Icons.science,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: codeController,
                label: 'Component Code *',
                prefixIcon: Icons.code,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: unitsController,
                label: 'Units (e.g., mg/dL, 10^3/μL)',
                prefixIcon: Icons.straighten,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: rangeController,
                label: 'Reference Range (e.g., 4.5-11.0)',
                prefixIcon: Icons.assessment,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: minController,
                      label: 'Min Value',
                      prefixIcon: Icons.arrow_downward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: maxController,
                      label: 'Max Value',
                      prefixIcon: Icons.arrow_upward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: orderController,
                label: 'Display Order',
                prefixIcon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: descController,
                label: 'Description (Optional)',
                prefixIcon: Icons.description,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Component name and code are required'),
                  ),
                );
                return;
              }

              LoadingDialog.show(context);
              try {
                final data = {
                  'component_name': nameController.text,
                  'component_code': codeController.text,
                  if (unitsController.text.isNotEmpty)
                    'units': unitsController.text,
                  if (rangeController.text.isNotEmpty)
                    'reference_range': rangeController.text,
                  if (minController.text.isNotEmpty)
                    'min_value': double.tryParse(minController.text),
                  if (maxController.text.isNotEmpty)
                    'max_value': double.tryParse(maxController.text),
                  if (orderController.text.isNotEmpty)
                    'display_order': int.tryParse(orderController.text),
                  if (descController.text.isNotEmpty)
                    'description': descController.text,
                };

                final response = component == null
                    ? await OwnerApiService.addTestComponent(test['_id'], data)
                    : await OwnerApiService.updateTestComponent(
                        test['_id'],
                        component['_id'],
                        data,
                      );

                if (!context.mounted) return;
                LoadingDialog.hide(context);

                if (response['message'] != null ||
                    response['component'] != null) {
                  Navigator.pop(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        component == null
                            ? 'Component added successfully'
                            : 'Component updated successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                LoadingDialog.hide(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(component == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComponent(String testId, String componentId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Component',
      message: 'Are you sure you want to delete this component?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTestComponent(
        testId,
        componentId,
      );

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Component deleted successfully')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showInventoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventory Management'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick inventory actions and overview',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildQuickActionButton(
                icon: Icons.add,
                label: 'Add New Item',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 6);
                  // Could trigger add item dialog here
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.warning,
                label: 'View Low Stock Items',
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 6);
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.inventory,
                label: 'Full Inventory Management',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 6);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrdersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Management'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick order actions and overview',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildQuickActionButton(
                icon: Icons.assignment,
                label: 'View All Orders',
                color: AppTheme.secondaryTeal,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 3);
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.pending,
                label: 'Pending Orders',
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 3);
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.check_circle,
                label: 'Completed Orders',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 3);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReportsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reports & Analytics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Access detailed reports and analytics',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildQuickActionButton(
                icon: Icons.analytics,
                label: 'Financial Reports',
                color: AppTheme.successGreen,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 7);
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.bar_chart,
                label: 'Order Statistics',
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 7);
                },
              ),
              const SizedBox(height: 12),
              _buildQuickActionButton(
                icon: Icons.history,
                label: 'Audit Logs',
                color: Colors.purple,
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = 8);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
