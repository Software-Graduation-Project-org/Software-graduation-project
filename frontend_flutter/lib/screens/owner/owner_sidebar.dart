import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../config/theme.dart';

class OwnerSidebar extends StatelessWidget {
  final int? selectedIndex;
  final Function(int)? onItemSelected;

  const OwnerSidebar({super.key, this.selectedIndex, this.onItemSelected});

  int _getSelectedIndex(BuildContext context) {
    if (selectedIndex != null) {
      return selectedIndex!;
    }
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/owner/dashboard') return 0;
    if (location == '/owner/staff') return 1;
    if (location == '/owner/doctors') return 2;
    if (location == '/owner/orders') return 3;
    if (location == '/owner/tests') return 4;
    if (location == '/owner/devices') return 5;
    if (location == '/owner/inventory') return 6;
    if (location == '/owner/notifications') return 7;
    if (location == '/owner/reports') return 8;
    if (location == '/owner/audit-logs') return 9;
    if (location == '/owner/profile') return 10;
    return 0; // Default to dashboard
  }

  int _getRouteIndex(String route) {
    if (route == '/owner/dashboard') return 0;
    if (route == '/owner/staff') return 1;
    if (route == '/owner/doctors') return 2;
    if (route == '/owner/orders') return 3;
    if (route == '/owner/tests') return 4;
    if (route == '/owner/devices') return 5;
    if (route == '/owner/inventory') return 6;
    if (route == '/owner/notifications') return 7;
    if (route == '/owner/reports') return 8;
    if (route == '/owner/audit-logs') return 9;
    if (route == '/owner/profile') return 10;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);
    final user = authProvider.user;
    final selectedIndex = _getSelectedIndex(context);

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
                const Icon(Icons.business, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Lab Owner',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back, ${user.displayName}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Navigation Items with Categories
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                // Overview Section
                _buildSection('Overview', [
                  _buildNavItem(
                    context,
                    'Dashboard',
                    Icons.dashboard,
                    '/owner/dashboard',
                    selectedIndex == 0,
                  ),
                ]),
                // Management Section
                _buildSection('Management', [
                  _buildNavItem(
                    context,
                    'Staff',
                    Icons.people,
                    '/owner/staff',
                    selectedIndex == 1,
                  ),
                  _buildNavItem(
                    context,
                    'Doctors',
                    Icons.medical_services,
                    '/owner/doctors',
                    selectedIndex == 2,
                  ),
                  _buildNavItem(
                    context,
                    'Orders',
                    Icons.assignment,
                    '/owner/orders',
                    selectedIndex == 3,
                  ),
                  _buildNavItem(
                    context,
                    'Tests',
                    Icons.science,
                    '/owner/tests',
                    selectedIndex == 4,
                  ),
                  _buildNavItem(
                    context,
                    'Devices',
                    Icons.devices,
                    '/owner/devices',
                    selectedIndex == 5,
                  ),
                  _buildNavItem(
                    context,
                    'Inventory',
                    Icons.inventory,
                    '/owner/inventory',
                    selectedIndex == 6,
                  ),
                  _buildNavItem(
                    context,
                    'Notifications',
                    Icons.notifications,
                    '/owner/notifications',
                    selectedIndex == 7,
                  ),
                  _buildNavItem(
                    context,
                    'My Profile',
                    Icons.person,
                    '/owner/profile',
                    selectedIndex == 10,
                  ),
                ]),
                // Reports Section
                _buildSection('Reports', [
                  _buildNavItem(
                    context,
                    'Reports',
                    Icons.analytics,
                    '/owner/reports',
                    selectedIndex == 8,
                  ),
                  _buildNavItem(
                    context,
                    'Audit Logs',
                    Icons.history,
                    '/owner/audit-logs',
                    selectedIndex == 9,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildNavItem(
                  context,
                  'Logout',
                  Icons.logout,
                  '/login',
                  false,
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    authProvider.logout();
    context.go('/login');
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
    String route,
    bool isSelected, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () {
            if (onItemSelected != null) {
              // For tab-based navigation (dashboard)
              final index = _getRouteIndex(route);
              onItemSelected!(index);
            } else {
              // For route-based navigation (separate screens)
              context.go(route);
            }
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
}
