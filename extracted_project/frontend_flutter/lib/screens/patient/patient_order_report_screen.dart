import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';

class PatientOrderReportScreen extends StatefulWidget {
  final String orderId;

  const PatientOrderReportScreen({super.key, required this.orderId});

  @override
  State<PatientOrderReportScreen> createState() =>
      _PatientOrderReportScreenState();
}

class _PatientOrderReportScreenState extends State<PatientOrderReportScreen> {
  List<dynamic> _results = [];
  Map<String, dynamic>? _orderInfo;
  bool _isLoading = true;
  String? _error;
  bool _hasAbnormalResults = false;
  int _abnormalCount = 0;

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
      final response = await PatientApiService.getOrderResults(widget.orderId);

      if (mounted) {
        setState(() {
          _results = response['results'] ?? [];
          _orderInfo = response['order'];
          _isLoading = false;

          // Check for abnormal results
          _hasAbnormalResults = false;
          _abnormalCount = 0;

          for (final result in _results) {
            final hasComponents = result['has_components'] == true;
            if (hasComponents) {
              final components = result['components'] as List<dynamic>? ?? [];
              for (final component in components) {
                if (component['is_abnormal'] == true) {
                  _hasAbnormalResults = true;
                  _abnormalCount++;
                }
              }
            } else {
              // For single-value tests, check if result indicates abnormality
              final resultValue = result['test_result']?.toString() ?? '';
              if (resultValue.contains('High') ||
                  resultValue.contains('Low') ||
                  resultValue.contains('Abnormal')) {
                _hasAbnormalResults = true;
                _abnormalCount++;
              }
            }
          }
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Laboratory Report',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading && _error == null && _results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download PDF',
              onPressed: () => _generatePdf(authProvider),
            ),
        ],
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
                    'Error loading report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadOrderResults,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildReportContent(authProvider),
    );
  }

  Widget _buildReportContent(PatientAuthProvider authProvider) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results available for this order',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // Calculate overall status based on all tests
    final totalTests = _results.length;
    final completedTests = _results
        .where((r) => r['status'] == 'completed')
        .length;
    final inProgressTests = _results
        .where((r) => r['status'] == 'in_progress')
        .length;

    // Overall status logic:
    // - If all tests are completed -> completed
    // - If any test is in progress -> in_progress
    // - Otherwise -> pending
    String overallStatus;
    if (completedTests == totalTests) {
      overallStatus = 'completed';
    } else if (inProgressTests > 0) {
      overallStatus = 'in_progress';
    } else {
      overallStatus = 'pending';
    }

    // Get date range for all tests
    final reportDates =
        _results
            .map((result) => result['createdAt']?.substring(0, 10))
            .where((date) => date != null)
            .toSet()
            .toList()
          ..sort();

    final reportDateRange = reportDates.isNotEmpty
        ? (reportDates.length == 1
              ? reportDates.first
              : '${reportDates.first} - ${reportDates.last}')
        : 'N/A';

    // Collect all remarks
    final allRemarks = _results
        .where(
          (result) =>
              result['remarks'] != null &&
              result['remarks'].toString().isNotEmpty,
        )
        .map((result) => result['remarks'])
        .join('\n\n');

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 16,
          vertical: 16,
        ),
        child: Column(
          children: [
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
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
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
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            28,
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            12,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ResponsiveText(
                                _orderInfo?['lab_name'] ?? 'Medical Laboratory',
                                style: AppTheme.medicalTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              if (_orderInfo?['lab_address'] != null)
                                Text(
                                  _orderInfo!['lab_address'],
                                  style: AppTheme.medicalTextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              if (_orderInfo?['lab_phone'] != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: AppTheme.textMedium,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _orderInfo!['lab_phone'],
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Laboratory Test Report',
                                style: AppTheme.medicalTextStyle(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(overallStatus),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getStatusText(overallStatus),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedTests/$totalTests Completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Abnormal Results Warning Banner
                  if (_hasAbnormalResults)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[700],
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CRITICAL: Abnormal Results Detected',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_abnormalCount abnormal value(s) found. Please contact your healthcare provider immediately for interpretation and next steps.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[800],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Patient Information Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Information',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Row 1: Patient Name only
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Patient Name',
                                _getPatientFullName(authProvider.user),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 2: ID Number and Gender
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'ID Number',
                                authProvider.user?.identityNumber ?? '-',
                              ),
                            ),
                            Expanded(
                              child: _buildInfoRow(
                                'Gender',
                                authProvider.user?.gender ?? '-',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 3: Date of Birth and Insurance
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Date of Birth',
                                authProvider.user?.birthday != null
                                    ? '${authProvider.user!.birthday!.day.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.month.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.year}'
                                    : '-',
                              ),
                            ),
                            Expanded(
                              child: _buildInfoRow(
                                'Insurance',
                                authProvider.user?.insuranceProvider ?? 'None',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 4: Order Date
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Order Date',
                                _orderInfo?['order_date']?.substring(0, 10) ??
                                    'N/A',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 5: Report Date and Doctor
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Report Date${reportDates.length > 1 ? 's' : ''}',
                                reportDateRange,
                              ),
                            ),
                            Expanded(
                              child: _buildInfoRow(
                                'Doctor',
                                _orderInfo?['doctor_name'] ?? 'Not assigned',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Test Results Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Results',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Results Table
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.05,
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Test Name',
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Result',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Reference',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Unit',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Rows
                              ..._results.map((result) {
                                final hasComponents =
                                    result['has_components'] == true;
                                final components =
                                    result['components'] as List<dynamic>? ??
                                    [];

                                if (hasComponents && components.isNotEmpty) {
                                  // Multi-component test - show expandable row
                                  return _buildExpandableResultRow(
                                    result['test_name'] ?? 'Unknown Test',
                                    components,
                                    result['status'] ?? 'pending',
                                    result['remarks'],
                                    result['staff'],
                                  );
                                } else {
                                  // Single-value test - show simple row
                                  return _buildResultRow(
                                    result['test_name'] ?? 'Unknown Test',
                                    result['test_result']?.toString() ?? 'N/A',
                                    result['reference_range'] ?? 'N/A',
                                    result['units'] ?? 'N/A',
                                    result['status'] ?? 'pending',
                                    result['staff'],
                                  );
                                }
                              }),
                            ],
                          ),
                        ),

                        // Remarks Section
                        if (allRemarks.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.note_alt_outlined,
                                      color: Colors.orange[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Remarks',
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  allRemarks,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textDark,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Footer
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Important Notice',
                                style: AppTheme.medicalTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• These results should be interpreted by your healthcare provider\n'
                                '• Keep this report for your medical records\n'
                                '• Contact your doctor if you have any questions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMedium,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.medicalTextStyle(
              fontSize: 12,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.medicalTextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    String testName,
    String result,
    String reference,
    String unit,
    String status,
    Map<String, dynamic>? staff,
  ) {
    // Determine display text and color based on status
    String displayResult;
    Color statusColor;

    if (status == 'completed') {
      displayResult = result;
      final bool isAbnormal = result != 'Normal' && result != 'N/A';
      statusColor = isAbnormal ? Colors.orange[700]! : Colors.green[700]!;
    } else if (status == 'in_progress') {
      displayResult = 'In Progress';
      statusColor = Colors.orange[700]!;
    } else {
      displayResult = 'Pending';
      statusColor = Colors.grey[600]!;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        color: status != 'completed'
            ? Colors.grey.withValues(alpha: 0.05)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (status != 'completed')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      status == 'in_progress'
                          ? Icons.hourglass_empty
                          : Icons.schedule,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: AppTheme.medicalTextStyle(
                          fontSize: 13,
                          color: AppTheme.textDark,
                        ),
                      ),
                      if (staff != null && staff['full_name'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Performed by: ${_buildStaffName(staff)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              displayResult,
              textAlign: TextAlign.center,
              style: status != 'completed'
                  ? TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontStyle: FontStyle.italic,
                    )
                  : AppTheme.medicalTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              reference,
              textAlign: TextAlign.center,
              style: AppTheme.medicalTextStyle(
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              unit
                  .replaceAll('μ', 'u')
                  .replaceAll('³', '3')
                  .replaceAll('⁶', '6')
                  .replaceAll('×', 'x'),
              textAlign: TextAlign.center,
              style: AppTheme.medicalTextStyle(
                fontSize: 13,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableResultRow(
    String testName,
    List<dynamic> components,
    String status,
    String? remarks,
    Map<String, dynamic>? staff,
  ) {
    return ExpansionTile(
      title: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testName,
                    style: AppTheme.medicalTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  if (staff != null && staff['full_name'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Performed by: ${_buildStaffName(staff)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${components.length} components',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Multiple',
                textAlign: TextAlign.center,
                style: AppTheme.medicalTextStyle(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'completed' ? 'Done' : status.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        // Component header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Component',
                  style: AppTheme.medicalTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Result',
                  textAlign: TextAlign.center,
                  style: AppTheme.medicalTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Reference',
                  textAlign: TextAlign.center,
                  style: AppTheme.medicalTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Unit',
                  textAlign: TextAlign.center,
                  style: AppTheme.medicalTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Component rows
        ...components.map((component) {
          final isAbnormal = component['is_abnormal'] == true;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isAbnormal
                  ? Colors.red.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.03),
              border: Border(
                left: BorderSide(
                  color: isAbnormal ? Colors.red[400]! : Colors.green[400]!,
                  width: 3,
                ),
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      if (isAbnormal)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[600],
                            size: 14,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          component['component_name'] ?? 'Unknown',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 12,
                            fontWeight: isAbnormal
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isAbnormal
                                ? Colors.red[900]
                                : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    component['component_value']?.toString() ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: AppTheme.medicalTextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAbnormal ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    component['reference_range'] ?? 'N/A',
                    textAlign: TextAlign.center,
                    style: AppTheme.medicalTextStyle(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    (component['units'] ?? 'N/A')
                        .replaceAll('μ', 'u')
                        .replaceAll('³', '3')
                        .replaceAll('⁶', '6')
                        .replaceAll('×', 'x'),
                    textAlign: TextAlign.center,
                    style: AppTheme.medicalTextStyle(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Remarks for the test
        if (remarks != null && remarks.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  color: Colors.orange[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remarks,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getPatientFullName(user) {
    if (user?.fullName != null) {
      final first = user!.fullName!.first;
      final middle = user.fullName!.middle;
      final last = user.fullName!.last;

      final nameParts = [first];
      if (middle != null && middle.isNotEmpty) {
        nameParts.add(middle);
      }
      nameParts.add(last);

      return nameParts.join(' ');
    }
    return user?.email ?? 'N/A';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'COMPLETED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'pending':
        return 'PENDING';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> _generatePdf(PatientAuthProvider authProvider) async {
    final pdf = pw.Document();

    // Collect all remarks
    final allRemarks = _results
        .where(
          (result) =>
              result['remarks'] != null &&
              result['remarks'].toString().isNotEmpty,
        )
        .map((result) => result['remarks'])
        .join('\n\n');

    // Check for abnormal results
    bool hasAbnormalResults = false;
    int abnormalCount = 0;
    for (final result in _results) {
      final hasComponents = result['has_components'] == true;
      if (hasComponents) {
        final components = result['components'] as List<dynamic>? ?? [];
        for (final component in components) {
          if (component['is_abnormal'] == true) {
            hasAbnormalResults = true;
            abnormalCount++;
          }
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _orderInfo?['lab_name'] ?? 'Medical Laboratory',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          if (_orderInfo?['lab_address'] != null)
                            pw.Text(
                              _orderInfo!['lab_address'],
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Laboratory Test Report',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'Order #${_orderInfo?['_id'] ?? 'N/A'}',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Critical Results Warning
            if (hasAbnormalResults) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                margin: const pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red50,
                  border: pw.Border.all(color: PdfColors.red, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'CRITICAL RESULTS',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '$abnormalCount abnormal value(s) detected. Please contact your healthcare provider immediately for interpretation and next steps.',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Patient Information
            pw.Text(
              'Patient Information',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildPdfRow(
                  'Patient Name',
                  _getPatientFullName(authProvider.user),
                ),
                _buildPdfRow(
                  'ID Number',
                  authProvider.user?.identityNumber ?? '-',
                ),
                _buildPdfRow('Gender', authProvider.user?.gender ?? '-'),
                _buildPdfRow(
                  'Date of Birth',
                  authProvider.user?.birthday != null
                      ? '${authProvider.user!.birthday!.day.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.month.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.year}'
                      : '-',
                ),
                _buildPdfRow(
                  'Insurance',
                  authProvider.user?.insuranceProvider ?? 'None',
                ),
                _buildPdfRow(
                  'Order Date',
                  _orderInfo?['order_date']?.substring(0, 10) ?? 'N/A',
                ),
                _buildPdfRow(
                  'Doctor',
                  _orderInfo?['doctor_name'] ?? 'Not assigned',
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Test Results
            pw.Text(
              'Test Results',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfHeaderCell('Test Name'),
                    _buildPdfHeaderCell('Result'),
                    _buildPdfHeaderCell('Reference Range'),
                    _buildPdfHeaderCell('Unit'),
                  ],
                ),
                ..._results.expand((result) {
                  final hasComponents = result['has_components'] == true;
                  final components =
                      result['components'] as List<dynamic>? ?? [];

                  if (hasComponents && components.isNotEmpty) {
                    // Multi-component test - create main row + component rows
                    final rows = <pw.TableRow>[];

                    // Main test row
                    rows.add(
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue50,
                        ),
                        children: [
                          _buildPdfCell(
                            '${result['test_name'] ?? 'Unknown Test'} (${components.length} components)',
                          ),
                          _buildPdfCell('Multiple Values'),
                          _buildPdfCell('Component-specific'),
                          _buildPdfCell('Various'),
                        ],
                      ),
                    );

                    // Component rows
                    for (final component in components) {
                      final isAbnormal = component['is_abnormal'] == true;
                      rows.add(
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isAbnormal
                                ? PdfColors.red50
                                : PdfColors.green50,
                            border: pw.Border.all(
                              color: isAbnormal
                                  ? PdfColors.red200
                                  : PdfColors.green200,
                              width: 0.5,
                            ),
                          ),
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Row(
                                children: [
                                  if (isAbnormal)
                                    pw.Container(
                                      margin: const pw.EdgeInsets.only(
                                        right: 4,
                                      ),
                                      child: pw.Text(
                                        'WARNING',
                                        style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.red,
                                        ),
                                      ),
                                    ),
                                  pw.Text(
                                    '  - ${component['component_name'] ?? 'Unknown'}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: isAbnormal
                                          ? pw.FontWeight.bold
                                          : pw.FontWeight.normal,
                                      color: isAbnormal
                                          ? PdfColors.red900
                                          : PdfColors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                component['component_value']?.toString() ??
                                    'N/A',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isAbnormal
                                      ? PdfColors.red
                                      : PdfColors.green,
                                ),
                              ),
                            ),
                            _buildPdfCell(
                              component['reference_range'] ?? 'N/A',
                            ),
                            _buildPdfCell(
                              (component['units'] ?? 'N/A')
                                  .replaceAll('μ', 'u')
                                  .replaceAll('³', '3')
                                  .replaceAll('⁶', '6')
                                  .replaceAll('×', 'x'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Add remarks row if present
                    final remarks = result['remarks'];
                    if (remarks != null && remarks.toString().isNotEmpty) {
                      rows.add(
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.orange50,
                          ),
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Remarks: $remarks',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ),
                            _buildPdfCell(''),
                            _buildPdfCell(''),
                            _buildPdfCell(''),
                          ],
                        ),
                      );
                    }

                    return rows;
                  } else {
                    // Single-value test - simple row
                    return [
                      pw.TableRow(
                        children: [
                          _buildPdfCell(result['test_name'] ?? 'Unknown Test'),
                          _buildPdfCell(
                            result['test_result']?.toString() ?? 'N/A',
                          ),
                          _buildPdfCell(result['reference_range'] ?? 'N/A'),
                          _buildPdfCell(
                            result['units'] ??
                                'N/A'
                                    .replaceAll('μ', 'u')
                                    .replaceAll('³', '3')
                                    .replaceAll('⁶', '6')
                                    .replaceAll('×', 'x'),
                          ),
                        ],
                      ),
                    ];
                  }
                }),
              ],
            ),

            // Remarks
            if (allRemarks.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  border: pw.Border.all(color: PdfColors.orange200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Remarks',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      allRemarks,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Footer
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Important Notice',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '- These results should be interpreted by your healthcare provider\n'
                    '- Keep this report for your medical records\n'
                    '- Contact your doctor if you have any questions',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Report generated timestamp
            pw.SizedBox(height: 10),
            pw.Text(
              'Report generated on: ${DateTime.now().toString().substring(0, 19)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    // Show PDF preview and print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laboratory_Report_${_orderInfo?['_id'] ?? 'N/A'}.pdf',
    );
  }

  pw.TableRow _buildPdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  String _buildStaffName(Map<String, dynamic> staff) {
    final fullName = staff['full_name'];
    if (fullName is Map<String, dynamic>) {
      final first = fullName['first'] ?? '';
      final middle = fullName['middle'] ?? '';
      final last = fullName['last'] ?? '';
      final parts = [
        first,
        middle,
        last,
      ].where((part) => part.isNotEmpty).toList();
      return parts.isEmpty ? 'Unknown Staff' : parts.join(' ');
    } else if (fullName is String) {
      return fullName;
    }
    return 'Unknown Staff';
  }
}
