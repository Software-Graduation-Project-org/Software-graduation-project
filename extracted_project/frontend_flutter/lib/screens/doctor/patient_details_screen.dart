import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../services/doctor_api_service.dart';
import '../../providers/doctor_auth_provider.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDetailsScreen({super.key, required this.patient});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _patientDetails;
  List<dynamic> _testHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPatientDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientDetails() async {
    try {
      setState(() => _isLoading = true);

      final doctorProvider = Provider.of<DoctorAuthProvider>(
        context,
        listen: false,
      );
      final doctorId = doctorProvider.user?.id;

      if (doctorId == null) {
        throw Exception('Doctor ID not found');
      }

      // Load patient details and test history
      final detailsResponse = await DoctorApiService.getPatientDetails(
        widget.patient['_id'],
      );
      final historyResponse = await DoctorApiService.getPatientTestHistory(
        widget.patient['_id'],
      );

      setState(() {
        _patientDetails = detailsResponse['patient'];
        _testHistory = historyResponse['orders'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patient details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = _patientDetails ?? widget.patient;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${patient['full_name']?['first'] ?? ''} ${patient['full_name']?['last'] ?? ''}',
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPatientHeader(patient),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Details'),
                    Tab(text: 'Test History'),
                    Tab(text: 'Request Test'),
                  ],
                  labelColor: AppTheme.primaryBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryBlue,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDetailsTab(patient),
                      _buildTestHistoryTab(),
                      _buildRequestTestTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPatientHeader(Map<String, dynamic> patient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          AppAnimations.breathe(
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                patient['full_name']?['first']?[0]?.toUpperCase() ?? 'P',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '${patient['full_name']?['first'] ?? ''} ${patient['full_name']?['last'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  patient['email'] ?? 'No email',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  patient['phone'] ?? 'No phone',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> patient) {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.waveIn(
              AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'First Name',
                        patient['full_name']?['first'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        'Last Name',
                        patient['full_name']?['last'] ?? 'N/A',
                      ),
                      _buildInfoRow('Email', patient['email'] ?? 'N/A'),
                      _buildInfoRow('Phone', patient['phone'] ?? 'N/A'),
                      _buildInfoRow(
                        'Date of Birth',
                        patient['date_of_birth'] ?? 'N/A',
                      ),
                      _buildInfoRow('Gender', patient['gender'] ?? 'N/A'),
                      _buildInfoRow('Address', patient['address'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
              0,
            ),
            const SizedBox(height: 16),
            AppAnimations.waveIn(
              AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medical Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Blood Type',
                        patient['blood_type'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        'Allergies',
                        patient['allergies'] ?? 'None',
                      ),
                      _buildInfoRow(
                        'Medical History',
                        patient['medical_history'] ?? 'None',
                      ),
                    ],
                  ),
                ),
              ),
              1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestHistoryTab() {
    if (_testHistory.isEmpty) {
      return AppAnimations.pageDepthTransition(
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No test history found',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Process test results for display
    final allResults = <Map<String, dynamic>>[];
    final orderDates = <String>{};
    final reportDates = <String>{};
    final allRemarks = <String>[];

    for (final order in _testHistory) {
      for (final test in order['tests'] ?? []) {
        final result = {
          'test_name': test['test_name'] ?? 'Unknown Test',
          'test_result': test['result']?['value'] ?? '-',
          'reference_range': test['result']?['reference_range'] ?? '-',
          'units': test['result']?['units'] ?? '',
          'order_date': order['order_date'],
          'createdAt': test['result']?['date'] ?? order['order_date'],
          'remarks': test['result']?['remarks'] ?? '',
          'status': test['status'] ?? 'pending',
        };
        allResults.add(result);

        if (order['order_date'] != null) {
          orderDates.add(order['order_date'].substring(0, 10));
        }
        if (test['result']?['date'] != null) {
          reportDates.add(test['result']['date'].substring(0, 10));
        }
        if (test['result']?['remarks']?.isNotEmpty == true) {
          allRemarks.add(test['result']['remarks']);
        }
      }
    }

    // Determine overall status
    final hasInProgress = allResults.any(
      (result) => result['status'] == 'in_progress',
    );
    final hasCompleted = allResults.any(
      (result) => result['status'] == 'completed',
    );
    final overallStatus = hasInProgress
        ? 'in_progress'
        : (hasCompleted ? 'completed' : 'pending');

    // Format date ranges
    final sortedOrderDates = orderDates.toList()..sort();
    final sortedReportDates = reportDates.toList()..sort();

    final orderDateRange = sortedOrderDates.isNotEmpty
        ? (sortedOrderDates.length == 1
              ? sortedOrderDates.first
              : '${sortedOrderDates.first} - ${sortedOrderDates.last}')
        : 'N/A';
    final reportDateRange = sortedReportDates.isNotEmpty
        ? (sortedReportDates.length == 1
              ? sortedReportDates.first
              : '${sortedReportDates.first} - ${sortedReportDates.last}')
        : 'N/A';

    final remarksText = allRemarks.join('\n\n');

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
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
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laboratory Test Report',
                            style: AppTheme.medicalTextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          Text(
                            'Medical Lab System',
                            style: AppTheme.medicalTextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMedium,
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
                            '${_patientDetails?['full_name']?['first'] ?? ''} ${_patientDetails?['full_name']?['last'] ?? ''}'
                                .trim(),
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
                            _patientDetails?['identity_number'] ?? '-',
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            'Gender',
                            _patientDetails?['gender'] ?? '-',
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
                            _patientDetails?['date_of_birth'] ?? '-',
                          ),
                        ),
                        Expanded(child: _buildInfoRow('Insurance', '-')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 4: Order Date
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            'Order Date${sortedOrderDates.length > 1 ? 's' : ''}',
                            orderDateRange,
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
                            'Report Date${sortedReportDates.length > 1 ? 's' : ''}',
                            reportDateRange,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoRow(
                            'Doctor',
                            'Dr. ${Provider.of<DoctorAuthProvider>(context, listen: false).user?.fullName?.first ?? 'Unknown'} ${Provider.of<DoctorAuthProvider>(context, listen: false).user?.fullName?.last ?? ''}'
                                .trim(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Test Results Section
              Padding(
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
                    const SizedBox(height: 16),
                    if (overallStatus == 'in_progress')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.warningYellow,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Some or all of your tests are currently being processed. Results will be available once completed.',
                                style: AppTheme.medicalTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Test',
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Result',
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Reference Range',
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Unit',
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table Rows
                            ...allResults.map((result) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        result['test_name'] ?? 'Unknown Test',
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        result['test_result'] ?? '-',
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _getResultColor(result),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        result['reference_range'] ?? '-',
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        result['units'] ?? '',
                                        style: AppTheme.medicalTextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: AppTheme.textMedium,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Remarks Section
                    if (remarksText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remarks/Notes',
                              style: AppTheme.medicalTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              remarksText,
                              style: AppTheme.medicalTextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textMedium,
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
      ),
    );
  }

  Widget _buildRequestTestTab() {
    return AppAnimations.pageDepthTransition(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAnimations.floating(
                AppAnimations.morphIn(
                  Icon(Icons.add_box, size: 80, color: AppTheme.primaryBlue),
                  delay: 200.ms,
                ),
              ),
              const SizedBox(height: 16),
              AppAnimations.blurFadeIn(
                Text(
                  'Request New Test',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                delay: 400.ms,
              ),
              const SizedBox(height: 8),
              AppAnimations.elasticSlideIn(
                Text(
                  'Create a new test request for this patient',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                delay: 600.ms,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return AppTheme.successGreen;
      case 'pending':
        return AppTheme.warningYellow;
      case 'in_progress':
        return AppTheme.primaryBlue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  Color _getResultColor(dynamic result) {
    // For now, return normal color. In future, could implement logic to highlight abnormal results
    return AppTheme.textDark;
  }
}

class AnimatedButton extends StatefulWidget {
  final Widget child;

  const AnimatedButton({super.key, required this.child});

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: widget.child),
      ),
    );
  }
}
