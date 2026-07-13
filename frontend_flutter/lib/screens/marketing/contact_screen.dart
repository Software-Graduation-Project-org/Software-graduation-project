import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/common/footer.dart';
import '../../widgets/animations.dart';
import '../../providers/marketing_provider.dart';
import '../../services/public_api_service.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0 = plan selection, 1 = registration form
  String? _selectedPlan;
  bool _isLoadingTiers = true;
  Map<String, dynamic> _subscriptionTiers = {};

  // Form controllers for registration
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _birthdayController = TextEditingController();
  String? _selectedGender;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _labNameController = TextEditingController();
  final _labLicenseController = TextEditingController();

  // Form controllers for contact form
  final _contactFormKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactLabNameController = TextEditingController();
  final _contactMessageController = TextEditingController();

  DateTime? _selectedBirthday;
  bool _isSubmitting = false;
  bool _isContactSubmitting = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionTiers();
    // Load admin contact information when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketingProvider>().loadAdminContactInfo();
    });
  }

  Future<void> _loadSubscriptionTiers() async {
    try {
      setState(() => _isLoadingTiers = true);
      final response = await PublicApiService.getSubscriptionTiers();
      if (response['success'] == true) {
        setState(() {
          _subscriptionTiers = response['tiers'] ?? {};
          _isLoadingTiers = false;
        });
      } else {
        setState(() => _isLoadingTiers = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load subscription plans')),
          );
        }
      }
    } catch (error) {
      setState(() => _isLoadingTiers = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading plans: $error')));
      }
    }
  }

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
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _contactLabNameController.dispose();
    _contactMessageController.dispose();
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
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  String _getPlanDisplayName(String plan) {
    final tierData = _subscriptionTiers[plan] as Map<String, dynamic>?;
    if (tierData != null) {
      return '${tierData['tier']?.toString().toUpperCase() ?? plan.toUpperCase()} Plan';
    }
    return '${plan.toUpperCase()} Plan';
  }

  String _getPlanPrice(String plan) {
    final tierData = _subscriptionTiers[plan] as Map<String, dynamic>?;
    if (tierData != null) {
      return '\$${tierData['monthlyFee'] ?? 0}/month';
    }
    return '\$0/month';
  }

  String _getPlanDescription(String plan) {
    final tierData = _subscriptionTiers[plan] as Map<String, dynamic>?;
    if (tierData != null) {
      return tierData['description'] ?? 'Contact for details';
    }
    return 'Contact for details';
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
                  child: const Text('OK'),
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

  Future<void> _submitContactForm() async {
    if (_contactFormKey.currentState!.validate()) {
      setState(() => _isContactSubmitting = true);

      try {
        final response = await PublicApiService.submitContactForm(
          name: _contactNameController.text.trim(),
          email: _contactEmailController.text.trim(),
          phone: _contactPhoneController.text.isNotEmpty
              ? _contactPhoneController.text.trim()
              : null,
          labName: _contactLabNameController.text.trim(),
          message: _contactMessageController.text.trim(),
        );

        if (mounted) {
          if (response['success'] == true) {
            // Clear form
            _contactNameController.clear();
            _contactEmailController.clear();
            _contactPhoneController.clear();
            _contactLabNameController.clear();
            _contactMessageController.clear();

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Text('Message Sent!'),
                  ],
                ),
                content: Text(
                  response['message'] ??
                      'Thank you for contacting us. We will get back to you soon.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Failed to send message'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isContactSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = context.useMobileLayout;
    return Consumer<MarketingProvider>(
      builder: (context, marketingProvider, child) {
        return Scaffold(
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(68),
            child: AppNavBar(),
          ),
          endDrawer: useMobileLayout ? const MobileDrawer() : null,
          body: SingleChildScrollView(
            child: Column(
              children: [
                AppAnimations.fadeIn(_buildHeader(context, useMobileLayout)),
                AppAnimations.fadeIn(
                  _currentStep == 0
                      ? _buildPlanSelectionSection(context, useMobileLayout)
                      : _buildRegistrationSection(context, useMobileLayout),
                  delay: 200.ms,
                ),
                if (_currentStep == 0) ...[
                  AppAnimations.fadeIn(
                    _buildContactSection(
                      context,
                      useMobileLayout,
                      marketingProvider,
                    ),
                    delay: 300.ms,
                  ),
                ],
                AppAnimations.fadeIn(const AppFooter(), delay: 400.ms),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              _currentStep == 0
                  ? 'Choose Your Subscription Plan'
                  : 'Complete Your Registration',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 32 : 48,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          AppAnimations.fadeIn(
            Text(
              _currentStep == 0
                  ? 'Select a plan that best fits your laboratory\'s needs. All plans include full system access and support.'
                  : 'Fill out the registration form to get started with your selected plan.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: isMobile ? 16 : 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
          if (_currentStep == 1 && _selectedPlan != null) ...[
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Selected Plan: ${_getPlanDisplayName(_selectedPlan!)} - ${_getPlanPrice(_selectedPlan!)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              delay: 500.ms,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelectionSection(BuildContext context, bool isMobile) {
    if (_isLoadingTiers) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 80,
          vertical: 60,
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading subscription plans...'),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: 60,
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: _subscriptionTiers.entries.map((entry) {
              final planKey = entry.key;
              final planData = entry.value as Map<String, dynamic>;
              return _buildPlanCard(context, planKey, planData, isMobile);
            }).toList(),
          ),
          const SizedBox(height: 40),
          if (_selectedPlan != null)
            AppAnimations.scaleIn(
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _currentStep = 1),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text(
                    'Continue to Registration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              delay: 300.ms,
            ),
        ],
      ),
    );
  }

  Widget _buildContactSection(
    BuildContext context,
    bool isMobile,
    MarketingProvider marketingProvider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: 60,
      ),
      color: Colors.grey[50],
      child: Column(
        children: [
          Text(
            'Contact Us',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Have questions about our subscription plans or need more information? Send us a message and we\'ll get back to you soon.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
            ),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _contactFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send us a message',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'Enter your full name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (!isMobile) const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address *',
                            hintText: 'Enter your email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (!isMobile) const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _contactPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactLabNameController,
                    decoration: const InputDecoration(
                      labelText: 'Laboratory Name *',
                      hintText: 'Enter your laboratory name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Laboratory name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactMessageController,
                    decoration: const InputDecoration(
                      labelText: 'Message *',
                      hintText: 'Tell us about your needs or questions',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Message is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Please provide more details (at least 10 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isContactSubmitting
                          ? null
                          : _submitContactForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isContactSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Send Message',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Contact information cards
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildContactCard(
                context,
                'Phone Support',
                Icons.phone,
                marketingProvider.adminContact?['phone'] ?? '+1 (555) 123-4567',
                'Call us for immediate assistance',
                isMobile,
              ),
              _buildContactCard(
                context,
                'Email Support',
                Icons.email,
                marketingProvider.adminContact?['email'] ??
                    'support@medlab.com',
                'Send us an email for detailed inquiries',
                isMobile,
              ),
              _buildContactCard(
                context,
                'Business Hours',
                Icons.schedule,
                'Mon-Fri: 9AM-6PM',
                'Emergency support available 24/7',
                isMobile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    String title,
    IconData icon,
    String contact,
    String description,
    bool isMobile,
  ) {
    return Container(
      width: isMobile ? double.infinity : 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            contact,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: 60,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Back to Plan Selection',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // First Name
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Middle Name
            TextFormField(
              controller: _middleNameController,
              decoration: const InputDecoration(
                labelText: 'Middle Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Last Name
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your last name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Identity Number
            TextFormField(
              controller: _identityNumberController,
              decoration: const InputDecoration(
                labelText: 'Identity Number *',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your identity number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Birthday
            TextFormField(
              controller: _birthdayController,
              decoration: const InputDecoration(
                labelText: 'Birthday *',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (_selectedBirthday == null) {
                  return 'Please select your birthday';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Gender
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon: Icon(Icons.people),
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Address Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // City
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City *',
                prefixIcon: Icon(Icons.location_city),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your city';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Street
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(
                labelText: 'Street *',
                prefixIcon: Icon(Icons.streetview),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your street';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Building
            TextFormField(
              controller: _buildingController,
              decoration: const InputDecoration(
                labelText: 'Building/Apartment',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Laboratory Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Lab Name
            TextFormField(
              controller: _labNameController,
              decoration: const InputDecoration(
                labelText: 'Laboratory Name *',
                prefixIcon: Icon(Icons.business_center),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your laboratory name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Lab License
            TextFormField(
              controller: _labLicenseController,
              decoration: const InputDecoration(
                labelText: 'Laboratory License Number *',
                prefixIcon: Icon(Icons.verified),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your laboratory license number';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (value) =>
                      setState(() => _termsAccepted = value ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I agree to the Terms and Conditions *',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || !_termsAccepted)
                    ? null
                    : _submitRegistration,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Registration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String planKey,
    Map<String, dynamic> planData,
    bool isMobile,
  ) {
    final isSelected = _selectedPlan == planKey;
    final color = _getPlanColor(planKey);

    return AppAnimations.fadeIn(
      GestureDetector(
        onTap: () => setState(() => _selectedPlan = planKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isMobile ? double.infinity : 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(Icons.business_center, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                _getPlanDisplayName(planKey),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getPlanPrice(planKey),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getPlanDescription(planKey),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlanColor(String plan) {
    switch (plan) {
      case 'starter':
        return Colors.blue;
      case 'professional':
        return Colors.green;
      case 'enterprise':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
