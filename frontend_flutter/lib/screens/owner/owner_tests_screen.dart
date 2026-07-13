import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/confirmation_dialog.dart';
import 'owner_sidebar.dart';

class OwnerTestsScreen extends StatefulWidget {
  const OwnerTestsScreen({super.key});

  @override
  State<OwnerTestsScreen> createState() => _OwnerTestsScreenState();
}

class _OwnerTestsScreenState extends State<OwnerTestsScreen> {
  List<Map<String, dynamic>> _tests = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _testSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  @override
  void dispose() {
    _testSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);

    try {
      final response = await OwnerApiService.getTests();
      setState(() {
        _tests = List<Map<String, dynamic>>.from(response['tests'] ?? []);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showTestDialog([Map<String, dynamic>? test]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TestDialog(test: test),
    );

    if (result != null) {
      await _loadTests();
    }
  }

  Future<void> _deleteTest(String testId) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Test',
      message:
          'Are you sure you want to delete this test? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      try {
        await OwnerApiService.deleteTest(testId);
        await _loadTests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete test: $e')));
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
          title: const Text('Tests Management'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showTestDialog(),
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
                        'Tests Management',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Manage your laboratory tests and pricing',
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
                          controller: _testSearchController,
                          decoration: InputDecoration(
                            hintText:
                                'Search by test name, code, price, or category...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _testSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _testSearchController.clear();
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
                        onPressed: () => _showTestDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(isMobile ? 'Add' : 'Add Test'),
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
                                  onPressed: _loadTests,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildTestsGrid(isMobile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestsGrid(bool isMobile) {
    // Filter tests based on search query
    final filteredTests = _tests.where((test) {
      if (_testSearchController.text.isEmpty) return true;
      final searchLower = _testSearchController.text.toLowerCase();
      final testName = (test['test_name'] ?? '').toString().toLowerCase();
      final testCode = (test['test_code'] ?? '').toString().toLowerCase();
      final price = (test['price'] ?? '').toString().toLowerCase();
      final category = (test['category'] ?? '').toString().toLowerCase();

      return testName.contains(searchLower) ||
          testCode.contains(searchLower) ||
          price.contains(searchLower) ||
          category.contains(searchLower);
    }).toList();

    if (filteredTests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No tests found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showTestDialog(),
              child: const Text('Add First Test'),
            ),
          ],
        ),
      );
    }

    int columns = isMobile ? 1 : 2;
    return ListView.builder(
      itemCount: (filteredTests.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        int startIndex = rowIndex * columns;
        List<Widget> rowItems = [];
        for (int i = 0; i < columns; i++) {
          int itemIndex = startIndex + i;
          if (itemIndex < filteredTests.length) {
            rowItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildTestCard(filteredTests[itemIndex], isMobile),
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

  Widget _buildTestCard(Map<String, dynamic> test, bool isMobile) {
    final testName = test['test_name'] ?? 'Unknown Test';
    final testCode = test['test_code'] ?? 'N/A';
    final price = test['price'] ?? 0;
    final category = test['category'] ?? 'General';
    final description = test['description'] ?? '';
    final isActive = test['is_active'] ?? true;

    return AnimatedCard(
      onTap: () => _showTestDialog(test),
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
                  child: const Icon(
                    Icons.science,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Code: $testCode',
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
                        _showTestDialog(test);
                        break;
                      case 'delete':
                        _deleteTest(test['_id']);
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
                        '\$${price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: $category',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

class _TestDialog extends StatefulWidget {
  final Map<String, dynamic>? test;

  const _TestDialog({this.test});

  @override
  State<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<_TestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _testNameController = TextEditingController();
  final _testCodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.test != null) {
      final test = widget.test!;
      _testNameController.text = test['test_name'] ?? '';
      _testCodeController.text = test['test_code'] ?? '';
      _priceController.text = test['price']?.toString() ?? '';
      _categoryController.text = test['category'] ?? '';
      _descriptionController.text = test['description'] ?? '';
      _isActive = test['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _testNameController.dispose();
    _testCodeController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'test_name': _testNameController.text.trim(),
        'test_code': _testCodeController.text.trim(),
        'price': double.parse(_priceController.text),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'is_active': _isActive,
      };

      if (widget.test != null) {
        await OwnerApiService.updateTest(widget.test!['_id'], data);
      } else {
        await OwnerApiService.createTest(data);
      }

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.test != null
                  ? 'Test updated successfully'
                  : 'Test added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save test: $e')));
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
      title: Text(widget.test != null ? 'Edit Test' : 'Add Test'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _testNameController,
                decoration: const InputDecoration(
                  labelText: 'Test Name *',
                  hintText: 'Enter test name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Test name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _testCodeController,
                decoration: const InputDecoration(
                  labelText: 'Test Code *',
                  hintText: 'Enter test code',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Test code is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  hintText: 'Enter price',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Price is required';
                  final price = double.tryParse(value!);
                  if (price == null || price < 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Enter test category',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter test description',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (widget.test != null) ...[
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
              : Text(widget.test != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
