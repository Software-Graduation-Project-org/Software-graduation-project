import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/feedback.dart' as feedback_model;

class FeedbackHistory extends StatefulWidget {
  final String userType; // 'patient', 'doctor', 'staff'
  final Future<Map<String, dynamic>> Function({
    int page,
    int limit,
    String? targetType,
  })
  fetchFeedback;

  const FeedbackHistory({
    super.key,
    required this.userType,
    required this.fetchFeedback,
  });

  @override
  State<FeedbackHistory> createState() => _FeedbackHistoryState();
}

class _FeedbackHistoryState extends State<FeedbackHistory> {
  List<feedback_model.Feedback> _feedbacks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _selectedTargetType;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback({bool loadMore = false}) async {
    if (loadMore && _currentPage >= _totalPages) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _error = null;
      }
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final response = await widget.fetchFeedback(
        page: page,
        limit: 10,
        targetType: _selectedTargetType,
      );

      if (response['success'] == false) {
        throw Exception(response['message'] ?? 'Failed to load feedback');
      }

      final feedbacks =
          (response['feedbacks'] as List?)
              ?.map((item) => feedback_model.Feedback.fromJson(item))
              .toList() ??
          [];

      final pagination = response['pagination'] as Map<String, dynamic>?;
      final totalPages = pagination?['pages'] ?? 1;

      setState(() {
        if (loadMore) {
          _feedbacks.addAll(feedbacks);
        } else {
          _feedbacks = feedbacks;
        }
        _currentPage = page;
        _totalPages = totalPages;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _filterByTargetType(String? targetType) {
    setState(() {
      _selectedTargetType = targetType;
      _currentPage = 1;
      _totalPages = 1;
    });
    _loadFeedback();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filter
        Row(
          children: [
            Text(
              'My Feedback History',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            DropdownButton<String?>(
              value: _selectedTargetType,
              hint: const Text('All Types'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...feedback_model.Feedback.targetTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      feedback_model.Feedback.getTargetTypeDisplayName(type),
                    ),
                  );
                }),
              ],
              onChanged: _filterByTargetType,
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFeedback,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _feedbacks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.feedback_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No feedback submitted yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your feedback history will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount:
                      _feedbacks.length + (_currentPage < _totalPages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _feedbacks.length) {
                      // Load more indicator
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: _isLoadingMore
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: () =>
                                      _loadFeedback(loadMore: true),
                                  child: const Text('Load More'),
                                ),
                        ),
                      );
                    }

                    final feedback = _feedbacks[index];
                    return FeedbackCard(feedback: feedback);
                  },
                ),
        ),
      ],
    );
  }
}

class FeedbackCard extends StatelessWidget {
  final feedback_model.Feedback feedback;

  const FeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rating and date
            Row(
              children: [
                Text(
                  feedback.ratingStars,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRatingColor(
                      feedback.rating,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getRatingColor(feedback.rating)),
                  ),
                  child: Text(
                    '${feedback.rating}/5',
                    style: TextStyle(
                      color: _getRatingColor(feedback.rating),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(feedback.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Target info
            Row(
              children: [
                Icon(
                  feedback.targetType == 'lab'
                      ? Icons.business
                      : feedback.targetType == 'test'
                      ? Icons.science
                      : Icons.receipt,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  feedback.targetDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message
            if (feedback.message != null && feedback.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                feedback.message!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],

            // Anonymous indicator
            if (feedback.isAnonymous) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_off, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Submitted anonymously',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],

            // Response from lab owner
            if (feedback.hasResponse) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text(
                          'Lab Response',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback.response!,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}
