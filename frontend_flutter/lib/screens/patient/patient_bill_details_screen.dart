import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';

class PatientBillDetailsScreen extends StatefulWidget {
  final String orderId;

  const PatientBillDetailsScreen({super.key, required this.orderId});

  @override
  State<PatientBillDetailsScreen> createState() =>
      _PatientBillDetailsScreenState();
}

class _PatientBillDetailsScreenState extends State<PatientBillDetailsScreen> {
  Map<String, dynamic>? _orderInfo;
  Map<String, dynamic>? _invoice;
  List<dynamic> _orderDetails = [];
  bool _isLoading = true;
  String? _error;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'ILS ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadBillDetails();
  }

  Future<void> _loadBillDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get order details and invoice
      final response = await PatientApiService.getOrderDetails(widget.orderId);
      final invoice = response['invoice'];
      final order = response['order'];
      final details = response['details'] ?? [];

      // If invoice not found in order details, try to find it from all invoices
      var finalInvoice = invoice;
      if (finalInvoice == null) {
        final invoicesResponse = await PatientApiService.getMyInvoices();
        final invoices = invoicesResponse['invoices'] as List?;
        if (invoices != null) {
          finalInvoice = invoices.firstWhere(
            (inv) =>
                inv['order_id']?['_id'] == widget.orderId ||
                inv['order_id'] == widget.orderId,
            orElse: () => null,
          );
        }
      }

      if (mounted) {
        setState(() {
          _orderInfo = order;
          _invoice = finalInvoice;
          _orderDetails = details;
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

  Future<void> _downloadInvoicePDF() async {
    if (_invoice == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Get the invoice ID
      final invoiceId = _invoice!['_id']?.toString();
      if (invoiceId == null) {
        throw Exception('Invoice ID not found');
      }

      // Get auth token
      final authProvider = Provider.of<PatientAuthProvider>(
        context,
        listen: false,
      );
      final token = authProvider.token;
      if (token == null) {
        throw Exception('Authentication required');
      }

      // Download PDF from server
      final url = Uri.parse(
        'http://192.168.1.6:5000/api/patient/invoices/$invoiceId/download',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Convert response bytes to Uint8List for printing package
        final pdfBytes = response.bodyBytes;

        // Use printing package to show PDF preview/download dialog
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Invoice_${_invoice!['invoice_id'] ?? 'N/A'}.pdf',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorBody = response.body;
        final errorMessage = errorBody.contains('message')
            ? errorBody.split('"message":"')[1].split('"')[0]
            : 'Download failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
          'Bill Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        actions: [
          if (_invoice != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download PDF',
              onPressed: () => _downloadInvoicePDF(),
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
                    'Error loading bill details',
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
                    onPressed: _loadBillDetails,
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
                    'No bill information available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ID: ${widget.orderId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                                      if (_orderInfo?['owner_id']?['phone_number'] !=
                                          null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: 12,
                                              color: AppTheme.textMedium,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _orderInfo!['owner_id']['phone_number'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMedium,
                                              ),
                                            ),
                                          ],
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successGreen,
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
                                      'Invoice #${_invoice!['_id'].toString().substring(0, 8).toUpperCase()}',
                                      style: const TextStyle(
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
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.1,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
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
                                        authProvider.user?.identityNumber ??
                                            '-',
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
                                        authProvider.user?.insuranceProvider ??
                                            'None',
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
                                          DateTime.parse(
                                            _invoice!['invoice_date'],
                                          ),
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
                                const Text(
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
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.05),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: AppTheme.primaryBlue
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                        ),
                                        child: const Row(
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
                                      if (_orderDetails.isNotEmpty)
                                        ..._orderDetails.map<Widget>(
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        detail['test_id']?['test_name'] ??
                                                            'Unknown Test',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              AppTheme.textDark,
                                                        ),
                                                      ),
                                                      if (detail['test_id']?['test_code'] !=
                                                          null)
                                                        Text(
                                                          'Code: ${detail['test_id']['test_code']}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: AppTheme
                                                                    .textMedium,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _currencyFormat.format(
                                                      detail['test_id']?['price'] ??
                                                          0,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppTheme.primaryBlue,
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
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.05),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Expanded(
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
                                                  _invoice!['total_amount'] ??
                                                      0,
                                                ),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
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
            style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
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
    final firstName = user.fullName?.first ?? '';
    final lastName = user.fullName?.last ?? '';
    return '$firstName $lastName'.trim().isEmpty
        ? 'N/A'
        : '$firstName $lastName'.trim();
  }
}
