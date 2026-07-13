import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/confirmation_dialog.dart';
import 'owner_sidebar.dart';

class OwnerStaffScreen extends StatefulWidget {
  const OwnerStaffScreen({super.key});

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _staffSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _staffSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);

    try {
      final response = await OwnerApiService.getStaff();
      setState(() {
        _staff = List<Map<String, dynamic>>.from(response['staff'] ?? []);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load staff: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showStaffDialog([Map<String, dynamic>? staff]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StaffDialog(staff: staff),
    );

    if (result != null) {
      await _loadStaff();
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Staff Member',
      message:
          'Are you sure you want to delete this staff member? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      try {
        await OwnerApiService.deleteStaff(staffId);
        await _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete staff: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Staff Management'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showStaffDialog(),
            ),
          ],
        ),
        drawer: const Drawer(child: OwnerSidebar()),
        body: _buildContent(context, isMobile),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const OwnerSidebar(),
          Expanded(child: _buildContent(context, isMobile)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    return Container(
      color: Colors.grey[50],
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          children: [
            // Search and Add Button Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _staffSearchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, employee number, role, or email...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _staffSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _staffSearchController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showStaffDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(isMobile ? 'Add' : 'Add Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(child: _buildStaffContent(isMobile)),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffContent(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadStaff, child: const Text('Retry')),
          ],
        ),
      );
    }

    return _buildStaffGrid(isMobile);
  }

  Widget _buildStaffGrid(bool isMobile) {
    // Filter staff based on search query
    final filteredStaff = _staff.where((staff) {
      if (_staffSearchController.text.isEmpty) return true;
      final searchLower = _staffSearchController.text.toLowerCase();
      final fullName =
          '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['last'] ?? ''}'
              .toLowerCase();
      final employeeNumber = (staff['employee_number'] ?? '')
          .toString()
          .toLowerCase();
      final role = (staff['role'] ?? '').toString().toLowerCase();
      final email = (staff['email'] ?? '').toString().toLowerCase();

      return fullName.contains(searchLower) ||
          employeeNumber.contains(searchLower) ||
          role.contains(searchLower) ||
          email.contains(searchLower);
    }).toList();

    if (filteredStaff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No staff members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showStaffDialog(),
              child: const Text('Add First Staff Member'),
            ),
          ],
        ),
      );
    }

    int columns = isMobile ? 1 : 2;
    return ListView.builder(
      itemCount: (filteredStaff.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        int startIndex = rowIndex * columns;
        List<Widget> rowItems = [];
        for (int i = 0; i < columns; i++) {
          int itemIndex = startIndex + i;
          if (itemIndex < filteredStaff.length) {
            rowItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildStaffCard(filteredStaff[itemIndex], isMobile),
                ),
              ),
            );
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems,
        );
      },
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff, bool isMobile) {
    final fullName =
        '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['last'] ?? ''}'
            .trim();
    final employeeNumber = staff['employee_number'] ?? 'N/A';
    final role = staff['role'] ?? 'Staff';
    final email = staff['email'] ?? 'N/A';
    final isActive = staff['is_active'] ?? true;

    return AnimatedCard(
      onTap: () => _showStaffDialog(staff),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.3),
            width: isActive ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'Unknown Staff',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Employee #: $employeeNumber',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showStaffDialog(staff);
                        break;
                      case 'delete':
                        _deleteStaff(staff['_id']);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text('Edit', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          const Text(
                            'Delete',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role: $role',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffDialog extends StatefulWidget {
  final Map<String, dynamic>? staff;

  const _StaffDialog({this.staff});

  @override
  State<_StaffDialog> createState() => _StaffDialogState();
}

class _StaffDialogState extends State<_StaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _employeeNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Staff';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      final staff = widget.staff!;
      _firstNameController.text = staff['full_name']?['first'] ?? '';
      _lastNameController.text = staff['full_name']?['last'] ?? '';
      _emailController.text = staff['email'] ?? '';
      _employeeNumberController.text = staff['employee_number'] ?? '';
      _selectedRole = staff['role'] ?? 'Staff';
      _isActive = staff['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _employeeNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'full_name': {
          'first': _firstNameController.text.trim(),
          'last': _lastNameController.text.trim(),
        },
        'email': _emailController.text.trim(),
        'employee_number': _employeeNumberController.text.trim(),
        'role': _selectedRole,
        'is_active': _isActive,
        if (_passwordController.text.isNotEmpty)
          'password': _passwordController.text,
      };

      if (widget.staff != null) {
        await OwnerApiService.updateStaff(widget.staff!['_id'], data);
      } else {
        await OwnerApiService.createStaff(data);
      }

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.staff != null
                  ? 'Staff member updated successfully'
                  : 'Staff member added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save staff: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.staff != null ? 'Edit Staff Member' : 'Add Staff Member',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  hintText: 'Enter first name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'First name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  hintText: 'Enter last name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Last name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'Enter email address',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value!)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employeeNumberController,
                decoration: const InputDecoration(
                  labelText: 'Employee Number *',
                  hintText: 'Enter employee number',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Employee number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: ['Staff', 'Supervisor', 'Manager']
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedRole = value!);
                },
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Role is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (widget.staff != null) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password (optional)',
                    hintText: 'Leave empty to keep current password',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.staff != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
