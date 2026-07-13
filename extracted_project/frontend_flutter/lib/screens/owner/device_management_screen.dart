import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/data_table_widget.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loading_dialog.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _devices = [];
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
      final deviceResponse = await OwnerApiService.getDevices();
      final staffResponse = await OwnerApiService.getStaff();

      bool deviceOk = deviceResponse['devices'] != null;
      bool staffOk = staffResponse['staff'] != null;

      if (deviceOk) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(deviceResponse['devices']);
          _staff = staffOk
              ? List<Map<String, dynamic>>.from(staffResponse['staff'])
              : [];
        });
        if (!staffOk && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Warning: Failed to load staff. Some features may be limited.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load devices. Please check your connection or login status.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeviceDialog([Map<String, dynamic>? device]) async {
    final nameController = TextEditingController(text: device?['name']);
    final modelController = TextEditingController(text: device?['model']);
    final serialController = TextEditingController(
      text: device?['serial_number'],
    );
    String? selectedStaff = device?['staff_id'];
    String status = device?['status'] ?? 'active';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(device == null ? 'Add Device' : 'Edit Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Device Name',
                  prefixIcon: Icons.devices,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: modelController,
                  label: 'Model',
                  prefixIcon: Icons.device_hub,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: serialController,
                  label: 'Serial Number',
                  prefixIcon: Icons.qr_code,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedStaff,
                  decoration: InputDecoration(
                    labelText: 'Assigned Staff (Optional)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._staff.map(
                      (s) => DropdownMenuItem<String>(
                        value: s['_id'] as String,
                        child: Text(
                          '${s['full_name']?['first']} ${s['full_name']?['last']}'
                              .trim(),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedStaff = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(Icons.info),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => status = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device name is required')),
                    );
                  }
                  return;
                }

                if (!context.mounted) return;
                LoadingDialog.show(context);
                try {
                  final data = {
                    'name': nameController.text,
                    'model': modelController.text,
                    'serial_number': serialController.text,
                    'staff_id': selectedStaff,
                    'status': status,
                  };

                  final response = device == null
                      ? await OwnerApiService.createDevice(data)
                      : await OwnerApiService.updateDevice(device['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);

                  if (response['message'] != null) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            device == null
                                ? 'Device created successfully'
                                : 'Device updated successfully',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(device == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Device',
      message: 'Are you sure you want to delete this device?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    if (!mounted) return;
    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDevice(deviceId);

      if (!mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.dashboard),
          onPressed: () => context.go('/owner/dashboard'),
          tooltip: 'Dashboard',
        ),
        title: const Text('Device Management'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Devices: ${_devices.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  CustomButton(
                    text: 'Add Device',
                    icon: Icons.add,
                    onPressed: () => _showDeviceDialog(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DataTableWidget(
                      columns: const ['Name', 'Model', 'Serial', 'Status'],
                      rows: _devices
                          .map(
                            (d) => {
                              'name': d['name'],
                              'model': d['model'] ?? '-',
                              'serial': d['serial_number'] ?? '-',
                              'status': StatusBadge(
                                status: d['status'] ?? 'active',
                                small: true,
                              ),
                              '_id': d['_id'],
                              '_data': d,
                            },
                          )
                          .toList(),
                      actions: (row) => [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showDeviceDialog(row['_data']),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteDevice(row['_id']),
                          tooltip: 'Delete',
                        ),
                      ],
                      emptyMessage: 'No devices found. Add your first device!',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
