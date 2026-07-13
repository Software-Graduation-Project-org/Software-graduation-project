import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/data_table_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loading_dialog.dart';
import '../../widgets/feedback_form.dart';

class TestManagementScreen extends StatefulWidget {
  const TestManagementScreen({super.key});

  @override
  State<TestManagementScreen> createState() => _TestManagementScreenState();
}

class _TestManagementScreenState extends State<TestManagementScreen> {
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final testResponse = await OwnerApiService.getTests();
      final deviceResponse = await OwnerApiService.getDevices();

      if (testResponse['tests'] != null && deviceResponse['devices'] != null) {
        setState(() {
          _tests = List<Map<String, dynamic>>.from(testResponse['tests']);
          _devices = List<Map<String, dynamic>>.from(deviceResponse['devices']);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load tests or devices. Please check your connection or login status.',
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

  void _showOwnerFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'owner',
        targetType: 'system',
        targetName: 'Medical Lab System',
        onSubmit: (feedbackData) async {
          // Submit feedback to API
          // await OwnerApiService.submitFeedback(feedbackData);
          // Close the dialog after successful submission
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showTestDialog([Map<String, dynamic>? test]) async {
    final nameController = TextEditingController(text: test?['test_name']);
    final testCodeController = TextEditingController(text: test?['test_code']);
    final priceController = TextEditingController(
      text: test?['price']?.toString(),
    );
    final turnaroundController = TextEditingController(
      text: test?['turnaround_time']?.toString(),
    );
    String selectedTimeUnit = 'hours'; // Default unit
    final unitController = TextEditingController(text: test?['units']);
    final methodController = TextEditingController(text: test?['method']);
    final referenceRangeController = TextEditingController(
      text: test?['reference_range'],
    );
    final tubeTypeController = TextEditingController(text: test?['tube_type']);
    final reagentController = TextEditingController(text: test?['reagent']);
    final sampleTypeController = TextEditingController(
      text: test?['sample_type'],
    );
    String? selectedDevice = test?['device_id'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(test == null ? 'Add Test' : 'Edit Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Test Name',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                if (test == null) ...[
                  CustomTextField(
                    controller: testCodeController,
                    label: 'Test Code',
                    prefixIcon: Icons.code,
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: priceController,
                  label: 'Price',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: turnaroundController,
                        label: 'Turnaround Time',
                        prefixIcon: Icons.access_time,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedTimeUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'minutes',
                            child: Text('Minutes'),
                          ),
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text('Hours'),
                          ),
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => selectedTimeUnit = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: unitController,
                  label: 'Units',
                  prefixIcon: Icons.straighten,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: methodController,
                  label: 'Method',
                  prefixIcon: Icons.biotech,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: referenceRangeController,
                  label: 'Reference Range',
                  prefixIcon: Icons.assessment,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: tubeTypeController,
                  label: 'Tube Type',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: reagentController,
                  label: 'Reagent',
                  prefixIcon: Icons.liquor,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: sampleTypeController,
                  label: 'Sample Type (e.g., Blood, Urine)',
                  prefixIcon: Icons.bloodtype,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDevice,
                  decoration: InputDecoration(
                    labelText: 'Device (Optional)',
                    prefixIcon: const Icon(Icons.devices),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Device'),
                    ),
                    ..._devices.map(
                      (device) => DropdownMenuItem<String>(
                        value: device['_id'] as String,
                        child: Text(
                          device['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedDevice = value),
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
                if (nameController.text.isEmpty ||
                    (test == null && testCodeController.text.isEmpty) ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Test name, test code (for new tests), and price are required',
                      ),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'test_name': nameController.text,
                    if (test == null) 'test_code': testCodeController.text,
                    'price': double.tryParse(priceController.text) ?? 0,
                    'turnaround_time': _convertToHours(
                      double.tryParse(turnaroundController.text) ?? 24,
                      selectedTimeUnit,
                    ),
                    'units': unitController.text,
                    'method': methodController.text,
                    'reference_range': referenceRangeController.text,
                    'tube_type': tubeTypeController.text,
                    'reagent': reagentController.text,
                    'sample_type': sampleTypeController.text.isNotEmpty
                        ? sampleTypeController.text
                        : 'Blood',
                    if (selectedDevice != null) 'device_id': selectedDevice,
                  };

                  final response = test == null
                      ? await OwnerApiService.createTest(data)
                      : await OwnerApiService.updateTest(test['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);

                  if (response['message'] != null) {
                    Navigator.pop(context);
                    _loadData();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          test == null
                              ? 'Test created successfully'
                              : 'Test updated successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(test == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTest(String testId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Test',
      message: 'Are you sure you want to delete this test?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    if (!context.mounted) return;
    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTest(testId);

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test deleted successfully')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showComponentsDialog(Map<String, dynamic> test) async {
    // Load components for this test
    List<Map<String, dynamic>> components = [];
    bool isLoading = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            OwnerApiService.getTestComponents(test['_id'])
                .then((response) {
                  if (response['components'] != null) {
                    setDialogState(() {
                      components = List<Map<String, dynamic>>.from(
                        response['components'],
                      );
                      isLoading = false;
                    });
                  }
                })
                .catchError((e) {
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error loading components: $e')),
                    );
                  }
                });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.view_list, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Components',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Text(
                        test['test_name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : components.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No components yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add components for multi-parameter tests',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: components.length,
                      itemBuilder: (context, index) {
                        final component = components[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              component['component_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code: ${component['component_code'] ?? 'N/A'}',
                                ),
                                Text('Units: ${component['units'] ?? 'N/A'}'),
                                Text(
                                  'Range: ${component['reference_range'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _showComponentFormDialog(
                                      test,
                                      component,
                                    ).then((_) => _showComponentsDialog(test));
                                  },
                                  tooltip: 'Edit Component',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _deleteComponent(
                                        test['_id'],
                                        component['_id'],
                                      ).then((_) {
                                        setDialogState(() {
                                          components.removeAt(index);
                                        });
                                      }),
                                  tooltip: 'Delete Component',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showComponentFormDialog(
                    test,
                  ).then((_) => _showComponentsDialog(test));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Component'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showComponentFormDialog(
    Map<String, dynamic> test, [
    Map<String, dynamic>? component,
  ]) async {
    final nameController = TextEditingController(
      text: component?['component_name'],
    );
    final codeController = TextEditingController(
      text: component?['component_code'],
    );
    final unitsController = TextEditingController(text: component?['units']);
    final rangeController = TextEditingController(
      text: component?['reference_range'],
    );
    final minController = TextEditingController(
      text: component?['min_value']?.toString(),
    );
    final maxController = TextEditingController(
      text: component?['max_value']?.toString(),
    );
    final orderController = TextEditingController(
      text: component?['display_order']?.toString(),
    );
    final descController = TextEditingController(
      text: component?['description'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(component == null ? 'Add Component' : 'Edit Component'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Component Name *',
                prefixIcon: Icons.science,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: codeController,
                label: 'Component Code *',
                prefixIcon: Icons.code,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: unitsController,
                label: 'Units (e.g., mg/dL, 10^3/μL)',
                prefixIcon: Icons.straighten,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: rangeController,
                label: 'Reference Range (e.g., 4.5-11.0)',
                prefixIcon: Icons.assessment,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: minController,
                      label: 'Min Value',
                      prefixIcon: Icons.arrow_downward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: maxController,
                      label: 'Max Value',
                      prefixIcon: Icons.arrow_upward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: orderController,
                label: 'Display Order',
                prefixIcon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: descController,
                label: 'Description (Optional)',
                prefixIcon: Icons.description,
                maxLines: 2,
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
              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Component name and code are required'),
                  ),
                );
                return;
              }

              LoadingDialog.show(context);
              try {
                final data = {
                  'component_name': nameController.text,
                  'component_code': codeController.text,
                  if (unitsController.text.isNotEmpty)
                    'units': unitsController.text,
                  if (rangeController.text.isNotEmpty)
                    'reference_range': rangeController.text,
                  if (minController.text.isNotEmpty)
                    'min_value': double.tryParse(minController.text),
                  if (maxController.text.isNotEmpty)
                    'max_value': double.tryParse(maxController.text),
                  if (orderController.text.isNotEmpty)
                    'display_order': int.tryParse(orderController.text),
                  if (descController.text.isNotEmpty)
                    'description': descController.text,
                };

                final response = component == null
                    ? await OwnerApiService.addTestComponent(test['_id'], data)
                    : await OwnerApiService.updateTestComponent(
                        test['_id'],
                        component['_id'],
                        data,
                      );

                if (!context.mounted) return;
                LoadingDialog.hide(context);

                if (response['message'] != null ||
                    response['component'] != null) {
                  Navigator.pop(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        component == null
                            ? 'Component added successfully'
                            : 'Component updated successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                LoadingDialog.hide(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(component == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComponent(String testId, String componentId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Component',
      message: 'Are you sure you want to delete this component?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTestComponent(
        testId,
        componentId,
      );

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Component deleted successfully')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
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
        title: const Text('Test Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback),
            onPressed: _showOwnerFeedbackDialog,
            tooltip: 'Give Feedback',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Tests: ${_tests.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                CustomButton(
                  text: 'Add Test',
                  icon: Icons.add,
                  onPressed: () => _showTestDialog(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DataTableWidget(
                    columns: const [
                      'Test Name',
                      'Test Code',
                      'Price',
                      'Turnaround',
                      'Units',
                      'Method',
                    ],
                    rows: _tests
                        .map(
                          (t) => {
                            'test_name': t['test_name'],
                            'test_code': t['test_code'] ?? '-',
                            'price': '\$${t['price']}',
                            'turnaround': _formatTurnaroundTime(
                              t['turnaround_time'],
                            ),
                            'units': t['units'] ?? '-',
                            'method': t['method'] ?? '-',
                            '_id': t['_id'],
                            '_data': t,
                          },
                        )
                        .toList(),
                    actions: (row) => [
                      IconButton(
                        icon: const Icon(Icons.view_list, color: Colors.green),
                        onPressed: () => _showComponentsDialog(row['_data']),
                        tooltip: 'Manage Components',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showTestDialog(row['_data']),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTest(row['_id']),
                        tooltip: 'Delete',
                      ),
                    ],
                    emptyMessage: 'No tests found. Add your first test!',
                  ),
          ),
        ],
      ),
    );
  }

  double _convertToHours(double value, String unit) {
    switch (unit) {
      case 'minutes':
        return value / 60; // Convert minutes to hours
      case 'hours':
        return value; // Already in hours
      case 'days':
        return value * 24; // Convert days to hours
      default:
        return value; // Default to hours
    }
  }

  String _formatTurnaroundTime(dynamic turnaroundHours) {
    if (turnaroundHours == null) return '-';

    final hours = turnaroundHours.toDouble();

    if (hours < 1) {
      // Show in minutes if less than 1 hour
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else if (hours < 24) {
      // Show in hours if less than 24 hours
      return '${hours.round()}h';
    } else {
      // Show in days if 24 hours or more
      final days = (hours / 24).round();
      return '${days}d';
    }
  }
}
