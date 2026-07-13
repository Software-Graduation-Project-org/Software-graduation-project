import 'package:flutter/widgets.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Performance monitoring utility for tracking app performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<double>> _metrics = {};
  final StreamController<PerformanceEvent> _eventController =
      StreamController.broadcast();

  Stream<PerformanceEvent> get events => _eventController.stream;

  /// Start timing an operation
  void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
    developer.log(
      'Performance: Started timing "$operation"',
      name: 'PerformanceMonitor',
    );
  }

  /// Stop timing an operation and record the duration
  void stopTimer(String operation) {
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsedMilliseconds;
      _recordMetric(operation, duration.toDouble());
      _eventController.add(PerformanceEvent(operation, duration));
      developer.log(
        'Performance: "$operation" completed in ${duration}ms',
        name: 'PerformanceMonitor',
      );
      _timers.remove(operation);
    }
  }

  /// Record a custom metric
  void recordMetric(String name, double value) {
    _recordMetric(name, value);
    _eventController.add(PerformanceEvent(name, value.toInt()));
  }

  void _recordMetric(String name, double value) {
    if (!_metrics.containsKey(name)) {
      _metrics[name] = [];
    }
    _metrics[name]!.add(value);

    // Keep only last 100 measurements to prevent memory leaks
    if (_metrics[name]!.length > 100) {
      _metrics[name]!.removeAt(0);
    }
  }

  /// Get average duration for an operation
  double getAverage(String operation) {
    final values = _metrics[operation];
    if (values == null || values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Get performance statistics
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    _metrics.forEach((key, values) {
      if (values.isNotEmpty) {
        final sorted = List<double>.from(values)..sort();
        stats[key] = {
          'count': values.length,
          'average': values.reduce((a, b) => a + b) / values.length,
          'min': sorted.first,
          'max': sorted.last,
          'median': sorted[sorted.length ~/ 2],
          'latest': values.last,
        };
      }
    });
    return stats;
  }

  /// Clear all metrics
  void clearMetrics() {
    _timers.clear();
    _metrics.clear();
  }

  /// Dispose of resources
  void dispose() {
    _eventController.close();
  }
}

/// Performance event for streaming updates
class PerformanceEvent {
  final String operation;
  final int durationMs;

  PerformanceEvent(this.operation, this.durationMs);

  @override
  String toString() =>
      'PerformanceEvent(operation: $operation, duration: ${durationMs}ms)';
}

/// Widget performance wrapper
class PerformanceTrackedWidget extends StatefulWidget {
  final Widget child;
  final String operationName;

  const PerformanceTrackedWidget({
    super.key,
    required this.child,
    required this.operationName,
  });

  @override
  State<PerformanceTrackedWidget> createState() =>
      _PerformanceTrackedWidgetState();
}

class _PerformanceTrackedWidgetState extends State<PerformanceTrackedWidget> {
  @override
  void initState() {
    super.initState();
    PerformanceMonitor().startTimer('${widget.operationName}_build');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceMonitor().stopTimer('${widget.operationName}_build');
    });

    return widget.child;
  }
}

/// API call performance tracker
class ApiPerformanceTracker {
  static Future<T> track<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    final monitor = PerformanceMonitor();
    monitor.startTimer(operation);

    try {
      final result = await apiCall();
      monitor.stopTimer(operation);
      return result;
    } catch (e) {
      monitor.stopTimer(operation);
      rethrow;
    }
  }
}

/// Navigation performance tracker
class NavigationTracker {
  static void trackRouteChange(String fromRoute, String toRoute) {
    PerformanceMonitor().recordMetric(
      'navigation_${fromRoute}_to_$toRoute',
      0.0, // Navigation time is tracked separately
    );
  }
}
