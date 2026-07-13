import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/performance_monitor.dart';
import '../../config/theme.dart';

class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key});

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard> {
  Map<String, dynamic> _stats = {};
  final List<PerformanceEvent> _recentEvents = [];
  StreamSubscription<PerformanceEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _subscription = PerformanceMonitor().events.listen((event) {
      setState(() {
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 20) {
          _recentEvents.removeLast();
        }
        _loadStats();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadStats() {
    setState(() {
      _stats = PerformanceMonitor().getStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Performance Monitor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStats,
                  tooltip: 'Refresh Stats',
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    PerformanceMonitor().clearMetrics();
                    setState(() {
                      _stats.clear();
                      _recentEvents.clear();
                    });
                  },
                  tooltip: 'Clear Metrics',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_stats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No performance data available yet'),
                ),
              )
            else
              _buildStatsGrid(),
            const SizedBox(height: 16),
            if (_recentEvents.isNotEmpty) ...[
              Text(
                'Recent Events',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _recentEvents.length,
                  itemBuilder: (context, index) {
                    final event = _recentEvents[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getEventIcon(event.operation),
                        size: 20,
                        color: _getEventColor(event.durationMs),
                      ),
                      title: Text(
                        event.operation,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Text(
                        '${event.durationMs}ms',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getEventColor(event.durationMs),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: _stats.length,
      itemBuilder: (context, index) {
        final entry = _stats.entries.elementAt(index);
        final stat = entry.value as Map<String, dynamic>;

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${stat['average'].toStringAsFixed(1)}ms avg',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${stat['count']} calls',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getEventIcon(String operation) {
    if (operation.contains('api') || operation.contains('API')) {
      return Icons.cloud;
    } else if (operation.contains('build')) {
      return Icons.build;
    } else if (operation.contains('navigation')) {
      return Icons.navigation;
    } else {
      return Icons.speed;
    }
  }

  Color _getEventColor(int durationMs) {
    if (durationMs < 100) return Colors.green;
    if (durationMs < 500) return Colors.orange;
    return Colors.red;
  }
}
