import 'package:flutter/material.dart';

class TestSearchWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allTests;
  final Function(List<Map<String, dynamic>>) onFiltered;

  const TestSearchWidget({
    super.key,
    required this.allTests,
    required this.onFiltered,
  });

  @override
  State<TestSearchWidget> createState() => _TestSearchWidgetState();
}

class _TestSearchWidgetState extends State<TestSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredTests = [];

  @override
  void initState() {
    super.initState();
    _filteredTests = widget.allTests;
    _searchController.addListener(_filterTests);
  }

  @override
  void didUpdateWidget(covariant TestSearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allTests != widget.allTests) {
      _filteredTests = widget.allTests;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filterTests();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTests() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTests = widget.allTests;
      } else {
        _filteredTests = widget.allTests.where((test) {
          final testName = test['test_name']?.toLowerCase() ?? '';
          final testCode = test['test_code']?.toLowerCase() ?? '';
          final category = test['category']?.toLowerCase() ?? '';
          return testName.contains(query) ||
              testCode.contains(query) ||
              category.contains(query);
        }).toList();
      }
    });
    widget.onFiltered(_filteredTests);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search by test name, code, or category...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
