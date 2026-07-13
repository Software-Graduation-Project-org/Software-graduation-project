import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/admin_service.dart';
import '../../services/notification_service.dart' as notification_service;
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../config/theme.dart';
import '../../widgets/admin_sidebar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'admin_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String? initialTab;

  const AdminDashboardScreen({super.key, this.initialTab});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  String _labOwnersSearchQuery = '';
  Timer? _searchDebounceTimer;
  int _refreshKey = 0; // Force FutureBuilder refresh
  final notification_service.NotificationService _notificationService =
      notification_service.NotificationService();

  // Notifications state
  List<Map<String, dynamic>> _notifications = [];
  bool _notificationsLoading = false;
  Map<String, Timer> _notificationRemovalTimers = {}; // Track removal timers
  String _notificationFilter = 'all'; // 'all' or 'unread'

  @override
  void initState() {
    super.initState();

    // Set initial tab based on parameter
    if (widget.initialTab != null) {
      _selectedIndex = _getTabIndexFromName(widget.initialTab!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        ApiService.setAuthToken(authProvider.token);
        _loadDashboardData();
        _loadNotifications(); // Load notifications
        _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          if (mounted) {
            _loadDashboardData();
            _loadNotifications(); // Refresh notifications periodically
          }
        });
      }
    });

    // Register for notification callbacks to refresh data when subscription requests arrive
    _notificationService.setNotificationCallback(_onNotificationReceived);
  }

  // Convert tab name to index
  int _getTabIndexFromName(String tabName) {
    switch (tabName.toLowerCase()) {
      case 'dashboard':
        return 0;
      case 'labowners':
      case 'lab-owners':
        return 1;
      case 'pending':
      case 'approvals':
      case 'pending-approvals':
        return 2;
      case 'subscriptions':
      case 'renewal':
      case 'renewals':
        return 3;
      case 'notifications':
        return 4;
      case 'feedback':
        return 5;
      case 'reports':
        return 6;
      default:
        return 0;
    }
  }

  // Load notifications
  Future<void> _loadNotifications() async {
    if (_notificationsLoading) return;

    setState(() => _notificationsLoading = true);
    try {
      final response = await ApiService.get(ApiConfig.adminNotifications);
      final notifications = response?['notifications'] as List? ?? [];
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(notifications);
          _notificationsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _notificationsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  // Mark notification as read with immediate removal
  Future<void> _markNotificationAsRead(String notificationId) async {
    debugPrint('🔔 MARKING NOTIFICATION AS READ: $notificationId');
    try {
      // First make the API call
      debugPrint('🔔 Making API call to mark as read...');
      await ApiService.put(
        '${ApiConfig.adminNotifications}/$notificationId/read',
        {},
      );
      debugPrint('🔔 API call successful');

      // Immediately remove from local list to prevent reappearance
      debugPrint(
        '🔔 Removing notification $notificationId from list immediately',
      );
      setState(() {
        _notifications.removeWhere((n) => n['_id'] == notificationId);
      });

      // Cancel any existing timer for this notification
      _notificationRemovalTimers.remove(notificationId);
    } catch (e) {
      debugPrint('🔔 ERROR marking notification as read: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to mark as read: $e')));
      }
    }
  }

  // Handle notification callbacks to refresh data
  void _onNotificationReceived(String type, Map<String, dynamic> data) {
    // Refresh dashboard data when subscription requests arrive
    if (type == 'subscription') {
      _loadDashboardData();
    }
  }

  String _formatLabOwnerName(dynamic name) {
    if (name is Map<String, dynamic>) {
      final first = name['first'] ?? '';
      final middle = name['middle'] ?? '';
      final last = name['last'] ?? '';
      return [first, middle, last].where((s) => s.isNotEmpty).join(' ');
    }
    return name?.toString() ?? 'Unknown Owner';
  }

  String _formatNotificationMessage(String message) {
    // Replace raw lab name objects with formatted names
    // Look for JSON objects in the message that represent names
    final jsonObjectRegex = RegExp(r'(\{[^}]+\})');
    final matches = jsonObjectRegex.allMatches(message);

    String formattedMessage = message;
    for (final match in matches) {
      try {
        final rawJson = match.group(1)!;
        final nameObj = rawJson.replaceAll("'", '"');
        final decoded = jsonDecode(nameObj);
        if (decoded is Map<String, dynamic> &&
            (decoded.containsKey('first') || decoded.containsKey('last'))) {
          final formattedName = _formatLabOwnerName(decoded);
          formattedMessage = formattedMessage.replaceFirst(
            rawJson,
            formattedName,
          );
        }
      } catch (e) {
        // If parsing fails, continue with next match
        continue;
      }
    }
    return formattedMessage;
  }

  // Get filtered notifications based on current filter
  List<Map<String, dynamic>> get _filteredNotifications {
    if (_notificationFilter == 'unread') {
      return _notifications.where((notification) {
        final isRead = notification['is_read'] ?? false;
        return !isRead;
      }).toList();
    }
    return _notifications;
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final result = await ApiService.get(ApiConfig.adminDashboard);

      setState(() {
        _dashboardData = result is Map<String, dynamic> ? result : {};
        _isLoading = false;
        _refreshKey++; // Force refresh
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
  }

  Future<void> _refreshDashboardData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final result = await ApiService.get(ApiConfig.adminDashboard);

      if (mounted) {
        setState(() {
          _dashboardData = result is Map<String, dynamic> ? result : {};
          _refreshKey++; // Force refresh
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing dashboard: $e')),
        );
      }
    }
  }

  void _handleNavigation(int index) {
    setState(() => _selectedIndex = index);

    // Handle navigation based on selected index
    switch (index) {
      case 0: // Dashboard - already handled by setState
        break;
      case 1: // Lab Owners - show in main content
        // Content shown when _selectedIndex == 1
        break;
      case 2: // Pending Approvals - show in main content
        // Content shown when _selectedIndex == 2
        break;
      case 3: // Subscriptions - show in main content
        // Content shown when _selectedIndex == 3
        break;
      case 4: // Notifications - show in main content
        // Content shown when _selectedIndex == 4
        break;
      case 5: // Feedback - show in main content
        // Content shown when _selectedIndex == 5
        break;
      case 6: // System Reports
        // Content shown when _selectedIndex == 6
        break;
      default:
        break;
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
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isVerySmall = MediaQuery.of(context).size.width < 500;

    // Show loading while auth state is being determined
    if (authProvider.token == null && authProvider.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
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
              title: Text(
                'Admin Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              title: Text(
                'Admin Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(
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
                        Icons.admin_panel_settings,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        authProvider.user?['full_name'] ??
                            authProvider.user?['username'] ??
                            'Administrator',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      drawer: isMobile
          ? AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                Navigator.pop(context);
                _handleNavigation(index);
              },
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile &&
                  _isSidebarOpen &&
                  MediaQuery.of(context).size.width > 600)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: AdminSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _handleNavigation,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Hero Section (only on dashboard)
                      if (_selectedIndex == 0)
                        AppAnimations.blurFadeIn(
                          _buildHeroSection(context, isMobile, isVerySmall),
                        ),
                      // Activity Section
                      if (_selectedIndex == 0)
                        AppAnimations.elasticSlideIn(
                          _buildActivitySection(context, isMobile, isVerySmall),
                          delay: 500.ms,
                        ),
                      // Quick Actions Section
                      if (_selectedIndex == 0)
                        AppAnimations.elasticSlideIn(
                          _buildQuickActionsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                          delay: 900.ms,
                        ),
                      // Lab Owners Section
                      if (_selectedIndex == 1)
                        AppAnimations.fadeIn(
                          _buildLabOwnersSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Pending Approvals Section
                      if (_selectedIndex == 2)
                        AppAnimations.fadeIn(
                          _buildPendingApprovalsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Subscriptions Section
                      if (_selectedIndex == 3)
                        AppAnimations.fadeIn(
                          _buildSubscriptionsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Notifications Section
                      if (_selectedIndex == 4)
                        AppAnimations.fadeIn(
                          _buildNotificationsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Feedback Section
                      if (_selectedIndex == 5)
                        AppAnimations.fadeIn(
                          _buildFeedbackSection(context, isMobile, isVerySmall),
                        ),
                      // System Reports Section
                      if (_selectedIndex == 6)
                        AppAnimations.fadeIn(const AdminReportsScreen()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Screen Width Display
          /*
          Positioned(
            top: isMobile ? 10 : 70,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Width: ${screenWidth.toStringAsFixed(0)}px',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          */
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final hasAppBar = !isMobile;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: EdgeInsets.only(
        left: isMobile ? 24 : 48,
        right: isMobile ? 24 : 48,
        top: hasAppBar
            ? (isVerySmall ? 32 : (isMobile ? 80 : 80))
            : (isVerySmall ? 48 : (isMobile ? 80 : 120)),
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
                    Icons.admin_panel_settings,
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
                        'Welcome to Admin Dashboard',
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
                          'Monitor and manage your entire medical laboratory system from one centralized dashboard',
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
                    'Total Labs',
                    '${_dashboardData?['totalLabs'] ?? 0}',
                    Icons.business,
                    AppTheme.primaryBlue,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Pending Requests',
                    '${_dashboardData?['pendingRequests'] ?? 0}',
                    Icons.pending_actions,
                    AppTheme.accentOrange,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.accentOrange,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Expiring Soon',
                    '${_dashboardData?['expiringLabsCount'] ?? 0}',
                    Icons.schedule,
                    AppTheme.errorRed,
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

  Widget _buildActivitySection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final expiringLabs = _dashboardData?['expiringLabs'] as List? ?? [];

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
          if (expiringLabs.isEmpty && _dashboardData?['pendingRequests'] == 0)
            AnimatedCard(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All systems running smoothly',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No urgent actions required at this time',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
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
                              Text(
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
                    if (_dashboardData?['pendingRequests'] != null &&
                        _dashboardData!['pendingRequests'] > 0)
                      _buildActivityItem(
                        context,
                        'Pending Lab Owner Requests',
                        '${_dashboardData!['pendingRequests']} requests awaiting approval',
                        Icons.pending_actions,
                        AppTheme.accentOrange,
                      ),
                    ...expiringLabs
                        .take(3)
                        .map(
                          (lab) => _buildActivityItem(
                            context,
                            'Subscription Expiring Soon',
                            '${_formatLabOwnerName(lab['name'])} - expires ${_formatDate(lab['subscription_end'])}',
                            Icons.warning,
                            AppTheme.errorRed,
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

  Widget _buildQuickActionsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final actions = [
      {
        'title': 'Manage Labs',
        'subtitle': 'View and manage laboratory accounts',
        'icon': Icons.science,
        'color': AppTheme.primaryBlue,
        'onTap': () => _showLabOwnersDialog(context),
      },
      {
        'title': 'Review Applications',
        'subtitle': 'Process pending lab owner requests',
        'icon': Icons.pending_actions,
        'color': AppTheme.accentOrange,
        'onTap': () => _showPendingRequestsDialog(context),
      },
      {
        'title': 'Subscription Management',
        'subtitle': 'Monitor and manage subscriptions',
        'icon': Icons.payment,
        'color': AppTheme.successGreen,
        'onTap': () => _showSubscriptionsDialog(context),
      },
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 12 : (isMobile ? 20 : 80),
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Quick Actions' : 'Quick Actions & Management',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: isMobile ? 1 : (isVerySmall ? 1 : 2),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: actions.map((action) {
              return AnimatedCard(
                onTap: action['onTap'] as VoidCallback,
                child: Padding(
                  padding: EdgeInsets.all(isVerySmall ? 20 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (action['color'] as Color).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: action['color'] as Color,
                          size: isVerySmall ? 24 : 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        action['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmall ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['subtitle'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 12 : null,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 16),
                      ClipRect(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Access Now',
                                style: TextStyle(
                                  color: action['color'] as Color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isVerySmall ? 12 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              color: action['color'] as Color,
                              size: isVerySmall ? 14 : 16,
                            ),
                          ],
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

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
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

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = dateTime.difference(now).inDays;

      if (difference == 0) return 'today';
      if (difference == 1) return 'tomorrow';
      if (difference > 0) return 'in $difference days';
      return '${-difference} days ago';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatFullDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _extractRenewalPeriodFromMessage(String message) {
    // Extract renewal period from message like "Lab Name requests subscription renewal for X month(s)"
    final regex = RegExp(r'renewal for (\d+) month');
    final match = regex.firstMatch(message);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return 'N/A';
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
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

  List<dynamic> _filterLabOwners(List<dynamic> labs) {
    final query = _labOwnersSearchQuery.toLowerCase();
    if (query.isEmpty) return labs;

    return labs.where((owner) {
      final name = owner['name'];
      final displayName = name is Map
          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'.trim()
          : (name?.toString() ?? '');
      final labName = owner['lab_name']?.toString() ?? '';
      final email = owner['email']?.toString() ?? '';
      final phone = owner['phone_number']?.toString() ?? '';
      final status = owner['status']?.toString() ?? '';

      return displayName.toLowerCase().contains(query) ||
          labName.toLowerCase().contains(query) ||
          email.toLowerCase().contains(query) ||
          phone.toLowerCase().contains(query) ||
          status.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildPendingApprovalsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      key: ObjectKey(_refreshKey),
      future: ApiService.get(ApiConfig.adminPendingLabOwners),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        final pendingRequests = response is List ? response : [];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Approvals',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review and approve lab owner registration requests',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Pending Requests: ${pendingRequests.length}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 24),
              if (pendingRequests.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending approval requests',
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
                      itemCount: pendingRequests.length,
                      itemBuilder: (context, index) {
                        final owner = pendingRequests[index];
                        final name = owner['name'];
                        final displayName = name is Map
                            ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                  .trim()
                            : (name?.toString() ?? 'Unknown');
                        final initial = displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : 'L';

                        // Format address
                        final address = owner['address'];
                        final addressStr = address is Map
                            ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                  .trim()
                                  .replaceAll(RegExp(r',\s*,'), ',')
                                  .replaceAll(RegExp(r'^,\s*'), '')
                                  .replaceAll(RegExp(r',\s*$'), '')
                            : 'N/A';

                        // Format dates
                        final requestDate = owner['date_subscription'] != null
                            ? _formatFullDate(owner['date_subscription'])
                            : 'N/A';

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accentOrange,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(owner['lab_name'] ?? 'Lab'),
                            trailing: const Chip(
                              label: Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: AppTheme.accentOrange,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      Icons.person,
                                      'Lab Owner',
                                      displayName,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.science,
                                      'Lab Name',
                                      owner['lab_name'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.email,
                                      'Email',
                                      owner['email'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.phone,
                                      'Phone',
                                      owner['phone_number'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.location_on,
                                      'Address',
                                      addressStr,
                                    ),
                                    const Divider(height: 24),
                                    _buildDetailRow(
                                      Icons.calendar_today,
                                      'Request Date',
                                      requestDate,
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _approveLabOwner(
                                              owner['_id'],
                                              displayName,
                                            );
                                          },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.successGreen,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await _rejectLabOwner(
                                              owner['_id'],
                                              displayName,
                                            );
                                          },
                                          icon: const Icon(Icons.close),
                                          label: const Text('Reject'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorRed,
                                            side: const BorderSide(
                                              color: AppTheme.errorRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: Future.wait([
        ApiService.get(ApiConfig.adminExpiringSubscriptions),
        ApiService.get(ApiConfig.adminRenewalRequests),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final responses = snapshot.data;
        final expiringResponse = responses?[0] as Map<String, dynamic>?;
        final renewalResponse = responses?[1] as Map<String, dynamic>?;

        final labs = expiringResponse?['labs'] as List? ?? [];
        final expiringCount = expiringResponse?['count'] ?? 0;
        final renewalRequests = renewalResponse?['requests'] as List? ?? [];
        final renewalCount = renewalResponse?['count'] ?? 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription Management',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor expiring subscriptions and manage renewal requests',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              // Summary Cards - stack vertically on very small screens
              if (isVerySmall)
                Column(
                  children: [
                    _buildSummaryCard(
                      'Expiring Soon',
                      expiringCount.toString(),
                      Icons.warning,
                      AppTheme.accentOrange,
                      'Subscriptions expiring within 30 days',
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(
                      'Renewal Requests',
                      renewalCount.toString(),
                      Icons.refresh,
                      AppTheme.primaryBlue,
                      'Pending renewal requests from owners',
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Expiring Soon',
                        expiringCount.toString(),
                        Icons.warning,
                        AppTheme.accentOrange,
                        'Subscriptions expiring within 30 days',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryCard(
                        'Renewal Requests',
                        renewalCount.toString(),
                        Icons.refresh,
                        AppTheme.primaryBlue,
                        'Pending renewal requests from owners',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              // Content Tabs
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning),
                              const SizedBox(width: 8),
                              Text('Expiring ($expiringCount)'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.refresh),
                              const SizedBox(width: 8),
                              Text('Renewals ($renewalCount)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 600, // Fixed height for tab content
                      child: TabBarView(
                        children: [
                          // Expiring Subscriptions Tab
                          _buildExpiringSubscriptionsTab(
                            context,
                            labs,
                            expiringCount,
                            isMobile,
                            isVerySmall,
                          ),
                          // Renewal Requests Tab
                          _buildRenewalRequestsTab(
                            context,
                            renewalRequests,
                            renewalCount,
                            isMobile,
                            isVerySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabOwnersSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      key: ObjectKey(_refreshKey),
      future: ApiService.get(ApiConfig.adminLabOwners),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        final labs = response is List ? response : [];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laboratory Owners',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage and view all registered laboratory owners',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Laboratory Owners: ${labs.length}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (labs.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('lab_owners_search'),
                        initialValue: _labOwnersSearchQuery,
                        onChanged: (value) {
                          _searchDebounceTimer?.cancel();
                          _searchDebounceTimer = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              setState(() {
                                _labOwnersSearchQuery = value;
                              });
                            },
                          );
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search lab owners by name, lab, email, phone, or status...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                    ),
                    if (_labOwnersSearchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'Found: ${_filterLabOwners(labs).length}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              if (labs.isNotEmpty) const SizedBox(height: 24),
              if (labs.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No laboratory owners found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_filterLabOwners(labs).isEmpty)
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
                          'No lab owners match your search',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
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
                        itemCount: _filterLabOwners(labs).length,
                        itemBuilder: (context, index) {
                          final filteredLabs = _filterLabOwners(labs);
                          final owner = filteredLabs[index];
                          final name = owner['name'];
                          final displayName = name is Map
                              ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                    .trim()
                              : (name?.toString() ?? 'Unknown');
                          final initial = displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'L';

                          // Format address
                          final address = owner['address'];
                          final addressStr = address is Map
                              ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                    .trim()
                                    .replaceAll(RegExp(r',\s*,'), ',')
                                    .replaceAll(RegExp(r'^,\s*'), '')
                                    .replaceAll(RegExp(r',\s*$'), '')
                              : 'N/A';

                          // Format dates
                          final subscriptionStart =
                              owner['date_subscription'] != null
                              ? _formatFullDate(owner['date_subscription'])
                              : 'N/A';
                          final subscriptionEnd =
                              owner['subscription_end'] != null
                              ? _formatFullDate(owner['subscription_end'])
                              : 'N/A';

                          return AnimatedCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: owner['status'] == 'approved'
                                    ? AppTheme.successGreen
                                    : owner['status'] == 'pending'
                                    ? AppTheme.accentOrange
                                    : AppTheme.errorRed,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(owner['lab_name'] ?? 'Lab'),
                              trailing: Chip(
                                label: Text(
                                  owner['status'] ?? 'unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: owner['status'] == 'approved'
                                    ? AppTheme.successGreen
                                    : owner['status'] == 'pending'
                                    ? AppTheme.accentOrange
                                    : AppTheme.errorRed,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                        Icons.person,
                                        'Lab Owner',
                                        displayName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.science,
                                        'Lab Name',
                                        owner['lab_name'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.email,
                                        'Email',
                                        owner['email'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.phone,
                                        'Phone',
                                        owner['phone_number'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.location_on,
                                        'Address',
                                        addressStr,
                                      ),
                                      const Divider(height: 24),
                                      _buildDetailRow(
                                        Icons.calendar_today,
                                        'Subscription Start',
                                        subscriptionStart,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.event,
                                        'Subscription End',
                                        subscriptionEnd,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.check_circle,
                                        'Active Status',
                                        owner['is_active'] == true
                                            ? 'Active'
                                            : 'Inactive',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showPendingRequestsDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(ApiConfig.adminPendingLabOwners);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      // API already returns only pending requests
      final pendingRequests = response is List ? response : [];

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.pending_actions, color: AppTheme.accentOrange),
              const SizedBox(width: 12),
              Expanded(child: const Text('Pending Approval Requests')),
              const SizedBox(width: 12),
              Chip(
                label: Text(
                  '${pendingRequests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.accentOrange,
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: pendingRequests.isNotEmpty
                ? ListView.builder(
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      final owner = pendingRequests[index];
                      final name = owner['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      // Format address
                      final address = owner['address'];
                      final addressStr = address is Map
                          ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                .trim()
                                .replaceAll(RegExp(r',\s*,'), ',')
                                .replaceAll(RegExp(r'^,\s*'), '')
                                .replaceAll(RegExp(r',\s*$'), '')
                          : 'N/A';

                      // Format dates
                      final requestDate = owner['date_subscription'] != null
                          ? _formatFullDate(owner['date_subscription'])
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentOrange,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(owner['lab_name'] ?? 'Lab'),
                          trailing: const Chip(
                            label: Text(
                              'PENDING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: AppTheme.accentOrange,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    owner['lab_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.email,
                                    'Email',
                                    owner['email'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.phone,
                                    'Phone',
                                    owner['phone_number'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.location_on,
                                    'Address',
                                    addressStr,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.calendar_today,
                                    'Request Date',
                                    requestDate,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);
                                          await _approveLabOwner(
                                            owner['_id'],
                                            displayName,
                                          );
                                        },
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);
                                          await _rejectLabOwner(
                                            owner['_id'],
                                            displayName,
                                          );
                                        },
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.errorRed,
                                          side: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppTheme.successGreen,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No pending approval requests',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading pending requests: $e')),
          );
        }
      }
    }
  }

  void _showLabOwnersDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(ApiConfig.adminLabOwners);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Laboratory Owners'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: response is List && response.isNotEmpty
                ? ListView.builder(
                    itemCount: response.length,
                    itemBuilder: (context, index) {
                      final owner = response[index];
                      final name = owner['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      // Format address
                      final address = owner['address'];
                      final addressStr = address is Map
                          ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                .trim()
                                .replaceAll(RegExp(r',\s*,'), ',')
                                .replaceAll(RegExp(r'^,\s*'), '')
                                .replaceAll(RegExp(r',\s*$'), '')
                          : 'N/A';

                      // Format dates
                      final subscriptionStart =
                          owner['date_subscription'] != null
                          ? _formatFullDate(owner['date_subscription'])
                          : 'N/A';
                      final subscriptionEnd = owner['subscription_end'] != null
                          ? _formatFullDate(owner['subscription_end'])
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: owner['status'] == 'approved'
                                ? AppTheme.successGreen
                                : owner['status'] == 'pending'
                                ? AppTheme.accentOrange
                                : AppTheme.errorRed,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(owner['lab_name'] ?? 'Lab'),
                          trailing: Chip(
                            label: Text(
                              owner['status'] ?? 'unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: owner['status'] == 'approved'
                                ? AppTheme.successGreen
                                : owner['status'] == 'pending'
                                ? AppTheme.accentOrange
                                : AppTheme.errorRed,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    owner['lab_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.email,
                                    'Email',
                                    owner['email'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.phone,
                                    'Phone',
                                    owner['phone_number'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.location_on,
                                    'Address',
                                    addressStr,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.calendar_today,
                                    'Subscription Start',
                                    subscriptionStart,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.event,
                                    'Subscription End',
                                    subscriptionEnd,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.check_circle,
                                    'Active Status',
                                    owner['is_active'] == true
                                        ? 'Active'
                                        : 'Inactive',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No laboratory owners found'),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading owners: $e')));
        }
      }
    }
  }

  void _showSubscriptionsDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(
        ApiConfig.adminExpiringSubscriptions,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      final labs = response['labs'] as List? ?? [];
      final count = response['count'] ?? 0;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.accentOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Expiring Subscriptions',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Chip(
                label: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.accentOrange,
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: labs.isNotEmpty
                ? ListView.builder(
                    itemCount: labs.length,
                    itemBuilder: (context, index) {
                      final lab = labs[index];
                      final name = lab['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown Lab');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      final labName = lab['lab_name'] ?? 'N/A';
                      final email = lab['email'] ?? 'N/A';
                      final phone = lab['phone_number'] ?? 'N/A';

                      final subscriptionEnd = lab['subscription_end'] != null
                          ? _formatFullDate(lab['subscription_end'])
                          : 'N/A';

                      // Calculate days remaining
                      int daysRemaining = 0;
                      if (lab['subscription_end'] != null) {
                        try {
                          final endDate = DateTime.parse(
                            lab['subscription_end'].toString(),
                          );
                          daysRemaining = endDate
                              .difference(DateTime.now())
                              .inDays;
                        } catch (e) {
                          daysRemaining = 0;
                        }
                      }

                      final isUrgent = daysRemaining <= 7;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        color: isUrgent
                            ? AppTheme.errorRed.withValues(alpha: 0.05)
                            : null,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isUrgent
                                ? AppTheme.errorRed
                                : AppTheme.accentOrange,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(labName),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? AppTheme.errorRed
                                  : AppTheme.accentOrange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUrgent ? Icons.error : Icons.access_time,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  daysRemaining > 0
                                      ? '$daysRemaining days'
                                      : 'Expired',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    labName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.email, 'Email', email),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.phone, 'Phone', phone),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.event,
                                    'Subscription End Date',
                                    subscriptionEnd,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    isUrgent ? Icons.error : Icons.access_time,
                                    'Days Remaining',
                                    daysRemaining > 0
                                        ? '$daysRemaining days'
                                        : 'Expired',
                                  ),
                                  if (isUrgent) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorRed.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.errorRed.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning,
                                            color: AppTheme.errorRed,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              daysRemaining > 0
                                                  ? 'Urgent: Subscription expires in $daysRemaining days!'
                                                  : 'Critical: Subscription has expired!',
                                              style: const TextStyle(
                                                color: AppTheme.errorRed,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          _showContactDialog(
                                            context,
                                            lab['_id'],
                                            displayName,
                                            email,
                                          );
                                        },
                                        icon: const Icon(Icons.email),
                                        label: const Text('Contact'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.primaryBlue,
                                          side: const BorderSide(
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppTheme.successGreen,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No expiring subscriptions',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All subscriptions are current',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading subscriptions: $e')),
          );
        }
      }
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final titleFontSize = isSmallScreen ? 11.0 : 14.0;
    final valueFontSize = isSmallScreen ? 18.0 : 24.0;
    final subtitleFontSize = isSmallScreen ? 10.0 : 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use actual available width to determine layout
        final availableWidth = constraints.maxWidth;
        final isVeryNarrow = availableWidth < 120;
        final padding = availableWidth < 150
            ? 8.0
            : (isSmallScreen ? 12.0 : 20.0);
        final iconSize = isSmallScreen ? 18.0 : 24.0;
        final iconPadding = isSmallScreen ? 6.0 : 10.0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Hide icon when available space is too narrow
                    if (!isVeryNarrow) ...[
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: iconSize),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isVeryNarrow ? 9.0 : titleFontSize,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: isVeryNarrow ? 14.0 : valueFontSize,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isVeryNarrow ? 8.0 : subtitleFontSize,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiringSubscriptionsTab(
    BuildContext context,
    List labs,
    int count,
    bool isMobile,
    bool isVerySmall,
  ) {
    if (labs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppTheme.successGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'No expiring subscriptions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'All subscriptions are current',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: labs.length,
          itemBuilder: (context, index) {
            final lab = labs[index];
            final name = lab['name'];
            final displayName = name is Map
                ? '${name['first'] ?? ''} ${name['last'] ?? ''}'.trim()
                : (name?.toString() ?? 'Unknown Lab');
            final initial = displayName.isNotEmpty
                ? displayName.substring(0, 1).toUpperCase()
                : 'L';

            final labName = lab['lab_name'] ?? 'N/A';
            final email = lab['email'] ?? 'N/A';
            final phone = lab['phone_number'] ?? 'N/A';

            final subscriptionEnd = lab['subscription_end'] != null
                ? _formatFullDate(lab['subscription_end'])
                : 'N/A';

            // Calculate days remaining
            int daysRemaining = 0;
            if (lab['subscription_end'] != null) {
              try {
                final endDate = DateTime.parse(
                  lab['subscription_end'].toString(),
                );
                daysRemaining = endDate.difference(DateTime.now()).inDays;
              } catch (e) {
                daysRemaining = 0;
              }
            }

            final isUrgent = daysRemaining <= 7;

            return AnimatedCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isUrgent
                      ? AppTheme.errorRed.withValues(alpha: 0.05)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUrgent
                        ? AppTheme.errorRed.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: isUrgent
                        ? AppTheme.errorRed
                        : AppTheme.accentOrange,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(labName),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? AppTheme.errorRed
                          : AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUrgent ? Icons.error : Icons.access_time,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          daysRemaining > 0 ? '$daysRemaining days' : 'Expired',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.person,
                            'Lab Owner',
                            displayName,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.science, 'Lab Name', labName),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.email, 'Email', email),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.phone, 'Phone', phone),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.event,
                            'Subscription End Date',
                            subscriptionEnd,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            isUrgent ? Icons.error : Icons.access_time,
                            'Days Remaining',
                            daysRemaining > 0
                                ? '$daysRemaining days'
                                : 'Expired',
                          ),
                          if (isUrgent) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.errorRed.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    color: AppTheme.errorRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      daysRemaining > 0
                                          ? 'Urgent: Subscription expires in $daysRemaining days!'
                                          : 'Critical: Subscription has expired!',
                                      style: const TextStyle(
                                        color: AppTheme.errorRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showContactDialog(
                                  context,
                                  lab['_id'],
                                  displayName,
                                  email,
                                ),
                                icon: const Icon(Icons.email),
                                label: const Text('Contact'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(
                                    color: AppTheme.primaryBlue,
                                  ),
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
          },
        ),
      ),
    );
  }

  Widget _buildRenewalRequestsTab(
    BuildContext context,
    List renewalRequests,
    int count,
    bool isMobile,
    bool isVerySmall,
  ) {
    if (renewalRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No renewal requests',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Renewal requests from owners will appear here',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: renewalRequests.length,
          itemBuilder: (context, index) {
            final request = renewalRequests[index];
            final ownerName = request['owner_name'] ?? 'Unknown Owner';
            final labName = request['lab_name'] ?? 'Unknown Lab';
            final email = request['email'] ?? 'N/A';
            final phone = request['phone'] ?? 'N/A';
            final currentEndDate = request['current_subscription_end'] != null
                ? _formatFullDate(request['current_subscription_end'])
                : 'N/A';
            final requestedAt = request['requested_at'] != null
                ? _formatFullDate(request['requested_at'])
                : 'N/A';
            final renewalDetails =
                request['renewal_details'] as Map<String, dynamic>? ?? {};
            final renewalPeriodFromMetadata =
                renewalDetails['renewal_period_months'];
            final renewalPeriod = renewalPeriodFromMetadata != null
                ? renewalPeriodFromMetadata.toString()
                : _extractRenewalPeriodFromMessage(request['message'] ?? '');
            final message = request['message'] ?? 'No message provided';

            final initial = ownerName.isNotEmpty
                ? ownerName.substring(0, 1).toUpperCase()
                : 'O';

            return AnimatedCard(
              margin: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    ownerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(labName),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.person,
                            'Owner Name',
                            ownerName,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.science, 'Lab Name', labName),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.email, 'Email', email),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.phone, 'Phone', phone),
                          const Divider(height: 24),
                          _buildDetailRow(
                            Icons.event,
                            'Current Subscription End',
                            currentEndDate,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.schedule,
                            'Requested Renewal Period',
                            '$renewalPeriod months',
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.access_time,
                            'Requested At',
                            requestedAt,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Message from Owner:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _approveRenewalRequest(
                                  context,
                                  request['_id'],
                                  ownerName,
                                  renewalPeriod,
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _denyRenewalRequest(
                                  context,
                                  request['_id'],
                                  ownerName,
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Deny'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorRed,
                                  side: const BorderSide(
                                    color: AppTheme.errorRed,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showContactDialog(
                                    context,
                                    request['owner_id'],
                                    ownerName,
                                    email,
                                  ),
                                  icon: const Icon(Icons.email),
                                  label: const Text('Contact Owner'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryBlue,
                                    side: const BorderSide(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
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
          },
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    if (_notificationsLoading && _notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final notifications = _filteredNotifications;
    final unreadCount = _notifications
        .where((n) => !(n['is_read'] ?? false))
        .length;
    final total = notifications.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View and manage system notifications and messages',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
              fontSize: isVerySmall ? 14 : 16,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  _notificationFilter == 'unread'
                      ? 'Unread Notifications: $total'
                      : 'Total Notifications: $total',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: Colors.white, size: 6),
                      const SizedBox(width: 4),
                      Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Filter buttons
          Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _notificationFilter == 'all',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _notificationFilter = 'all');
                  }
                },
                backgroundColor: _notificationFilter == 'all'
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : null,
                selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                  'Unread (${_notifications.where((n) => !(n['is_read'] ?? false)).length})',
                ),
                selected: _notificationFilter == 'unread',
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _notificationFilter = 'unread');
                  }
                },
                backgroundColor: _notificationFilter == 'unread'
                    ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                    : null,
                selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (notifications.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _notificationFilter == 'unread'
                        ? 'No unread notifications'
                        : 'No notifications',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
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
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification['is_read'] ?? false;
                    final type = notification['type'] ?? 'system';
                    final title = notification['title'] ?? 'Notification';
                    final message = notification['message'] ?? '';
                    final createdAt = notification['createdAt'];
                    final from = notification['from']; // Lab owner info

                    IconData icon;
                    Color iconColor;
                    switch (type) {
                      case 'alert':
                        icon = Icons.warning;
                        iconColor = AppTheme.errorRed;
                        break;
                      case 'system':
                        icon = Icons.info;
                        iconColor = AppTheme.primaryBlue;
                        break;
                      case 'subscription':
                        icon = Icons.payment;
                        iconColor = AppTheme.accentOrange;
                        break;
                      case 'message':
                        icon = Icons.mail;
                        iconColor = AppTheme.secondaryTeal;
                        break;
                      default:
                        icon = Icons.notifications;
                        iconColor = AppTheme.secondaryTeal;
                    }

                    return AnimatedCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead
                              ? null
                              : AppTheme.primaryBlue.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: iconColor, size: 24),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (from != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryTeal,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'From Lab Owner',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNotificationMessage(message),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (createdAt != null)
                                    Text(
                                      'Received: ${_formatDate(createdAt)}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (message.length > 100)
                                        Text(
                                          message,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          if (!isRead)
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                _markNotificationAsRead(
                                                  notification['_id']
                                                      .toString(),
                                                );
                                              },
                                              icon: const Icon(Icons.check),
                                              label: const Text('Mark as Read'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.successGreen,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          if (!isRead && from != null)
                                            const SizedBox(width: 12),
                                          if (from != null)
                                            OutlinedButton.icon(
                                              onPressed: () {
                                                _showReplyDialog(
                                                  context,
                                                  notification['_id']
                                                      .toString(),
                                                  from['email']?.toString() ??
                                                      '',
                                                  from['name']?.toString() ??
                                                      'Lab Owner',
                                                );
                                              },
                                              icon: const Icon(Icons.reply),
                                              label: const Text('Reply'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.primaryBlue,
                                                side: const BorderSide(
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
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
            ),
        ],
      ),
    );
  }

  void _approveRenewalRequest(
    BuildContext context,
    String requestId,
    String ownerName,
    dynamic renewalPeriod,
  ) async {
    final feeController = TextEditingController();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Approve Renewal Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Approve renewal request for $ownerName'),
              const SizedBox(height: 8),
              Text(
                'Requested period: $renewalPeriod months',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feeController,
                decoration: const InputDecoration(
                  labelText: 'Subscription Fee (Optional)',
                  hintText: 'Leave empty to keep current fee',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);

                      try {
                        final fee = feeController.text.trim().isEmpty
                            ? null
                            : double.tryParse(feeController.text);

                        await ApiService.put(
                          ApiConfig.adminApproveRenewalRequest(requestId),
                          {
                            'renewal_period_months':
                                int.tryParse(renewalPeriod.toString()) ?? 12,
                            if (fee != null) 'renewal_fee': fee,
                          },
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext, true);
                          _loadDashboardData(); // Refresh dashboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Renewal request approved for $ownerName',
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Failed to approve renewal: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    // Dispose controller after dialog animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      feeController.dispose();
    });
  }

  void _denyRenewalRequest(
    BuildContext context,
    String requestId,
    String ownerName,
  ) async {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Deny Renewal Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deny renewal request for $ownerName'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Denial',
                  hintText: 'Please provide a reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please provide a reason for denial'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        await ApiService.put(
                          ApiConfig.adminDenyRenewalRequest(requestId),
                          {'reason': reasonController.text.trim()},
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext, true);
                          _loadDashboardData(); // Refresh dashboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '❌ Renewal request denied for $ownerName',
                              ),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Failed to deny renewal: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.close),
              label: const Text('Deny'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    // Dispose controller after dialog animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
    });
  }

  String _formatNotificationDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      }
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _approveLabOwner(String ownerId, String displayName) async {
    try {
      final result = await ApiService.approveLabOwner(ownerId);

      if (result['success'] == true || result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully approved $displayName'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        // Refresh the dashboard data to update statistics
        await _refreshDashboardData();
      } else {
        throw Exception(result['message'] ?? 'Approval failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to approve $displayName: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _rejectLabOwner(String ownerId, String displayName) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.errorRed),
            const SizedBox(width: 12),
            Text('Reject $displayName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final apiResult = await ApiService.rejectLabOwner(
          ownerId,
          rejectionReason: result,
        );

        if (apiResult['success'] == true || apiResult['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Successfully rejected $displayName'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          // Refresh the dashboard data to update statistics
          await _refreshDashboardData();
        } else {
          throw Exception(apiResult['message'] ?? 'Rejection failed');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reject $displayName: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildFeedbackSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminFeedback),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data as Map<String, dynamic>?;
        final feedbackList = response?['feedback'] as List? ?? [];
        final total = response?['total'] ?? 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Feedback',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage feedback from patients, staff, and doctors',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Feedback: $total',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (feedbackList.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.feedback_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback yet',
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
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        final userId = feedback['user_id'];
                        final userRole = feedback['user_role'] ?? 'User';
                        final userName = userId != null
                            ? '${userId['full_name']?['first'] ?? ''} ${userId['full_name']?['last'] ?? ''}'
                                  .trim()
                            : 'Anonymous';
                        final userEmail = userId?['email'] ?? 'N/A';
                        final rating = feedback['rating'] ?? 0;
                        final message = feedback['message'] ?? '';
                        final createdAt = feedback['createdAt'];
                        final isAnonymous = feedback['is_anonymous'] ?? false;

                        // Format role for display
                        String displayRole = userRole;
                        if (userRole == 'Owner') displayRole = 'Lab Owner';

                        // Format user display name with role
                        final userDisplayName = isAnonymous
                            ? 'Anonymous User'
                            : '$userName ($displayRole)';

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                isAnonymous
                                    ? '?'
                                    : userName.isNotEmpty
                                    ? userName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userDisplayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              _formatNotificationDate(createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isAnonymous) ...[
                                      _buildDetailRow(
                                        Icons.person,
                                        'Name',
                                        userName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.badge,
                                        'Role',
                                        displayRole,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.email,
                                        'Email',
                                        userEmail,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildDetailRow(
                                      Icons.calendar_today,
                                      'Submitted',
                                      _formatFullDate(createdAt),
                                    ),
                                    const Divider(height: 24),
                                    Text(
                                      'Feedback Message:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showContactDialog(
    BuildContext context,
    String ownerId,
    String ownerName,
    String ownerEmail,
  ) {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mail, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text('Contact $ownerName')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $ownerEmail',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Enter subject...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              subjectController.dispose();
              messageController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (subjectController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both subject and message'),
                  ),
                );
                return;
              }

              try {
                await ApiService.sendNotificationToOwner(
                  ownerId: ownerId,
                  title: subjectController.text.trim(),
                  message: messageController.text.trim(),
                  type: 'message',
                );

                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Message sent to $ownerName'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error sending message: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              } finally {
                subjectController.dispose();
                messageController.dispose();
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsDialogContent(Map<String, dynamic> report) {
    final data = report['data'] as Map<String, dynamic>?;
    final platform = data?['platform'] as Map<String, dynamic>?;

    if (platform == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with report info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.secondaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Type: ${report['type']?.toString().toUpperCase() ?? 'Unknown'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Period: ${report['period']?.toString().toUpperCase() ?? 'Unknown'}',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generated: ${platform['generatedAt'] != null ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(platform['generatedAt'])) : 'Unknown'}',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Platform Overview Cards
          const Text(
            'Platform Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildMetricCard(
                'Total Labs',
                platform['totalLabs']?.toString() ?? '0',
                Icons.science,
                AppTheme.primaryBlue,
              ),
              _buildMetricCard(
                'Active Labs',
                platform['activeLabs']?.toString() ?? '0',
                Icons.check_circle,
                AppTheme.successGreen,
              ),
              _buildMetricCard(
                'Pending Labs',
                platform['pendingLabs']?.toString() ?? '0',
                Icons.pending,
                AppTheme.accentOrange,
              ),
              _buildMetricCard(
                'Total Revenue',
                '\$${platform['totalRevenue']?.toString() ?? '0'}',
                Icons.attach_money,
                AppTheme.secondaryTeal,
              ),
              _buildMetricCard(
                'Monthly Revenue',
                '\$${platform['monthlyRevenue']?.toString() ?? '0'}',
                Icons.trending_up,
                AppTheme.successGreen,
              ),
              _buildMetricCard(
                'New Registrations',
                platform['newRegistrations']?.toString() ?? '0',
                Icons.person_add,
                AppTheme.primaryBlue,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Additional metrics
          const Text(
            'Additional Metrics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Patients',
                  platform['totalPatients']?.toString() ?? '0',
                  Icons.people,
                  AppTheme.accentOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Tests',
                  platform['totalTests']?.toString() ?? '0',
                  Icons.biotech,
                  AppTheme.secondaryTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Total Orders',
                  platform['totalOrders']?.toString() ?? '0',
                  Icons.assignment,
                  AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(
    BuildContext context,
    String notificationId,
    String toEmail,
    String toName,
  ) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.reply, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text('Reply to $toName')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $toEmail',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Type your reply here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              replyController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }

              try {
                // Send notification reply to the lab owner (with WhatsApp)
                final result = await AdminService.replyToOwnerNotification(
                  notificationId,
                  replyController.text.trim(),
                );

                if (result['success']) {
                  Navigator.pop(dialogContext);
                  if (context.mounted) {
                    final whatsappSent =
                        result['data']['whatsappSent'] ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          whatsappSent
                              ? '✅ Reply sent via WhatsApp and notification'
                              : '✅ Reply notification sent (WhatsApp failed)',
                        ),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                } else {
                  throw Exception(result['message']);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending reply: $e')),
                  );
                }
              } finally {
                replyController.dispose();
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _notificationService.removeNotificationCallback();
    // Cancel all notification removal timers
    for (final timer in _notificationRemovalTimers.values) {
      timer.cancel();
    }
    _notificationRemovalTimers.clear();
    super.dispose();
  }
}
