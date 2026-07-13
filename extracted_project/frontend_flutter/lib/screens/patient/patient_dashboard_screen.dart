import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../services/notification_service.dart' as notification_service;
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/system_feedback_form.dart';
import 'patient_profile_screen.dart';
import 'patient_order_report_screen.dart';
import '../../utils/responsive_utils.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;
  List<dynamic> _notifications = [];
  int _unreadNotificationsCount = 0;
  final notification_service.NotificationService _notificationService =
      notification_service.NotificationService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _checkFeedbackStatus();
    // Don't load notifications here - wait for authentication check

    // Register for notification callbacks to refresh data when test results are completed
    _notificationService.setNotificationCallback(_onNotificationReceived);

    // Check for pending notifications that might need navigation
    _notificationService.checkPendingNotifications();

    // Set up periodic refresh every 30 seconds as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationService.removeNotificationCallback();
    super.dispose();
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

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await PatientApiService.getMyFeedback();
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

  Future<void> _refreshData() async {
    final authProvider = Provider.of<PatientAuthProvider>(
      context,
      listen: false,
    );
    if (authProvider.isAuthenticated) {
      await Future.wait([_loadOrders(), _loadNotifications()]);
    } else {
      await _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final ordersResponse = await PatientApiService.getOrdersWithResults();

      if (mounted) {
        final ordersList = ordersResponse['orders'];
        setState(() {
          _orders = (ordersList is List) ? ordersList : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      // Try fallback to old endpoint if new one doesn't exist yet
      try {
        final fallbackResponse = await PatientApiService.getMyOrders();
        if (mounted) {
          final ordersList = fallbackResponse['orders'];
          setState(() {
            _orders = (ordersList is List) ? ordersList : [];
            _isLoading = false;
          });
        }
      } catch (fallbackError) {
        if (mounted) {
          setState(() {
            _orders = [];
            _isLoading = false;
          });

          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load orders. Please try again later.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadOrders,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    try {
      final notificationsResponse = await PatientApiService.getNotifications();

      if (mounted) {
        final notificationsList = notificationsResponse['notifications'];
        setState(() {
          _notifications = (notificationsList is List) ? notificationsList : [];
          _unreadNotificationsCount = _notifications
              .where((n) => !(n['is_read'] ?? false))
              .length;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      // Don't show error for notifications, just set empty list
      if (mounted) {
        setState(() {
          _notifications = [];
          _unreadNotificationsCount = 0;
        });
      }
    }
  }

  // Handle real-time notifications to refresh data
  void _onNotificationReceived(String type, Map<String, dynamic> data) {
    final authProvider = Provider.of<PatientAuthProvider>(
      context,
      listen: false,
    );
    if (!authProvider.isAuthenticated) return;

    debugPrint(
      '🔔 Patient dashboard received notification: $type, data: $data',
    );

    // Refresh data based on notification type
    switch (type) {
      case 'test_result':
        // Refresh orders and notifications when test results are completed
        _refreshData();
        break;
      case 'order_created':
        // Refresh orders when new orders are created
        _loadOrders();
        break;
      case 'order_completed':
        // Refresh orders and notifications when orders are completed
        _refreshData();
        break;
      default:
        // For any other notification type, refresh notifications
        _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<PatientAuthProvider>(context);

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

    // Check for pending navigation from notification click
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pendingRoute =
          await notification_service.NotificationService.getPendingNavigation();
      if (pendingRoute != null && mounted) {
        debugPrint(
          '📍 Patient Dashboard: Found pending navigation: $pendingRoute',
        );
        context.go(pendingRoute);
      }
    });

    // Load notifications once authenticated
    if (_notifications.isEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNotifications();
      });
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                'Patient Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              ResponsiveText(
                'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Patient'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            AppAnimations.bounce(
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: _showNotificationsDialog,
                  ),
                  if (_unreadNotificationsCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _unreadNotificationsCount > 99
                              ? '99+'
                              : _unreadNotificationsCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PatientProfileScreen(),
                  ),
                );
              },
            ),
            AppAnimations.scaleIn(
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authProvider.logout();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (mounted) context.go('/');
                },
              ),
              delay: const Duration(milliseconds: 200),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveText(
              'Patient Dashboard',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            ResponsiveText(
              'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Patient'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          AppAnimations.bounce(
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 99
                            ? '99+'
                            : _unreadNotificationsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientProfileScreen(),
                ),
              );
            },
          ),
          AppAnimations.scaleIn(
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authProvider.logout();
                await Future.delayed(const Duration(milliseconds: 50));
                if (mounted) context.go('/');
              },
            ),
            delay: const Duration(milliseconds: 200),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _orders.isEmpty ? _buildEmptyState() : _buildOrdersList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppAnimations.pageDepthTransition(
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAnimations.floating(
              AppAnimations.morphIn(
                Icon(
                  Icons.science_outlined,
                  size: 80,
                  color: AppTheme.textLight,
                ),
                delay: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 16),
            AppAnimations.blurFadeIn(
              Text(
                'No orders yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.textLight),
              ),
              delay: const Duration(milliseconds: 400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return AppAnimations.slideInFromBottom(
              _buildOrderCard(order),
              delay: Duration(milliseconds: index * 100),
            );
          },
        ),
        if (_showFeedbackReminder)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppAnimations.bounce(
              FloatingActionButton(
                onPressed: _showFeedbackDialog,
                backgroundColor: AppTheme.primaryBlue,
                child: const Icon(Icons.feedback, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadNotificationsCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _unreadNotificationsCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _notifications.isEmpty
              ? const Center(child: Text('No notifications available.'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final isRead = notification['is_read'] ?? true;
                    final createdAt = DateTime.parse(notification['createdAt']);
                    final timeAgo = _getTimeAgo(createdAt);

                    return ListTile(
                      leading: Icon(
                        _getNotificationIcon(notification['type']),
                        color: isRead ? Colors.grey : AppTheme.primaryBlue,
                      ),
                      title: Text(
                        notification['title'] ?? 'Notification',
                        style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatNotificationMessage(
                              notification['message'] ?? '',
                            ),
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _markNotificationAsRead(notification['_id']),
                      trailing: !isRead
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllNotificationsAsRead,
              child: const Text('Mark All Read'),
            ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'test_result':
        return Icons.science;
      case 'invoice':
        return Icons.receipt;
      case 'feedback':
        return Icons.feedback;
      default:
        return Icons.notifications;
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await PatientApiService.markNotificationAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['_id'] == notificationId,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _unreadNotificationsCount = _notifications
              .where((n) => !(n['is_read'] ?? true))
              .length;
        }
      });
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark notification as read')),
      );
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      // Mark each notification as read individually
      for (var notification in _notifications.where(
        (n) => !(n['is_read'] ?? true),
      )) {
        await PatientApiService.markNotificationAsRead(notification['_id']);
      }
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
        _unreadNotificationsCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all notifications as read')),
      );
    }
  }

  Widget _buildOrderCard(dynamic order) {
    final orderDate = DateTime.parse(order['order_date']);
    final status = order['status'] ?? 'unknown';
    final testCount = order['test_count'] ?? 0;
    final labName = order['owner_id']?['lab_name'] ?? 'Medical Lab';

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
            if (order['order_details'] != null &&
                order['order_details'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tests Ordered:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (order['order_details'] as List).take(3).map((
                  detail,
                ) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail['test_name'] ?? 'Unknown Test',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if ((order['order_details'] as List).length > 3)
                Text(
                  '+${(order['order_details'] as List).length - 3} more tests',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (order['has_results'] == true)
                        ? () => _showOrderResults(order)
                        : null,
                    icon: const Icon(Icons.science, size: 18),
                    label: Text(
                      (order['has_results'] == true)
                          ? 'View Results'
                          : 'No Results Yet',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
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
                    onPressed: () => _showOrderBill(order),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Bill'),
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

  void _showOrderResults(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PatientOrderReportScreen(orderId: order['order_id']),
      ),
    );
  }

  void _showOrderBill(dynamic order) async {
    // Navigate to bill details screen
    GoRouter.of(
      context,
    ).push('/patient-dashboard/bill-details/${order['order_id']}');
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await PatientApiService.provideFeedback(
              targetType: feedbackData['target_type'],
              targetId: feedbackData['target_id'],
              rating: feedbackData['rating'],
              message: feedbackData['message'],
              isAnonymous: feedbackData['is_anonymous'],
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: AppTheme.successGreen,
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
}
