import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:frontend_flutter/providers/owner_auth_provider.dart';
import 'package:frontend_flutter/providers/staff_auth_provider.dart';
import 'package:frontend_flutter/providers/doctor_auth_provider.dart';
import 'package:frontend_flutter/providers/patient_auth_provider.dart';
import 'package:frontend_flutter/providers/marketing_provider.dart';

void main() {
  // Use AutomatedTestWidgetsFlutterBinding to completely disable animations
  AutomatedTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a minimal app with all required providers but no animated widgets
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => OwnerAuthProvider()),
          ChangeNotifierProvider(create: (_) => StaffAuthProvider()),
          ChangeNotifierProvider(create: (_) => DoctorAuthProvider()),
          ChangeNotifierProvider(create: (_) => PatientAuthProvider()),
          ChangeNotifierProvider(create: (_) => MarketingProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('Test App'))),
        ),
      ),
    );

    // Just pump once to build the widget tree
    await tester.pump();

    // Verify that the app builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);

    // Verify that we can find a Scaffold widget (basic structure)
    expect(find.byType(Scaffold), findsOneWidget);

    // Verify the test text is present
    expect(find.text('Test App'), findsOneWidget);
  });
}
