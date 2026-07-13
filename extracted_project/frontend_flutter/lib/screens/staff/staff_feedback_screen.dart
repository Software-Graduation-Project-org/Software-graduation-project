import 'package:flutter/material.dart';
import '../../services/staff_api_service.dart';
import '../../widgets/feedback_form.dart';
import '../../widgets/feedback_history.dart';

class StaffFeedbackScreen extends StatefulWidget {
  const StaffFeedbackScreen({super.key});

  @override
  State<StaffFeedbackScreen> createState() => _StaffFeedbackScreenState();
}

class _StaffFeedbackScreenState extends State<StaffFeedbackScreen>
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
    return await StaffApiService.getMyFeedback(
      page: page,
      limit: limit,
      targetType: targetType,
    );
  }

  Future<void> _submitFeedback(Map<String, dynamic> feedbackData) async {
    await StaffApiService.provideFeedback(
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
          FeedbackHistory(userType: 'staff', fetchFeedback: _fetchFeedback),
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
            'Internal Feedback',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Help improve our laboratory operations and services from the inside:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Quick feedback options
          _buildFeedbackOption(
            icon: Icons.business,
            title: 'Laboratory Operations',
            description:
                'Feedback on lab management, procedures, and overall operations',
            onTap: () => _showLabSelectionDialog(),
          ),

          _buildFeedbackOption(
            icon: Icons.science,
            title: 'Test Procedures',
            description:
                'Suggestions for improving test methodologies and protocols',
            onTap: () => _showTestSelectionDialog(),
          ),

          _buildFeedbackOption(
            icon: Icons.assignment,
            title: 'Order Processing',
            description: 'Feedback on order handling and workflow efficiency',
            onTap: () => _showOrderSelectionDialog(),
          ),

          const SizedBox(height: 32),

          // Internal improvement section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Internal Improvements',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '- Suggest process improvements and efficiency gains\n'
                  '- Report equipment or facility issues\n'
                  '- Share ideas for better patient experience\n'
                  '- Help maintain quality standards and compliance',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Anonymous feedback encouragement
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Anonymous feedback is encouraged for sensitive internal matters.',
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
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
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.purple, size: 24),
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
    // For staff, they can only provide feedback on their own lab
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'staff',
        targetType: 'lab',
        targetId: 'current_lab',
        targetName: 'Current Laboratory',
        onSubmit: _submitFeedback,
      ),
    );
  }

  void _showTestSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'staff',
        targetType: 'test',
        targetId: 'sample_test',
        targetName: 'Sample Test Procedure',
        onSubmit: _submitFeedback,
      ),
    );
  }

  void _showOrderSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => FeedbackForm(
        userType: 'staff',
        targetType: 'order',
        targetId: 'sample_order',
        targetName: 'Sample Order Processing',
        onSubmit: _submitFeedback,
      ),
    );
  }
}
