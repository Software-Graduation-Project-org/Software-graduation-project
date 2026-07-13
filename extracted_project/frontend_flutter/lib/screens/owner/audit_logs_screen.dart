import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../config/theme.dart';
import '../../widgets/common/navbar.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String? _error;
  String _selectedAction = 'all';
  String _selectedStaff = 'all';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await ApiService.get(ApiConfig.ownerAuditLogs);

      setState(() {
        _auditLogs = List<Map<String, dynamic>>.from(
          response['auditLogs'] ?? [],
        );
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load audit logs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    List<Map<String, dynamic>> filtered = _auditLogs;

    // Filter by action
    if (_selectedAction != 'all') {
      filtered = filtered
          .where((log) => log['action'] == _selectedAction)
          .toList();
    }

    // Filter by staff
    if (_selectedStaff != 'all') {
      filtered = filtered
          .where((log) => log['staff_name'] == _selectedStaff)
          .toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filtered = filtered.where((log) {
        final logDate = DateTime.parse(
          log['timestamp'] ?? DateTime.now().toIso8601String(),
        );
        return logDate.isAfter(
              _dateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            logDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by timestamp (newest first)
    filtered.sort((a, b) {
      final dateA = DateTime.parse(
        a['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      final dateB = DateTime.parse(
        b['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  List<String> get _uniqueActions {
    final actions = _auditLogs
        .map((log) => log['action'] as String?)
        .where((action) => action != null)
        .toSet();
    return ['all', ...actions.whereType<String>()];
  }

  List<String> get _uniqueStaff {
    final staff = _auditLogs
        .map((log) => log['staff_name'] as String?)
        .where((staffName) => staffName != null)
        .toSet();
    return ['all', ...staff.whereType<String>()];
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'create':
      case 'add':
        return Colors.green;
      case 'update':
      case 'edit':
        return Colors.blue;
      case 'delete':
      case 'remove':
        return Colors.red;
      case 'login':
        return Colors.purple;
      case 'logout':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toLowerCase()) {
      case 'create':
      case 'add':
        return Icons.add_circle;
      case 'update':
      case 'edit':
        return Icons.edit;
      case 'delete':
      case 'remove':
        return Icons.delete;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy HH:mm:ss').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getRelativeTime(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks > 1 ? 's' : ''} ago';
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
              title: const Text('Audit Logs'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
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
                  Text(
                    'Audit Logs',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Track all system activities and changes',
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
                    // Filters Row
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedAction,
                            underline: const SizedBox(),
                            hint: const Text('Action'),
                            items: _uniqueActions.map((action) {
                              return DropdownMenuItem(
                                value: action,
                                child: Text(
                                  action == 'all'
                                      ? 'All Actions'
                                      : action.toUpperCase(),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedAction = value!);
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedStaff,
                            underline: const SizedBox(),
                            hint: const Text('Staff'),
                            items: _uniqueStaff.map((staff) {
                              return DropdownMenuItem(
                                value: staff,
                                child: Text(
                                  staff == 'all' ? 'All Staff' : staff,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedStaff = value!);
                            },
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(isMobile ? 'Date' : 'Date Range'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryBlue,
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
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
                    if (_dateRange != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Date Range: ${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.blue),
                              onPressed: () =>
                                  setState(() => _dateRange = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Stats Cards
                    _buildStatsCards(isMobile),
                    const SizedBox(height: 24),

                    // Audit Logs List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
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
                                      onPressed: _loadAuditLogs,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _filteredLogs.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedAction == 'all' &&
                                              _selectedStaff == 'all' &&
                                              _dateRange == null
                                          ? 'No audit logs found'
                                          : 'No logs match your filters',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _buildAuditLogsList(isMobile),
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
    final totalLogs = _auditLogs.length;
    final todayLogs = _auditLogs.where((log) {
      final logDate = DateTime.parse(
        log['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      final today = DateTime.now();
      return logDate.year == today.year &&
          logDate.month == today.month &&
          logDate.day == today.day;
    }).length;

    final uniqueUsers = _uniqueStaff.where((staff) => staff != 'all').length;

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Logs',
          totalLogs.toString(),
          Icons.history,
          AppTheme.primaryBlue,
        ),
        _buildStatCard(
          'Today\'s Activity',
          todayLogs.toString(),
          Icons.today,
          Colors.green,
        ),
        _buildStatCard(
          'Active Users',
          uniqueUsers.toString(),
          Icons.people,
          Colors.orange,
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

  Widget _buildAuditLogsList(bool isMobile) {
    return ListView.builder(
      itemCount: _filteredLogs.length,
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        final action = log['action'] ?? 'unknown';

        return AnimatedCard(
          onTap: () => _showLogDetails(log),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getActionColor(action).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getActionIcon(action),
                        color: _getActionColor(action),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['message'] ?? 'Unknown action',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${log['staff_name'] ?? 'Unknown user'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
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
                        color: _getActionColor(action).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        action.toUpperCase(),
                        style: TextStyle(
                          color: _getActionColor(action),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Table: ${log['table_name'] ?? 'Unknown'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          if (log['record_id'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Record ID: ${log['record_id']}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _getRelativeTime(log['timestamp']),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getActionIcon(log['action'] ?? 'unknown'),
              color: _getActionColor(log['action'] ?? 'unknown'),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Audit Log Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Action',
                (log['action'] ?? 'unknown').toUpperCase(),
              ),
              _buildDetailRow('User', log['username'] ?? 'Unknown'),
              _buildDetailRow('Table', log['table_name'] ?? 'Unknown'),
              if (log['record_id'] != null)
                _buildDetailRow('Record ID', log['record_id'].toString()),
              _buildDetailRow('Timestamp', _formatDate(log['timestamp'])),
              const SizedBox(height: 16),
              const Text(
                'Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log['message'] ?? 'No message available',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
