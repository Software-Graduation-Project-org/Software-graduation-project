// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../config/theme.dart';
import '../../widgets/common/navbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Map<String, Timer> _notificationRemovalTimers = {}; // Track removal timers
  String? _error;
  String _selectedFilter = 'all';
  String _readFilter = 'all'; // 'all' or 'unread'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    // Cancel all notification removal timers
    for (final timer in _notificationRemovalTimers.values) {
      timer.cancel();
    }
    _notificationRemovalTimers.clear();
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

  Future<void> _loadNotifications() async {
    debugPrint('🔔 FRONTEND DEBUG: Loading notifications...');
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);
      debugPrint(
        '🔔 FRONTEND DEBUG: Auth token set for notifications API call',
      );

      final response = await ApiService.get(ApiConfig.ownerNotifications);
      debugPrint('🔔 FRONTEND DEBUG: Notifications API response: $response');

      if (mounted) {
        if (response is Map<String, dynamic> && response['success'] == true) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(
              response['data'] ?? [],
            );
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _error = response is Map<String, dynamic>
                ? (response['message'] ?? 'Failed to load notifications')
                : 'Failed to load notifications';
            _isLoading = false;
          });
        }
      }

      debugPrint(
        '🔔 FRONTEND DEBUG: Loaded ${_notifications.length} notifications',
      );
    } catch (e) {
      debugPrint('🔔 FRONTEND DEBUG: Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    debugPrint(
      '🔔 FRONTEND DEBUG: Marking notification as read: $notificationId',
    );
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      // First make the API call
      await ApiService.put(
        '${ApiConfig.ownerNotifications}/$notificationId/read',
        {},
      );

      debugPrint('🔔 FRONTEND DEBUG: Successfully marked notification as read');

      // Immediately remove from local list to prevent reappearance
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n['_id'] == notificationId);
        });
      }

      // Cancel any existing timer for this notification
      _notificationRemovalTimers.remove(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to mark as read: $e')));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      // Mark all unread notifications as read
      final unreadNotifications = _notifications
          .where((n) => !(n['is_read'] ?? false))
          .toList();

      for (final notification in unreadNotifications) {
        await ApiService.put(
          '${ApiConfig.ownerNotifications}/${notification['_id']}/read',
          {},
        );
      }

      // Immediately remove all unread notifications from local list
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => !(n['is_read'] ?? false));
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _sendNotification() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _SendNotificationDialog(),
    );

    if (result != null) {
      await _loadNotifications();
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    List<Map<String, dynamic>> filtered = _notifications;

    // Filter by read status
    if (_readFilter == 'unread') {
      filtered = filtered.where((notification) {
        final isRead = notification['is_read'] ?? false;
        return !isRead;
      }).toList();
    }

    // Filter by type
    if (_selectedFilter != 'all') {
      filtered = filtered
          .where((notification) => notification['type'] == _selectedFilter)
          .toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) {
      final dateA = DateTime.parse(
        a['createdAt'] ?? a['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      final dateB = DateTime.parse(
        b['createdAt'] ?? b['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  int get _unreadCount =>
      _notifications.where((n) => !(n['is_read'] ?? false)).length;

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'subscription':
        return Colors.blue;
      case 'system':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'test_result':
        return Colors.purple;
      case 'request':
        return Colors.red;
      // case 'payment':
      //   return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'subscription':
        return Icons.subscriptions;
      case 'system':
        return Icons.system_update;
      case 'maintenance':
        return Icons.build;
      case 'test_result':
        return Icons.science;
      case 'request':
        return Icons.request_page;
      // case 'payment':
      //   return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Notifications'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              actions: [
                if (_unreadCount > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.done_all),
                    onPressed: _markAllAsRead,
                    tooltip: 'Mark all as read',
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendNotification,
                  tooltip: 'Send notification',
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!isMobile) ...[
            const AppNavBar(),
            Container(
              width: double.infinity,
              color: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stay updated with system notifications and communications',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: Column(
                  children: [
                    // Filters and Actions Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Types'),
                              ),
                              DropdownMenuItem(
                                value: 'subscription',
                                child: Text('Subscription'),
                              ),
                              DropdownMenuItem(
                                value: 'system',
                                child: Text('System'),
                              ),
                              DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance'),
                              ),
                              DropdownMenuItem(
                                value: 'test_result',
                                child: Text('Test Results'),
                              ),
                              DropdownMenuItem(
                                value: 'request',
                                child: Text('Requests'),
                              ),
                              // DropdownMenuItem(
                              //   value: 'payment',
                              //   child: Text('Payment'),
                              // ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedFilter = value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Read filter chips
                        FilterChip(
                          label: const Text('All'),
                          selected: _readFilter == 'all',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _readFilter = 'all');
                            }
                          },
                          backgroundColor: _readFilter == 'all'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : null,
                          selectedColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(
                            'Unread (${_notifications.where((n) => !(n['is_read'] ?? false)).length})',
                          ),
                          selected: _readFilter == 'unread',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _readFilter = 'unread');
                            }
                          },
                          backgroundColor: _readFilter == 'unread'
                              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                              : null,
                          selectedColor: AppTheme.primaryBlue.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppTheme.primaryBlue,
                        ),
                        if (!isMobile && _unreadCount > 0) ...[
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _markAllAsRead,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Mark All Read'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                        if (!isMobile) ...[
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _sendNotification,
                            icon: const Icon(Icons.send),
                            label: const Text('Send Notification'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats Cards
                    _buildStatsCards(isMobile),
                    const SizedBox(height: 24),

                    // Notifications List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadNotifications,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredNotifications.isEmpty
                          ? Center(
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
                                    (_selectedFilter == 'all' &&
                                            _readFilter == 'all')
                                        ? 'No notifications found'
                                        : (_readFilter == 'unread' &&
                                              _selectedFilter == 'all')
                                        ? 'No unread notifications'
                                        : 'No notifications match your filters',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            )
                          : _buildNotificationsList(isMobile),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final totalNotifications = _notifications.length;
    final unreadNotifications = _unreadCount;
    final readNotifications = totalNotifications - unreadNotifications;

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total',
          totalNotifications.toString(),
          Icons.notifications,
          AppTheme.primaryBlue,
        ),
        _buildStatCard(
          'Unread',
          unreadNotifications.toString(),
          Icons.notifications_active,
          Colors.red,
        ),
        _buildStatCard(
          'Read',
          readNotifications.toString(),
          Icons.notifications_off,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isMobile) {
    return ListView.builder(
      itemCount: _filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = _filteredNotifications[index];
        final isRead = notification['is_read'] ?? false;
        final type = notification['type'] ?? 'system';

        return AnimatedCard(
          onTap: () => _showNotificationDetails(notification),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRead
                  ? Colors.white
                  : Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRead
                    ? Colors.grey.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.3),
                width: isRead ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIcon(type),
                    color: _getNotificationColor(type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'No Title',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isRead
                                        ? Colors.black
                                        : Colors.blue[900],
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatNotificationMessage(
                          notification['message'] ?? 'No message',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _formatDate(
                              notification['createdAt'] ??
                                  notification['timestamp'],
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(
                                type,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: TextStyle(
                                color: _getNotificationColor(type),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!isRead) ...[
                            TextButton(
                              onPressed: () => _markAsRead(notification['_id']),
                              child: const Text('Mark as Read'),
                            ),
                          ],
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
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getNotificationIcon(notification['type'] ?? 'system'),
              color: _getNotificationColor(notification['type'] ?? 'system'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(notification['title'] ?? 'Notification Details'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatNotificationMessage(
                  notification['message'] ?? 'No message content',
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Type: ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    (notification['type'] ?? 'system').toUpperCase(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getNotificationColor(
                        notification['type'] ?? 'system',
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Received: ${_formatDate(notification['createdAt'] ?? notification['timestamp'])}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          if (!isRead) ...[
            TextButton(
              onPressed: () {
                _markAsRead(notification['_id']);
                Navigator.of(context).pop();
              },
              child: const Text('Mark as Read'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  const _SendNotificationDialog();

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedType = 'system';
  String _selectedRecipient = 'staff';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final data = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _selectedType,
        'recipient_type': _selectedRecipient,
      };

      await ApiService.post('${ApiConfig.ownerNotifications}/send', data);

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Notification'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter notification title',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message *',
                  hintText: 'Enter notification message',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Message is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Type *'),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('System')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                  DropdownMenuItem(
                    value: 'subscription',
                    child: Text('Subscription'),
                  ),
                  DropdownMenuItem(value: 'request', child: Text('Request')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment')),
                ],
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRecipient,
                decoration: const InputDecoration(labelText: 'Send to *'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('All Staff')),
                  DropdownMenuItem(
                    value: 'doctors',
                    child: Text('All Doctors'),
                  ),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  setState(() => _selectedRecipient = value!);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Notification'),
        ),
      ],
    );
  }
}
