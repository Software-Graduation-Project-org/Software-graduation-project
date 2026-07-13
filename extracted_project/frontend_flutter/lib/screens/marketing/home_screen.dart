import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/common/footer.dart';
import '../../widgets/animations.dart';
import '../../providers/marketing_provider.dart';
import '../../providers/staff_auth_provider.dart';
import '../../providers/doctor_auth_provider.dart';
import '../../providers/owner_auth_provider.dart';
import '../../providers/patient_auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load system feedback for testimonials (ensure representation from all user roles)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketingProvider>().loadSystemFeedback(
        limit: 12, // Load more to ensure representation from all roles
        minRating: 4,
      );
      context.read<MarketingProvider>().loadAdminContactInfo();

      // Debug: Check authentication status
      final staffAuth = context.read<StaffAuthProvider>();
      final doctorAuth = context.read<DoctorAuthProvider>();
      final ownerAuth = context.read<OwnerAuthProvider>();
      final patientAuth = context.read<PatientAuthProvider>();
      debugPrint(
        '🏠 HomeScreen: Auth status - Staff: ${staffAuth.isAuthenticated}, Doctor: ${doctorAuth.isAuthenticated}, Owner: ${ownerAuth.isAuthenticated}, Patient: ${patientAuth.isAuthenticated}',
      );

      // Add a debug widget to show auth status on screen
      if (staffAuth.isAuthenticated ||
          doctorAuth.isAuthenticated ||
          ownerAuth.isAuthenticated ||
          patientAuth.isAuthenticated) {
        debugPrint('🏠 HomeScreen: User is authenticated somewhere!');
      } else {
        debugPrint('🏠 HomeScreen: No authentication found');
      }

      // Add a debug widget to show auth status on screen
      if (staffAuth.isAuthenticated ||
          doctorAuth.isAuthenticated ||
          ownerAuth.isAuthenticated ||
          patientAuth.isAuthenticated) {
        debugPrint('🏠 HomeScreen: User is authenticated somewhere!');
      } else {
        debugPrint('🏠 HomeScreen: No authentication found');
      }
    });
  }

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
            // Debug width (optional - remove in production)
            /*
            if (kDebugMode)
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
            AppAnimations.fadeIn(_buildHeroSection(context, useMobileLayout)),
            AppAnimations.fadeIn(
              _buildFeaturesSection(context, useMobileLayout),
              delay: 200.ms,
            ),
            // Add Find Labs section for mobile only
            if (useMobileLayout)
              AppAnimations.fadeIn(
                _buildFindLabsSection(context),
                delay: 400.ms,
              ),
            AppAnimations.fadeIn(
              _buildWhyChooseSection(context, useMobileLayout),
              delay: 600.ms,
            ),
            AppAnimations.fadeIn(
              _buildTestimonialsSection(context, useMobileLayout),
              delay: 700.ms,
            ),
            AppAnimations.fadeIn(
              _buildCTASection(context, useMobileLayout),
              delay: 900.ms,
            ),
            AppAnimations.fadeIn(const AppFooter(), delay: 800.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;
    return Container(
      width: double.infinity,
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
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 120),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall
                  ? 'Transform Your Lab'
                  : 'Transform Your Medical Laboratory',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontSize: isVerySmall ? 24 : (isMobile ? 32 : 48),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          AppAnimations.fadeIn(
            Text(
              isVerySmall
                  ? 'Complete management system for modern labs'
                  : 'Complete management system for modern medical laboratories.\nStreamline operations, manage patients, and grow your business.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isVerySmall ? 12 : (isMobile ? 16 : 20),
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
          const SizedBox(height: 32),
          AppAnimations.scaleIn(
            AnimatedButton(
              child: ElevatedButton(
                onPressed: () => context.go('/contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmall ? 24 : (isMobile ? 32 : 48),
                    vertical: isVerySmall ? 12 : (isMobile ? 16 : 20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(isVerySmall ? 'Get Started' : 'Get Started Today'),
              ),
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;
    final features = [
      {
        'icon': Icons.people_outline,
        'title': 'Patient Management',
        'description':
            'Comprehensive patient records, test history, and result tracking',
      },
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'Inventory Control',
        'description':
            'Real-time inventory tracking with automated alerts and reordering',
      },
      {
        'icon': Icons.science_outlined,
        'title': 'Test Management',
        'description':
            'Manage test catalog, results entry, and quality control',
      },
      {
        'icon': Icons.analytics_outlined,
        'title': 'Analytics & Reports',
        'description': 'Comprehensive dashboards and customizable reports',
      },
      {
        'icon': Icons.security_outlined,
        'title': 'Secure & Compliant',
        'description': 'Bank-level security with full HIPAA compliance',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall
                  ? 'Powerful Features'
                  : 'Powerful Features for Your Laboratory',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: isMobile ? 1 : 3,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: features.map((feature) {
              return AnimatedCard(
                onTap: () => context.go('/services'),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      AppAnimations.bounce(
                        Icon(
                          feature['icon'] as IconData,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppAnimations.fadeIn(
                        Text(
                          feature['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        delay: 200.ms,
                      ),
                      const SizedBox(height: 12),
                      AppAnimations.fadeIn(
                        Text(
                          feature['description'] as String,
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

  Widget _buildFindLabsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Find Laboratories Near You',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          AppAnimations.fadeIn(
            Text(
              'Discover accredited medical laboratories in your area. Compare services, check hours, and contact labs directly.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            delay: 200.ms,
          ),
          const SizedBox(height: 32),
          AppAnimations.scaleIn(
            ElevatedButton.icon(
              onPressed: () => context.go('/lab-finder'),
              icon: const Icon(Icons.search),
              label: const Text('Find Labs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            delay: 400.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseSection(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Why Choose Us' : 'Why Laboratory Owners Choose Us',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          // AppAnimations.slideInFromLeft(
          //   _buildStatRow(context, isMobile, '500+', 'Active Laboratories'),
          // ),
          // const SizedBox(height: 24),
          // AppAnimations.slideInFromRight(
          //   _buildStatRow(context, isMobile, '99.9%', 'Uptime Guarantee'),
          //   delay: 200.ms,
          // ),
          const SizedBox(height: 24),
          AppAnimations.slideInFromLeft(
            _buildStatRow(context, isMobile, '24/7', 'Support Available'),
            delay: 400.ms,
          ),
          const SizedBox(height: 24),
          AppAnimations.slideInFromRight(
            _buildStatRow(context, isMobile, '100%', 'Data Security'),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    bool isMobile,
    String stat,
    String label,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return isVerySmall
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                stat,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 36 : 48,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: isMobile ? 18 : 24),
              ),
            ],
          );
  }

  Widget _buildTestimonialsSection(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

    return Consumer<MarketingProvider>(
      builder: (context, marketingProvider, child) {
        if (marketingProvider.isLoading) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 80,
              vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (marketingProvider.error != null) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 80,
              vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
            ),
            child: Center(
              child: Text(
                'Unable to load testimonials at this time',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        final allFeedback = marketingProvider.systemFeedback;
        if (allFeedback.isEmpty) {
          return const SizedBox.shrink();
        }

        // Select diverse feedback representing all user roles
        final feedback = _selectDiverseFeedback(allFeedback);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
          ),
          child: Column(
            children: [
              AppAnimations.fadeIn(
                Column(
                  children: [
                    Text(
                      'What Our Users Say',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real Feedback from Lab Owners, Staff, Doctors & Patients',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: isVerySmall ? 12 : (isMobile ? 14 : 16),
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: isVerySmall ? 40 : 60),
              AnimatedGridView(
                crossAxisCount: isMobile
                    ? 1
                    : (feedback.length >= 3 ? 3 : feedback.length),
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                padding: EdgeInsets.zero,
                children: feedback.map((item) {
                  return AnimatedCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rating stars
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < item.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          // Message
                          AppAnimations.fadeIn(
                            Text(
                              '"${item.message}"',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // User name and role with badge
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _getRoleColor(
                                  item.userModel,
                                ).withValues(alpha: 0.2),
                                child: Icon(
                                  _getRoleIcon(item.userModel),
                                  size: 20,
                                  color: _getRoleColor(item.userModel),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getUserDisplayName(item),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(
                                          item.userModel,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getRoleColor(
                                            item.userModel,
                                          ).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        item.userModel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getRoleColor(
                                            item.userModel,
                                          ).withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      },
    );
  }

  // Helper methods for testimonials section
  List<dynamic> _selectDiverseFeedback(List<dynamic> allFeedback) {
    // Group feedback by user role
    final feedbackByRole = <String, List<dynamic>>{};
    for (final item in allFeedback) {
      final role = item.userModel as String;
      feedbackByRole[role] = (feedbackByRole[role] ?? [])..add(item);
    }

    // Target roles to include
    final targetRoles = ['Owner', 'Staff', 'Doctor', 'Patient'];
    final selectedFeedback = <dynamic>[];

    // First, try to get at least one from each role
    for (final role in targetRoles) {
      final roleFeedback = feedbackByRole[role] ?? [];
      if (roleFeedback.isNotEmpty) {
        // Sort by rating (highest first) and take the best one
        roleFeedback.sort(
          (a, b) => (b.rating as int).compareTo(a.rating as int),
        );
        selectedFeedback.add(roleFeedback.first);
      }
    }

    // If we don't have enough, fill with remaining feedback
    if (selectedFeedback.length < 4) {
      final remainingFeedback = allFeedback
          .where((item) => !selectedFeedback.contains(item))
          .toList();

      // Sort remaining by rating and add top ones
      remainingFeedback.sort(
        (a, b) => (b.rating as int).compareTo(a.rating as int),
      );

      for (final item in remainingFeedback) {
        if (selectedFeedback.length >= 4) break;
        selectedFeedback.add(item);
      }
    }

    // If we still don't have 4, just take the top 4
    if (selectedFeedback.length < 4) {
      final topFeedback = allFeedback.take(4).toList();
      selectedFeedback.clear();
      selectedFeedback.addAll(topFeedback);
    }

    return selectedFeedback;
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Owner':
        return Colors.purple;
      case 'Staff':
        return Colors.blue;
      case 'Doctor':
        return Colors.green;
      case 'Patient':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Owner':
        return Icons.business;
      case 'Staff':
        return Icons.badge;
      case 'Doctor':
        return Icons.medical_services;
      case 'Patient':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  String _getUserDisplayName(dynamic item) {
    if (item.isAnonymous) {
      return 'Anonymous ${item.userModel}';
    }

    // Use the direct userName from backend if available
    if (item.userName != null && item.userName!.isNotEmpty) {
      return item.userName!;
    }

    // Fallback to user object if populated
    if (item.user != null) {
      // Check for lab_name (Owner)
      if (item.user['lab_name'] != null) {
        return item.user['lab_name'];
      }

      // Check for full_name (Patient, Staff, Doctor)
      if (item.user['full_name'] != null) {
        final firstName = item.user['full_name']['first'] ?? '';
        final lastName = item.user['full_name']['last'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) {
          return fullName;
        }
      }

      // Check for username
      if (item.user['username'] != null) {
        return item.user['username'];
      }
    }

    return '${item.userModel} User';
  }

  Widget _buildCTASection(BuildContext context, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall =
        screenWidth < 500; // Custom breakpoint for very small screens

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.primary,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 12 : (isMobile ? 20 : 80),
        vertical: isVerySmall ? 30 : (isMobile ? 60 : 80),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall
                  ? 'Transform Your Lab'
                  : 'Ready to Transform Your Laboratory?',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 12 : 24),
          AppAnimations.fadeIn(
            Text(
              isVerySmall
                  ? 'Join hundreds of labs using our platform'
                  : 'Join hundreds of laboratories already using our platform',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isVerySmall ? 12 : (isMobile ? 16 : 20),
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
          SizedBox(height: isVerySmall ? 20 : 40),
          AppAnimations.slideInFromBottom(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedButton(
                  child: ElevatedButton(
                    onPressed: () => context.go('/contact'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: isVerySmall ? 16 : 24,
                        vertical: isVerySmall ? 12 : 16,
                      ),
                      textStyle: TextStyle(fontSize: isVerySmall ? 12 : 14),
                    ),
                    child: const Text('Contact Sales'),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedButton(
                  child: OutlinedButton(
                    onPressed: () => context.go('/services'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: isVerySmall ? 16 : 24,
                        vertical: isVerySmall ? 12 : 16,
                      ),
                    ),
                    child: Text(
                      'View Services',
                      style: TextStyle(fontSize: isVerySmall ? 12 : 14),
                    ),
                  ),
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }
}
