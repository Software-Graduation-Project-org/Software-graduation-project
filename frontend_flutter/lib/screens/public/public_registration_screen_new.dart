import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/public_api_service.dart';
import '../../models/lab.dart';
import '../../models/test.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';

class PublicRegistrationScreen extends StatefulWidget {
  const PublicRegistrationScreen({super.key});

  @override
  State<PublicRegistrationScreen> createState() =>
      _PublicRegistrationScreenState();
}

class _PublicRegistrationScreenState extends State<PublicRegistrationScreen> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _socialStatusController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _remarksController = TextEditingController();

  // Form data
  String? _selectedLabId;
  String? _selectedGender;
  final List<String> _selectedTestIds = [];
  List<Lab> _availableLabs = [];
  List<Test> _availableTests = [];
  bool _isLoading = false;
  bool _isLoadingLabs = true;
  bool _isLoadingTests = false;
  int _currentStep = 0;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _socialStatuses = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
  ];

  @override
  void initState() {
    super.initState();
    _loadLabs();
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
    _addressController.dispose();
    _socialStatusController.dispose();
    _insuranceProviderController.dispose();
    _insuranceNumberController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadLabs() async {
    try {
      setState(() => _isLoadingLabs = true);
      final response = await PublicApiService.getLabs();

      if (response['success'] == true) {
        final labsData = response['labs'] as List<dynamic>;
        debugPrint('DEBUG: Processing ${labsData.length} labs');
        _availableLabs = labsData.map((lab) {
          debugPrint('DEBUG: Raw lab data: $lab');
          final parsedLab = Lab.fromJson(lab);
          debugPrint(
            'DEBUG: Parsed lab - ID: ${parsedLab.id}, Name: "${parsedLab.labName}"',
          );
          return parsedLab;
        }).toList();
        debugPrint(
          'DEBUG: Final labs list: ${_availableLabs.map((l) => '${l.id}: "${l.labName}"').join(', ')}',
        );
        setState(() {
          _isLoadingLabs = false;
        });
      } else {
        setState(() => _isLoadingLabs = false);
        _showError('Failed to load labs');
      }
    } catch (e) {
      setState(() => _isLoadingLabs = false);
      _showError('Network error: $e');
    }
  }

  Future<void> _loadTestsForLab(String labId) async {
    if (labId.isEmpty) return;

    try {
      setState(() => _isLoadingTests = true);
      final response = await PublicApiService.getLabTests(labId);

      if (response['success'] == true) {
        final testsData = response['tests'] as List<dynamic>;
        setState(() {
          _availableTests = testsData
              .map((test) => Test.fromJson(test))
              .toList();
          _isLoadingTests = false;
        });
      } else {
        setState(() => _isLoadingTests = false);
        _showError('Failed to load tests');
      }
    } catch (e) {
      setState(() => _isLoadingTests = false);
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLabId == null) {
      _showError('Please select a lab');
      return;
    }
    if (_selectedTestIds.isEmpty) {
      _showError('Please select at least one test');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await PublicApiService.submitRegistration(
        labId: _selectedLabId!,
        fullName: {
          'first': _firstNameController.text.trim(),
          'middle': _middleNameController.text.trim(),
          'last': _lastNameController.text.trim(),
        },
        identityNumber: _identityNumberController.text.trim(),
        birthday: _birthdayController.text,
        gender: _selectedGender!,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        testIds: _selectedTestIds,
        socialStatus: _socialStatusController.text.isNotEmpty
            ? _socialStatusController.text
            : null,
        insuranceProvider: _insuranceProviderController.text.isNotEmpty
            ? _insuranceProviderController.text
            : null,
        insuranceNumber: _insuranceNumberController.text.isNotEmpty
            ? _insuranceNumberController.text
            : null,
        remarks: _remarksController.text.isNotEmpty
            ? _remarksController.text
            : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['success'] != false) {
          _showSuccessDialog(response);
        } else {
          _showError(response['message'] ?? 'Registration failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Network error: $e');
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> response) {
    final registration = response['registration'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Submitted Successfully!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                size: 64,
                color: AppTheme.successGreen,
              ),
              const SizedBox(height: 16),
              Text(
                'Order ID: ${registration['order_id']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Lab: ${registration['lab_name']}'),
              Text('Tests Ordered: ${registration['tests_count']}'),
              Text('Total Cost: ${registration['total_cost']} ILS'),
              const SizedBox(height: 16),
              const Text(
                'Check your email and SMS for account creation link.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index <= _currentStep
                ? AppTheme.primaryBlue
                : Colors.grey[300],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registration'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
          tooltip: 'Return to Home',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AnimatedCard(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppAnimations.scaleIn(
                      Icon(
                        Icons.person_add,
                        size: 64,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppAnimations.fadeIn(
                      Text(
                        'Order Tests',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      delay: 200.ms,
                    ),
                    const SizedBox(height: 8),
                    AppAnimations.fadeIn(
                      Text(
                        'Complete your information to order lab tests',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      delay: 400.ms,
                    ),
                    const SizedBox(height: 24),
                    _buildStepIndicator(),
                    const SizedBox(height: 32),

                    // Step content
                    if (_currentStep == 0) _buildLabSelectionStep(),
                    if (_currentStep == 1) _buildPersonalInfoStep(),
                    if (_currentStep == 2) _buildTestSelectionStep(),
                    if (_currentStep == 3) _buildReviewStep(),

                    const SizedBox(height: 32),

                    // Navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          ElevatedButton(
                            onPressed: _previousStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                            child: const Text('Previous'),
                          )
                        else
                          const SizedBox.shrink(),

                        if (_currentStep < 3)
                          ElevatedButton(
                            onPressed: _nextStep,
                            child: const Text('Next'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
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
                                : const Text('Submit Order'),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    AppAnimations.fadeIn(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account? '),
                          TextButton(
                            onPressed: () {
                              context.goNamed('merged-login');
                            },
                            child: const Text('Login'),
                          ),
                        ],
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
    );
  }

  Widget _buildLabSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAnimations.fadeIn(
          Text(
            'Step 1: Select Lab',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingLabs)
          const Center(child: CircularProgressIndicator())
        else
          AppAnimations.slideInFromLeft(
            DropdownButtonFormField<String>(
              initialValue: _selectedLabId,
              decoration: const InputDecoration(
                labelText: 'Choose Lab *',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
              items: _availableLabs.map((lab) {
                return DropdownMenuItem<String>(
                  value: lab.id,
                  child: Text(lab.labName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLabId = value;
                  _selectedTestIds.clear();
                  _availableTests.clear();
                });
                if (value != null) {
                  _loadTestsForLab(value);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a lab';
                }
                return null;
              },
            ),
            delay: 200.ms,
          ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAnimations.fadeIn(
          Text(
            'Step 2: Personal Information',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        // Name fields
        Row(
          children: [
            Expanded(
              child: AppAnimations.slideInFromLeft(
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                delay: 200.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppAnimations.slideInFromRight(
                TextFormField(
                  controller: _middleNameController,
                  decoration: const InputDecoration(
                    labelText: 'Middle Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                delay: 400.ms,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppAnimations.slideInFromLeft(
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          delay: 600.ms,
        ),

        const SizedBox(height: 16),

        // ID and Birthday
        Row(
          children: [
            Expanded(
              child: AppAnimations.slideInFromRight(
                TextFormField(
                  controller: _identityNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Identity Number *',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                delay: 800.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppAnimations.slideInFromLeft(
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
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                delay: 1000.ms,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Gender and Phone
        Row(
          children: [
            Expanded(
              child: AppAnimations.slideInFromRight(
                DropdownButtonFormField<String>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  items: _genders.map((gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedGender = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                delay: 1200.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppAnimations.slideInFromLeft(
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                delay: 1400.ms,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Email and Address
        AppAnimations.slideInFromRight(
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              if (!value.contains('@')) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          delay: 1600.ms,
        ),

        const SizedBox(height: 12),

        AppAnimations.slideInFromLeft(
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address *',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            },
          ),
          delay: 1800.ms,
        ),

        const SizedBox(height: 16),

        // Optional fields
        AppAnimations.slideInFromRight(
          DropdownButtonFormField<String>(
            initialValue: _socialStatusController.text.isNotEmpty
                ? _socialStatusController.text
                : null,
            decoration: const InputDecoration(
              labelText: 'Social Status (Optional)',
              prefixIcon: Icon(Icons.family_restroom),
              border: OutlineInputBorder(),
            ),
            items: _socialStatuses.map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _socialStatusController.text = value ?? '');
            },
          ),
          delay: 2000.ms,
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: AppAnimations.slideInFromLeft(
                TextFormField(
                  controller: _insuranceProviderController,
                  decoration: const InputDecoration(
                    labelText: 'Insurance Provider',
                    prefixIcon: Icon(Icons.health_and_safety),
                    border: OutlineInputBorder(),
                  ),
                ),
                delay: 2200.ms,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppAnimations.slideInFromRight(
                TextFormField(
                  controller: _insuranceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Insurance Number',
                    prefixIcon: Icon(Icons.numbers),
                    border: OutlineInputBorder(),
                  ),
                ),
                delay: 2400.ms,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTestSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAnimations.fadeIn(
          Text(
            'Step 3: Select Tests',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        if (_selectedLabId == null)
          const Center(child: Text('Please select a lab first'))
        else if (_isLoadingTests)
          const Center(child: CircularProgressIndicator())
        else if (_availableTests.isEmpty)
          const Center(child: Text('No tests available for this lab'))
        else
          AppAnimations.slideInFromLeft(
            Column(
              children: _availableTests.map((test) {
                final isSelected = _selectedTestIds.contains(test.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    title: Text(test.testName),
                    subtitle: Text('${test.testCode} - ${test.price ?? 0} ILS'),
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedTestIds.add(test.id);
                        } else {
                          _selectedTestIds.remove(test.id);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            delay: 200.ms,
          ),

        if (_selectedTestIds.isNotEmpty)
          AppAnimations.fadeIn(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedTestIds.length} test(s) selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            delay: 400.ms,
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final selectedLab = _availableLabs.firstWhere(
      (lab) => lab.id == _selectedLabId,
      orElse: () => Lab(id: '', labName: 'Unknown'),
    );

    final selectedTests = _availableTests
        .where((test) => _selectedTestIds.contains(test.id))
        .toList();

    final totalCost = selectedTests.fold<double>(
      0,
      (sum, test) => sum + (test.price ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAnimations.fadeIn(
          Text(
            'Step 4: Review & Submit',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),

        // Personal Information
        AppAnimations.slideInFromLeft(
          _buildReviewSection('Personal Information', [
            'Name: ${_firstNameController.text} ${_middleNameController.text} ${_lastNameController.text}'
                .trim(),
            'ID: ${_identityNumberController.text}',
            'Birthday: ${_birthdayController.text}',
            'Gender: $_selectedGender',
            'Phone: ${_phoneController.text}',
            'Email: ${_emailController.text}',
            'Address: ${_addressController.text}',
          ]),
          delay: 200.ms,
        ),

        const SizedBox(height: 16),

        // Lab Information
        AppAnimations.slideInFromRight(
          _buildReviewSection('Selected Lab', [
            'Lab: ${selectedLab.labName}',
            'Phone: ${selectedLab.phoneNumber ?? 'N/A'}',
            'Email: ${selectedLab.email ?? 'N/A'}',
          ]),
          delay: 400.ms,
        ),

        const SizedBox(height: 16),

        // Tests
        AppAnimations.slideInFromLeft(
          _buildReviewSection(
            'Selected Tests (${selectedTests.length})',
            selectedTests
                .map(
                  (test) =>
                      '${test.testName} (${test.testCode}) - ${test.price ?? 0} ILS',
                )
                .toList(),
          ),
          delay: 600.ms,
        ),

        const SizedBox(height: 16),

        // Total
        AppAnimations.slideInFromRight(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.successGreen),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Cost:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${totalCost.toStringAsFixed(2)} ILS',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          ),
          delay: 800.ms,
        ),

        const SizedBox(height: 16),

        // Remarks
        if (_remarksController.text.isNotEmpty)
          AppAnimations.slideInFromLeft(
            _buildReviewSection('Remarks', [_remarksController.text]),
            delay: 1000.ms,
          ),
      ],
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
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
}
