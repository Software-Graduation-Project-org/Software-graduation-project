import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../utils/devtools_notifier.dart';
import 'freeze_viewport.dart';

class DevToolsAdaptiveWrapper extends StatefulWidget {
  final Widget child;

  const DevToolsAdaptiveWrapper({super.key, required this.child});

  @override
  State<DevToolsAdaptiveWrapper> createState() =>
      _DevToolsAdaptiveWrapperState();
}

class _DevToolsAdaptiveWrapperState extends State<DevToolsAdaptiveWrapper> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      DevToolsNotifier.instance.addListener(_onDevToolsChange);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      DevToolsNotifier.instance.removeListener(_onDevToolsChange);
    }
    super.dispose();
  }

  void _onDevToolsChange() {
    setState(() {}); // Rebuild when DevTools open/close
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return widget.child; // Phones stay normal always
    }

    return DevToolsNotifier.instance.isOpen
        ? FreezeViewport(child: widget.child)
        : widget.child;
  }
}
