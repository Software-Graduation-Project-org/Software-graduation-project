import 'package:flutter/material.dart';
import 'package:frontend_flutter/widgets/common/footer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/animations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
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
            _buildHeader(context, useMobileLayout),
            const SizedBox(height: 40),
            _buildMissionSection(context, useMobileLayout),
            const SizedBox(height: 40),
            _buildAdvantagesSection(context, useMobileLayout),
            const SizedBox(height: 40),
            _buildTeamSection(context, useMobileLayout),
            const SizedBox(height: 40),
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: isMobile ? 20 : 80,
      vertical: isMobile ? 70 : 110,
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
            'About MedLab System',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 34 : 52,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        AppAnimations.fadeIn(
          Text(
            'Revolutionizing medical laboratory management with cutting-edge technology',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: isMobile ? 17 : 22,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          delay: 300.ms,
        ),
      ],
    ),
  );

  Widget _buildMissionSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Our Mission',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 28 : 36,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          AppAnimations.fadeIn(
            Text(
              'We empower medical laboratories to deliver exceptional patient care through innovative technology solutions. Our platform streamlines operations, reduces errors, and enables lab owners to focus on what matters most – providing accurate and timely diagnostic services.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: isMobile ? 16 : 18),
              textAlign: TextAlign.center,
            ),
            delay: 200.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantagesSection(BuildContext context, bool isMobile) {
    final List<Map<String, dynamic>> advantages = [
      {
        'icon': Icons.speed,
        'title': 'Increased Efficiency',
        'description':
            'Automate routine tasks and reduce manual data entry by up to 70%',
      },
      {
        'icon': Icons.savings,
        'title': 'Cost Reduction',
        'description':
            'Save on operational costs with optimized inventory and resource management',
      },
      {
        'icon': Icons.trending_up,
        'title': 'Business Growth',
        'description':
            'Scale your laboratory operations seamlessly as your business grows',
      },
      {
        'icon': Icons.verified_user,
        'title': 'Compliance Ready',
        'description':
            'Built-in compliance features for HIPAA, CAP, and other regulatory requirements',
      },
      {
        'icon': Icons.cloud_done,
        'title': 'Cloud-Based Access',
        'description':
            'Access your data securely from anywhere, anytime, on any device',
      },
      {
        'icon': Icons.support_agent,
        'title': 'Expert Support',
        'description':
            '24/7 dedicated support team ready to assist you whenever needed',
      },
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Why Laboratory Owners Love Us',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 28 : 36,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 60),
          AnimatedGridView(
            crossAxisCount: isMobile ? 1 : 3,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: advantages.map((advantage) {
              return AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      AppAnimations.bounce(
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            advantage['icon'] as IconData,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppAnimations.fadeIn(
                        Text(
                          advantage['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        delay: 200.ms,
                      ),
                      const SizedBox(height: 12),
                      AppAnimations.fadeIn(
                        Text(
                          advantage['description'] as String,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        delay: 400.ms,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Trusted by Industry Leaders',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 28 : 36,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          AppAnimations.fadeIn(
            Text(
              'Join laboratories worldwide that trust MedLab System to manage their operations efficiently and securely.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: isMobile ? 16 : 18),
              textAlign: TextAlign.center,
            ),
            delay: 200.ms,
          ),
        ],
      ),
    );
  }
}
