import 'package:flutter/material.dart';
import '../../services/doctor_api_service.dart';
import '../../widgets/feedback_form.dart';
import '../../widgets/feedback_history.dart';

class DoctorFeedbackScreen extends StatefulWidget {
  const DoctorFeedbackScreen({super.key});

  @override
  State<DoctorFeedbackScreen> createState() => _DoctorFeedbackScreenState();
}

class _DoctorFeedbackScreenState extends State<DoctorFeedbackScreen>
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
    return await DoctorApiService.getMyFeedback(
      page: page,
      limit: limit,
      targetType: targetType,
    );
  }

  Future<void> _submitFeedback(Map<String, dynamic> feedbackData) async {
    await DoctorApiService.provideFeedback(
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
          FeedbackHistory(userType: 'doctor', fetchFeedback: _fetchFeedback),
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
            'Share Your Professional Feedback',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'As a healthcare professional, your feedback on lab services and test quality is invaluable for improving patient care:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Quick feedback options
          _buildFeedbackOption(
            icon: Icons.business,
            title: 'Laboratory Services',
            description:
                'Rate lab efficiency, communication, and overall service quality',
            onTap: () => _showLabSelectionDialog(),
          ),

          _buildFeedbackOption(
            icon: Icons.science,
            title: 'Test Accuracy & Quality',
            description:
                'Provide feedback on specific test results and methodologies',
            onTap: () => _showTestSelectionDialog(),
          ),

          const SizedBox(height: 32),

          // Professional insights section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Professional Impact',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Help improve diagnostic accuracy and patient outcomes\n'
                  '• Share insights on test reliability and turnaround times\n'
                  '• Contribute to quality assurance and standardization\n'
                  '• Your expertise helps maintain high medical standards',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.privacy_tip, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your professional feedback is shared with lab management to drive quality improvements.',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 14,
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

  Widget _buildFeedbackOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showLabSelectionDialog() {
    // Basic implementation: Show feedback form for general lab services
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'doctor',
        targetType: 'lab',
        targetId: 'general_lab_services', // Placeholder ID
        targetName: 'Laboratory Services',
        onSubmit: _submitFeedback,
      ),
    );
  }

  void _showTestSelectionDialog() {
    // Basic implementation: Show feedback form for general test quality
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'doctor',
        targetType: 'test',
        targetId: 'general_test_quality', // Placeholder ID
        targetName: 'Test Quality & Accuracy',
        onSubmit: _submitFeedback,
      ),
    );
  }
}
