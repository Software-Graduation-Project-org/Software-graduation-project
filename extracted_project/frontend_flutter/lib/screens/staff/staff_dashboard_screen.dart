// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/staff_auth_provider.dart';
import '../../services/staff_api_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/paginated_list.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/notification_service.dart' as notification_service;
import 'staff_sidebar.dart';
import '../../widgets/system_feedback_form.dart';
import '../../widgets/new_order_form.dart';
import 'staff_order_results_screen.dart';
import 'staff_invoice_details_screen.dart';
import 'staff_profile_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _assignedTests;
  Map<String, dynamic>? _pendingOrders;
  Map<String, dynamic>? _allResultsForUpload;
  List<Map<String, dynamic>>? _dropdownInventoryItems;
  bool _isTestsLoading = false;
  bool _isOrdersLoading = false;
  bool _isResultsForUploadLoading = false;

  // Orders data
  Map<String, dynamic>? _allOrders;
  bool _isAllOrdersLoading = false;
  String? _selectedStatus; // Default to showing all tests
  String? _selectedDeviceId;
  late TabController _tabController;
  String _inventorySearchQuery = '';

  // Sidebar state
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  // Scaffold key for drawer management
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Notification service for real-time updates
  final notification_service.NotificationService _notificationService =
      notification_service.NotificationService();

  // Notifications state
  List<Map<String, dynamic>> _notifications = [];
  bool _notificationsLoading = false;
  Map<String, Timer> _notificationRemovalTimers = {}; // Track removal timers
  String _notificationFilter = 'all'; // 'all' or 'unread'

  // Search for results
  String _resultSearchQuery = '';

  // Search for samples
  String _sampleSearchQuery = '';

  // Timer for periodic refresh of upload results
  Timer? _uploadResultsRefreshTimer;

  // Tab routes for URL navigation
  static const Map<int, String> _tabRoutes = {
    0: 'dashboard',
    1: 'new-order',
    2: 'orders',
    3: 'my-tests',
    4: 'sample-collection',
    5: 'result-upload',
    6: 'inventory',
    7: 'notifications',
    8: 'profile',
  };

  // Reverse map for getting index from tab name
  static const Map<String, int> _tabIndices = {
    'dashboard': 0,
    'new-order': 1,
    'orders': 2,
    'my-tests': 3,
    'sample-collection': 4,
    'result-upload': 5,
    'inventory': 6,
    'notifications': 7,
    'profile': 8,
  };

  @override
  void initState() {
    super.initState();

    // Set initial tab based on URL parameter
    final initialIndex = widget.initialTab != null
        ? _tabIndices[widget.initialTab] ?? 0
        : 0;

    _tabController = TabController(
      length: 9,
      vsync: this,
      initialIndex: initialIndex,
    );
    _selectedIndex = initialIndex;

    _tabController.addListener(_handleTabChange);
    _loadInitialData();
    _loadNotifications(); // Load notifications
    _checkFeedbackStatus();

    // Register for notification callbacks to refresh data when relevant notifications are received
    _notificationService.setNotificationCallback(_onNotificationReceived);

    // Start background timer for upload results refresh
    _startUploadResultsTimer();
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await StaffApiService.getMyFeedback();
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted =
              (response['feedbacks'] as List?)?.isNotEmpty ?? false;
          _showFeedbackReminder = !_hasFeedbackSubmitted;
        });
      }
    } catch (e) {
      // If error, assume no feedback submitted
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted = false;
          _showFeedbackReminder = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stopUploadResultsTimer();
    _notificationService.removeNotificationCallback();
    // Cancel all notification removal timers
    for (final timer in _notificationRemovalTimers.values) {
      timer.cancel();
    }
    _notificationRemovalTimers.clear();
    super.dispose();
  }

  // Handle real-time notifications to refresh data
  void _onNotificationReceived(String type, Map<String, dynamic> data) {
    debugPrint(
      '🔔 STAFF DASHBOARD: Received notification type: $type with data: $data',
    );

    // Refresh upload results for any result-related notification
    if (type == 'result_uploaded' ||
        type == 'order_completed' ||
        type == 'test_result') {
      debugPrint(
        '🔔 STAFF DASHBOARD: Result-related notification received ($type), refreshing upload results',
      );
      _loadResultsForUpload();
    }

    // Show success message for completed result upload/simulation
    if (mounted && type == 'result_uploaded') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Test result processed - refreshing list'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Mark notification as read
  Future<void> _markNotificationAsRead(
    String staffId,
    String notificationId,
  ) async {
    try {
      // First make the API call
      await StaffApiService.markNotificationAsRead(staffId, notificationId);

      // Immediately remove from local list to prevent reappearance
      setState(() {
        _notifications.removeWhere((n) => n['_id'] == notificationId);
      });

      // Cancel any existing timer for this notification
      _notificationRemovalTimers.remove(notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark notification as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Load notifications
  Future<void> _loadNotifications() async {
    if (_notificationsLoading) return;

    setState(() => _notificationsLoading = true);
    try {
      final authProvider = Provider.of<StaffAuthProvider>(
        context,
        listen: false,
      );
      final staffId = authProvider.user?.id ?? '';

      if (staffId.isEmpty) {
        setState(() => _notificationsLoading = false);
        return;
      }

      final notifications = await StaffApiService.getNotifications(staffId);
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

  void _startUploadResultsTimer() {
    _stopUploadResultsTimer(); // Cancel any existing timer
    _uploadResultsRefreshTimer = Timer.periodic(
      const Duration(
        seconds: 10,
      ), // Refresh every 10 seconds (longer interval when not on tab)
      (_) {
        if (mounted && !_isResultsForUploadLoading) {
          // Always refresh upload results in background, but load immediately if on the tab
          if (_tabController.index == 5) {
            _loadResultsForUpload();
          } else {
            // Background refresh - only load if we haven't loaded recently
            _loadResultsForUpload();
          }
        }
      },
    );
  }

  void _stopUploadResultsTimer() {
    _uploadResultsRefreshTimer?.cancel();
    _uploadResultsRefreshTimer = null;
  }

  // Load only the first tab's data initially
  Future<void> _loadInitialData() async {
    // Load initial data for dashboard and orders
    await Future.wait([_loadAssignedTests(), _loadAllOrders()]);
  }

  // Handle tab changes to load data on demand
  void _handleTabChange() {
    // Update URL when tab changes
    final tabRoute = _tabRoutes[_tabController.index];
    if (tabRoute != null) {
      final targetPath = '/staff/dashboard/$tabRoute';
      final currentPath = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.path;
      if (currentPath != targetPath) {
        GoRouter.of(context).go(targetPath);
      }
    }

    // Sync selectedIndex with tab controller
    setState(() => _selectedIndex = _tabController.index);

    if (_tabController.index == 1 &&
        _pendingOrders == null &&
        !_isOrdersLoading) {
      _loadPendingOrders();
    }

    // Refresh upload results when switching to result-upload tab
    if (_tabController.index == 5 && !_isResultsForUploadLoading) {
      _loadResultsForUpload(); // Immediate refresh when switching to tab
    }
    // Timer continues running in background for all tabs
    // Inventory tab now uses PaginatedList, no need for manual loading
  }

  Future<void> _loadAssignedTests() async {
    if (_isTestsLoading) return; // Prevent multiple simultaneous loads
    setState(() => _isTestsLoading = true);

    try {
      // For sample collection view, always load all tests to ensure assigned tests are available
      final statusFilter = _selectedIndex == 4 ? null : _selectedStatus;

      final response = await StaffApiService.getMyAssignedTests(
        statusFilter: statusFilter,
        deviceId: _selectedDeviceId,
      );

      if (mounted) {
        setState(() {
          _assignedTests = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assigned tests: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestsLoading = false);
      }
    }
  }

  Future<void> _loadPendingOrders() async {
    if (_isOrdersLoading) return;
    setState(() => _isOrdersLoading = true);

    try {
      final response = await StaffApiService.getPendingOrders();
      if (mounted) {
        setState(() {
          _pendingOrders = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load pending orders: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOrdersLoading = false);
      }
    }
  }

  Future<void> _loadOrdersInBackground() async {
    if (_isAllOrdersLoading) return;
    setState(() => _isAllOrdersLoading = true);

    try {
      final response = await StaffApiService.getAllLabOrders();
      if (mounted) {
        setState(() {
          _allOrders = response;
        });
      }
      // Also refresh tests for upload and assigned tests
      await Future.wait([_loadResultsForUpload(), _loadAssignedTests()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAllOrdersLoading = false);
      }
    }
  }

  Future<void> _loadResultsForUpload() async {
    if (_isResultsForUploadLoading) return;
    setState(() => _isResultsForUploadLoading = true);

    try {
      final response = await StaffApiService.getTestsForResultUpload(
        limit: 100, // Get more tests
      );

      if (mounted) {
        setState(() {
          _allResultsForUpload = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tests for result upload: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResultsForUploadLoading = false);
      }
    }
  }

  Future<void> _loadAllOrders() async {
    if (_isAllOrdersLoading) return;
    setState(() => _isAllOrdersLoading = true);

    try {
      final response = await StaffApiService.getAllLabOrders();
      if (mounted) {
        setState(() {
          _allOrders = response;
        });
      }
      // Also refresh tests for upload and assigned tests
      await Future.wait([_loadResultsForUpload(), _loadAssignedTests()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAllOrdersLoading = false);
      }
    }
  }

  Future<void> _loadDropdownInventoryItems() async {
    try {
      final response = await StaffApiService.getInventoryItems(
        page: 1,
        limit: 1000,
      ); // Load more for dropdown
      if (mounted) {
        setState(() {
          _dropdownInventoryItems = List<Map<String, dynamic>>.from(
            response['data'] ?? [],
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load inventory for dropdown: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _fetchInventoryPage(int page, int limit) async {
    try {
      final response = await StaffApiService.getInventoryItems(
        page: page,
        limit: limit,
      );

      // Filter results based on search query
      List<dynamic> allItems = response['data'] ?? [];
      List<dynamic> filteredItems = allItems;

      if (_inventorySearchQuery.isNotEmpty) {
        filteredItems = allItems.where((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final itemCode = (item['item_code'] as String? ?? '').toLowerCase();
          final query = _inventorySearchQuery.toLowerCase();
          return name.contains(query) || itemCode.contains(query);
        }).toList();
      }

      return {
        'data': filteredItems,
        'hasMore': response['pagination']?['hasMore'] ?? false,
      };
    } catch (e) {
      throw Exception('Failed to load inventory: $e');
    }
  }

  Future<void> _showReportInventoryIssueDialog() async {
    // Load inventory items for dropdown if not already loaded
    if (_dropdownInventoryItems == null) {
      await _loadDropdownInventoryItems();
    }

    final inventoryController = TextEditingController();
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedIssueType = 'damaged';

    final inventoryItems = _dropdownInventoryItems ?? [];

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              const Text('Report Inventory Issue'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedIssueType,
                    decoration: const InputDecoration(
                      labelText: 'Issue Type',
                      hintText: 'Select the type of issue',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text('Damaged'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expired'),
                      ),
                      DropdownMenuItem(
                        value: 'contaminated',
                        child: Text('Contaminated'),
                      ),
                      DropdownMenuItem(
                        value: 'missing',
                        child: Text('Missing'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedIssueType = value ?? 'damaged');
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Inventory Item',
                      hintText: 'Select the affected item',
                    ),
                    items: inventoryItems.map((item) {
                      final name = item['name'] as String? ?? 'Unknown';
                      final currentStock = item['current_stock'] as int? ?? 0;
                      return DropdownMenuItem(
                        value: item['_id']?.toString(),
                        child: Text('$name (Stock: $currentStock)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      inventoryController.text = value ?? '';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity Affected',
                      hintText: 'Enter the quantity affected',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Provide additional details',
                    ),
                    maxLines: 3,
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
                if (inventoryController.text.isNotEmpty &&
                    quantityController.text.isNotEmpty) {
                  Navigator.pop(context, true);

                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                    return;
                  }

                  try {
                    final response = await StaffApiService.reportInventoryIssue(
                      inventoryId: inventoryController.text,
                      issueType: selectedIssueType,
                      quantity: quantity,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                    );

                    if (context.mounted) {
                      if (response['success'] != false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Inventory issue reported successfully',
                            ),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                        // Refresh dropdown inventory items
                        _loadDropdownInventoryItems();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              response['message'] ?? 'Failed to report issue',
                            ),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to report issue: $e'),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningYellow,
                foregroundColor: Colors.black,
              ),
              child: const Text('Report Issue'),
            ),
          ],
        ),
      ),
    );

    inventoryController.dispose();
    quantityController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showConsumeInventoryDialog(Map<String, dynamic> item) async {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    final currentStock = item['current_stock'] as int? ?? 0;
    final itemName = item['name'] as String? ?? 'Unknown Item';

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.remove_circle, color: AppTheme.warningYellow),
            const SizedBox(width: 8),
            Text('Consume $itemName'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current stock: $currentStock'),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Consume',
                    hintText: 'Enter the quantity to consume',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                    hintText: 'e.g., Used for sample collection',
                  ),
                  maxLines: 2,
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              if (quantity > currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot consume more than available stock ($currentStock)',
                    ),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);

              try {
                final response = await StaffApiService.consumeInventory(
                  inventoryId: item['_id']?.toString() ?? '',
                  quantity: quantity,
                  reason: reasonController.text.isEmpty
                      ? null
                      : reasonController.text,
                );

                if (context.mounted) {
                  if (response['success'] != false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inventory consumed successfully'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    // Refresh inventory list
                    setState(() {
                      // Trigger refresh by calling _loadInitialData or similar
                      // For now, just show success
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          response['message'] ?? 'Failed to consume inventory',
                        ),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to consume inventory: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Consume'),
          ),
        ],
      ),
    );

    quantityController.dispose();
    reasonController.dispose();
  }

  Widget _buildInventoryItemCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Unknown Item';
    final currentStock = item['current_stock'] as int? ?? 0;
    final unit = item['unit'] as String? ?? 'units';
    final minThreshold = item['min_threshold'] as int? ?? 0;
    final isLowStock = currentStock <= minThreshold;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isLowStock
                  ? AppTheme.errorRed.withValues(alpha: 0.2)
                  : AppTheme.primaryBlue.withValues(alpha: 0.2),
              child: Icon(
                isLowStock ? Icons.warning : Icons.inventory,
                color: isLowStock ? AppTheme.errorRed : AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: $currentStock $unit',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (isLowStock)
                    Text(
                      'Low stock alert!',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.remove_circle,
                color: AppTheme.warningYellow,
              ),
              onPressed: () => _showConsumeInventoryDialog(item),
              tooltip: 'Consume Item',
            ),
            if (isLowStock)
              Icon(Icons.warning, color: AppTheme.errorRed, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _collectSample(String detailId) async {
    try {
      final response = await StaffApiService.collectSample(detailId: detailId);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Sample collected successfully',
              ),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          // Remove the test from the sample collection list with animation
          _removeSampleFromCollectionList(detailId);
          // Refresh all data to show updated status across all tabs
          await _loadOrdersInBackground();
          // Also refresh upload results immediately to ensure collected samples appear
          await _loadResultsForUpload();
          // Force UI update
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to collect sample'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error collecting sample: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showUploadResultDialog(Map<String, dynamic> test) async {
    // Show initial dialog with two options
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.upload_file, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload Result', style: TextStyle(fontSize: 18)),
                  Text(
                    test['test_name'] as String? ?? 'Unknown Test',
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how you want to upload the result:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, 'manual'),
                    child: const Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Manual Entry',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter result values manually',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, 'hl7'),
                    child: const Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.science, color: Colors.green, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'HL7 Simulation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Run automated test simulation',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result == 'manual') {
      await _showManualResultEntry(test);
    } else if (result == 'hl7') {
      await _runHL7Simulation(test);
    }
  }

  Future<void> _showManualResultEntry(Map<String, dynamic> test) async {
    // First, check if this test has components
    bool isLoadingComponents = true;
    List<Map<String, dynamic>> components = [];
    bool hasComponents = false;

    // Controllers for components
    final Map<String, TextEditingController> componentControllers = {};
    final Map<String, TextEditingController> componentRemarksControllers = {};

    // Controllers for single-value test
    final resultController = TextEditingController();
    final remarksController = TextEditingController();

    // Get test_id from the test data
    final testId = test['test_id']?.toString() ?? '';

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load components on first build
          if (isLoadingComponents) {
            if (testId.isNotEmpty) {
              StaffApiService.getTestComponents(testId)
                  .then((response) {
                    if (response['has_components'] == true &&
                        response['components'] != null) {
                      setDialogState(() {
                        components = List<Map<String, dynamic>>.from(
                          response['components'],
                        );
                        hasComponents = components.isNotEmpty;
                        isLoadingComponents = false;

                        // Create controllers for each component
                        for (var comp in components) {
                          final compId = comp['_id'].toString();
                          componentControllers[compId] =
                              TextEditingController();
                          componentRemarksControllers[compId] =
                              TextEditingController();
                        }
                      });
                    } else {
                      setDialogState(() {
                        hasComponents = false;
                        isLoadingComponents = false;
                      });
                    }
                  })
                  .catchError((e) {
                    setDialogState(() {
                      hasComponents = false;
                      isLoadingComponents = false;
                    });
                  });
            } else {
              // If testId is empty, assume no components and stop loading
              setDialogState(() {
                hasComponents = false;
                isLoadingComponents = false;
              });
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.upload_file, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manual Result Entry',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        test['test_name'] as String? ?? 'Unknown Test',
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
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: isLoadingComponents
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Checking test configuration...'),
                        ],
                      )
                    : hasComponents
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This test has ${components.length} components. Enter values for each:',
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...components.asMap().entries.map((entry) {
                            final index = entry.key;
                            final comp = entry.value;
                            final compId = comp['_id'].toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.blue[100],
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[900],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            comp['component_name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (comp['component_code'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              comp['component_code'],
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        if (comp['units'] != null)
                                          Text(
                                            'Units: ${comp['units']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (comp['reference_range'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Normal Range: ${comp['reference_range']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: componentControllers[compId],
                                      decoration: const InputDecoration(
                                        labelText: 'Value *',
                                        hintText: 'Enter measured value',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller:
                                          componentRemarksControllers[compId],
                                      decoration: const InputDecoration(
                                        labelText: 'Remarks (Optional)',
                                        hintText: 'Notes for this component',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextField(
                            controller: remarksController,
                            decoration: const InputDecoration(
                              labelText: 'Overall Remarks (Optional)',
                              hintText: 'General notes about the result',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: resultController,
                            decoration: const InputDecoration(
                              labelText: 'Result Value',
                              hintText: 'Enter test result',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: remarksController,
                            decoration: const InputDecoration(
                              labelText: 'Remarks (Optional)',
                              hintText: 'Any additional notes',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Dispose controllers
                  for (var controller in componentControllers.values) {
                    controller.dispose();
                  }
                  for (var controller in componentRemarksControllers.values) {
                    controller.dispose();
                  }
                  resultController.dispose();
                  remarksController.dispose();
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoadingComponents
                    ? null
                    : () async {
                        // Validation
                        if (hasComponents) {
                          // Check if all component values are filled
                          bool allFilled = componentControllers.values.every(
                            (controller) => controller.text.isNotEmpty,
                          );
                          if (!allFilled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter values for all components',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        } else {
                          // Single-value test
                          if (resultController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a result value'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }

                        // Dispose controllers
                        for (var controller in componentControllers.values) {
                          controller.dispose();
                        }
                        for (var controller
                            in componentRemarksControllers.values) {
                          controller.dispose();
                        }
                        resultController.dispose();
                        remarksController.dispose();

                        Navigator.pop(dialogContext, true);

                        // Prepare data for submission

                        if (hasComponents) {
                          // Multi-component test
                          final componentValues = components.map((comp) {
                            final compId = comp['_id'].toString();
                            return {
                              'component_id': compId,
                              'component_value':
                                  componentControllers[compId]!.text,
                              if (componentRemarksControllers[compId]!
                                  .text
                                  .isNotEmpty)
                                'remarks':
                                    componentRemarksControllers[compId]!.text,
                            };
                          }).toList();

                          final response = await StaffApiService.uploadResult(
                            detailId: test['detail_id']?.toString() ?? '',
                            components: componentValues,
                            remarks: remarksController.text.isEmpty
                                ? null
                                : remarksController.text,
                          );

                          if (context.mounted) {
                            if (response['success'] == true) {
                              debugPrint(
                                '✅ MULTI-COMPONENT UPLOAD SUCCESS: Response = $response',
                              );

                              // Remove test from list immediately
                              debugPrint(
                                '🗑️ UPLOAD SUCCESS: Removing test ${test['detail_id']} from upload list',
                              );
                              _removeTestFromList(test);

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Result uploaded successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Reset status filter to show all tests including completed
                              setState(() => _selectedStatus = null);

                              // Note: Background refresh removed to prevent overriding the immediate removal

                              // Check if order status was updated and refresh orders if needed
                              if (response['order_status_updated'] == true) {
                                _loadAllOrders();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Order marked as completed!'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            } else {
                              debugPrint(
                                '❌ MULTI-COMPONENT UPLOAD FAILED: Response = $response',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response['message'] ??
                                        'Failed to upload result',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } else {
                          // Single-value test
                          final response = await StaffApiService.uploadResult(
                            detailId: test['detail_id']?.toString() ?? '',
                            resultValue: resultController.text,
                            remarks: remarksController.text.isEmpty
                                ? null
                                : remarksController.text,
                          );

                          if (context.mounted) {
                            if (response['success'] == true) {
                              debugPrint(
                                '✅ SINGLE-VALUE UPLOAD SUCCESS: Response = $response',
                              );

                              // Remove test from list immediately
                              debugPrint(
                                '🗑️ UPLOAD SUCCESS: Removing test ${test['detail_id']} from upload list',
                              );
                              _removeTestFromList(test);

                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Result uploaded successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // Reset status filter to show all tests including completed
                              setState(() => _selectedStatus = null);

                              // Note: Background refresh removed to prevent overriding the immediate removal

                              // Check if order status was updated and refresh orders if needed
                              if (response['order_status_updated'] == true) {
                                _loadAllOrders();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Order marked as completed!'),
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                );
                              }
                            } else {
                              debugPrint(
                                '❌ SINGLE-VALUE UPLOAD FAILED: Response = $response',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response['message'] ??
                                        'Failed to upload result',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runHL7Simulation(Map<String, dynamic> test) async {
    final detailId = test['detail_id']?.toString() ?? '';

    // print('🎯 FRONTEND SIMULATION START: _runHL7Simulation called');
    // print('📨 FRONTEND: detailId = $detailId');
    // print('📊 FRONTEND: test data = $test');

    if (detailId.isEmpty) {
      // print('❌ FRONTEND SIMULATION ERROR: Test detail ID is missing');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test detail ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog with fixed 1-minute delay
    const int simulationDelaySeconds = 60; // Always 1 minute
    final isLongDelay =
        simulationDelaySeconds >
        10; // Allow cancellation for delays > 10 seconds

    showDialog(
      context: context,
      barrierDismissible: isLongDelay, // Allow dismissal for long delays
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Running HL7 simulation...'),
            const SizedBox(height: 8),
            const Text(
              'Simulating laboratory processing',
              style: TextStyle(fontSize: 12, color: Colors.blue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isLongDelay
                  ? 'Simulation will take 1 minute - tap outside or cancel to abort'
                  : 'Results will appear after processing delay',
              style: TextStyle(
                fontSize: 12,
                color: isLongDelay ? Colors.orange : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (isLongDelay) ...[const SizedBox(height: 16)],
          ],
        ),
        actions: isLongDelay
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ]
            : null,
      ),
    );

    try {
      // Call the new run-test API
      final response = await StaffApiService.runTest(
        detailId: detailId,
        priority: 'normal',
      );

      // Only proceed if context is still mounted (user didn't cancel)
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (response['success'] == true &&
            response['status'] == 'simulation_started') {
          // Simulation started successfully - show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ??
                    'HL7 simulation started. You will be notified when results are ready.',
              ),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 5),
            ),
          );

          // Update test status to 'simulating' in assigned tests list
          _updateTestStatusInList(test['detail_id']?.toString(), 'simulating');

          // Refresh the assigned tests list to show updated status
          _loadAssignedTests();

          // Fallback: Refresh upload results after a delay in case notification fails
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              debugPrint(
                '🔄 Fallback: Refreshing upload results after HL7 simulation',
              );
              _loadResultsForUpload();
            }
          });

          // Note: Test will be removed from upload list when simulation completes (via notification)
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Failed to start HL7 simulation',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      // If context is not mounted, user cancelled - silently ignore
    } catch (error) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    // print('🎉 FRONTEND SIMULATION END: _runHL7Simulation function completed');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<StaffAuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final showSidebar = MediaQuery.of(context).size.width >= 600;
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
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Open menu',
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Staff'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
              ],
            )
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: showSidebar
                  ? IconButton(
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _isSidebarOpen
                            ? const AlwaysStoppedAnimation(1.0)
                            : const AlwaysStoppedAnimation(0.0),
                      ),
                      onPressed: () =>
                          setState(() => _isSidebarOpen = !_isSidebarOpen),
                      tooltip: _isSidebarOpen
                          ? 'Close sidebar'
                          : 'Open sidebar',
                    )
                  : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Staff'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
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
                        Icons.biotech,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lab Staff',
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
      drawer: isMobile ? _buildDrawer() : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (showSidebar && _isSidebarOpen)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: StaffSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _handleSidebarNavigation,
                  ),
                ),
              Expanded(
                child: AppAnimations.fadeIn(
                  _buildDashboardContent(),
                  delay: 300.ms,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await StaffApiService.provideFeedback(
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

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildNewOrderView();
      case 2:
        return _buildOrdersView();
      case 3:
        return _buildMyTestsView();
      case 4:
        return _buildSampleCollectionView();
      case 5:
        return _buildResultUploadView();
      case 6:
        return _buildInventoryView();
      case 7:
        return _buildNotificationsView();
      case 8:
        return const StaffProfileScreen();
      default:
        return _buildDashboardView();
    }
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
                  const Icon(Icons.biotech, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Lab Staff',
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
                children: [
                  // WORKSTATION Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'WORKSTATION',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('Dashboard', Icons.dashboard, 0),
                  _buildDrawerItem('New Order', Icons.add_box, 1),
                  _buildDrawerItem('Orders', Icons.assignment, 2),
                  _buildDrawerItem('My Tests', Icons.assignment, 3),
                  _buildDrawerItem('Sample Collection', Icons.science, 4),
                  _buildDrawerItem('Result Upload', Icons.upload_file, 5),

                  // OPERATIONS Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'OPERATIONS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('Inventory', Icons.inventory, 6),
                  _buildDrawerItem('Notifications', Icons.notifications, 7),

                  // ACCOUNT Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'ACCOUNT',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('My Profile', Icons.person, 8),
                  _buildDrawerItem('Logout', Icons.logout, -1, isLogout: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    String title,
    IconData icon,
    int index, {
    bool isLogout = false,
  }) {
    final isSelected = _selectedIndex == index;

    return AnimatedCard(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () async {
            if (isLogout) {
              _showLogoutDialog();
            } else {
              setState(() => _selectedIndex = index);
              _scaffoldKey.currentState?.closeDrawer(); // Close drawer
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textLight,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
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
      ),
    );
  }

  void _handleSidebarNavigation(int index) {
    setState(() => _selectedIndex = index);

    // Update tab controller to match sidebar selection
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }

    // Update URL for sidebar navigation
    final tabRoute = _tabRoutes[index];
    if (tabRoute != null) {
      GoRouter.of(context).go('/staff/dashboard/$tabRoute');
    }

    // Load data for specific tabs when selected
    switch (index) {
      case 2: // Orders tab
        if (!_isAllOrdersLoading) {
          _loadAllOrders();
        }
        break;
      case 4: // Sample Collection tab
        // Always reload assigned tests for sample collection to ensure we have assigned tests
        _loadAssignedTests();
        // Also refresh upload results in case collected samples should appear there
        _loadResultsForUpload();
        break;
      // Add other cases as needed
    }
  }

  Widget _buildNotificationsView() {
    final authProvider = Provider.of<StaffAuthProvider>(context);
    final staffId = authProvider.user?.id ?? '';

    if (staffId.isEmpty) {
      return const Center(
        child: Text('Unable to load notifications - staff ID not found'),
      );
    }

    if (_notificationsLoading && _notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final notifications = _filteredNotifications;

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'View your recent notifications and updates',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    _notificationFilter == 'unread'
                        ? 'Unread Notifications: ${notifications.length}'
                        : 'Total Notifications: ${notifications.length}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notifications
                      .where((n) => !(n['is_read'] ?? true))
                      .isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Colors.white,
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${notifications.where((n) => !(n['is_read'] ?? true)).length} Unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
                          : 'No notifications yet',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll see notifications here when there are updates',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
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

                      IconData icon;
                      Color iconColor;
                      switch (type) {
                        case 'system':
                          icon = Icons.info;
                          iconColor = AppTheme.primaryBlue;
                          break;
                        case 'test_result':
                          icon = Icons.science;
                          iconColor = AppTheme.successGreen;
                          break;
                        case 'inventory':
                          icon = Icons.inventory;
                          iconColor = AppTheme.warningYellow;
                          break;
                        case 'payment':
                          icon = Icons.payment;
                          iconColor = AppTheme.accentOrange;
                          break;
                        case 'request':
                          icon = Icons.assignment;
                          iconColor = AppTheme.secondaryTeal;
                          break;
                        case 'message':
                          icon = Icons.mail;
                          iconColor = AppTheme.primaryBlue;
                          break;
                        case 'issue':
                          icon = Icons.warning;
                          iconColor = AppTheme.errorRed;
                          break;
                        case 'feedback':
                          icon = Icons.feedback;
                          iconColor = AppTheme.secondaryTeal;
                          break;
                        case 'maintenance':
                          icon = Icons.build;
                          iconColor = AppTheme.warningYellow;
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
                          child: ExpansionTile(
                            onExpansionChanged: (expanded) {
                              if (expanded && !isRead) {
                                _markNotificationAsRead(
                                  staffId,
                                  notification['_id'],
                                );
                              }
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, color: iconColor, size: 24),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.isNotEmpty) ...[
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
                                ],
                                if (createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNotificationTime(createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            children: [
                              if (message.isNotEmpty &&
                                  message.length > 100) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    72,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Text(
                                    message,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                              if (!isRead) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    72,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await _markNotificationAsRead(
                                              staffId,
                                              notification['_id'],
                                            );
                                          } catch (e) {
                                            // Error handling is done in _markNotificationAsRead
                                          }
                                        },
                                        icon: const Icon(Icons.mark_email_read),
                                        label: const Text('Mark as Read'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
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
              ),
          ],
        ),
      ),
    );
  }

  String _formatNotificationTime(dynamic createdAt) {
    if (createdAt == null) return '';

    try {
      final dateTime = DateTime.parse(createdAt.toString());
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
    } catch (e) {
      return '';
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

  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _loadAssignedTests,
      child: AppAnimations.pageDepthTransition(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showFeedbackReminder)
                AppAnimations.elasticSlideIn(
                  _buildFeedbackReminderBanner(),
                  delay: 50.ms,
                ),
              if (_showFeedbackReminder) const SizedBox(height: 16),
              AppAnimations.blurFadeIn(_buildHeroSection(), delay: 100.ms),
              const SizedBox(height: 24),
              // AppAnimations.elasticSlideIn(_buildFilters(), delay: 500.ms),
              // const SizedBox(height: 16),
              AppAnimations.fadeIn(_buildTestsList(), delay: 700.ms),
            ],
          ),
        ),
      ),
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

  Widget _buildNewOrderView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Order',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Register walk-in patient and create order',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            NewOrderForm(onOrderCreated: _loadAllOrders),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTestsView() {
    // Load assigned tests if not already loaded
    if (_assignedTests == null && !_isTestsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAssignedTests();
      });
    }

    return RefreshIndicator(
      onRefresh: _loadAssignedTests,
      child: AppAnimations.pageDepthTransition(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAnimations.blurFadeIn(
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Assigned Tests',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                delay: 100.ms,
              ),
              const SizedBox(height: 16),
              AppAnimations.fadeIn(
                Text(
                  'View and manage tests assigned to you',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                ),
                delay: 200.ms,
              ),
              const SizedBox(height: 24),

              // Tests List - same as main dashboard
              AppAnimations.fadeIn(_buildTestsList(), delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersView() {
    final orders = _allOrders?['orders'] as List<dynamic>? ?? [];
    final isLoading = _isAllOrdersLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(
                  Icons.assignment,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Lab Orders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAllOrders,
                  tooltip: 'Refresh Orders',
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  )
                : orders.isEmpty
                ? Center(
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
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCardWithInvoice(order)
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                          .slideY(begin: 0.1, end: 0, duration: 300.ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCardWithInvoice(dynamic order) {
    final orderDate = DateTime.parse(order['order_date']);
    final status = order['status'] ?? 'unknown';
    final testCount = order['test_count'] ?? 0;
    final labName = order['owner_id']?['lab_name'] ?? 'Medical Lab';
    final tests = order['tests'] as List<dynamic>? ?? [];

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
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
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
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
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
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.blue[700],
                              ),
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
                            order['patient_info']?['full_name']?['first'] !=
                                    null
                                ? '${order['patient_info']['full_name']['first']} ${order['patient_info']['full_name']['last']}'
                                : order['patient_name'] ?? 'N/A',
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
                          Text(
                            order['doctor_name'] ?? 'Not Assigned',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: order['doctor_name'] != null
                                  ? AppTheme.textDark
                                  : Colors.grey[500],
                              fontStyle: order['doctor_name'] != null
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tests Section
                const Text(
                  'Tests:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...tests.map((test) => _buildTestAssignmentCard(test, order)),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StaffOrderResultsScreen(
                                orderId: order['order_id'],
                              ),
                            ),
                          );
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StaffInvoiceDetailsScreen(
                                orderId: order['order_id'],
                              ),
                            ),
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
        ],
      ),
    );
  }

  Future<void> _assignTestToMe(dynamic test, dynamic order) async {
    try {
      final detailId = test['detail_id'];
      if (detailId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find test details to assign'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final response = await StaffApiService.assignTestToMe(detailId);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully assigned ${test['test_name']} to you'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Update local state instead of reloading everything
        final authProvider = Provider.of<StaffAuthProvider>(
          context,
          listen: false,
        );
        final currentUser = authProvider.user;

        if (currentUser != null) {
          setState(() {
            // Update the test assignment in the local state
            test['assigned_to'] = {
              '_id': currentUser.id,
              'name': currentUser.displayName,
            };
            test['status'] = 'assigned'; // Update status if needed
          });
        }

        // Only refresh assigned tests, not all orders (which causes page refresh)
        _loadAssignedTests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to assign test'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTestAssignmentCard(dynamic test, dynamic order) {
    final authProvider = Provider.of<StaffAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    final isAssigned = test['assigned_to'] != null;
    final assignedStaffId = isAssigned ? test['assigned_to']['_id'] : null;
    final isAssignedToMe = isAssigned && assignedStaffId == currentUserId;

    final assignedStaffName = isAssigned
        ? (isAssignedToMe
              ? 'You'
              : test['assigned_to']['name'] ?? 'Unknown Staff')
        : null;
    final status = test['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test['test_name'] ?? 'Unknown Test',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isAssigned ? Icons.person : Icons.person_outline,
                        size: 16,
                        color: isAssigned
                            ? AppTheme.primaryBlue
                            : AppTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isAssigned
                              ? 'Assigned to: $assignedStaffName'
                              : 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAssigned
                                ? AppTheme.primaryBlue
                                : AppTheme.textLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isAssigned)
              ElevatedButton.icon(
                onPressed: () => _assignTestToMe(test, order),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign to Me'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.textLight;
      case 'assigned':
        return AppTheme.primaryBlue;
      case 'collected':
        return Colors.purple;
      case 'in_progress':
        return AppTheme.warningYellow;
      case 'completed':
        return AppTheme.successGreen;
      case 'cancelled':
        return AppTheme.errorRed;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSampleCollectionView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'Sample Collection',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'Collect samples for assigned tests',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            // Search Bar
            AppAnimations.elasticSlideIn(
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by test name or patient name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _sampleSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _sampleSearchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _sampleSearchQuery = value);
                },
              ),
              delay: 250.ms,
            ),
            const SizedBox(height: 16),
            // Show tests that need sample collection
            AppAnimations.fadeIn(_buildSampleCollectionList(), delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUploadView() {
    // Load results for upload if not already loaded
    if (_allResultsForUpload == null && !_isResultsForUploadLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadResultsForUpload();
      });
    }

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'All My Tests',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'View and manage all tests assigned to you',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            // Search Bar
            AppAnimations.elasticSlideIn(
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by test name or patient name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _resultSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _resultSearchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _resultSearchQuery = value);
                },
              ),
              delay: 250.ms,
            ),
            const SizedBox(height: 16),
            // Show all tests assigned to the staff
            AppAnimations.fadeIn(_buildResultUploadList(), delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'Inventory Management',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'Report inventory issues or check current stock levels',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            AppAnimations.elasticSlideIn(
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by item name or code...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _inventorySearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _inventorySearchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _inventorySearchQuery = value);
                },
              ),
              delay: 150.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.elasticSlideIn(
              AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: AppTheme.warningYellow,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Report Inventory Issue',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'If you notice damaged, expired, contaminated, or missing inventory items, please report them immediately.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.report_problem),
                          label: const Text('Report Issue'),
                          onPressed: _showReportInventoryIssueDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningYellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              delay: 300.ms,
            ),
            const SizedBox(height: 24),
            AppAnimations.elasticSlideIn(
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: PaginatedList<Map<String, dynamic>>(
                  key: ValueKey(
                    _inventorySearchQuery,
                  ), // Force rebuild on search change
                  fetchData: _fetchInventoryPage,
                  itemBuilder: _buildInventoryItemCard,
                  emptyMessage: _inventorySearchQuery.isNotEmpty
                      ? 'No items found matching "$_inventorySearchQuery"'
                      : 'No inventory items found',
                  loadingMessage: 'Loading inventory...',
                  initialLimit: 20,
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Inventory',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              delay: 400.ms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleCollectionList() {
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};
    final assignedTests = testsByStatus['assigned'] as List? ?? [];

    // Filter out tests that have already been collected
    final uncollectedTests = assignedTests.where((test) {
      final sampleCollected = test['sample_collected'] as bool? ?? false;
      return !sampleCollected;
    }).toList();

    // Apply search filter
    final filteredTests = _sampleSearchQuery.isEmpty
        ? uncollectedTests
        : uncollectedTests.where((test) {
            final testName = test['test_name']?.toLowerCase() ?? '';
            final patient = test['patient'] as Map<String, dynamic>?;
            final patientName = patient?['name']?.toLowerCase() ?? '';
            final query = _sampleSearchQuery.toLowerCase();
            return testName.contains(query) || patientName.contains(query);
          }).toList();

    if (filteredTests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _sampleSearchQuery.isNotEmpty
                ? 'No tests found matching "$_sampleSearchQuery"'
                : 'No tests assigned for sample collection',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredTests
          .map((test) => _buildSampleCollectionCard(test))
          .toList(),
    );
  }

  Widget _buildResultUploadList() {
    final tests = _allResultsForUpload?['tests'] as List? ?? [];

    // Apply search filter
    final filteredTests = _resultSearchQuery.isEmpty
        ? tests.map((test) => test as Map<String, dynamic>).toList()
        : tests
              .where((test) {
                final testMap = test as Map<String, dynamic>;
                final testName = testMap['test_name']?.toLowerCase() ?? '';
                final patientName =
                    testMap['patient']?['name']?.toLowerCase() ?? '';
                final query = _resultSearchQuery.toLowerCase();
                return testName.contains(query) || patientName.contains(query);
              })
              .toList()
              .cast<Map<String, dynamic>>();

    if (filteredTests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _resultSearchQuery.isNotEmpty
                    ? 'No tests found matching "$_resultSearchQuery"'
                    : 'No tests ready for result upload',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _resultSearchQuery.isNotEmpty
                    ? 'Try a different search term'
                    : 'Tests will appear here once samples are collected and ready for result upload',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...filteredTests.map((test) => _buildResultUploadCard(test))],
    );
  }

  Widget _buildSampleCollectionCard(Map<String, dynamic> test) {
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patient = test['patient'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'N/A';
    final testId = test['detail_id']?.toString();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: AppTheme.secondaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark as Collected'),
                onPressed: testId != null && testId.isNotEmpty
                    ? () => _collectSample(testId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletedTestResults(Map<String, dynamic> test) {
    // Navigate to the order results screen to view completed results
    final orderId = test['order_id']?.toString();
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StaffOrderResultsScreen(orderId: orderId),
        ),
      );
    }
  }

  void _removeTestFromList(Map<String, dynamic> testToRemove) {
    if (_allResultsForUpload == null) {
      debugPrint('❌ Cannot remove test: _allResultsForUpload is null');
      return;
    }

    final tests = _allResultsForUpload!['tests'] as List? ?? [];
    final initialCount = tests.length;

    // Get the detail_id of the test to remove
    final detailIdToRemove = testToRemove['detail_id']?.toString() ?? '';

    debugPrint(
      '🗑️ _removeTestFromList called for detail_id: $detailIdToRemove',
    );

    // Remove test by detail_id instead of object reference
    final updatedTests = tests.where((test) {
      final testDetailId = test['detail_id']?.toString() ?? '';
      return testDetailId != detailIdToRemove;
    }).toList();
    final finalCount = updatedTests.length;

    debugPrint(
      '🗑️ Removing test from list: $initialCount -> $finalCount tests (detail_id: $detailIdToRemove)',
    );

    setState(() {
      _allResultsForUpload!['tests'] = updatedTests;
      // Update total count
      _allResultsForUpload!['total'] = updatedTests.length;
    });

    // Temporarily stop the auto-refresh timer to prevent it from reloading the removed test
    debugPrint('🗑️ Stopping upload results timer temporarily');
    _stopUploadResultsTimer();

    // Restart the timer after a delay to allow manual changes to persist
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _tabController.index == 5) {
        debugPrint('🗑️ Restarting upload results timer');
        _startUploadResultsTimer();
      }
    });

    // Show a brief success animation feedback
    if (mounted && initialCount != finalCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Test removed from list'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _updateTestStatusInList(String? detailId, String newStatus) {
    if (detailId == null || _allResultsForUpload == null) {
      debugPrint(
        '❌ Cannot update test status: detailId=$detailId, _allResultsForUpload=${_allResultsForUpload != null}',
      );
      return;
    }

    final tests = _allResultsForUpload!['tests'] as List? ?? [];
    final updatedTests = tests.map((test) {
      if (test['detail_id'] == detailId) {
        // Create a copy of the test with updated status
        final updatedTest = Map<String, dynamic>.from(test);
        updatedTest['status'] = newStatus;
        return updatedTest;
      }
      return test;
    }).toList();

    setState(() {
      _allResultsForUpload!['tests'] = updatedTests;
    });
  }

  void _removeSampleFromCollectionList(String? detailId) {
    if (detailId == null || _assignedTests == null) return;

    final testsByStatus = _assignedTests!['tests_by_status'] as Map? ?? {};
    final assignedTests = testsByStatus['assigned'] as List? ?? [];

    // Find and remove the test from assigned tests
    final updatedAssignedTests = assignedTests
        .where((test) => test['detail_id'] != detailId)
        .toList();

    setState(() {
      _assignedTests!['tests_by_status']['assigned'] = updatedAssignedTests;
      // Update total count
      _assignedTests!['total'] = (_assignedTests!['total'] as int? ?? 0) - 1;
    });

    // No snackbar here - success message already shown in _collectSample
  }

  Widget _buildResultUploadCard(Map<String, dynamic> test) {
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patient = test['patient'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'Unknown Patient';
    final detailId = test['detail_id']?.toString();
    final status = test['status'] as String? ?? 'unknown';

    // Determine status color and text
    Color statusColor;
    String statusText;
    IconData statusIcon;
    Color buttonColor;
    String buttonText;
    IconData buttonIcon;
    bool showButton;

    switch (status) {
      case 'assigned':
        statusColor = AppTheme.primaryBlue;
        statusText = 'Assigned';
        statusIcon = Icons.assignment;
        buttonColor = AppTheme.primaryBlue;
        buttonText = 'Collect Sample';
        buttonIcon = Icons.science;
        showButton = true;
        break;
      case 'collected':
        statusColor = AppTheme.secondaryTeal;
        statusText = 'Sample Collected';
        statusIcon = Icons.check_circle;
        buttonColor = AppTheme.primaryBlue;
        buttonText = 'Upload Result';
        buttonIcon = Icons.upload;
        showButton = true;
        break;
      case 'simulating':
        statusColor = AppTheme.accentCoral;
        statusText = 'HL7 Simulation Running';
        statusIcon = Icons.sync;
        buttonColor = Colors.grey;
        buttonText = 'Simulation in Progress';
        buttonIcon = Icons.hourglass_empty;
        showButton = false; // Disable button during simulation
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Simulation Failed';
        statusIcon = Icons.error;
        buttonColor = Colors.red;
        buttonText = 'Retry Simulation';
        buttonIcon = Icons.refresh;
        showButton = true;
        break;
      case 'completed':
        statusColor = AppTheme.successGreen;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        buttonColor = AppTheme.successGreen;
        buttonText = 'View Results';
        buttonIcon = Icons.visibility;
        showButton = true;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
        buttonColor = Colors.grey;
        buttonText = 'N/A';
        buttonIcon = Icons.help;
        showButton = false;
    }

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            const SizedBox(height: 16),
            if (showButton)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(buttonIcon),
                  label: Text(buttonText),
                  onPressed:
                      detailId != null &&
                          detailId.isNotEmpty &&
                          !detailId.startsWith('sample_')
                      ? () {
                          if (status == 'completed') {
                            // For completed tests, show results instead of upload dialog
                            _showCompletedTestResults(test);
                          } else {
                            _showUploadResultDialog(test);
                          }
                        }
                      : () {
                          // Handle sample data
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This is sample data for development. Connect to a database for real functionality.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final stats = _assignedTests?['stats'] ?? {};

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Workload', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                AppAnimations.scaleIn(
                  _buildStatItem(
                    'Total',
                    stats['total']?.toString() ?? '0',
                    AppTheme.primaryBlue,
                  ),
                  delay: 100.ms,
                ),
                AppAnimations.scaleIn(
                  _buildStatItem(
                    'Pending',
                    stats['pending_work']?.toString() ?? '0',
                    AppTheme.warningYellow,
                  ),
                  delay: 200.ms,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final stats = _assignedTests?['stats'] ?? {};

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAnimations.liquidMorph(
            Row(
              children: [
                AppAnimations.rotateIn(
                  Icon(
                    Icons.biotech,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  delay: 200.ms,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAnimations.typingEffect(
                        'Welcome to Your Lab Workstation',
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ) ??
                            const TextStyle(),
                      ),
                      const SizedBox(height: 8),
                      AppAnimations.fadeIn(
                        Text(
                          'Manage your assigned tests and laboratory operations',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 18,
                                height: 1.4,
                              ),
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
              spacing: 20,
              runSpacing: 16,
              children: [
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Tests',
                    stats['total']?.toString() ?? '0',
                    Icons.assignment,
                    AppTheme.primaryBlue,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Pending Work',
                    stats['pending_work']?.toString() ?? '0',
                    Icons.pending,
                    AppTheme.warningYellow,
                  ),
                  glowColor: AppTheme.warningYellow,
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        SelectableText(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /*
  Widget _buildFilters() {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedStatus == null,
                    onSelected: (selected) {
                      setState(() => _selectedStatus = null);
                      _loadAssignedTests();
                    },
                  ),
                  delay: 100.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('Assigned'),
                    selected: _selectedStatus == 'assigned',
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'assigned' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 200.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('In Progress'),
                    selected: _selectedStatus == 'in_progress',
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'in_progress' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 400.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _selectedStatus == 'completed',
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'completed' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 500.ms,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  */

  Widget _buildTestsList() {
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (testsByStatus['assigned']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Assigned Tests',
            testsByStatus['assigned'],
            AppTheme.primaryBlue,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['collected']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Collected Samples',
            testsByStatus['collected'],
            AppTheme.secondaryTeal,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['in_progress']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'In Progress',
            testsByStatus['in_progress'],
            AppTheme.warningYellow,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['completed']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Completed',
            testsByStatus['completed'],
            AppTheme.successGreen,
          ),
        ],
      ],
    );
  }

  Widget _buildTestsGroup(String title, List tests, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(tests.length.toString()),
              backgroundColor: color.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tests.map((test) => _buildTestCard(test)),
      ],
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final status = test['status'] as String? ?? 'pending';
    final sampleCollected = test['sample_collected'] as bool? ?? false;
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patient = test['patient'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'N/A';
    final deviceName = test['device']?['name'] as String?;

    // For completed tests, use ExpansionTile to show results
    if (status == 'completed') {
      return AnimatedCard(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
            child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
          ),
          title: Text(testName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: $patientName'),
              if (deviceName != null) Text('Device: $deviceName'),
            ],
          ),
          children: [
            // Test Results Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Results',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildResultDisplay(test),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For non-completed tests, use custom Row layout
    final actionButton = _buildActionButton(test, status, sampleCollected);
    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
              child: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    testName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Patient: $patientName',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (deviceName != null)
                    SelectableText(
                      'Device: $deviceName',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                ],
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(width: 8),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultDisplay(Map<String, dynamic> test) {
    final result = test['result'] as Map<String, dynamic>?;

    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No results available.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    final hasComponents = result['has_components'] as bool? ?? false;
    final isAbnormal = result['is_abnormal'] as bool? ?? false;

    if (hasComponents) {
      // Display results with components
      final components = result['components'] as List<dynamic>? ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAbnormal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: AppTheme.errorRed, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Abnormal Results',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ...components.map((component) {
            final componentName =
                component['component_name'] as String? ?? 'Unknown';
            final value = component['component_value'] as String? ?? 'N/A';
            final units = component['units'] as String? ?? '';
            final referenceRange =
                component['reference_range'] as String? ?? '';
            final isComponentAbnormal =
                component['is_abnormal'] as bool? ?? false;
            final remarks = component['remarks'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isComponentAbnormal
                    ? AppTheme.errorRed.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isComponentAbnormal
                      ? AppTheme.errorRed.withValues(alpha: 0.3)
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          componentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isComponentAbnormal)
                        const Icon(
                          Icons.warning,
                          color: AppTheme.errorRed,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Result: $value ${units.isNotEmpty ? units : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isComponentAbnormal
                              ? AppTheme.errorRed
                              : Colors.black,
                          fontWeight: isComponentAbnormal
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (referenceRange.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reference: $referenceRange',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Remarks: $remarks',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      );
    } else {
      // Display simple result without components
      final resultValue = result['result_value'] as String? ?? 'N/A';
      final units = result['units'] as String? ?? '';
      final referenceRange = result['reference_range'] as String? ?? '';
      final remarks = result['remarks'] as String? ?? '';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAbnormal
              ? AppTheme.errorRed.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAbnormal
                ? AppTheme.errorRed.withValues(alpha: 0.3)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAbnormal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: AppTheme.errorRed, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Abnormal Result',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Result: $resultValue ${units.isNotEmpty ? units : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAbnormal ? AppTheme.errorRed : Colors.black,
              ),
            ),
            if (referenceRange.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Reference Range: $referenceRange',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: $remarks',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget? _buildActionButton(
    Map<String, dynamic> test,
    String status,
    bool sampleCollected,
  ) {
    final testId = test['_id']?.toString();
    if (status == 'assigned' && !sampleCollected) {
      return AnimatedButton(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.science, size: 16),
          label: const Text('Collect'),
          onPressed: testId != null && testId.isNotEmpty
              ? () => _collectSample(testId)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryTeal,
          ),
        ),
      );
    } else if (status == 'collected' || status == 'in_progress') {
      return AnimatedButton(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Upload'),
          onPressed: testId != null && testId.isNotEmpty
              ? () => _showUploadResultDialog(test)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      );
    } else if (status == 'completed') {
      return const Icon(Icons.check_circle, color: AppTheme.successGreen);
    }
    return null;
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment;
      case 'collected':
        return Icons.science;
      case 'in_progress':
        return Icons.pending;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 24);
        final labelFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          14,
        );
        final valueFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          28,
        );
        final padding = ResponsiveUtils.getResponsiveSpacing(context, 24);
        final iconPadding = ResponsiveUtils.getResponsiveSpacing(context, 10);

        return Container(
          width: 200,
          padding: EdgeInsets.all(padding),
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
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: iconSize),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16),
              ),
              SelectableText(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 8),
              ),
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
      },
    );
  }

  void _showNotificationsDialog() async {
    // Refresh upload results before showing notifications
    // This ensures completed HL7 simulations are removed from the upload list
    if (!_isResultsForUploadLoading) {
      await _loadResultsForUpload();
    }

    try {
      final authProvider = Provider.of<StaffAuthProvider>(
        context,
        listen: false,
      );
      final response = await StaffApiService.getNotifications(
        authProvider.staffId ?? '',
      );
      final notifications = response as List? ?? [];
      final total = notifications.length;

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
                                        '/staff/notifications/${authProvider.staffId}/${notification['_id']?.toString() ?? ''}/read',
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
                                      '/staff/notifications/${authProvider.staffId}/${notification['_id']?.toString() ?? ''}/read',
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(dialogContext);

              // Perform logout
              final authProvider = Provider.of<StaffAuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout();

              // Navigate to home using named route
              if (context.mounted) {
                context.goNamed('home');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
