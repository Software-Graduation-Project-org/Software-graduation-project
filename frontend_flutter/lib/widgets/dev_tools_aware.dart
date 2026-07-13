import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// A widget that handles browser dev tools overlay issues on web
class DevToolsAware extends StatefulWidget {
  final Widget child;

  const DevToolsAware({super.key, required this.child});

  @override
  State<DevToolsAware> createState() => _DevToolsAwareState();
}

class _DevToolsAwareState extends State<DevToolsAware>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Force rebuild when viewport changes (dev tools opened/closed)
    if (kIsWeb && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: widget.child,
        );
      },
    );
  }
}
