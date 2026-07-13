import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';

class OwnerOrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OwnerOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OwnerOrderDetailsScreen> createState() =>
      _OwnerOrderDetailsScreenState();
}

class _OwnerOrderDetailsScreenState extends State<OwnerOrderDetailsScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await OwnerApiService.getOrderById(widget.orderId);
      if (mounted) {
        setState(() {
          _order = response;
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
          'Order Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/owner/dashboard/orders');
            }
          },
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
                    'Error loading order details',
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
                    onPressed: _loadOrderDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _order == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No order information available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
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
                    _buildOrderHeader(),
                    const SizedBox(height: 20),
                    _buildPatientInfo(),
                    const SizedBox(height: 20),
                    _buildTestList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderHeader() {
    final order = _order!;
    final orderDate = order['order_date'] != null
        ? DateTime.parse(order['order_date'])
        : DateTime.now();
    final status = order['status'] ?? 'unknown';
    final testCount = order['test_count'] ?? 0;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Information',
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
                    Icons.receipt_long,
                    order['_id']?.toString().substring(0, 8) ?? 'N/A',
                    'Order ID',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.calendar_today,
                    DateFormat('MMM dd, yyyy').format(orderDate),
                    'Order Date',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(Icons.science, '$testCount', 'Tests'),
                ),
                Expanded(child: _buildStatusChip(status)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfo() {
    final order = _order!;
    final patient = order['patient'];

    return Container(
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
      child: Padding(
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
            if (patient != null && patient is Map<String, dynamic>) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.person,
                      _formatFullName(patient['name']),
                      'Patient Name',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.badge,
                      patient['patient_id']?.toString() ?? 'N/A',
                      'ID Number',
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'No patient information available',
                style: TextStyle(
                  color: AppTheme.textMedium,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestList() {
    final order = _order!;
    final testDetails = order['order_details'] as List<dynamic>? ?? [];

    return Container(
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
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: AppTheme.successGreen, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Tests',
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
              children: testDetails.isEmpty
                  ? [
                      const Text(
                        'No test details available',
                        style: TextStyle(
                          color: AppTheme.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]
                  : testDetails.map((detail) {
                      return _buildTestItem(detail);
                    }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(dynamic detail) {
    final testName = detail['test_name'] ?? 'Unknown Test';
    final testCode = detail['test_code'] ?? '';
    final status = detail['status'] ?? 'pending';
    final hasResult = detail['has_result'] ?? false;
    final hasComponents = detail['has_components'] ?? false;
    final components = detail['components'] as List<dynamic>? ?? [];
    final staffName = detail['staff_name'] != null
        ? _formatFullName(detail['staff_name'])
        : 'Unassigned';
    final staffEmployeeNumber = detail['staff_employee_number'] ?? '';

    // For backward compatibility with tests without components
    final resultValue = detail['result_value'];
    final resultUnits = detail['result_units'];
    final resultReferenceRange = detail['result_reference_range'];
    final resultRemarks = detail['result_remarks'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
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
                    const SizedBox(height: 4),
                    _buildStatusChip(status),
                    const SizedBox(height: 4),
                    Text(
                      staffName == 'Unassigned'
                          ? 'Assigned Staff: Unassigned'
                          : 'Assigned Staff: $staffName',
                      style: TextStyle(
                        fontSize: 12,
                        color: staffName == 'Unassigned'
                            ? Colors.orange[700]
                            : AppTheme.primaryBlue,
                        fontWeight: staffName == 'Unassigned'
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                    if (staffEmployeeNumber.isNotEmpty) ...[
                      Text(
                        'Employee #: $staffEmployeeNumber',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // Results Section (show if test is completed)
          if (status == 'completed') ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Test Results',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            // Display components if test has them
            if (hasComponents && components.isNotEmpty) ...[
              ...components.map(
                (component) => _buildComponentResult(component),
              ),
            ] else if (hasComponents && components.isEmpty) ...[
              // Test has components but no results yet
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red[300]!, width: 1),
                ),
                child: const Text(
                  'Component results unavailable - please contact support',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              // Test without components - show single result
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasResult && resultValue != null
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasResult && resultValue != null
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                    width: 1,
                  ),
                ),
                child: hasResult && resultValue != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Value: $resultValue ${resultUnits ?? ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (resultReferenceRange != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reference: $resultReferenceRange',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                          if (resultRemarks != null &&
                              resultRemarks.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Remarks: $resultRemarks',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMedium,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      )
                    : const Text(
                        'Result data unavailable - please contact support',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildComponentResult(dynamic component) {
    final componentName = component['component_name'] ?? 'Unknown Component';
    final componentCode = component['component_code'] ?? '';
    final componentValue = component['component_value'];
    final units = component['units'];
    final referenceRange = component['reference_range'];
    final isAbnormal = component['is_abnormal'] ?? false;
    final remarks = component['remarks'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isAbnormal ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAbnormal ? Colors.red[300]! : Colors.green[300]!,
          width: 1,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              if (componentCode.isNotEmpty)
                Text(
                  '($componentCode)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Value: $componentValue ${units ?? ''}',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (referenceRange != null && referenceRange.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Reference: $referenceRange',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMedium),
            ),
          ],
          if (remarks != null && remarks.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Remarks: $remarks',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMedium,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isAbnormal) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'ABNORMAL',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = AppTheme.successGreen.withValues(alpha: 0.1);
        textColor = AppTheme.successGreen;
        displayText = 'Completed';
        break;
      case 'in_progress':
        backgroundColor = AppTheme.primaryBlue.withValues(alpha: 0.1);
        textColor = AppTheme.primaryBlue;
        displayText = 'In Progress';
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[800]!;
        displayText = 'Pending';
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey[600]!;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
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

  String _formatFullName(dynamic fullName) {
    if (fullName == null) return 'N/A';

    if (fullName is Map<String, dynamic>) {
      final first = fullName['first']?.toString() ?? '';
      final middle = fullName['middle']?.toString() ?? '';
      final last = fullName['last']?.toString() ?? '';

      // Format as "First Middle Last" or "First Last"
      final parts = [
        first,
        if (middle.isNotEmpty) middle,
        last,
      ].where((part) => part.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.join(' ') : 'N/A';
    }

    // Fallback for string values
    return fullName.toString();
  }
}
