import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/staff_auth_provider.dart';
import '../../config/theme.dart';

class StaffSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const StaffSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<StaffAuthProvider>(context);
    final user = authProvider.user;

    return Container(
      width: 280,
      color: AppTheme.cardColor,
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              children: [
                const Icon(Icons.biotech, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Lab Staff',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navigation Sections
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavSection(context, 'WORKSTATION', [
                    _buildNavItem(context, 'Dashboard', Icons.dashboard, 0),
                    _buildNavItem(context, 'New Order', Icons.add_box, 1),
                    _buildNavItem(context, 'Orders', Icons.assignment, 2),
                    _buildNavItem(
                      context,
                      'My Tests',
                      Icons.assignment_turned_in,
                      3,
                    ),
                    _buildNavItem(
                      context,
                      'Sample Collection',
                      Icons.science,
                      4,
                    ),
                    _buildNavItem(
                      context,
                      'Result Upload',
                      Icons.upload_file,
                      5,
                    ),
                  ]),
                  _buildNavSection(context, 'OPERATIONS', [
                    // _buildNavItem(
                    //   context,
                    //   'Barcode Generation',
                    //   Icons.qr_code,
                    //   4,
                    // ),
                    _buildNavItem(context, 'Inventory', Icons.inventory, 6),
                    _buildNavItem(
                      context,
                      'Notifications',
                      Icons.notifications,
                      7,
                    ),
                  ]),
                  _buildNavSection(context, 'ACCOUNT', [
                    _buildNavItem(context, 'My Profile', Icons.person, 8),
                    _buildNavItem(
                      context,
                      'Logout',
                      Icons.logout,
                      -1,
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ]),
                ],
              ), // Close Column
            ), // Close SingleChildScrollView
          ), // Close Expanded
        ], // Close Container Column children
      ),
    );
  }

  Widget _buildNavSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    int index, {
    VoidCallback? onTap,
  }) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap:
          onTap ??
          () {
            onItemSelected(index);
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textLight,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.chevron_right, color: AppTheme.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = Provider.of<StaffAuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout();
              // Small delay to ensure logout is complete before navigation
              await Future.delayed(const Duration(milliseconds: 50));
              // Use post frame callback to ensure navigation happens after dialog is closed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  GoRouter.of(context).go('/');
                }
              });
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
