// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';

class PatientBillsScreen extends StatefulWidget {
  const PatientBillsScreen({super.key});

  @override
  State<PatientBillsScreen> createState() => _PatientBillsScreenState();
}

class _PatientBillsScreenState extends State<PatientBillsScreen> {
  List<dynamic> _invoices = [];
  bool _isLoading = true;
  String? _selectedStatus;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'ILS ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final response = await PatientApiService.getMyInvoices(
        paymentStatus: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _invoices = (response['invoices'] as List?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load bills. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadInvoices,
            ),
          ),
        );
      }
    }
  }

  void _filterByStatus(String? status) {
    setState(() => _selectedStatus = status);
    _loadInvoices();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.successGreen;
      case 'pending':
        return AppTheme.warningYellow;
      case 'overdue':
        return AppTheme.errorRed;
      default:
        return AppTheme.textMedium;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Bills & Invoices',
          style: TextStyle(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primaryBlue),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvoices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  'Filter: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (selected) => _filterByStatus(null),
                  backgroundColor: Colors.grey[100],
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.1),
                  checkmarkColor: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Paid'),
                  selected: _selectedStatus == 'paid',
                  onSelected: (selected) =>
                      _filterByStatus(selected ? 'paid' : null),
                  backgroundColor: Colors.grey[100],
                  selectedColor: AppTheme.successGreen.withOpacity(0.1),
                  checkmarkColor: AppTheme.successGreen,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _selectedStatus == 'pending',
                  onSelected: (selected) =>
                      _filterByStatus(selected ? 'pending' : null),
                  backgroundColor: Colors.grey[100],
                  selectedColor: AppTheme.warningYellow.withOpacity(0.1),
                  checkmarkColor: AppTheme.warningYellow,
                ),
              ],
            ),
          ),

          // Bills List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  )
                : _invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bills found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedStatus != null
                              ? 'Try changing the filter or check back later'
                              : 'Your bills will appear here once generated',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return _buildInvoiceCard(invoice)
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

  Widget _buildInvoiceCard(dynamic invoice) {
    final order = invoice['order_id'];
    final labName = order?['owner_id']?['name'] ?? 'Medical Lab';
    final invoiceDate = DateTime.parse(invoice['invoice_date']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showInvoiceDetails(invoice),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor('paid').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon('paid'),
                      color: _getStatusColor('paid'),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice #${invoice['_id'].toString().substring(0, min(8, invoice['_id'].toString().length)).toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          labName,
                          style: TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 14,
                          ),
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
                      color: _getStatusColor('paid').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PAID',
                      style: TextStyle(
                        color: _getStatusColor('paid'),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Amount and Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(invoice['total_amount'] ?? 0),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Invoice Date',
                          style: TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(invoiceDate),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Order info
              if (order != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medical_services,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order['test_count'] ?? 0} test(s) ordered',
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(dynamic invoice) async {
    try {
      final response = await PatientApiService.getInvoiceById(invoice['_id']);
      final detailedInvoice = response['invoice'] ?? invoice;
      final orderDetails = response['tests'] ?? [];

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _buildInvoiceDetails(
              detailedInvoice,
              orderDetails,
              scrollController,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load invoice details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInvoiceDetails(
    dynamic invoice,
    List<dynamic> orderDetails,
    ScrollController scrollController,
  ) {
    final authProvider = Provider.of<PatientAuthProvider>(context);
    final order = invoice['order_id'];
    final labInfo = order?['owner_id'];

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
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
                                labInfo?['name'] ?? 'Medical Laboratory',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              if (labInfo?['address'] != null)
                                Text(
                                  labInfo['address'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              if (labInfo?['phone_number'] != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: AppTheme.textMedium,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      labInfo['phone_number'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Invoice & Bill',
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor('paid'),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Invoice #${invoice['_id'].toString().substring(0, min(8, invoice['_id'].toString().length)).toUpperCase()}',
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
                          style: TextStyle(
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
                        // Row 4: Invoice Date
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                'Invoice Date',
                                DateFormat('yyyy-MM-dd').format(
                                  DateTime.parse(invoice['invoice_date']),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Test Details Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Details & Pricing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tests Table
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
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Price',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
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
                              if (orderDetails.isNotEmpty)
                                ...orderDetails.map<Widget>(
                                  (detail) => Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.1),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                detail['test_id']?['test_name'] ??
                                                    'Unknown Test',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textDark,
                                                ),
                                              ),
                                              if (detail['test_id']?['test_code'] !=
                                                  null)
                                                Text(
                                                  'Code: ${detail['test_id']['test_code']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textMedium,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _currencyFormat.format(
                                              detail['test_id']?['price'] ?? 0,
                                            ),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Total Row
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currencyFormat.format(
                                          invoice['total_amount'] ?? 0,
                                        ),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
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
            style: TextStyle(fontSize: 12, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  String _getPatientFullName(user) {
    if (user == null) return 'N/A';
    final firstName = user.firstName ?? '';
    final lastName = user.lastName ?? '';
    return '$firstName $lastName'.trim().isEmpty
        ? 'N/A'
        : '$firstName $lastName'.trim();
  }
}
