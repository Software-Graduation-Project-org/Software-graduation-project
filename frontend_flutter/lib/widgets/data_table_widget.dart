import 'package:flutter/material.dart';

class DataTableWidget extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final List<Widget> Function(Map<String, dynamic>)? actions;
  final bool isLoading;
  final String? emptyMessage;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.rows,
    this.actions,
    this.isLoading = false,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                emptyMessage ?? 'No data available',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Card(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
          ),
          columns: [
            ...columns.map(
              (col) => DataColumn(
                label: Text(
                  col,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (actions != null)
              const DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    ...columns.map(
                      (col) => DataCell(
                        _buildCellContent(
                          row[col.toLowerCase().replaceAll(' ', '_')],
                        ),
                      ),
                    ),
                    if (actions != null)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!(row),
                        ),
                      ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCellContent(dynamic value) {
    if (value == null) {
      return const Text('-');
    }
    if (value is Widget) {
      return value;
    }
    return Text(value.toString());
  }
}
