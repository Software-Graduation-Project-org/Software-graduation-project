import 'package:flutter/material.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/feedback_form.dart';
import '../../widgets/feedback_history.dart';

class PatientFeedbackScreen extends StatefulWidget {
  const PatientFeedbackScreen({super.key});

  @override
  State<PatientFeedbackScreen> createState() => _PatientFeedbackScreenState();
}

class _PatientFeedbackScreenState extends State<PatientFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchFeedback({
    int page = 1,
    int limit = 10,
    String? targetType,
  }) async {
    return await PatientApiService.getMyFeedback(
      page: page,
      limit: limit,
      targetType: targetType,
    );
  }

  Future<void> _submitFeedback(Map<String, dynamic> feedbackData) async {
    await PatientApiService.provideFeedback(
      targetType: feedbackData['target_type'],
      targetId: feedbackData['target_id'],
      rating: feedbackData['rating'],
      message: feedbackData['message'],
      isAnonymous: feedbackData['is_anonymous'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Submit Feedback'),
            Tab(text: 'My Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Submit Feedback Tab
          _buildSubmitFeedbackTab(),

          // My Feedback Tab
          FeedbackHistory(userType: 'patient', fetchFeedback: _fetchFeedback),
        ],
      ),
    );
  }

  Widget _buildSubmitFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Your Experience',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve our services',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Simple feedback form
          FeedbackForm(
            userType: 'patient',
            targetType: 'system',
            targetId: 'general_system_feedback',
            targetName: 'Medical Lab System',
            onSubmit: _submitFeedback,
          ),

          const SizedBox(height: 32),

          // Info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy & Impact',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '- Your feedback is valuable and helps improve our services\n'
                  '- You can choose to submit feedback anonymously\n'
                  '- All feedback is reviewed and taken seriously',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
