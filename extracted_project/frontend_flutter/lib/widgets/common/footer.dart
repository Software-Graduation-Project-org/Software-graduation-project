import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall =
        screenWidth < 300; // Very small screens (dev tools open)

    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 8 : (isMobile ? 20 : 80),
        vertical: isVerySmall ? 20 : (isMobile ? 40 : 60),
      ),
      child: isVerySmall
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(context, 'Company', [
                  {'label': 'About Us', 'route': '/about'},
                  {'label': 'Services', 'route': '/services'},
                  {'label': 'Contact', 'route': '/contact'},
                ]),
                const SizedBox(height: 16),
                _buildSection(context, 'Legal', [
                  {'label': 'Privacy Policy', 'route': '/'},
                  {'label': 'Terms of Service', 'route': '/'},
                ]),
                const SizedBox(height: 16),
                _buildCopyright(context),
              ],
            )
          : isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(context, 'Company', [
                  {'label': 'About Us', 'route': '/about'},
                  {'label': 'Services', 'route': '/services'},
                  {'label': 'Contact', 'route': '/contact'},
                ]),
                const SizedBox(height: 32),
                _buildSection(context, 'Legal', [
                  {'label': 'Privacy Policy', 'route': '/'},
                  {'label': 'Terms of Service', 'route': '/'},
                ]),
                const SizedBox(height: 32),
                _buildCopyright(context),
              ],
            )
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 40,
              runSpacing: 32,
              children: [
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'MedLab System',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Complete management solution for modern medical laboratories.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                _buildSection(context, 'Company', [
                  {'label': 'About Us', 'route': '/about'},
                  {'label': 'Services', 'route': '/services'},
                  {'label': 'Contact', 'route': '/contact'},
                ]),
                _buildSection(context, 'Legal', [
                  {'label': 'Privacy Policy', 'route': '/'},
                  {'label': 'Terms of Service', 'route': '/'},
                ]),
              ],
            ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Map<String, String>> links,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isVerySmall ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isVerySmall ? 8 : 16),
        ...links.map(
          (link) => Padding(
            padding: EdgeInsets.only(bottom: isVerySmall ? 8 : 12),
            child: InkWell(
              onTap: () => context.go(link['route']!),
              child: Text(
                link['label']!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: isVerySmall ? 12 : 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyright(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 300;

    return Container(
      margin: EdgeInsets.only(top: isVerySmall ? 16 : 32),
      padding: EdgeInsets.only(top: isVerySmall ? 12 : 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Text(
        '© 2025 MedLab System. All rights reserved.',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: isVerySmall ? 10 : 14,
        ),
      ),
    );
  }
}
