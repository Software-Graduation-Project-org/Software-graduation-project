import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../providers/doctor_auth_provider.dart';
import '../../services/doctor_api_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart' as notification_service;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../widgets/system_feedback_form.dart';
import '../../utils/responsive_utils.dart' as app_responsive;
import 'doctor_profile_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;
  final TextEditingController _searchController = TextEditingController();
  final notification_service.NotificationService _notificationService =
      notification_service.NotificationService();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _checkFeedbackStatus();

    // Register for notification callbacks to refresh data when test results are completed
    _notificationService.setNotificationCallback(_onNotificationReceived);
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final response = await DoctorApiService.getMyFeedback();
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

  // Handle notification callbacks to refresh data
  void _onNotificationReceived(String type, Map<String, dynamic> data) {
    // Refresh dashboard data when test results are available
    if (type == 'test_result' || type == 'result_ready') {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    try {
      final ordersResponse =
          await DoctorApiService.getPatientOrdersWithResults();

      if (mounted) {
        setState(() {
          _orders = ordersResponse['orders'] ?? [];
          _filteredOrders = _orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _orders = [];
          _filteredOrders = [];
          _isLoading = false;
        });
      }
    }
  }

  void _filterOrders(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((order) {
          final patientName = (order['patient_name'] ?? '').toLowerCase();
          final searchLower = query.toLowerCase();
          return patientName.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<DoctorAuthProvider>(context);

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

    return Scaffold(
      appBar: AppBar(
        title: AppAnimations.fadeIn(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              app_responsive.ResponsiveText(
                'Patient Reports',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              app_responsive.ResponsiveText(
                'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Doctor'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppAnimations.bounce(
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _showNotificationsDialog,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DoctorProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _isLoading
          ? AppAnimations.pulse(
              const Center(child: CircularProgressIndicator()),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: AppAnimations.fadeIn(_buildPatientsList()),
            ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await DoctorApiService.provideFeedback(
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

  Widget _buildPatientsList() {
    return AppAnimations.pageDepthTransition(
      AnimatedListView(
        padding: app_responsive.ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 16,
          vertical: 16,
        ),
        children: [
          if (_showFeedbackReminder) _buildFeedbackReminderBanner(),
          if (_showFeedbackReminder)
            SizedBox(
              height: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                context,
                16,
              ),
            ),

          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterOrders,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterOrders('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                      context,
                      12,
                    ),
                  ),
                  child: app_responsive.ResponsiveText(
                    'Found: ${_filteredOrders.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: app_responsive.ResponsiveUtils.getResponsiveSpacing(
              context,
              16,
            ),
          ),

          // Order Cards
          if (_filteredOrders.isEmpty && !_isLoading)
            Center(
              child: Column(
                children: [
                  SizedBox(
                    height: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                      context,
                      40,
                    ),
                  ),
                  Icon(
                    Icons.inbox_outlined,
                    size: app_responsive.ResponsiveUtils.getResponsiveIconSize(
                      context,
                      64,
                    ),
                    color: Colors.grey[400],
                  ),
                  SizedBox(
                    height: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                      context,
                      16,
                    ),
                  ),
                  app_responsive.ResponsiveText(
                    _searchController.text.isNotEmpty
                        ? 'No reports found'
                        : 'No patient reports yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          ..._filteredOrders.map((order) {
            return AppAnimations.waveIn(
              _buildOrderCard(order),
              _filteredOrders.indexOf(order),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final completedTests = order['completed_tests'] ?? 0;
    final totalTests = order['total_tests'] ?? 0;
    final hasResults = order['has_results'] ?? false;

    // Calculate overall status
    String overallStatus;
    if (completedTests == totalTests) {
      overallStatus = 'completed';
    } else if (order['in_progress_tests'] > 0) {
      overallStatus = 'in_progress';
    } else {
      overallStatus = 'pending';
    }

    Color statusColor;
    IconData statusIcon;
    switch (overallStatus) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: hasResults
            ? () {
                context.go(
                  '/doctor-dashboard/patient-report/${order['order_id']}',
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['patient_name'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${order['patient_identity'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          overallStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      'Order Date',
                      order['order_date']?.substring(0, 10) ?? 'N/A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                Icons.local_hospital,
                'Lab',
                order['lab_name'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$completedTests / $totalTests',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tests Completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: hasResults
                          ? () {
                              context.go(
                                '/doctor-dashboard/patient-report/${order['order_id']}',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasResults
                            ? AppTheme.primaryBlue
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
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
                    'Help us improve by sharing your feedback about the system',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showFeedbackDialog(),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('Provide Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
                  child: const Text(
                    'Remind me later',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() async {
    try {
      final response = await DoctorApiService.getNotifications();
      final notifications = response['notifications'] as List? ?? [];
      final total = response['count'] ?? notifications.length;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.notifications, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text('Notifications ($total)'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: notifications.isNotEmpty
                ? ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification['is_read'] ?? false;
                      IconData icon;

                      switch (notification['type']) {
                        case 'info':
                          icon = Icons.info;
                          break;
                        case 'success':
                          icon = Icons.check_circle;
                          break;
                        default:
                          icon = Icons.notifications;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            icon,
                            color: isRead ? Colors.grey : AppTheme.primaryBlue,
                          ),
                          title: SelectableText(
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
                              SelectableText(
                                _formatNotificationMessage(
                                  notification['message'] ?? '',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notification['created_at'] != null
                                    ? _formatDate(notification['created_at'])
                                    : '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: !isRead
                              ? IconButton(
                                  icon: const Icon(Icons.mark_email_read),
                                  onPressed: () async {
                                    try {
                                      await ApiService.put(
                                        '${ApiConfig.doctorNotifications}/${notification['_id']}/read',
                                        {},
                                      );
                                      setState(() {
                                        notifications[index]['is_read'] = true;
                                      });
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to mark as read: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                )
                              : null,
                          onTap: !isRead
                              ? () async {
                                  try {
                                    await ApiService.put(
                                      '${ApiConfig.doctorNotifications}/${notification['_id']}/read',
                                      {},
                                    );
                                    setState(() {
                                      notifications[index]['is_read'] = true;
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to mark as read: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notifications found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<DoctorAuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout();
              // Small delay to ensure logout is complete before navigation
              await Future.delayed(const Duration(milliseconds: 50));
              if (context.mounted) context.go('/');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
