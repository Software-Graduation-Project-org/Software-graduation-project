// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';

class OwnerInvoiceDetailsScreen extends StatefulWidget {
  final String orderId;

  const OwnerInvoiceDetailsScreen({super.key, required this.orderId});

  @override
  State<OwnerInvoiceDetailsScreen> createState() =>
      _OwnerInvoiceDetailsScreenState();
}

class _OwnerInvoiceDetailsScreenState extends State<OwnerInvoiceDetailsScreen> {
  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _orderInfo;
  List<dynamic> _tests = [];
  bool _isLoading = true;
  String? _error;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'ILS ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First get the invoice by order ID
      final invoiceResponse = await OwnerApiService.getInvoiceByOrderId(
        widget.orderId,
      );
      final invoice = invoiceResponse['invoice'];

      if (invoice == null) {
        throw Exception('No invoice found for this order');
      }

      // Then get detailed invoice information
      final response = await OwnerApiService.getInvoiceDetails(invoice['_id']);

      if (mounted) {
        setState(() {
          _invoice = response['invoice'];
          _orderInfo = response;
          _tests = response['tests'] ?? [];
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

  String _buildFullName(dynamic nameObj) {
    if (nameObj == null) return 'N/A';

    // If nameObj is already a string, return it
    if (nameObj is String) return nameObj;

    // If nameObj is a Map, extract first, middle, last
    if (nameObj is Map) {
      final first = nameObj['first'] ?? '';
      final middle = nameObj['middle'] ?? '';
      final last = nameObj['last'] ?? '';

      final parts = [first, middle, last]
          .where((part) => part.isNotEmpty && part.toString().trim().isNotEmpty)
          .toList();
      return parts.isEmpty ? 'N/A' : parts.join(' ');
    }

    return 'N/A';
  }

  List<Widget> _buildInvoiceTestList(List<dynamic> tests) {
    return tests.map((test) {
      final testName = test['test_name'] ?? 'Unknown Test';
      final testCode = test['test_code'] ?? '';
      final price = test['price'] ?? 0;
      final status = test['status'] ?? 'pending';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
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
                ],
              ),
            ),
            Text(
              _currencyFormat.format(price),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = AppTheme.successGreen.withOpacity(0.1);
        textColor = AppTheme.successGreen;
        displayText = 'Completed';
        break;
      case 'in_progress':
        backgroundColor = AppTheme.primaryBlue.withOpacity(0.1);
        textColor = AppTheme.primaryBlue;
        displayText = 'In Progress';
        break;
      case 'pending':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[800]!;
        displayText = 'Pending';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
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

  Widget _buildPaymentSummary() {
    final totals = _orderInfo?['totals'] ?? {};

    return Column(
      children: [
        // Invoice breakdown
        _buildSummaryRow('Subtotal', totals['subtotal'] ?? 0),
        if ((totals['tax'] ?? 0) > 0)
          _buildSummaryRow('Tax', totals['tax'] ?? 0),
        if ((totals['discount'] ?? 0) > 0)
          _buildSummaryRow(
            'Discount',
            -(totals['discount'] ?? 0),
            color: AppTheme.successGreen,
          ),
        const Divider(height: 16, thickness: 1),

        // Total amount
        Builder(
          builder: (context) {
            final totalValue = totals['total'] ?? 0;
            return _buildSummaryRow(
              'Total Amount',
              totalValue,
              isBold: true,
              isTotal: true,
            );
          },
        ),

        const SizedBox(height: 12),

        // Payment status section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.successGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Status: PAID',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      'Invoice has been fully paid',
                      style: TextStyle(
                        fontSize: 12,
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
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isTotal = false,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: isTotal
          ? BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                width: 1,
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isBold || isTotal
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: color ?? AppTheme.textDark,
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isBold || isTotal
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: color ?? AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Invoice Details',
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
                    'Error loading invoice details',
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
                    onPressed: _loadInvoiceDetails,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _invoice == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No invoice information available',
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
                                  Icons.receipt_long,
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
                                    Text(
                                      'Invoice Date',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                    if (_invoice?['invoice_date'] != null)
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(
                                          DateTime.parse(
                                            _invoice!['invoice_date'],
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Invoice Info Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Invoice Information',
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
                                        Icons.payment,
                                        'PAID',
                                        'Payment Status',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.calendar_today,
                                        _invoice?['invoice_date'] != null
                                            ? DateFormat('MMM dd, yyyy').format(
                                                DateTime.parse(
                                                  _invoice!['invoice_date'],
                                                ),
                                              )
                                            : 'N/A',
                                        'Invoice Date',
                                      ),
                                    ),
                                  ],
                                ),
                                if (_invoice?['due_date'] != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoItem(
                                          Icons.event_available,
                                          DateFormat('MMM dd, yyyy').format(
                                            DateTime.parse(
                                              _invoice!['due_date'],
                                            ),
                                          ),
                                          'Due Date',
                                        ),
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Order Info Card with View Details Button
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
                                    _invoice?['order_id'] ?? 'N/A',
                                    'Order ID',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    Icons.calendar_today,
                                    _invoice?['order_date'] != null
                                        ? DateFormat('MMM dd, yyyy').format(
                                            DateTime.parse(
                                              _invoice!['order_date'],
                                            ),
                                          )
                                        : 'N/A',
                                    'Order Date',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Patient Info Card
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
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    Icons.person,
                                    _buildFullName(
                                      _orderInfo?['patient']?['name'],
                                    ),
                                    'Patient Name',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    Icons.badge,
                                    _orderInfo?['patient']?['identity_number'] ??
                                        _orderInfo?['patient']?['patient_id'] ??
                                        'N/A',
                                    'ID Number',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tests Section
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
                              children: _buildInvoiceTestList(_tests),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment Summary Card
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildPaymentSummary(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
