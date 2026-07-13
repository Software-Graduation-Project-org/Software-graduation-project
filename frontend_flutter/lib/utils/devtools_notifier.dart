// Web-only DevTools Detector (reactive)
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';

class DevToolsNotifier extends ChangeNotifier {
  static final DevToolsNotifier instance = DevToolsNotifier._();
  DevToolsNotifier._() {
    if (kIsWeb) {
      // Listen for viewport changes
      html.window.onResize.listen((_) => _check());
      _check();
    }
  }

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  void _check() {
    final visualWidth =
        html.window.visualViewport?.width ?? html.window.innerWidth!.toDouble();
    final windowWidth = html.window.innerWidth!.toDouble();
    final difference = (windowWidth - visualWidth);

    final newState = difference > 100; // DevTools opened

    if (newState != _isOpen) {
      _isOpen = newState;
      notifyListeners();
    }
  }
}
