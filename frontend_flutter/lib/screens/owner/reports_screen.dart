import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../config/theme.dart';
import '../../widgets/common/navbar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _reportsData;
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'monthly';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final response = await ApiService.get(ApiConfig.ownerReports);

      setState(() {
        _reportsData = response is Map<String, dynamic> ? response : {};
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 'custom';
      });
      // In a real implementation, you'd reload reports with the custom date range
    }
  }

  String _formatCurrency(double? value) {
    if (value == null) return '\$0.00';
    return NumberFormat.currency(symbol: '\$').format(value);
  }

  String _formatNumber(int? value) {
    if (value == null) return '0';
    return NumberFormat.decimalPattern().format(value);
  }

  String _formatPercentage(double? value) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Reports & Analytics'),
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
                    'Reports & Analytics',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comprehensive insights into your laboratory performance',
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
                    // Period Selector
                    Row(
                      children: [
                        Text(
                          'Report Period:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Text('This Week'),
                              ),
                              DropdownMenuItem(
                                value: 'monthly',
                                child: Text('This Month'),
                              ),
                              DropdownMenuItem(
                                value: 'quarterly',
                                child: Text('This Quarter'),
                              ),
                              DropdownMenuItem(
                                value: 'yearly',
                                child: Text('This Year'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom Range'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedPeriod = value!);
                              if (value == 'custom') {
                                _selectCustomDateRange();
                              } else {
                                _loadReports();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _loadReports,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Content
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: Column(
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
                                    onPressed: _loadReports,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _reportsData == null
                          ? const Center(
                              child: Text('No report data available'),
                            )
                          : _buildReportsContent(isMobile),
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

  Widget _buildReportsContent(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildKeyMetricsSection(isMobile),
          const SizedBox(height: 32),

          // Detailed Reports
          _buildDetailedReportsSection(isMobile),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsSection(bool isMobile) {
    final metrics = _reportsData?['key_metrics'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              'Total Revenue',
              _formatCurrency(metrics['total_revenue']?.toDouble()),
              Icons.attach_money,
              AppTheme.successGreen,
            ),
            _buildMetricCard(
              'Total Orders',
              _formatNumber(metrics['total_orders']),
              Icons.receipt_long,
              AppTheme.primaryBlue,
            ),
            _buildMetricCard(
              'Completed Tests',
              _formatNumber(metrics['completed_tests']),
              Icons.check_circle,
              Colors.green,
            ),
            _buildMetricCard(
              'Growth Rate',
              _formatPercentage(metrics['growth_rate']?.toDouble()),
              Icons.trending_up,
              metrics['growth_rate'] != null && metrics['growth_rate'] >= 0
                  ? AppTheme.successGreen
                  : Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
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

  Widget _buildDetailedReportsSection(bool isMobile) {
    final reports = _reportsData?['detailed_reports'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Reports',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isMobile ? 1 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildReportCard(
              'Test Performance Report',
              'Analysis of test completion times and success rates',
              Icons.science,
              Colors.blue,
              reports['test_performance'] ?? {},
            ),
            _buildReportCard(
              'Staff Productivity Report',
              'Staff performance metrics and workload analysis',
              Icons.people,
              Colors.green,
              reports['staff_productivity'] ?? {},
            ),
            _buildReportCard(
              'Equipment Utilization',
              'Device usage statistics and maintenance schedules',
              Icons.build,
              Colors.orange,
              reports['equipment_utilization'] ?? {},
            ),
            _buildReportCard(
              'Financial Summary',
              'Revenue breakdown and cost analysis',
              Icons.account_balance_wallet,
              Colors.purple,
              reports['financial_summary'] ?? {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(
    String title,
    String description,
    IconData icon,
    Color color,
    Map<String, dynamic> data,
  ) {
    return AnimatedCard(
      onTap: () {
        // In a real implementation, this would navigate to detailed report view
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title - Detailed view coming soon!')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
                Icon(Icons.arrow_forward, color: color, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
