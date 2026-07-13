import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';

class SystemHealthWidget extends StatelessWidget {
  final Map<String, dynamic>? systemHealth;
  final Map<String, dynamic>? realtimeMetrics;
  final Map<String, dynamic>? alertsData;

  const SystemHealthWidget({
    super.key,
    this.systemHealth,
    this.realtimeMetrics,
    this.alertsData,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getSystemStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getSystemStatusIcon(),
                    color: _getSystemStatusColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Health',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Real-time system monitoring and alerts',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? 80 : 100,
                    minWidth: isMobile ? 60 : 70,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSystemStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getSystemStatusColor().withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSystemStatusIcon(),
                          size: isMobile ? 12 : 14,
                          color: _getSystemStatusColor(),
                        ),
                        SizedBox(width: isMobile ? 4 : 6),
                        Flexible(
                          child: Text(
                            _getSystemStatusText().toUpperCase(),
                            style: TextStyle(
                              color: _getSystemStatusColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 10 : 11,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Health Metrics Grid
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate how many columns can fit based on available width
                final availableWidth = constraints.maxWidth;
                final minColumnWidth =
                    140.0; // Minimum width needed for each metric
                final spacing = 16.0;
                final numColumns = (availableWidth / (minColumnWidth + spacing))
                    .floor()
                    .clamp(1, 4);

                return GridView.count(
                  crossAxisCount: numColumns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildHealthMetric(
                      context,
                      'Database',
                      systemHealth?['database']?['status'] == 'healthy'
                          ? 'Healthy'
                          : 'Issues',
                      Icons.storage,
                      systemHealth?['database']?['status'] == 'healthy'
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                    ),
                    _buildHealthMetric(
                      context,
                      'Memory',
                      '${systemHealth?['performance']?['memoryUsage']?['heapUsed'] ?? 'N/A'}',
                      Icons.memory,
                      _getMemoryStatusColor(),
                    ),
                    _buildHealthMetric(
                      context,
                      'Response Time',
                      systemHealth?['performance']?['responseTime'] ?? 'N/A',
                      Icons.timer,
                      _getResponseTimeColor(),
                    ),
                    _buildHealthMetric(
                      context,
                      'Active Labs',
                      '${systemHealth?['business']?['activeLabs'] ?? 0}',
                      Icons.business,
                      AppTheme.primaryBlue,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Real-time Metrics
            if (realtimeMetrics != null) ...[
              Text(
                'Real-time Metrics',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 400;
                  return isNarrow
                      ? Column(
                          children: [
                            _buildRealtimeMetric(
                              context,
                              'Today\'s Orders',
                              '${realtimeMetrics!['todayOrders'] ?? 0}',
                              '${realtimeMetrics!['orderGrowth']?.toStringAsFixed(1) ?? '0'}%',
                              (realtimeMetrics!['orderGrowth'] ?? 0) >= 0
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                            ),
                            const SizedBox(height: 16),
                            _buildRealtimeMetric(
                              context,
                              'Avg TAT',
                              '${realtimeMetrics!['avgTurnaroundHours']?.toStringAsFixed(1) ?? '0'}h',
                              'Last 7 days',
                              AppTheme.warningYellow,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildRealtimeMetric(
                                context,
                                'Today\'s Orders',
                                '${realtimeMetrics!['todayOrders'] ?? 0}',
                                '${realtimeMetrics!['orderGrowth']?.toStringAsFixed(1) ?? '0'}%',
                                (realtimeMetrics!['orderGrowth'] ?? 0) >= 0
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildRealtimeMetric(
                                context,
                                'Avg TAT',
                                '${realtimeMetrics!['avgTurnaroundHours']?.toStringAsFixed(1) ?? '0'}h',
                                'Last 7 days',
                                AppTheme.warningYellow,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ],

            // Alerts Summary
            if (alertsData != null && alertsData!['summary'] != null) ...[
              const SizedBox(height: 24),
              Text(
                'Active Alerts',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildAlertsSummary(context, alertsData!['summary']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetric(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 120;
        return Container(
          padding: EdgeInsets.all(isCompact ? 8 : 16),
          constraints: BoxConstraints(
            minHeight: isCompact ? 60 : 100,
            maxHeight: isCompact ? 80 : 120,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: isCompact ? 16 : 20),
                  SizedBox(width: isCompact ? 4 : 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 10 : 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 4 : 8),
              Flexible(
                child: SelectableText(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    fontSize: isCompact ? 12 : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealtimeMetric(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 150;
        return Container(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          constraints: BoxConstraints(
            minHeight: isCompact ? 60 : 80,
            maxHeight: isCompact ? 80 : 100,
          ),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.textLight.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: isCompact ? 10 : 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: isCompact ? 2 : 4),
              Flexible(
                child: SelectableText(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: isCompact ? 14 : null,
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 1 : 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: color,
                  fontSize: isCompact ? 9 : 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsSummary(
    BuildContext context,
    Map<String, dynamic> summary,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final alerts = [
      {
        'label': 'Critical',
        'count': summary['critical'] ?? 0,
        'color': AppTheme.errorRed,
      },
      {
        'label': 'High',
        'count': summary['high'] ?? 0,
        'color': AppTheme.accentOrange,
      },
      {
        'label': 'Medium',
        'count': summary['medium'] ?? 0,
        'color': AppTheme.warningYellow,
      },
      {
        'label': 'Low',
        'count': summary['low'] ?? 0,
        'color': AppTheme.secondaryTeal,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textLight.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alert Summary',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${summary['total'] ?? 0} total',
                style: TextStyle(color: AppTheme.textLight, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: alerts.map((alert) {
              final count = alert['count'] as int;
              final color = alert['color'] as Color;
              final label = alert['label'] as String;

              return Container(
                constraints: BoxConstraints(
                  minWidth: isMobile ? 70 : 80,
                  maxWidth: isMobile ? 120 : 140,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: SelectableText(
                        '$label: $count',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 12,
                          fontWeight: count > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getSystemStatusColor() {
    if (systemHealth == null) return AppTheme.textLight;

    final status = systemHealth!['status'];
    switch (status) {
      case 'healthy':
        return AppTheme.successGreen;
      case 'warning':
        return AppTheme.warningYellow;
      case 'critical':
        return AppTheme.errorRed;
      default:
        return AppTheme.textLight;
    }
  }

  IconData _getSystemStatusIcon() {
    if (systemHealth == null) return Icons.help_outline;

    final status = systemHealth!['status'];
    switch (status) {
      case 'healthy':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  String _getSystemStatusText() {
    if (systemHealth == null) return 'Unknown';

    final status = systemHealth!['status'];
    switch (status) {
      case 'healthy':
        return 'Healthy';
      case 'warning':
        return 'Warning';
      case 'critical':
        return 'Critical';
      default:
        return 'Unknown';
    }
  }

  Color _getMemoryStatusColor() {
    if (systemHealth == null) return AppTheme.textLight;

    final heapUsed = systemHealth!['performance']?['memoryUsage']?['heapUsed'];
    if (heapUsed == null) return AppTheme.textLight;

    // Parse memory usage (assuming format like "256MB")
    final memoryMB = int.tryParse(heapUsed.replaceAll('MB', '')) ?? 0;

    if (memoryMB > 400) return AppTheme.errorRed;
    if (memoryMB > 200) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }

  Color _getResponseTimeColor() {
    if (systemHealth == null) return AppTheme.textLight;

    final responseTime = systemHealth!['performance']?['responseTime'];
    if (responseTime == null) return AppTheme.textLight;

    // Parse response time (assuming format like "150ms")
    final timeMs = int.tryParse(responseTime.replaceAll('ms', '')) ?? 0;

    if (timeMs > 1000) return AppTheme.errorRed;
    if (timeMs > 500) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }
}
