// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String _selectedReportType = 'comprehensive';
  String _selectedPeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'value': 'comprehensive',
      'label': 'Comprehensive',
      'icon': Icons.analytics_outlined,
      'description': 'Complete system overview',
      'color': AppTheme.primaryBlue,
    },
    {
      'value': 'revenue',
      'label': 'Revenue',
      'icon': Icons.attach_money_rounded,
      'description': 'Financial analysis',
      'color': AppTheme.successGreen,
    },
    {
      'value': 'labs',
      'label': 'Labs',
      'icon': Icons.science_outlined,
      'description': 'Laboratory metrics',
      'color': AppTheme.secondaryTeal,
    },
    {
      'value': 'subscriptions',
      'label': 'Subscriptions',
      'icon': Icons.payment_rounded,
      'description': 'Subscription analytics',
      'color': Colors.purple,
    },
  ];

  final List<Map<String, String>> _periods = [
    {'value': 'daily', 'label': 'Today'},
    {'value': 'weekly', 'label': 'This Week'},
    {'value': 'monthly', 'label': 'This Month'},
    {'value': 'yearly', 'label': 'This Year'},
    {'value': 'custom', 'label': 'Custom'},
  ];

  // Helper to safely parse numbers from API (may be strings)
  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        ApiService.setAuthToken(authProvider.token);
        _loadReport();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      Map<String, String> params = {
        'type': _selectedReportType,
        'period': _selectedPeriod,
      };

      if (_selectedPeriod == 'custom' &&
          _customStartDate != null &&
          _customEndDate != null) {
        params['startDate'] = _customStartDate!.toIso8601String();
        params['endDate'] = _customEndDate!.toIso8601String();
      }

      final response = await ApiService.get('/admin/reports', params: params);

      if (mounted) {
        setState(() {
          _reportData = response['report'];
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to load report: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadReport();
    }
  }

  // Get responsive values based on screen size
  bool get _isMobile => ResponsiveBreakpoints.of(context).isMobile;
  bool get _isTablet => ResponsiveBreakpoints.of(context).isTablet;
  bool get _isDesktop => ResponsiveBreakpoints.of(context).isDesktop;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  // Responsive padding
  double get _contentPadding {
    if (_isMobile) return 16;
    if (_isTablet) return 24;
    return 32;
  }

  // Responsive font sizes
  double get _headerFontSize {
    if (_isMobile) return 24;
    if (_isTablet) return 28;
    return 32;
  }

  double get _sectionTitleSize {
    if (_isMobile) return 18;
    if (_isTablet) return 20;
    return 22;
  }

  // Responsive grid columns for stat cards
  int get _statGridColumns {
    if (_screenWidth < 500) return 2;
    if (_screenWidth < 900) return 3;
    return 4;
  }

  // Responsive card width for report type selector
  double get _reportTypeCardWidth {
    if (_isMobile) return 130;
    if (_isTablet) return 150;
    return 170;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      constraints: BoxConstraints(maxHeight: _screenHeight - 100),
      child: _buildReportsContent(context),
    );
  }

  Widget _buildReportsContent(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(_contentPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(context),
              SizedBox(height: _isMobile ? 20 : 28),

              // Report Type Selection (Card Pills)
              _buildReportTypeSelector(context),
              SizedBox(height: _isMobile ? 16 : 24),

              // Period Selection & Generate
              _buildPeriodControls(context),
              SizedBox(height: _isMobile ? 20 : 28),

              // Report Content
              if (_isLoading)
                _buildLoadingState()
              else if (_reportData != null)
                _buildReportDisplay(context)
              else
                _buildEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final iconSize = _isMobile ? 40.0 : (_isTablet ? 48.0 : 56.0);

    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : (_isTablet ? 20 : 28)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
            AppTheme.secondaryTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_isMobile ? 12 : 20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: _isMobile ? 10 : 20,
            offset: Offset(0, _isMobile ? 5 : 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _headerFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: _isMobile ? 6 : 10),
                Text(
                  dateFormat.format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: _isMobile ? 13 : (_isTablet ? 15 : 17),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Analyze system performance and metrics',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: _isMobile ? 12 : (_isTablet ? 13 : 15),
                  ),
                ),
              ],
            ),
          ),
          if (!_isMobile) ...[
            const SizedBox(width: 16),
            Container(
              padding: EdgeInsets.all(_isTablet ? 14 : 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(_isTablet ? 14 : 18),
              ),
              child: Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildReportTypeSelector(BuildContext context) {
    // On larger screens, show as a grid; on smaller screens, horizontal scroll
    final showAsGrid = _screenWidth > 700;
    final cardHeight = _isMobile ? 100.0 : (_isTablet ? 110.0 : 120.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Report Type',
            style: TextStyle(
              fontSize: _sectionTitleSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ),
        if (showAsGrid)
          // Grid layout for tablets and desktops
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _reportTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final type = entry.value;
              return _buildReportTypeCard(type, index, cardHeight);
            }).toList(),
          )
        else
          // Horizontal scroll for mobile
          SizedBox(
            height: cardHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _reportTypes.length,
              itemBuilder: (context, index) {
                final type = _reportTypes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _reportTypes.length - 1 ? 12 : 0,
                  ),
                  child: _buildReportTypeCard(type, index, cardHeight),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildReportTypeCard(
    Map<String, dynamic> type,
    int index,
    double height,
  ) {
    final isSelected = _selectedReportType == type['value'];
    final color = type['color'] as Color;
    final iconSize = _isMobile ? 20.0 : (_isTablet ? 22.0 : 26.0);
    final labelSize = _isMobile ? 11.0 : (_isTablet ? 12.0 : 13.0);
    final iconPadding = _isMobile ? 5.0 : 7.0;

    return GestureDetector(
          onTap: () {
            setState(() => _selectedReportType = type['value'] as String);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _reportTypeCardWidth,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 8 : 12,
              vertical: _isMobile ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(_isMobile ? 12 : 16),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(_isMobile ? 6 : 8),
                  ),
                  child: Icon(
                    type['icon'] as IconData,
                    color: isSelected ? Colors.white : color,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: _isMobile ? 4 : 6),
                Flexible(
                  child: Text(
                    type['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.w600,
                      fontSize: labelSize,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: _isMobile ? 1 : 2),
                Flexible(
                  child: Text(
                    type['description'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey[500],
                      fontSize: _isMobile ? 8 : 9,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(delay: (index * 80).ms)
        .fadeIn()
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildPeriodControls(BuildContext context) {
    final chipPadding = _isMobile
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);

    return Container(
      padding: EdgeInsets.all(_isMobile ? 14 : (_isTablet ? 18 : 22)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primaryBlue,
                size: _isMobile ? 18 : 22,
              ),
              SizedBox(width: _isMobile ? 6 : 10),
              Text(
                'Time Period',
                style: TextStyle(
                  fontSize: _isMobile ? 15 : (_isTablet ? 17 : 18),
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: _isMobile ? 12 : 18),
          Wrap(
            spacing: _isMobile ? 6 : 10,
            runSpacing: _isMobile ? 6 : 10,
            children: _periods.map((period) {
              final isSelected = _selectedPeriod == period['value'];
              return ChoiceChip(
                label: Text(period['label']!),
                selected: isSelected,
                padding: chipPadding,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPeriod = period['value']!);
                    if (period['value'] != 'custom') {
                      _loadReport();
                    } else {
                      _selectDateRange();
                    }
                  }
                },
                selectedColor: AppTheme.primaryBlue,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: _isMobile ? 12 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          if (_selectedPeriod == 'custom' &&
              _customStartDate != null &&
              _customEndDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _selectDateRange,
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: _isMobile ? 14 : 18),
          // On larger screens, limit button width; full width on mobile
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _isMobile ? double.infinity : 400,
                minWidth: _isMobile ? double.infinity : 250,
              ),
              child: SizedBox(
                width: _isMobile ? double.infinity : null,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadReport,
                  icon: _isLoading
                      ? SizedBox(
                          width: _isMobile ? 18 : 22,
                          height: _isMobile ? 18 : 22,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.auto_graph_rounded,
                          size: _isMobile ? 20 : 24,
                        ),
                  label: Text(
                    _isLoading ? 'Generating...' : 'Generate Report',
                    style: TextStyle(fontSize: _isMobile ? 14 : 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: _isMobile ? 14 : 18,
                      horizontal: _isMobile ? 16 : 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_isMobile ? 10 : 14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Generating Report...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we analyze the data',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Report Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a report type and time period to generate your report',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildReportDisplay(BuildContext context) {
    final data = _reportData?['data'] as Map<String, dynamic>?;
    final period = _reportData?['period'] as String?;

    if (data == null) {
      return _buildErrorState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (period != null) _buildReportInfoBanner(context, period),
        SizedBox(height: _isMobile ? 20 : 28),
        if (_selectedReportType == 'comprehensive')
          _buildComprehensiveReport(context, data)
        else if (_selectedReportType == 'revenue')
          _buildRevenueReport(context, data['revenue'] ?? {})
        else if (_selectedReportType == 'labs')
          _buildLabsReport(context, data['labs'] ?? {})
        else if (_selectedReportType == 'subscriptions')
          _buildSubscriptionsReport(context, data['subscriptions'] ?? {}),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try generating the report again',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportInfoBanner(BuildContext context, String period) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final now = DateTime.now();
    final iconSize = _isMobile ? 20.0 : 26.0;

    String periodText;
    IconData periodIcon;

    switch (period) {
      case 'daily':
        periodText = 'Today\'s Report';
        periodIcon = Icons.today;
        break;
      case 'weekly':
        periodText = 'Weekly Report';
        periodIcon = Icons.view_week;
        break;
      case 'monthly':
        periodText = 'Monthly Report';
        periodIcon = Icons.calendar_month;
        break;
      case 'yearly':
        periodText = 'Yearly Report';
        periodIcon = Icons.calendar_today;
        break;
      case 'custom':
        periodText = 'Custom Range Report';
        periodIcon = Icons.date_range;
        break;
      default:
        periodText = 'Report';
        periodIcon = Icons.analytics;
    }

    return Container(
      padding: EdgeInsets.all(_isMobile ? 12 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successGreen.withOpacity(0.1),
            AppTheme.successGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(_isMobile ? 10 : 14),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(_isMobile ? 8 : 12),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(_isMobile ? 8 : 12),
            ),
            child: Icon(
              periodIcon,
              color: AppTheme.successGreen,
              size: iconSize,
            ),
          ),
          SizedBox(width: _isMobile ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: _isMobile ? 14 : 18,
                    ),
                    SizedBox(width: _isMobile ? 4 : 8),
                    Text(
                      'Report Generated Successfully',
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: _isMobile ? 12 : 15,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isMobile ? 2 : 6),
                Text(
                  periodText,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                    fontSize: _isMobile ? 12 : 14,
                  ),
                ),
                Text(
                  'Generated: ${dateFormat.format(now)}',
                  style: TextStyle(
                    fontSize: _isMobile ? 11 : 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildComprehensiveReport(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    return Column(
      children: [
        _buildRevenueReport(context, data['revenue'] ?? {}),
        SizedBox(height: _isMobile ? 20 : 32),
        _buildLabsReport(context, data['labs'] ?? {}),
      ],
    );
  }

  Widget _buildRevenueReport(BuildContext context, Map<String, dynamic> data) {
    final monthlyRevenue = data['monthlyRevenue'] as List? ?? [];
    final projectedRevenue = data['projectedRevenue'] as List? ?? [];
    final averageRevenuePerLab = _parseNumber(data['averageRevenuePerLab']);
    final revenueGrowth = _parseNumber(data['revenueGrowth']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Revenue Analysis',
          Icons.attach_money_rounded,
          AppTheme.successGreen,
        ),
        SizedBox(height: _isMobile ? 12 : 20),
        _buildStatGrid([
          _StatData(
            'Average Revenue/Lab',
            '\$${averageRevenuePerLab.toStringAsFixed(2)}',
            Icons.account_balance_rounded,
            AppTheme.successGreen,
            'Per lab average',
          ),
          _StatData(
            'Revenue Growth',
            '${revenueGrowth.toStringAsFixed(1)}%',
            revenueGrowth >= 0 ? Icons.trending_up : Icons.trending_down,
            revenueGrowth >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
            revenueGrowth >= 0 ? 'Positive trend' : 'Needs attention',
          ),
          _StatData(
            'Monthly Records',
            '${monthlyRevenue.length}',
            Icons.calendar_month_rounded,
            AppTheme.primaryBlue,
            'Data points',
          ),
          _StatData(
            'Projected Items',
            '${projectedRevenue.length}',
            Icons.schedule_rounded,
            AppTheme.secondaryTeal,
            'Forecasted',
          ),
        ]),
        if (monthlyRevenue.isNotEmpty) ...[
          SizedBox(height: _isMobile ? 20 : 28),
          _buildRevenueChart(context, monthlyRevenue),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(_isMobile ? 6 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_isMobile ? 6 : 10),
          ),
          child: Icon(icon, color: color, size: _isMobile ? 18 : 24),
        ),
        SizedBox(width: _isMobile ? 8 : 14),
        Text(
          title,
          style: TextStyle(
            fontSize: _sectionTitleSize,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildStatGrid(List<_StatData> stats) {
    // Calculate responsive aspect ratio - lower values give more height
    double aspectRatio;
    if (_screenWidth < 360) {
      aspectRatio = 0.75;
    } else if (_screenWidth < 400) {
      aspectRatio = 0.8;
    } else if (_screenWidth < 500) {
      aspectRatio = 0.85;
    } else if (_screenWidth < 700) {
      aspectRatio = 0.95;
    } else if (_screenWidth < 900) {
      aspectRatio = 1.05;
    } else {
      aspectRatio = 1.15;
    }

    final spacing = _isMobile ? 8.0 : (_isTablet ? 12.0 : 16.0);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _statGridColumns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildModernStatCard(stat, index);
      },
    );
  }

  Widget _buildModernStatCard(_StatData stat, int index) {
    final cardPadding = _isMobile ? 8.0 : (_isTablet ? 10.0 : 14.0);
    final iconSize = _isMobile ? 16.0 : (_isTablet ? 20.0 : 24.0);
    final iconPadding = _isMobile ? 5.0 : (_isTablet ? 7.0 : 9.0);
    final valueSize = _isMobile ? 14.0 : (_isTablet ? 18.0 : 22.0);
    final labelSize = _isMobile ? 9.0 : (_isTablet ? 10.0 : 12.0);
    final subtitleSize = _isMobile ? 7.0 : (_isTablet ? 8.0 : 9.0);
    final decorCircleSize = _isMobile ? 40.0 : (_isTablet ? 60.0 : 80.0);

    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_isMobile ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: stat.color.withOpacity(0.15),
                blurRadius: _isMobile ? 6 : 12,
                offset: Offset(0, _isMobile ? 2 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                top: -decorCircleSize * 0.3,
                right: -decorCircleSize * 0.3,
                child: Container(
                  width: decorCircleSize,
                  height: decorCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stat.color.withOpacity(0.08),
                  ),
                ),
              ),
              // Content - using LayoutBuilder for safe sizing
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: stat.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            _isMobile ? 5 : 8,
                          ),
                        ),
                        child: Icon(
                          stat.icon,
                          color: stat.color,
                          size: iconSize,
                        ),
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          stat.value,
                          style: TextStyle(
                            fontSize: valueSize,
                            fontWeight: FontWeight.bold,
                            color: stat.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Flexible(
                        child: Text(
                          stat.label,
                          style: TextStyle(
                            fontSize: labelSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (stat.subtitle != null && !_isMobile)
                        Flexible(
                          child: Text(
                            stat.subtitle!,
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
        .animate(delay: (index * 80 + 200).ms)
        .fadeIn()
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }

  Widget _buildRevenueChart(
    BuildContext context,
    List<dynamic> monthlyRevenue,
  ) {
    // Calculate responsive chart height
    double chartHeight;
    if (_screenWidth < 500) {
      chartHeight = _screenHeight * 0.28;
    } else if (_screenWidth < 900) {
      chartHeight = _screenHeight * 0.32;
    } else {
      chartHeight = _screenHeight * 0.38;
    }

    // Responsive bar width
    final barWidth = _isMobile ? 14.0 : (_isTablet ? 20.0 : 28.0);
    final containerPadding = _isMobile ? 14.0 : (_isTablet ? 18.0 : 24.0);

    // Prepare data for the chart
    final spots = <FlSpot>[];
    final labels = <String>[];
    double maxY = 0;

    for (int i = 0; i < monthlyRevenue.length && i < 12; i++) {
      final item = monthlyRevenue[i];
      final revenue = (item['revenue'] ?? 0).toDouble();
      if (revenue > maxY) maxY = revenue;

      String label;
      if (item['_id'] is Map) {
        final id = item['_id'] as Map<String, dynamic>;
        label = '${id['month']}/${id['year'].toString().substring(2)}';
      } else if (item['_id'] is String) {
        final idStr = item['_id'] as String;
        if (idStr.contains('-')) {
          final parts = idStr.split('-');
          if (parts.length >= 2) {
            label = '${parts[1]}/${parts[0].substring(2)}';
          } else {
            label = idStr;
          }
        } else {
          label = idStr;
        }
      } else {
        label = 'M${i + 1}';
      }

      spots.add(FlSpot(i.toDouble(), revenue));
      labels.add(label);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isMobile ? 12 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: _isMobile ? 10 : 18,
            offset: Offset(0, _isMobile ? 3 : 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(_isMobile ? 6 : 10),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(_isMobile ? 6 : 10),
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        color: AppTheme.successGreen,
                        size: _isMobile ? 18 : 24,
                      ),
                    ),
                    SizedBox(width: _isMobile ? 8 : 14),
                    Flexible(
                      child: Text(
                        'Revenue Trend',
                        style: TextStyle(
                          fontSize: _isMobile ? 15 : (_isTablet ? 17 : 20),
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 8 : 12,
                  vertical: _isMobile ? 3 : 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _isMobile ? 6 : 10,
                      height: _isMobile ? 6 : 10,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: _isMobile ? 4 : 8),
                    Text(
                      'Revenue',
                      style: TextStyle(
                        fontSize: _isMobile ? 10 : 13,
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: _isMobile ? 18 : 28),
          SizedBox(
            height: chartHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: Colors.grey[800],
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '\$${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: _isMobile ? 6 : 10),
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                fontSize: _isMobile ? 9 : (_isTablet ? 11 : 13),
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: _isMobile ? 26 : 36,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: TextStyle(
                            fontSize: _isMobile ? 9 : (_isTablet ? 11 : 13),
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                      reservedSize: _isMobile ? 40 : (_isTablet ? 55 : 70),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 5 : 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: spots.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.y,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.successGreen.withOpacity(0.8),
                            AppTheme.successGreen,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: barWidth,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(_isMobile ? 4 : 8),
                          topRight: Radius.circular(_isMobile ? 4 : 8),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildLabsReport(BuildContext context, Map<String, dynamic> data) {
    final totalLabs = _parseNumber(data['totalLabs']).toInt();
    final activeLabs = _parseNumber(data['activeLabs']).toInt();
    final inactiveLabs = _parseNumber(data['inactiveLabs']).toInt();
    final activeRate = totalLabs > 0
        ? ((activeLabs / totalLabs) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Lab Statistics',
          Icons.science_outlined,
          AppTheme.secondaryTeal,
        ),
        SizedBox(height: _isMobile ? 12 : 20),
        _buildStatGrid([
          _StatData(
            'Total Labs',
            '$totalLabs',
            Icons.business_rounded,
            AppTheme.primaryBlue,
            'Registered',
          ),
          _StatData(
            'Active Labs',
            '$activeLabs',
            Icons.check_circle_rounded,
            AppTheme.successGreen,
            'Currently active',
          ),
          _StatData(
            'Inactive Labs',
            '$inactiveLabs',
            Icons.cancel_rounded,
            AppTheme.errorRed,
            'Need attention',
          ),
          _StatData(
            'Active Rate',
            '$activeRate%',
            Icons.pie_chart_rounded,
            AppTheme.secondaryTeal,
            'Health indicator',
          ),
        ]),
        SizedBox(height: _isMobile ? 20 : 28),
        _buildLabsDistributionChart(activeLabs, inactiveLabs),
      ],
    );
  }

  Widget _buildLabsDistributionChart(int activeLabs, int inactiveLabs) {
    final total = activeLabs + inactiveLabs;
    if (total == 0) return const SizedBox();

    final containerPadding = _isMobile ? 14.0 : (_isTablet ? 18.0 : 24.0);
    final pieRadius = _isMobile ? 45.0 : (_isTablet ? 55.0 : 65.0);
    final centerRadius = _isMobile ? 30.0 : (_isTablet ? 38.0 : 48.0);
    final useVerticalLayout = _screenWidth < 500;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isMobile ? 12 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: _isMobile ? 10 : 18,
            offset: Offset(0, _isMobile ? 3 : 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(_isMobile ? 6 : 10),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_isMobile ? 6 : 10),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: AppTheme.secondaryTeal,
                  size: _isMobile ? 18 : 24,
                ),
              ),
              SizedBox(width: _isMobile ? 8 : 14),
              Text(
                'Labs Distribution',
                style: TextStyle(
                  fontSize: _isMobile ? 15 : (_isTablet ? 17 : 20),
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: _isMobile ? 18 : 28),
          if (useVerticalLayout)
            // Vertical layout for very small screens
            Column(
              children: [
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: _isMobile ? 2 : 4,
                      centerSpaceRadius: centerRadius,
                      sections: [
                        PieChartSectionData(
                          color: AppTheme.successGreen,
                          value: activeLabs.toDouble(),
                          title: '${((activeLabs / total) * 100).round()}%',
                          radius: pieRadius,
                          titleStyle: TextStyle(
                            fontSize: _isMobile ? 12 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: AppTheme.errorRed,
                          value: inactiveLabs.toDouble(),
                          title: '${((inactiveLabs / total) * 100).round()}%',
                          radius: pieRadius,
                          titleStyle: TextStyle(
                            fontSize: _isMobile ? 12 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: _isMobile ? 16 : 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _buildLegendItem(
                        'Active Labs',
                        activeLabs,
                        AppTheme.successGreen,
                      ),
                    ),
                    SizedBox(width: _isMobile ? 16 : 40),
                    Flexible(
                      child: _buildLegendItem(
                        'Inactive Labs',
                        inactiveLabs,
                        AppTheme.errorRed,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Horizontal layout for larger screens
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: _isMobile ? 2 : 4,
                        centerSpaceRadius: centerRadius,
                        sections: [
                          PieChartSectionData(
                            color: AppTheme.successGreen,
                            value: activeLabs.toDouble(),
                            title: '${((activeLabs / total) * 100).round()}%',
                            radius: pieRadius,
                            titleStyle: TextStyle(
                              fontSize: _isMobile ? 12 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: AppTheme.errorRed,
                            value: inactiveLabs.toDouble(),
                            title: '${((inactiveLabs / total) * 100).round()}%',
                            radius: pieRadius,
                            titleStyle: TextStyle(
                              fontSize: _isMobile ? 12 : 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: _isMobile ? 16 : 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(
                        'Active Labs',
                        activeLabs,
                        AppTheme.successGreen,
                      ),
                      SizedBox(height: _isMobile ? 12 : 20),
                      _buildLegendItem(
                        'Inactive Labs',
                        inactiveLabs,
                        AppTheme.errorRed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    final boxSize = _isMobile ? 12.0 : 18.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_isMobile ? 3 : 4),
          ),
        ),
        SizedBox(width: _isMobile ? 6 : 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _isMobile ? 10 : 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '$value labs',
                style: TextStyle(
                  fontSize: _isMobile ? 9 : 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsReport(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final totalSubscriptions = _parseNumber(data['totalSubscriptions']).toInt();
    final activeSubscriptions = _parseNumber(
      data['activeSubscriptions'],
    ).toInt();
    final expiredSubscriptions = _parseNumber(
      data['expiredSubscriptions'],
    ).toInt();
    final renewalsNeeded = _parseNumber(data['renewalsNeeded']).toInt();
    final totalRevenue = _parseNumber(data['totalRevenue']);
    final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
    final averageFee = _parseNumber(metrics['averageFee']);
    final lifetimeValue = _parseNumber(data['lifetimeValue']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Subscription Analytics',
          Icons.payment_rounded,
          Colors.purple,
        ),
        SizedBox(height: _isMobile ? 12 : 20),
        _buildStatGrid([
          _StatData(
            'Total Subscriptions',
            '$totalSubscriptions',
            Icons.subscriptions_rounded,
            Colors.purple,
            'All subscriptions',
          ),
          _StatData(
            'Active',
            '$activeSubscriptions',
            Icons.check_circle_rounded,
            AppTheme.successGreen,
            'Currently active',
          ),
          _StatData(
            'Expired',
            '$expiredSubscriptions',
            Icons.cancel_rounded,
            AppTheme.errorRed,
            'Need renewal',
          ),
          _StatData(
            'Renewals Needed',
            '$renewalsNeeded',
            Icons.warning_rounded,
            Colors.orange,
            'Expiring soon',
          ),
        ]),
        SizedBox(height: _isMobile ? 16 : 24),
        _buildStatGrid([
          _StatData(
            'Total Revenue',
            '\$${totalRevenue.toStringAsFixed(2)}',
            Icons.attach_money_rounded,
            AppTheme.successGreen,
            'From subscriptions',
          ),
          _StatData(
            'Average Fee',
            '\$${averageFee.toStringAsFixed(2)}',
            Icons.analytics_rounded,
            AppTheme.primaryBlue,
            'Per lab',
          ),
          _StatData(
            'Lifetime Value',
            '\$${lifetimeValue.toStringAsFixed(2)}',
            Icons.trending_up_rounded,
            AppTheme.secondaryTeal,
            'Est. annual',
          ),
        ]),
      ],
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  _StatData(this.label, this.value, this.icon, this.color, [this.subtitle]);
}
