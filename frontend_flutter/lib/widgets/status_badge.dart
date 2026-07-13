import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['border']!, width: 1),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: colors['text'],
          fontWeight: FontWeight.w600,
          fontSize: small ? 11 : 13,
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'background': Colors.orange.shade50,
          'border': Colors.orange.shade200,
          'text': Colors.orange.shade900,
        };
      case 'assigned':
        return {
          'background': Colors.blue.shade50,
          'border': Colors.blue.shade200,
          'text': Colors.blue.shade900,
        };
      case 'collected':
      case 'in_progress':
      case 'in progress':
        return {
          'background': Colors.purple.shade50,
          'border': Colors.purple.shade200,
          'text': Colors.purple.shade900,
        };
      case 'completed':
      case 'delivered':
        return {
          'background': Colors.green.shade50,
          'border': Colors.green.shade200,
          'text': Colors.green.shade900,
        };
      case 'cancelled':
      case 'rejected':
        return {
          'background': Colors.grey.shade100,
          'border': Colors.grey.shade300,
          'text': Colors.grey.shade700,
        };
      case 'paid':
        return {
          'background': Colors.teal.shade50,
          'border': Colors.teal.shade200,
          'text': Colors.teal.shade900,
        };
      case 'unpaid':
        return {
          'background': Colors.amber.shade50,
          'border': Colors.amber.shade300,
          'text': Colors.amber.shade900,
        };
      case 'active':
        return {
          'background': Colors.green.shade50,
          'border': Colors.green.shade200,
          'text': Colors.green.shade900,
        };
      case 'inactive':
      case 'offline':
        return {
          'background': Colors.grey.shade100,
          'border': Colors.grey.shade300,
          'text': Colors.grey.shade700,
        };
      default:
        return {
          'background': Colors.grey.shade50,
          'border': Colors.grey.shade200,
          'text': Colors.grey.shade800,
        };
    }
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
