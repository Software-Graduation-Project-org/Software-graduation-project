import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/staff_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/staff_auth_provider.dart';

class StaffOrderResultsScreen extends StatefulWidget {
  final String orderId;

  const StaffOrderResultsScreen({super.key, required this.orderId});

  @override
  State<StaffOrderResultsScreen> createState() =>
      _StaffOrderResultsScreenState();
}

class _StaffOrderResultsScreenState extends State<StaffOrderResultsScreen> {
  Map<String, dynamic>? _orderInfo;
  List<dynamic> _results = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderResults();
  }

  Future<void> _loadOrderResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await StaffApiService.getOrderResultsReport(
        widget.orderId,
      );

      // Debug: Log the full API response
      // print('🔍 FRONTEND DEBUG: Order results response for ${widget.orderId}:');
      // print('Order info: ${response['order']}');
      // print('Results count: ${response['results']?.length ?? 0}');
      // response['results']?.forEach((result) {
      //   print(
      //     'Test: ${result['test_name']}, Status: ${result['status']}, Result: "${result['test_result']}", Has Result: ${result['result'] != null}',
      //   );
      // });

      if (mounted) {
        setState(() {
          _orderInfo = response['order'];
          _results = response['results'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Order Results',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading order results',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadOrderResults,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results available for this order',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            )
          : AppAnimations.pageDepthTransition(
              SingleChildScrollView(
                padding: ResponsiveUtils.getResponsivePadding(
                  context,
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // Header Card
                    Container(
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
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_hospital,
                                  color: AppTheme.primaryBlue,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _orderInfo?['owner_id']?['lab_name'] ??
                                            'Medical Laboratory',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                      if (_orderInfo?['owner_id']?['address'] !=
                                          null)
                                        Text(
                                          _orderInfo!['owner_id']['address'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMedium,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Laboratory Report',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Order #${_orderInfo?['order_id']?.toString().substring(0, 8) ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    if (_orderInfo?['order_date'] != null)
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(
                                          DateTime.parse(
                                            _orderInfo!['order_date'],
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Patient Info Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patient Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.person,
                                        _orderInfo?['patient_info']?['name'] ??
                                            'N/A',
                                        'Patient Name',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.badge,
                                        _orderInfo?['patient_info']?['patient_id'] ??
                                            'N/A',
                                        'ID Number',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.phone,
                                        _orderInfo?['patient_info']?['phone_number']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? _orderInfo!['patient_info']['phone_number']
                                            : 'Not provided',
                                        'Phone',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.email,
                                        _orderInfo?['patient_info']?['email']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? _orderInfo!['patient_info']['email']
                                            : 'Not provided',
                                        'Email',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Doctor Info Section
                          if (_orderInfo?['doctor_name'] != null &&
                              _orderInfo?['doctor_name'] != '-')
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Referring Doctor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoItem(
                                    Icons.medical_services,
                                    _orderInfo?['doctor_name'] ??
                                        'Not Assigned',
                                    'Doctor Name',
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Test Results Section
                    Container(
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.science,
                                  color: AppTheme.successGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Test Results',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: _buildTestResultsList(_results),
                            ),
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

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTestResultsList(List<dynamic> results) {
    return results.map((result) {
      final testName = result['test_name'] ?? 'Unknown Test';
      final testCode = result['test_code'] ?? '';
      final status = result['status'] ?? 'pending';
      final hasComponents = result['has_components'] == true;
      final components = result['components'] as List<dynamic>? ?? [];

      Color statusColor;
      IconData statusIcon;

      switch (status) {
        case 'completed':
          statusColor = AppTheme.successGreen;
          statusIcon = Icons.check_circle;
          break;
        case 'in_progress':
          statusColor = AppTheme.warningYellow;
          statusIcon = Icons.hourglass_top;
          break;
        default:
          statusColor = Colors.grey;
          statusIcon = Icons.schedule;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (testCode.isNotEmpty)
                        Text(
                          'Code: $testCode',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final authProvider = Provider.of<StaffAuthProvider>(
                            context,
                            listen: false,
                          );
                          final currentUserId = authProvider.user?.id;
                          final staffId = result['staff_id'];
                          final isAssignedToMe =
                              staffId != null && staffId == currentUserId;

                          final displayName =
                              result['staff_name'] != null &&
                                  result['staff_name'] != 'Unassigned'
                              ? (isAssignedToMe ? 'You' : result['staff_name'])
                              : 'Unassigned';

                          return Text(
                            'Staff: $displayName',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  result['staff_name'] != null &&
                                      result['staff_name'] != 'Unassigned'
                                  ? AppTheme.primaryBlue
                                  : AppTheme.accentOrange,
                              fontWeight:
                                  result['staff_name'] != null &&
                                      result['staff_name'] != 'Unassigned'
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (hasComponents && components.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Components:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...components.map(
                (component) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              component['component_name'] ??
                                  'Unknown Component',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (component['unit'] != null)
                              Text(
                                'Unit: ${component['unit']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            component['component_value']?.toString() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: component['is_abnormal'] == true
                                  ? Colors.red[700]
                                  : AppTheme.successGreen,
                            ),
                          ),
                          if (component['reference_range'] != null)
                            Text(
                              component['reference_range'],
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMedium,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!hasComponents) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Result',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    // Debug: Log what test_result value is being displayed
                    Builder(
                      builder: (context) {
                        final displayValue =
                            result['test_result']?.toString() ?? 'N/A';
                        // print(
                        //   '🔍 FRONTEND DEBUG: Displaying result for ${result['test_name']}: "${result['test_result']}" -> "$displayValue"',
                        // );
                        return Text(
                          displayValue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            if (result['remarks'] != null &&
                result['remarks'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result['remarks'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}
