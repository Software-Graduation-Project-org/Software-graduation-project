import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doctor_auth_provider.dart';
import '../../providers/owner_auth_provider.dart';
import '../../providers/patient_auth_provider.dart';
import '../../providers/staff_auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';

class MergedLoginScreen extends StatefulWidget {
  const MergedLoginScreen({super.key});

  @override
  State<MergedLoginScreen> createState() => _MergedLoginScreenState();
}

class _MergedLoginScreenState extends State<MergedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _logoutAllProviders() async {
    // Logout all auth providers to ensure single user session
    final patientAuth = Provider.of<PatientAuthProvider>(
      context,
      listen: false,
    );
    final doctorAuth = Provider.of<DoctorAuthProvider>(context, listen: false);
    final staffAuth = Provider.of<StaffAuthProvider>(context, listen: false);
    final ownerAuth = Provider.of<OwnerAuthProvider>(context, listen: false);
    final adminAuth = Provider.of<AuthProvider>(context, listen: false);

    await patientAuth.logout();
    await doctorAuth.logout();
    await staffAuth.logout();
    await ownerAuth.logout();
    await adminAuth.logout();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Use unified login endpoint
      final response = await ApiService.post('/public/login', {
        'username': _usernameController.text,
        'password': _passwordController.text,
      });

      if (response['token'] != null && response['role'] != null) {
        final role = response['role'] as String;
        final token = response['token'] as String;
        final route = response['route'] as String? ?? '/';
        final userData = response['user'] as Map<String, dynamic>;

        // Logout all other auth providers before setting up the new one
        await _logoutAllProviders();

        // Set auth token in ApiService
        ApiService.setAuthToken(token);

        // Save token and user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();

        // Set up the appropriate auth provider and save data based on role
        switch (role) {
          case 'patient':
            await prefs.setString('patient_token', token);
            await prefs.setString('patient_id', userData['_id']);
            await prefs.setString('patient_email', userData['email'] ?? '');
            final authProvider = Provider.of<PatientAuthProvider>(
              context,
              listen: false,
            );
            await authProvider.loadAuthState();

            // Check for pending notifications after login
            final pendingType = prefs.getString('pending_notification_type');
            final pendingOrderId = prefs.getString(
              'pending_notification_order_id',
            );
            if (pendingType != null && pendingOrderId != null) {
              // Clear pending notifications
              await prefs.remove('pending_notification_type');
              await prefs.remove('pending_notification_order_id');

              // Navigate to the pending notification destination
              Future.delayed(const Duration(milliseconds: 500), () {
                if (pendingOrderId.isNotEmpty) {
                  context.go('/patient-dashboard/order-report/$pendingOrderId');
                } else {
                  context.go('/patient-dashboard');
                }
              });
            }
            break;
          case 'doctor':
            await prefs.setString('doctor_token', token);
            await prefs.setString('doctor_id', userData['_id']);
            await prefs.setString('doctor_email', userData['email'] ?? '');
            final authProvider = Provider.of<DoctorAuthProvider>(
              context,
              listen: false,
            );
            await authProvider.loadAuthState();
            break;
          case 'Staff':
            await prefs.setString('staff_token', token);
            await prefs.setString('staff_id', userData['_id']);
            await prefs.setString('staff_email', userData['email'] ?? '');
            final authProvider = Provider.of<StaffAuthProvider>(
              context,
              listen: false,
            );
            await authProvider.loadAuthState();
            break;
          case 'owner':
            await prefs.setString('owner_token', token);
            await prefs.setString('owner_id', userData['_id']);
            await prefs.setString('owner_email', userData['email'] ?? '');
            final authProvider = Provider.of<OwnerAuthProvider>(
              context,
              listen: false,
            );
            await authProvider.loadAuthState();
            break;
          case 'admin':
            await prefs.setString('admin_token', token);
            await prefs.setString('admin_id', userData['_id']);
            await prefs.setString('admin_email', userData['email'] ?? '');
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            await authProvider.loadAuthState();
            break;
        }

        // Navigate to the appropriate dashboard
        if (mounted) {
          context.go(route);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Login failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppAnimations.scaleIn(
                        Icon(
                          Icons.medical_services,
                          size: 80,
                          color: AppTheme.primaryBlue,
                        ),
                        delay: 200.ms,
                      ),
                      const SizedBox(height: 16),
                      AppAnimations.fadeIn(
                        Text(
                          'Medical Lab System',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        delay: 400.ms,
                      ),
                      const SizedBox(height: 8),
                      AppAnimations.slideInFromBottom(
                        Text(
                          'Login to your account',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textLight),
                        ),
                        delay: 600.ms,
                      ),
                      const SizedBox(height: 32),
                      AppAnimations.slideInFromRight(
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Email or Username',
                            prefixIcon: Icon(Icons.person),
                            hintText: 'Enter your email or username',
                          ),
                          keyboardType: TextInputType.text,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email or username';
                            }
                            return null;
                          },
                        ),
                        delay: 800.ms,
                      ),
                      const SizedBox(height: 16),
                      AppAnimations.slideInFromLeft(
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        delay: 1000.ms,
                      ),
                      const SizedBox(height: 24),
                      AppAnimations.scaleIn(
                        SizedBox(
                          width: double.infinity,
                          child: AnimatedButton(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                          ),
                        ),
                        delay: 1200.ms,
                      ),
                      const SizedBox(height: 16),
                      AppAnimations.fadeIn(
                        TextButton(
                          onPressed: () {
                            context.go('/');
                          },
                          child: const Text('Back to Home'),
                        ),
                        delay: 1400.ms,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
