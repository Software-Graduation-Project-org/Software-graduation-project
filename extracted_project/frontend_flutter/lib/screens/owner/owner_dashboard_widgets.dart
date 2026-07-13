import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../providers/owner_auth_provider.dart';

class InventoryManagementWidget extends StatefulWidget {
  const InventoryManagementWidget({super.key});

  @override
  State<InventoryManagementWidget> createState() =>
      InventoryManagementWidgetState();
}

class InventoryManagementWidgetState extends State<InventoryManagementWidget> {
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await ApiService.get(ApiConfig.ownerInventory);

      setState(() {
        _inventoryItems = List<Map<String, dynamic>>.from(
          response['items'] ?? [],
        );
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load inventory: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addInventoryItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddInventoryDialog(),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  Future<void> _editInventoryItem(Map<String, dynamic> item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditInventoryDialog(item: item),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  Future<void> _deleteInventoryItem(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text(
          'Are you sure you want to delete this inventory item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<OwnerAuthProvider>(
          context,
          listen: false,
        );
        ApiService.setAuthToken(authProvider.token);

        await ApiService.delete('${ApiConfig.ownerInventory}/$itemId');

        await _loadInventory();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
      }
    }
  }

  Future<void> _addStockInput(String itemId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StockInputDialog(itemId: itemId),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchController.text.isEmpty) return _inventoryItems;

    final query = _searchController.text.toLowerCase();
    return _inventoryItems.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final itemCode = item['item_code']?.toString().toLowerCase() ?? '';
      return name.contains(query) || itemCode.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadInventory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and Add Button Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search inventory items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addInventoryItem,
                  icon: const Icon(Icons.add),
                  label: Text(isMobile ? 'Add' : 'Add Item'),
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
                            _error!,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInventory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No inventory items found'
                                : 'No items match your search',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addInventoryItem,
                            child: const Text('Add First Item'),
                          ),
                        ],
                      ),
                    )
                  : _buildInventoryGrid(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryGrid(bool isMobile) {
    int columns = isMobile ? 1 : 2;
    return ListView.builder(
      itemCount: (_filteredItems.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        int startIndex = rowIndex * columns;
        List<Widget> rowItems = [];
        for (int i = 0; i < columns; i++) {
          int itemIndex = startIndex + i;
          if (itemIndex < _filteredItems.length) {
            rowItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildInventoryCard(
                    _filteredItems[itemIndex],
                    isMobile,
                  ),
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

  Widget _buildInventoryCard(Map<String, dynamic> item, bool isMobile) {
    final count = item['count'] ?? 0;
    final criticalLevel = item['critical_level'] ?? 0;
    final isLowStock = count <= criticalLevel;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editInventoryItem(item);
                        break;
                      case 'delete':
                        _deleteInventoryItem(item['_id']);
                        break;
                      case 'add_stock':
                        _addStockInput(item['_id']);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'add_stock',
                      child: Text('Add Stock'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Code: ${item['item_code'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isLowStock ? Icons.warning : Icons.inventory,
                  color: isLowStock ? Colors.red : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Stock: $count',
                  style: TextStyle(
                    color: isLowStock ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (criticalLevel > 0) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Critical: $criticalLevel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cost: \$${item['cost']?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (item['expiration_date'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Expires: ${_formatDate(item['expiration_date'])}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

class _AddInventoryDialog extends StatefulWidget {
  const _AddInventoryDialog();

  @override
  State<_AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<_AddInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _costController = TextEditingController();
  final _criticalLevelController = TextEditingController();
  final _countController = TextEditingController();
  DateTime? _expirationDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _costController.dispose();
    _criticalLevelController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final itemData = {
        'name': _nameController.text.trim(),
        'item_code': _itemCodeController.text.trim(),
        'cost': double.tryParse(_costController.text) ?? 0,
        'critical_level': int.tryParse(_criticalLevelController.text) ?? 0,
        'count': int.tryParse(_countController.text) ?? 0,
        if (_expirationDate != null)
          'expiration_date': _expirationDate!.toIso8601String(),
      };

      await ApiService.post(ApiConfig.ownerInventory, itemData);

      if (!context.mounted) return;
      Navigator.of(context).pop(itemData);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Inventory Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter item name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemCodeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter item code' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost per Unit',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter cost';
                  final cost = double.tryParse(value!);
                  if (cost == null || cost < 0)
                    return 'Please enter valid cost';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _criticalLevelController,
                decoration: const InputDecoration(
                  labelText: 'Critical Level',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter critical level';
                  final level = int.tryParse(value!);
                  if (level == null || level < 0)
                    return 'Please enter valid level';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: 'Initial Count',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter count';
                  final count = int.tryParse(value!);
                  if (count == null || count < 0)
                    return 'Please enter valid count';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectExpirationDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date (Optional)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _expirationDate != null
                        ? '${_expirationDate!.day}/${_expirationDate!.month}/${_expirationDate!.year}'
                        : 'Select date',
                  ),
                ),
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
              : const Text('Add Item'),
        ),
      ],
    );
  }
}

class _EditInventoryDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const _EditInventoryDialog({required this.item});

  @override
  State<_EditInventoryDialog> createState() => _EditInventoryDialogState();
}

class _EditInventoryDialogState extends State<_EditInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _itemCodeController;
  late final TextEditingController _costController;
  late final TextEditingController _criticalLevelController;
  late final TextEditingController _countController;
  DateTime? _expirationDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name']);
    _itemCodeController = TextEditingController(text: widget.item['item_code']);
    _costController = TextEditingController(
      text: widget.item['cost']?.toString(),
    );
    _criticalLevelController = TextEditingController(
      text: widget.item['critical_level']?.toString(),
    );
    _countController = TextEditingController(
      text: widget.item['count']?.toString(),
    );
    if (widget.item['expiration_date'] != null) {
      _expirationDate = DateTime.parse(widget.item['expiration_date']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _costController.dispose();
    _criticalLevelController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final itemData = {
        'name': _nameController.text.trim(),
        'item_code': _itemCodeController.text.trim(),
        'cost': double.tryParse(_costController.text) ?? 0,
        'critical_level': int.tryParse(_criticalLevelController.text) ?? 0,
        'count': int.tryParse(_countController.text) ?? 0,
        if (_expirationDate != null)
          'expiration_date': _expirationDate!.toIso8601String(),
      };

      await ApiService.put(
        '${ApiConfig.ownerInventory}/${widget.item['_id']}',
        itemData,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(itemData);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Inventory Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter item name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemCodeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter item code' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost per Unit',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter cost';
                  final cost = double.tryParse(value!);
                  if (cost == null || cost < 0)
                    return 'Please enter valid cost';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _criticalLevelController,
                decoration: const InputDecoration(
                  labelText: 'Critical Level',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter critical level';
                  final level = int.tryParse(value!);
                  if (level == null || level < 0)
                    return 'Please enter valid level';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: 'Count',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter count';
                  final count = int.tryParse(value!);
                  if (count == null || count < 0)
                    return 'Please enter valid count';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectExpirationDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date (Optional)',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _expirationDate != null
                        ? '${_expirationDate!.day}/${_expirationDate!.month}/${_expirationDate!.year}'
                        : 'Select date',
                  ),
                ),
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
              : const Text('Update Item'),
        ),
      ],
    );
  }
}

class _StockInputDialog extends StatefulWidget {
  final String itemId;

  const _StockInputDialog({required this.itemId});

  @override
  State<_StockInputDialog> createState() => _StockInputDialogState();
}

class _StockInputDialogState extends State<_StockInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inputValueController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _inputValueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final inputData = {
        'item_id': widget.itemId,
        'input_value': int.tryParse(_inputValueController.text) ?? 0,
        'input_date': DateTime.now().toIso8601String(),
      };

      await ApiService.post('${ApiConfig.ownerInventory}/input', inputData);

      if (!context.mounted) return;
      Navigator.of(context).pop(inputData);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add stock: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Stock Input'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _inputValueController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter quantity';
                final quantity = int.tryParse(value!);
                if (quantity == null || quantity <= 0)
                  return 'Please enter valid quantity';
                return null;
              },
            ),
          ],
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
              : const Text('Add Stock'),
        ),
      ],
    );
  }
}

class StaffCardExpanded extends StatefulWidget {
  final Map<String, dynamic> staff;
  final String fullName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StaffCardExpanded({
    super.key,
    required this.staff,
    required this.fullName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<StaffCardExpanded> createState() => StaffCardExpandedState();
}

class StaffCardExpandedState extends State<StaffCardExpanded> {
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStaffDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildStaffDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.staff['email'] ?? 'No email',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStaffDetailSection('Personal Information', [
                      _buildStaffDetailRow('Full Name', widget.fullName),
                      _buildStaffDetailRow(
                        'Email',
                        widget.staff['email'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Phone',
                        widget.staff['phone'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Address',
                        widget.staff['address'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Date of Birth',
                        _formatDate(widget.staff['date_of_birth']),
                      ),
                      _buildStaffDetailRow(
                        'Gender',
                        widget.staff['gender'] ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildStaffDetailSection('Employment Information', [
                      _buildStaffDetailRow(
                        'Employee ID',
                        widget.staff['employee_id'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Department',
                        widget.staff['department'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Position',
                        widget.staff['position'] ?? 'N/A',
                      ),
                      _buildStaffDetailRow(
                        'Salary',
                        '\$${widget.staff['salary']?.toString() ?? 'N/A'}',
                      ),
                      _buildStaffDetailRow(
                        'Joining Date',
                        _formatDate(widget.staff['joining_date']),
                      ),
                      _buildStaffDetailRow(
                        'Status',
                        widget.staff['status'] ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildStaffDetailSection('System Information', [
                      _buildStaffDetailRow(
                        'Created At',
                        _formatDate(widget.staff['createdAt']),
                      ),
                      _buildStaffDetailRow(
                        'Last Updated',
                        _formatDate(widget.staff['updatedAt']),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoctorCardExpanded extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final String fullName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DoctorCardExpanded({
    super.key,
    required this.doctor,
    required this.fullName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<DoctorCardExpanded> createState() => DoctorCardExpandedState();
}

class DoctorCardExpandedState extends State<DoctorCardExpanded> {
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.local_hospital,
                      size: 30,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.doctor['email'] ?? 'No email',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Personal Information', [
                      _buildDetailRow('Full Name', widget.fullName),
                      _buildDetailRow(
                        'Email',
                        widget.doctor['email']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Phone',
                        widget.doctor['phone']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Address',
                        widget.doctor['address']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Date of Birth',
                        widget.doctor['date_of_birth']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Gender',
                        widget.doctor['gender']?.toString() ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('Professional Information', [
                      _buildDetailRow(
                        'Doctor ID',
                        widget.doctor['doctor_id']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Specialization',
                        widget.doctor['specialization']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'License Number',
                        widget.doctor['license_number']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Experience (Years)',
                        widget.doctor['experience_years']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Consultation Fee',
                        '\$${widget.doctor['consultation_fee']?.toString() ?? 'N/A'}',
                      ),
                      _buildDetailRow(
                        'Status',
                        widget.doctor['status']?.toString() ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('System Information', [
                      _buildDetailRow(
                        'Created At',
                        widget.doctor['createdAt']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Last Updated',
                        widget.doctor['updatedAt']?.toString() ?? 'N/A',
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TestCardExpanded extends StatefulWidget {
  final Map<String, dynamic> test;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onComponents;

  const TestCardExpanded({
    super.key,
    required this.test,
    required this.onEdit,
    required this.onDelete,
    required this.onComponents,
  });

  @override
  State<TestCardExpanded> createState() => TestCardExpandedState();
}

class TestCardExpandedState extends State<TestCardExpanded> {
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.science,
                      size: 30,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.test['name'] ?? 'Unknown Test',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Test ID: ${widget.test['test_id'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Test Information', [
                      _buildDetailRow(
                        'Test Name',
                        widget.test['name'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Test ID',
                        widget.test['test_id'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Category',
                        widget.test['category'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Description',
                        widget.test['description'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Price',
                        '\$${widget.test['price']?.toString() ?? 'N/A'}',
                      ),
                      _buildDetailRow(
                        'Turnaround Time',
                        '${widget.test['turnaround_time_hours']?.toString() ?? 'N/A'} hours',
                      ),
                      _buildDetailRow('Status', widget.test['status'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('Reference Values', [
                      _buildDetailRow(
                        'Normal Range',
                        widget.test['normal_range'] ?? 'N/A',
                      ),
                      _buildDetailRow('Unit', widget.test['unit'] ?? 'N/A'),
                      _buildDetailRow(
                        'Critical Low',
                        widget.test['critical_low']?.toString() ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Critical High',
                        widget.test['critical_high']?.toString() ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('System Information', [
                      _buildDetailRow(
                        'Created At',
                        widget.test['createdAt'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Last Updated',
                        widget.test['updatedAt'] ?? 'N/A',
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onComponents,
                    child: const Text('Components'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceCardExpanded extends StatefulWidget {
  final Map<String, dynamic> device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DeviceCardExpanded({
    super.key,
    required this.device,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<DeviceCardExpanded> createState() => DeviceCardExpandedState();
}

class DeviceCardExpandedState extends State<DeviceCardExpanded> {
  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'online':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'offline':
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.devices,
                      size: 30,
                      color: _getStatusColor(widget.device['status']),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.device['name'] ?? 'Unknown Device',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Device ID: ${widget.device['device_id'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Device Information', [
                      _buildDetailRow(
                        'Device Name',
                        widget.device['name'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Device ID',
                        widget.device['device_id'] ?? 'N/A',
                      ),
                      _buildDetailRow('Type', widget.device['type'] ?? 'N/A'),
                      _buildDetailRow('Model', widget.device['model'] ?? 'N/A'),
                      _buildDetailRow(
                        'Serial Number',
                        widget.device['serial_number'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Manufacturer',
                        widget.device['manufacturer'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Location',
                        widget.device['location'] ?? 'N/A',
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('Status & Maintenance', [
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Status')),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                widget.device['status'],
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(widget.device['status']),
                              ),
                            ),
                            child: Text(
                              widget.device['status'] ?? 'Unknown',
                              style: TextStyle(
                                color: _getStatusColor(widget.device['status']),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildDetailRow(
                        'Purchase Date',
                        _formatDate(widget.device['purchase_date']),
                      ),
                      _buildDetailRow(
                        'Warranty Until',
                        _formatDate(widget.device['warranty_until']),
                      ),
                      _buildDetailRow(
                        'Last Maintenance',
                        _formatDate(widget.device['last_maintenance']),
                      ),
                      _buildDetailRow(
                        'Next Maintenance',
                        _formatDate(widget.device['next_maintenance']),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildDetailSection('System Information', [
                      _buildDetailRow(
                        'Created At',
                        _formatDate(widget.device['createdAt']),
                      ),
                      _buildDetailRow(
                        'Last Updated',
                        _formatDate(widget.device['updatedAt']),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onEdit,
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
