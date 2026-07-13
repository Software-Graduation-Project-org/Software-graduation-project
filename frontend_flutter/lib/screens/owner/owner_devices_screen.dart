import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
// import '../../widgets/animations.dart';
import '../../widgets/confirmation_dialog.dart';
// import '../../widgets/loading_dialog.dart';
import 'owner_sidebar.dart';

class OwnerDevicesScreen extends StatefulWidget {
  const OwnerDevicesScreen({super.key});

  @override
  State<OwnerDevicesScreen> createState() => _OwnerDevicesScreenState();
}

class _OwnerDevicesScreenState extends State<OwnerDevicesScreen> {
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _deviceSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadStaff();
  }

  @override
  void dispose() {
    _deviceSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    try {
      final response = await OwnerApiService.getDevices();
      setState(() {
        _devices = List<Map<String, dynamic>>.from(response['devices'] ?? []);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load devices: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStaff() async {
    try {
      final response = await OwnerApiService.getStaff();
      setState(() {
        _staff = List<Map<String, dynamic>>.from(response['staff'] ?? []);
      });
    } catch (e) {
      // Staff loading failure doesn't block the UI
    }
  }

  Future<void> _showDeviceDialog([Map<String, dynamic>? device]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DeviceDialog(device: device, staff: _staff),
    );

    if (result != null) {
      await _loadDevices();
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Device',
      message:
          'Are you sure you want to delete this device? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      try {
        await OwnerApiService.deleteDevice(deviceId);
        await _loadDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete device: $e')),
          );
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
          title: const Text('Devices Management'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showDeviceDialog(),
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
    return Column(
      children: [
        ...(isMobile
            ? []
            : [
                Container(
                  width: double.infinity,
                  color: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Devices Management',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Manage your laboratory equipment and devices',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ]),
        Expanded(
          child: Container(
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
                          controller: _deviceSearchController,
                          decoration: InputDecoration(
                            hintText:
                                'Search by device name, model, or serial number...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _deviceSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _deviceSearchController.clear();
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
                        onPressed: () => _showDeviceDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(isMobile ? 'Add' : 'Add Device'),
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

                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: $_error',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDevices,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildDevicesList(isMobile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesList(bool isMobile) {
    // Filter devices based on search query
    final filteredDevices = _devices.where((device) {
      if (_deviceSearchController.text.isEmpty) return true;
      final searchLower = _deviceSearchController.text.toLowerCase();
      final name = (device['name'] ?? '').toString().toLowerCase();
      final serialNumber = (device['serial_number'] ?? '')
          .toString()
          .toLowerCase();
      final model = (device['model'] ?? '').toString().toLowerCase();
      final manufacturer = (device['manufacturer'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(searchLower) ||
          serialNumber.contains(searchLower) ||
          model.contains(searchLower) ||
          manufacturer.contains(searchLower);
    }).toList();

    if (filteredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showDeviceDialog(),
              child: const Text('Add First Device'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredDevices.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DeviceCardExpanded(
            device: filteredDevices[index],
            onEdit: () => _showDeviceDialog(filteredDevices[index]),
            onDelete: () => _deleteDevice(filteredDevices[index]['_id']),
          ),
        );
      },
    );
  }
}

class _DeviceCardExpanded extends StatefulWidget {
  final Map<String, dynamic> device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCardExpanded({
    required this.device,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DeviceCardExpanded> createState() => _DeviceCardExpandedState();
}

class _DeviceCardExpandedState extends State<_DeviceCardExpanded> {
  bool isExpanded = false;

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceName = device['name'] ?? 'Unknown Device';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.deepOrange.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.orange,
                  child: const Icon(
                    Icons.devices,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            device['status'],
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (device['status'] ?? 'UNKNOWN')
                              .toString()
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(device['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isExpanded = !isExpanded);
                  },
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isExpanded ? 'Hide' : 'See Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Device Information', [
                    _buildDetailRow(
                      Icons.confirmation_number,
                      'Serial Number',
                      device['serial_number'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.category,
                      'Model',
                      device['model'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.business,
                      'Manufacturer',
                      device['manufacturer'] ?? 'N/A',
                    ),
                    if (device['purchase_date'] != null)
                      _buildDetailRow(
                        Icons.shopping_cart,
                        'Purchase Date',
                        _formatDate(device['purchase_date']),
                      ),
                    if (device['warranty_expiry'] != null)
                      _buildDetailRow(
                        Icons.shield,
                        'Warranty Expiry',
                        _formatDate(device['warranty_expiry']),
                      ),
                    if (device['last_maintenance'] != null)
                      _buildDetailRow(
                        Icons.build,
                        'Last Maintenance',
                        _formatDate(device['last_maintenance']),
                      ),
                    if (device['next_maintenance'] != null)
                      _buildDetailRow(
                        Icons.event,
                        'Next Maintenance',
                        _formatDate(device['next_maintenance']),
                      ),
                  ]),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'operational':
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'faulty':
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _DeviceDialog extends StatefulWidget {
  final Map<String, dynamic>? device;
  final List<Map<String, dynamic>> staff;

  const _DeviceDialog({this.device, required this.staff});

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  String? _selectedStaff;
  String _status = 'active';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      final device = widget.device!;
      _nameController.text = device['name'] ?? '';
      _modelController.text = device['model'] ?? '';
      _serialController.text = device['serial_number'] ?? '';
      _selectedStaff = device['staff_id'];
      _status = device['status'] ?? 'active';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'model': _modelController.text.trim(),
        'serial_number': _serialController.text.trim(),
        'staff_id': _selectedStaff,
        'status': _status,
      };

      if (widget.device != null) {
        await OwnerApiService.updateDevice(widget.device!['_id'], data);
      } else {
        await OwnerApiService.createDevice(data);
      }

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.device != null
                  ? 'Device updated successfully'
                  : 'Device added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save device: $e')));
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
      title: Text(widget.device != null ? 'Edit Device' : 'Add Device'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name *',
                  hintText: 'Enter device name',
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Device name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Enter device model',
                  prefixIcon: Icon(Icons.device_hub),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  hintText: 'Enter serial number',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStaff,
                decoration: const InputDecoration(
                  labelText: 'Assigned Staff (Optional)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...widget.staff.map(
                    (s) => DropdownMenuItem<String>(
                      value: s['_id'],
                      child: Text(
                        '${s['full_name']?['first']} ${s['full_name']?['last']}'
                            .trim(),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedStaff = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
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
              : Text(widget.device != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
