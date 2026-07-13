import 'package:flutter/material.dart';

class FeedbackForm extends StatefulWidget {
  final String userType; // 'patient', 'doctor', 'staff', 'owner'
  final String targetType; // 'system', 'lab', 'test', 'order', 'service'
  final String? targetId;
  final String? targetName;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback? onCancel;

  const FeedbackForm({
    super.key,
    required this.userType,
    required this.targetType,
    this.targetId,
    this.targetName,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  int _rating = 0;
  final TextEditingController _messageController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide feedback message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedbackData = {
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'rating': _rating,
        'message': _messageController.text.trim(),
        'is_anonymous': _isAnonymous,
      };

      await widget.onSubmit(feedbackData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        // Removed Navigator.of(context).pop() to avoid double pop error
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getTargetTypeDisplayName(String targetType) {
    switch (targetType) {
      case 'system':
        return 'System';
      case 'lab':
        return 'Lab';
      case 'test':
        return 'Test';
      case 'order':
        return 'Order';
      case 'service':
        return 'Service';
      default:
        return targetType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.feedback, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Provide Feedback',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      widget.onCancel ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.targetType == 'lab'
                        ? Icons.business
                        : widget.targetType == 'test'
                        ? Icons.science
                        : Icons.receipt,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTargetTypeDisplayName(widget.targetType),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (widget.targetName != null)
                          Text(
                            widget.targetName!,
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Rating
            Text(
              'Rating *',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starNumber),
                  icon: Icon(
                    _rating >= starNumber ? Icons.star : Icons.star_border,
                    color: _rating >= starNumber ? Colors.amber : Colors.grey,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Message
            Text(
              'Message *',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Share your experience or suggestions...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Anonymous option
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (value) =>
                      setState(() => _isAnonymous = value ?? false),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Submit anonymously',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Tooltip(
                  message: 'Your identity will be hidden from the lab owner',
                  child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : (widget.onCancel ?? () => Navigator.of(context).pop()),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Feedback'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
