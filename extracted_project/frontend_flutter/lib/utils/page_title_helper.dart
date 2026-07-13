import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// Utility class to update browser page title dynamically
class PageTitleHelper {
  /// Update the browser tab title (web only)
  static void updateTitle(String title) {
    if (kIsWeb) {
      html.document.title = title;
    }
  }

  /// Get title based on role and screen
  static String getTitleForRole({required String role, String? screenName}) {
    final baseTitle = 'MedLab System';

    switch (role.toLowerCase()) {
      case 'owner':
        return screenName != null
            ? '$screenName - Owner Dashboard - $baseTitle'
            : 'Owner Dashboard - $baseTitle';

      case 'staff':
        return screenName != null
            ? '$screenName - Staff Dashboard - $baseTitle'
            : 'Staff Dashboard - $baseTitle';

      case 'patient':
        return screenName != null
            ? '$screenName - Patient Portal - $baseTitle'
            : 'Patient Portal - $baseTitle';

      case 'doctor':
        return screenName != null
            ? '$screenName - Doctor Portal - $baseTitle'
            : 'Doctor Portal - $baseTitle';

      case 'admin':
        return screenName != null
            ? '$screenName - Admin Dashboard - $baseTitle'
            : 'Admin Dashboard - $baseTitle';

      default:
        return screenName != null ? '$screenName - $baseTitle' : baseTitle;
    }
  }
}
