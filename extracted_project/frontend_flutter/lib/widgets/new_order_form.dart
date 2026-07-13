import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/staff_api_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/test_search_widget.dart';

class NewOrderForm extends StatefulWidget {
  final Future<void> Function()? onOrderCreated;

  const NewOrderForm({super.key, this.onOrderCreated});

  @override
  State<NewOrderForm> createState() => _NewOrderFormState();
}

class _NewOrderFormState extends State<NewOrderForm> {
  final _formKey = GlobalKey<FormState>();

  // Patient Information Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _insuranceProviderController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _birthday;
  String _selectedGender = 'Male';
  String _selectedSocialStatus = 'Single';

  // Doctor selection
  List<Map<String, dynamic>> _availableDoctors = [];
  Map<String, dynamic>? _selectedDoctor;
  bool _isLoadingDoctors = false;

  // Available tests and selected tests
  List<Map<String, dynamic>> _availableTests = [];
  final List<Map<String, dynamic>> _selectedTests = [];
  bool _isLoadingTests = false;
  bool _isSubmitting = false;

  // Filtered tests for display
  List<Map<String, dynamic>> _filteredTests = [];

  // Patient search
  final _patientSearchController = TextEditingController();
  List<Map<String, dynamic>> _patientSearchResults = [];
  bool _isSearchingPatients = false;
  Map<String, dynamic>? _selectedPatient;

  @override
  void initState() {
    super.initState();
    _loadAvailableTests();
    _loadAvailableDoctors();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _identityNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _insuranceProviderController.dispose();
    _insuranceNumberController.dispose();
    _notesController.dispose();
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDoctors() async {
    setState(() => _isLoadingDoctors = true);

    try {
      final response = await StaffApiService.getLabDoctors();

      if (mounted) {
        setState(() {
          _availableDoctors = List<Map<String, dynamic>>.from(
            response['doctors'] ?? [],
          );
          _isLoadingDoctors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDoctors = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load doctors: $e')));
      }
    }
  }

  Future<void> _loadAvailableTests() async {
    setState(() => _isLoadingTests = true);

    try {
      final response = await StaffApiService.getLabTests();

      if (mounted) {
        setState(() {
          _availableTests = List<Map<String, dynamic>>.from(
            response['tests'] ?? [],
          );
          _filteredTests = _availableTests;
          _isLoadingTests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTests = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tests: $e')));
      }
    }
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _patientSearchResults = []);
      return;
    }

    setState(() => _isSearchingPatients = true);

    try {
      final response = await StaffApiService.searchPatients(query);

      if (mounted) {
        setState(() {
          _patientSearchResults = List<Map<String, dynamic>>.from(
            response['patients'] ?? [],
          );
          _isSearchingPatients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingPatients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search patients: $e')),
        );
      }
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatient = patient;
      _patientSearchController.clear();
      _patientSearchResults = [];

      // Populate form fields with patient data
      _firstNameController.text = patient['name']?.split(' ')?.first ?? '';
      _lastNameController.text = patient['name']?.split(' ')?.last ?? '';
      _emailController.text = patient['email'] ?? '';
      _phoneController.text = patient['phone'] ?? '';
      _identityNumberController.text = patient['identity_number'] ?? '';

      if (patient['birthday'] != null) {
        _birthday = DateTime.parse(patient['birthday']);
      }

      if (patient['gender'] != null) {
        _selectedGender = patient['gender'];
      }
    });
  }

  void _clearPatientSelection() {
    setState(() {
      _selectedPatient = null;
      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
      _identityNumberController.clear();
      _emailController.clear();
      _phoneController.clear();
      _streetController.clear();
      _cityController.clear();
      _insuranceProviderController.clear();
      _insuranceNumberController.clear();
      _notesController.clear();
      _birthday = null;
      _selectedGender = 'Male';
      _selectedSocialStatus = 'Single';
    });
  }

  Future<void> _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  void _toggleTestSelection(Map<String, dynamic> test) {
    setState(() {
      final index = _selectedTests.indexWhere((t) => t['_id'] == test['_id']);

      if (index >= 0) {
        _selectedTests.removeAt(index);
      } else {
        _selectedTests.add(test);
      }
    });
  }

  bool _isTestSelected(Map<String, dynamic> test) {
    return _selectedTests.any((t) => t['_id'] == test['_id']);
  }

  double _getTotalCost() {
    return _selectedTests.fold(0.0, (sum, test) {
      final price = test['price'];
      if (price is num) return sum + price.toDouble();
      return sum;
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one test')),
      );
      return;
    }

    if (_birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select patient birthday')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Create order through staff API
      final response = await StaffApiService.createWalkInOrder(
        patientInfo: {
          'full_name': {
            'first': _firstNameController.text.trim(),
            'middle': _middleNameController.text.trim(),
            'last': _lastNameController.text.trim(),
          },
          'identity_number': _identityNumberController.text.trim(),
          'email': _emailController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'birthday': _birthday!.toIso8601String(),
          'gender': _selectedGender,
          'social_status': _selectedSocialStatus,
          'address': {
            'street': _streetController.text.trim(),
            'city': _cityController.text.trim(),
            'country': 'Palestine',
          },
          'insurance_provider': _insuranceProviderController.text.trim(),
          'insurance_number': _insuranceNumberController.text.trim(),
          'notes': _notesController.text.trim(),
        },
        testIds: _selectedTests.map((t) => t['_id'].toString()).toList(),
        doctorId: _selectedDoctor?['_id'],
      );

      if (mounted) {
        final credentials = response['credentials'];
        final isNewAccount = response['patient']?['is_new_account'] ?? false;

        // Show success dialog with credentials
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Order Created Successfully'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNewAccount && credentials != null) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_circle, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'New Patient Account Created',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildCredentialRow(
                            'Username',
                            credentials['username'],
                          ),
                          SizedBox(height: 8),
                          _buildCredentialRow(
                            'Password',
                            credentials['password'],
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email,
                                  size: 16,
                                  color: Colors.amber.shade900,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    credentials['message'] ??
                                        'Credentials sent via email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Order linked to existing patient account',
                              style: TextStyle(color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Close dialog first to avoid context issues
                  if (mounted) {
                    Navigator.pop(context);
                  }
                  // Then call the callback
                  await widget.onOrderCreated?.call();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );

        // Reset form
        _formKey.currentState!.reset();
        _firstNameController.clear();
        _middleNameController.clear();
        _lastNameController.clear();
        _identityNumberController.clear();
        _emailController.clear();
        _phoneController.clear();
        _streetController.clear();
        _cityController.clear();
        _insuranceProviderController.clear();
        _insuranceNumberController.clear();
        _notesController.clear();
        setState(() {
          _birthday = null;
          _selectedTests.clear();
          _selectedGender = 'Male';
          _selectedSocialStatus = 'Single';
          _selectedDoctor = null;
          _isSubmitting = false;
          _selectedPatient = null;
          _patientSearchController.clear();
          _patientSearchResults = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Search Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.search, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Text(
                        'Search Existing Patient',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Search for an existing patient by name, email, or ID. If found, their information will be pre-filled.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  CustomTextField(
                    controller: _patientSearchController,
                    label: 'Search Patient',
                    prefixIcon: Icons.search,
                    hint: 'Enter patient name, email, or ID...',
                    onChanged: _searchPatients,
                  ),

                  // Selected Patient Display
                  if (_selectedPatient != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.successGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient Selected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                Text(
                                  _selectedPatient!['name'] ?? '',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                if (_selectedPatient!['email'] != null)
                                  Text(
                                    _selectedPatient!['email'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: _clearPatientSelection,
                            tooltip: 'Clear selection',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Search Results
                  if (_patientSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Search Results',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _patientSearchResults.length,
                        itemBuilder: (context, index) {
                          final patient = _patientSearchResults[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: AppTheme.primaryBlue,
                            ),
                            title: Text(patient['name'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (patient['email'] != null)
                                  Text('Email: ${patient['email']}'),
                                if (patient['phone'] != null)
                                  Text('Phone: ${patient['phone']}'),
                                if (patient['identity_number'] != null)
                                  Text('ID: ${patient['identity_number']}'),
                              ],
                            ),
                            onTap: () => _selectPatient(patient),
                          );
                        },
                      ),
                    ),
                  ],

                  // Loading Indicator
                  if (_isSearchingPatients) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],

                  // No Results Message
                  if (!_isSearchingPatients &&
                      _patientSearchController.text.length >= 2 &&
                      _patientSearchResults.isEmpty) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'No patients found. You can proceed to enter new patient information below.',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Patient Information Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedPatient != null
                              ? 'Patient Information (Pre-filled from search)'
                              : 'Patient Information',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_selectedPatient != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            'Existing Patient',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name Fields
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _firstNameController,
                                    label: 'First Name',
                                    prefixIcon: Icons.person_outline,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'First name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _middleNameController,
                                    label: 'Middle Name',
                                    prefixIcon: Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _lastNameController,
                                    label: 'Last Name',
                                    prefixIcon: Icons.person_outline,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Last name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                CustomTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'First name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _middleNameController,
                                  label: 'Middle Name',
                                  prefixIcon: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  prefixIcon: Icons.person_outline,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Last name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Identity & Contact
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _identityNumberController,
                                    label: 'Identity Number',
                                    prefixIcon: Icons.badge,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Identity number is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _emailController,
                                    label: 'Email',
                                    prefixIcon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Email is required';
                                      }
                                      if (!value!.contains('@')) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _phoneController,
                                    label: 'Phone Number',
                                    prefixIcon: Icons.phone,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Phone number is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                CustomTextField(
                                  controller: _identityNumberController,
                                  label: 'Identity Number',
                                  prefixIcon: Icons.badge,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Identity number is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  prefixIcon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Email is required';
                                    }
                                    if (!value!.contains('@')) {
                                      return 'Invalid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  prefixIcon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Phone number is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Birthday & Gender & Social Status
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectBirthday,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Birthday',
                                        prefixIcon: Icon(Icons.calendar_today),
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        _birthday == null
                                            ? 'Select birthday'
                                            : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedGender,
                                    decoration: const InputDecoration(
                                      labelText: 'Gender',
                                      prefixIcon: Icon(Icons.wc),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: ['Male', 'Female', 'Other'].map((
                                      gender,
                                    ) {
                                      return DropdownMenuItem(
                                        value: gender,
                                        child: Text(gender),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedGender = value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedSocialStatus,
                                    decoration: const InputDecoration(
                                      labelText: 'Social Status',
                                      prefixIcon: Icon(Icons.family_restroom),
                                      border: OutlineInputBorder(),
                                    ),
                                    items:
                                        [
                                          'Single',
                                          'Married',
                                          'Divorced',
                                          'Widowed',
                                        ].map((status) {
                                          return DropdownMenuItem(
                                            value: status,
                                            child: Text(status),
                                          );
                                        }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                          () => _selectedSocialStatus = value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                InkWell(
                                  onTap: _selectBirthday,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Birthday',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      _birthday == null
                                          ? 'Select birthday'
                                          : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    prefixIcon: Icon(Icons.wc),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ['Male', 'Female', 'Other'].map((
                                    gender,
                                  ) {
                                    return DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedGender = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSocialStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Social Status',
                                    prefixIcon: Icon(Icons.family_restroom),
                                    border: OutlineInputBorder(),
                                  ),
                                  items:
                                      [
                                        'Single',
                                        'Married',
                                        'Divorced',
                                        'Widowed',
                                      ].map((status) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _selectedSocialStatus = value,
                                      );
                                    }
                                  },
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Address Fields
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _streetController,
                                    label: 'Street Address',
                                    prefixIcon: Icons.location_on,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _cityController,
                                    label: 'City',
                                    prefixIcon: Icons.location_city,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                CustomTextField(
                                  controller: _streetController,
                                  label: 'Street Address',
                                  prefixIcon: Icons.location_on,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _cityController,
                                  label: 'City',
                                  prefixIcon: Icons.location_city,
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Insurance Information
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _insuranceProviderController,
                                    label: 'Insurance Provider',
                                    prefixIcon: Icons.health_and_safety,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _insuranceNumberController,
                                    label: 'Insurance Number',
                                    prefixIcon: Icons.confirmation_number,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                CustomTextField(
                                  controller: _insuranceProviderController,
                                  label: 'Insurance Provider',
                                  prefixIcon: Icons.health_and_safety,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  controller: _insuranceNumberController,
                                  label: 'Insurance Number',
                                  prefixIcon: Icons.confirmation_number,
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  CustomTextField(
                    controller: _notesController,
                    label: 'Notes',
                    prefixIcon: Icons.note,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Doctor Selection
                  _isLoadingDoctors
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          constraints: const BoxConstraints(
                            minWidth: double.infinity,
                          ),
                          child: DropdownButtonFormField<Map<String, dynamic>>(
                            isExpanded: true,
                            initialValue: _selectedDoctor,
                            decoration: const InputDecoration(
                              labelText: 'Referring Doctor (Optional)',
                              prefixIcon: Icon(Icons.medical_services),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No referring doctor'),
                              ),
                              ..._availableDoctors.map((doctor) {
                                return DropdownMenuItem(
                                  value: doctor,
                                  child: Text(
                                    '${doctor['name']} ${doctor['specialty'] != null ? '(${doctor['specialty']})' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedDoctor = value);
                            },
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Test Selection Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.science, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Text(
                        'Select Tests',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedTests.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Total: \$${_getTotalCost().toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TestSearchWidget(
                    allTests: _availableTests,
                    onFiltered: (filtered) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _filteredTests = filtered);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingTests)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_availableTests.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tests available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _filteredTests.map((test) {
                        final isSelected = _isTestSelected(test);
                        final testName = test['test_name'] ?? 'Unknown Test';
                        final testCode = test['test_code'] ?? '';
                        final price = test['price'] ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      AppTheme.primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      AppTheme.secondaryTeal.withValues(
                                        alpha: 0.05,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleTestSelection(test),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryBlue
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),

                                    // Test Icon
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryBlue.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.biotech,
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.grey.shade600,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Test Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            testName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isSelected
                                                  ? AppTheme.primaryBlue
                                                  : Colors.black87,
                                            ),
                                          ),
                                          if (testCode.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Code: $testCode',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Price Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '\$${price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Order',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
