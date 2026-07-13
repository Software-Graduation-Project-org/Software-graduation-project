import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/data_table_widget.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loading_dialog.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  int get totalStaff => _staff.length;
  String _searchQuery = '';
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final staffResponse = await OwnerApiService.getStaff();
      debugPrint('Staff response: $staffResponse');

      if (staffResponse['staff'] != null) {
        setState(() {
          _staff = List<Map<String, dynamic>>.from(staffResponse['staff']);
        });
      } else {
        if (mounted) {
          debugPrint('Staff data is null');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to load staff data. Please check your connection.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading staff: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showStaffDialog([Map<String, dynamic>? staff]) async {
    final firstNameController = TextEditingController(
      text: staff?['full_name']?['first'],
    );
    final middleNameController = TextEditingController(
      text: staff?['full_name']?['middle'],
    );
    final lastNameController = TextEditingController(
      text: staff?['full_name']?['last'],
    );
    final emailController = TextEditingController(text: staff?['email']);
    final phoneController = TextEditingController(
      text: staff?['phone_number'] ?? staff?['phone'],
    );
    final usernameController = TextEditingController(text: staff?['username']);
    final identityController = TextEditingController(
      text: staff?['identity_number'],
    );
    final birthdayController = TextEditingController(text: staff?['birthday']);
    final genderController = TextEditingController(text: staff?['gender']);
    final addressController = TextEditingController(
      text: staff?['address'] ?? '',
    );
    String role = staff?['role'] ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomTextField(
                    controller: firstNameController,
                    label: 'First Name',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: middleNameController,
                    label: 'Middle Name',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: lastNameController,
                    label: 'Last Name',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: emailController,
                    label: 'Email',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: identityController,
                    label: 'Identity Number',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: birthdayController,
                    label: 'Birthday (YYYY-MM-DD)',
                    prefixIcon: Icons.cake,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: genderController,
                    label: 'Gender',
                    prefixIcon: Icons.wc,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: addressController,
                    label: 'Address',
                    prefixIcon: Icons.home,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: usernameController,
                    label: 'Username',
                    prefixIcon: Icons.account_circle,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      prefixIcon: const Icon(Icons.work),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                      DropdownMenuItem(
                        value: 'receptionist',
                        child: Text('Receptionist'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => role = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (firstNameController.text.isEmpty ||
                    emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('First name and email are required'),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);

                try {
                  final data = {
                    'full_name': {
                      'first': firstNameController.text,
                      'middle': middleNameController.text,
                      'last': lastNameController.text,
                    },
                    'email': emailController.text,
                    'phone_number': phoneController.text,
                    'identity_number': identityController.text,
                    'birthday': birthdayController.text,
                    'gender': genderController.text,
                    'address': addressController.text,
                    'username': usernameController.text,
                    'role': role,
                  };

                  final response = staff == null
                      ? await OwnerApiService.createStaff(data)
                      : await OwnerApiService.updateStaff(staff['_id'], data);

                  LoadingDialog.hide(context);

                  if (response['success']) {
                    Navigator.pop(context, true);
                  }
                } catch (e) {
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(staff == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _loadData();
  }

  Future<void> _deleteStaff(String staffId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Staff',
      message: 'Are you sure you want to delete this staff member?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteStaff(staffId);
      LoadingDialog.hide(context);

      if (response['success']) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff deleted successfully')),
        );
      }
    } catch (e) {
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/owner/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    debugPrint('Building StaffManagementScreen, _staff: \n$_staff');
    final filteredStaff = _staff.where((s) {
      final fullName = s['full_name'] ?? {};
      final name = [
        fullName['first'] ?? '',
        fullName['middle'] ?? '',
        fullName['last'] ?? '',
      ].where((part) => part.isNotEmpty).join(' ');
      final email = s['email'] ?? '';
      return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.dashboard),
          onPressed: () => context.go('/owner/dashboard'),
          tooltip: 'Dashboard',
        ),
        title: const Text('Staff Management'),
      ),
      drawer: MediaQuery.of(context).size.width < 600
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                    ),
                    child: const Text(
                      'Menu',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Staff Management'),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Staff'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tableHeight = constraints.maxHeight * 0.75;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Staff: ${_staff.length}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search staff by name or email...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            'Found: ${filteredStaff.length}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: tableHeight,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : filteredStaff.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No staff found. Add your first staff member!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : DataTableWidget(
                                columns: const [
                                  'Avatar',
                                  'Name',
                                  'Email',
                                  'Role',
                                  'Status',
                                ],
                                rows: filteredStaff.map((s) {
                                  final fullName = s['full_name'] ?? {};
                                  final name = [
                                    fullName['first'] ?? '',
                                    fullName['middle'] ?? '',
                                    fullName['last'] ?? '',
                                  ].where((part) => part.isNotEmpty).join(' ');
                                  final initials =
                                      (fullName['first'] ?? '')
                                          .toString()
                                          .isNotEmpty
                                      ? (fullName['first'][0] ?? '') +
                                            (fullName['last']?[0] ?? '')
                                      : '';
                                  return {
                                    'avatar': CircleAvatar(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    'name': name,
                                    'email': s['email'] ?? '',
                                    'role': s['role'] ?? '-',
                                    'status': StatusBadge(
                                      status: s['status'] ?? 'active',
                                      small: true,
                                    ),
                                    '_id': s['_id'],
                                    '_data': s,
                                  };
                                }).toList(),
                                actions: (row) => [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _showStaffDialog(row['_data']),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteStaff(row['_id']),
                                  ),
                                ],
                                emptyMessage: '',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
