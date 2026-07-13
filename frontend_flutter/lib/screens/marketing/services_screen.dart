import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/common/footer.dart';
import '../../widgets/animations.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = context.useMobileLayout;
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(68),
        child: AppNavBar(),
      ),
      endDrawer: useMobileLayout ? const MobileDrawer() : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Debug width (optional)
            /*
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  'Width: ${MediaQuery.of(context).size.width.toStringAsFixed(0)} px',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            */
            AppAnimations.fadeIn(_buildHeader(context, useMobileLayout)),
            AppAnimations.fadeIn(
              _buildServicesSection(context, useMobileLayout),
              delay: 200.ms,
            ),
            AppAnimations.fadeIn(
              _buildCTA(context, useMobileLayout),
              delay: 300.ms,
            ),
            AppAnimations.fadeIn(const AppFooter(), delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Our Services',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 32 : 48,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          AppAnimations.fadeIn(
            Text(
              'Comprehensive laboratory management features designed for modern medical facilities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: isMobile ? 16 : 20,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context, bool isMobile) {
    final services = [
      {
        'icon': Icons.people,
        'title': 'Patient Management',
        'features': [
          'Complete patient registration and profile management',
          'Medical history and previous test results',
          'Patient portal for self-service access',
        ],
      },
      {
        'icon': Icons.science,
        'title': 'Test & Result Management',
        'features': [
          'Comprehensive test catalog management',
          'Digital result entry with validation',
          'Automated result notifications',
          'Quality control and audit trails',
        ],
      },
      {
        'icon': Icons.inventory,
        'title': 'Inventory & Supply Chain',
        'features': [
          'Real-time inventory tracking',
          'Automated reorder alerts',
          'Supplier management',
          'Expiration date monitoring',
        ],
      },
      {
        'icon': Icons.people_alt,
        'title': 'Staff Management',
        'features': [
          'Role-based access control',
          'Staff scheduling and shifts',
          'Performance tracking',
          'Task assignment and monitoring',
        ],
      },
      {
        'icon': Icons.analytics,
        'title': 'Analytics & Reporting',
        'features': [
          'Real-time dashboards with KPIs',
          'Customizable reports',
          'Revenue and expense tracking',
          'Operational efficiency metrics',
        ],
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: AnimatedListView(
        padding: EdgeInsets.zero,
        children: services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 40),
            child: AppAnimations.slideInFromBottom(
              AnimatedCard(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 24 : 40),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAnimations.bounce(
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            service['icon'] as IconData,
                            size: isMobile ? 32 : 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppAnimations.fadeIn(
                              Text(
                                service['title'] as String,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              delay: 200.ms,
                            ),
                            const SizedBox(height: 16),
                            ...(service['features'] as List<String>).map((
                              feature,
                            ) {
                              return AppAnimations.fadeIn(
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                delay: 400.ms,
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              delay: (index * 200).ms,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCTA(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 80,
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Ready to Get Started?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 28 : 36,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          AppAnimations.fadeIn(
            Text(
              'Contact us today to learn how MedLab System can transform your laboratory',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isMobile ? 16 : 20,
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
          const SizedBox(height: 40),
          AppAnimations.scaleIn(
            AnimatedButton(
              child: ElevatedButton(
                onPressed: () => context.go('/contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 16 : 20,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Contact Us'),
              ),
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }
}
