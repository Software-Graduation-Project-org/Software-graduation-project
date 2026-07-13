import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/common/footer.dart';
import '../../services/public_api_service.dart';

class OwnerRegistrationScreen extends StatefulWidget {
  const OwnerRegistrationScreen({super.key});

  @override
  State<OwnerRegistrationScreen> createState() =>
      _OwnerRegistrationScreenState();
}

class _OwnerRegistrationScreenState extends State<OwnerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _termsAccepted = false;

  // Personal Information Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _birthdayController = TextEditingController();
  String? _selectedGender;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Address Controllers
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();

  // Lab Information Controllers
  final _labNameController = TextEditingController();
  final _labLicenseController = TextEditingController();
  String? _selectedPlan;

  // Account Credentials Controllers - REMOVED
  // final _usernameController = TextEditingController();
  // final _passwordController = TextEditingController();
  // final _confirmPasswordController = TextEditingController();

  DateTime? _selectedBirthday;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _identityNumberController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _labNameController.dispose();
    _labLicenseController.dispose();
    // _usernameController.dispose();
    // _passwordController.dispose();
    // _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final response = await PublicApiService.submitOwnerRegistration(
          firstName: _firstNameController.text.trim(),
          middleName: _middleNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          identityNumber: _identityNumberController.text.trim(),
          birthday: _selectedBirthday!.toIso8601String(),
          gender: _selectedGender!,
          phone: _phoneController.text.trim(),
          address:
              '${_cityController.text.trim()}, ${_streetController.text.trim()}, ${_buildingController.text.trim()}',
          email: _emailController.text.trim(),
          selectedPlan: _selectedPlan!, // Use selected plan
          labName: _labNameController.text.trim(),
          labLicenseNumber: _labLicenseController.text.trim(),
        );

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Text('Registration Submitted!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    response['message'] ??
                        'Your registration has been submitted successfully.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Subscription Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly Fee: \$${response['subscription']?['monthlyFee'] ?? 50}',
                  ),
                  Text(
                    'Plan: ${response['subscription']?['description'] ?? 'Starter'}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You will receive an email once your account is approved by our admin team. This typically takes 24-48 hours.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Use GoRouter to navigate to home instead of popping
                    context.go('/'); // Navigate to home page
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 32),
                  SizedBox(width: 12),
                  Text('Registration Failed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (() {
                      final errorMessage = error.toString();
                      if (errorMessage.contains('Registration failed:')) {
                        return errorMessage.replaceAll(
                          'Registration failed: ',
                          '',
                        );
                      }
                      return 'Registration failed: $errorMessage';
                    })(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please check your information and try again. If the problem persists, contact our support team.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with responsive layout
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                context.push('/login');
              },
              icon: const Icon(Icons.login, size: 18),
              label: const Text(
                'Already have an account? Login',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Name fields - responsive layout
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // Mobile: Stack vertically
              return Column(
                children: [
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _middleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Middle Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                ],
              );
            } else {
              // Desktop: Row layout
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _middleNameController,
                      decoration: const InputDecoration(
                        labelText: 'Middle Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _identityNumberController,
                decoration: const InputDecoration(
                  labelText: 'Identity Number *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _birthdayController,
                decoration: const InputDecoration(
                  labelText: 'Birthday *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender *',
                  border: OutlineInputBorder(),
                ),
                items: ['Male', 'Female']
                    .map(
                      (gender) =>
                          DropdownMenuItem(value: gender, child: Text(gender)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Phone and Email - responsive
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(),
                      helperText: 'Example: yourname@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Email is required';
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value!)) {
                        return 'Please enter a valid email address';
                      }
                      if (value.length > 254) {
                        return 'Email address is too long';
                      }
                      return null;
                    },
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        border: OutlineInputBorder(),
                        helperText: 'Example: yourname@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Email is required';
                        final emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegex.hasMatch(value!)) {
                          return 'Please enter a valid email address';
                        }
                        if (value.length > 254) {
                          return 'Email address is too long';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Address',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _buildingController,
                    decoration: const InputDecoration(
                      labelText: 'Building Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Street',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _buildingController,
                      decoration: const InputDecoration(
                        labelText: 'Building Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildLabInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laboratory Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _labNameController,
          decoration: const InputDecoration(
            labelText: 'Laboratory Name *',
            border: OutlineInputBorder(),
            helperText: 'The official name of your laboratory',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _labLicenseController,
          decoration: const InputDecoration(
            labelText: 'Laboratory License Number',
            border: OutlineInputBorder(),
            helperText: 'Optional: Your lab\'s official license number',
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionPlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Your Subscription Plan',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select a plan that best fits your laboratory\'s needs. All plans include full system access and support.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _buildPlanCard(
          'Starter',
          'Perfect for small laboratories',
          'Up to 500 patients/month',
          '\$50/month',
          'Basic email support',
          'starter',
          Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          'Professional',
          'Ideal for growing laboratories',
          'Up to 2,000 patients/month',
          '\$100/month',
          'Priority email support\nAdvanced analytics',
          'professional',
          Colors.green,
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          'Enterprise',
          'For large medical facilities',
          'Unlimited patients',
          '\$200/month',
          '24/7 phone support\nCustom integrations\nDedicated account manager',
          'enterprise',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    String title,
    String subtitle,
    String capacity,
    String price,
    String features,
    String planValue,
    Color accentColor,
  ) {
    final isSelected = _selectedPlan == planValue;
    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? accentColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPlan = planValue),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people, color: Colors.grey.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    capacity,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features
                    .split('\n')
                    .map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: accentColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature.trim(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Your Information',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        // Selected Plan Summary
        if (_selectedPlan != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Selected Subscription Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getPlanDisplayName(_selectedPlan!),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monthly Fee: ${_getPlanPrice(_selectedPlan!)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  _getPlanDescription(_selectedPlan!),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please go back and select a subscription plan to continue.',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Personal Info Review
        _buildReviewSection('Personal Information', [
          'Name: ${_firstNameController.text} ${_middleNameController.text} ${_lastNameController.text}',
          'Identity: ${_identityNumberController.text}',
          'Birthday: ${_birthdayController.text}',
          'Gender: ${_selectedGender ?? ''}',
          'Phone: ${_phoneController.text}',
          'Email: ${_emailController.text}',
        ]),
        const SizedBox(height: 16),

        // Lab Info Review
        _buildReviewSection('Laboratory Information', [
          'Lab Name: ${_labNameController.text}',
          if (_labLicenseController.text.isNotEmpty)
            'License: ${_labLicenseController.text}',
        ]),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your registration will be reviewed by our admin team within 24-48 hours. You will receive an email notification once approved.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Terms of Service Checkbox
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _termsAccepted
                  ? Colors.green.shade200
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: CheckboxListTile(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() => _termsAccepted = value ?? false);
            },
            title: const Text(
              'I accept the Terms of Service and Privacy Policy',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'By registering, you agree to our terms and conditions',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item),
            ),
          ),
        ],
      ),
    );
  }

  String _getPlanDisplayName(String plan) {
    switch (plan) {
      case 'starter':
        return 'Starter Plan';
      case 'professional':
        return 'Professional Plan';
      case 'enterprise':
        return 'Enterprise Plan';
      default:
        return 'Starter Plan';
    }
  }

  String _getPlanPrice(String plan) {
    switch (plan) {
      case 'starter':
        return '\$50/month';
      case 'professional':
        return '\$100/month';
      case 'enterprise':
        return '\$200/month';
      default:
        return '\$50/month';
    }
  }

  String _getPlanDescription(String plan) {
    switch (plan) {
      case 'starter':
        return 'Up to 500 patients/month • Basic email support';
      case 'professional':
        return 'Up to 2,000 patients/month • Priority email support • Advanced analytics';
      case 'enterprise':
        return 'Unlimited patients • 24/7 phone support • Custom integrations • Dedicated account manager';
      default:
        return 'Up to 500 patients/month • Basic email support';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(68),
        child: AppNavBar(),
      ),
      endDrawer: useMobileLayout ? const MobileDrawer() : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(48),
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Form(
                key: _formKey,
                child: Stepper(
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep < 3) {
                      // Validate current step before proceeding
                      if (_currentStep == 2 && _selectedPlan == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select a subscription plan to continue',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      // Don't validate the entire form, just move to next step
                      // Individual fields have validators but we'll check them on submit
                      setState(() => _currentStep++);
                    } else {
                      if (!_termsAccepted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please accept the Terms of Service to continue',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      // Validate entire form before final submission
                      if (_formKey.currentState!.validate()) {
                        _submitRegistration();
                      }
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setState(() => _currentStep--);
                    }
                  },
                  onStepTapped: (step) {
                    // Prevent jumping to review step without selecting a plan
                    if (step == 3 && _selectedPlan == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select a subscription plan first',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    // Allow navigation to previous steps or to current/completed steps
                    if (step <= _currentStep || step < 3) {
                      setState(() => _currentStep = step);
                    }
                  },
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : details.onStepContinue,
                            child: Text(
                              _currentStep == 3
                                  ? 'Submit Registration'
                                  : 'Continue',
                            ),
                          ),
                          if (_currentStep > 0)
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : details.onStepCancel,
                              child: const Text('Back'),
                            ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Personal Information'),
                      content: _buildPersonalInfoStep(),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Laboratory Information'),
                      content: _buildLabInfoStep(),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Choose Subscription Plan'),
                      content: _buildSubscriptionPlanStep(),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Review & Submit'),
                      content: _buildReviewStep(),
                      isActive: _currentStep >= 3,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
