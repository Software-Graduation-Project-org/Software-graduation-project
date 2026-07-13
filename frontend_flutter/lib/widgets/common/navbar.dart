import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

// Extension for clean responsive checks
extension ResponsiveExt on BuildContext {
  bool get useMobileLayout {
    // Use mobile layout for tablets and mobile devices
    return ResponsiveBreakpoints.of(this).smallerThan(DESKTOP);
  }
}

// ------------------------------
// MOBILE DRAWER WIDGET
// ------------------------------
class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: Text(
              'MedLab System',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          ...AppNavBar._navItems.map(
            (item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              selected:
                  GoRouterState.of(context).uri.toString() == item.route ||
                  GoRouterState.of(context).uri.path == item.route,
              selectedTileColor: theme.colorScheme.primary.withValues(
                alpha: 0.1,
              ),
              onTap: () {
                context.go(item.route);
                Navigator.pop(context);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Login'),
            onTap: () {
              context.goNamed('merged-login');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  static final List<_NavItem> _navItems = [
    _NavItem('Home', '/', Icons.home),
    _NavItem('About', '/about', Icons.info_outline),
    _NavItem('Services', '/services', Icons.medical_services_outlined),
    _NavItem('Contact', '/contact', Icons.contact_mail_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return context.useMobileLayout
        ? const _MobileNavBar()
        : const _DesktopNavBar();
  }
}

// ------------------------------
// DESKTOP NAVBAR
// ------------------------------
class _DesktopNavBar extends StatelessWidget {
  const _DesktopNavBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakpoints = ResponsiveBreakpoints.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: breakpoints.smallerThan(DESKTOP) ? 20 : 40,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand
          InkWell(
            onTap: () => context.go('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_hospital,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  breakpoints.isMobile ? 'MedLab' : 'MedLab System',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Navigation Links - Only show on larger screens
          if (!breakpoints.smallerThan(DESKTOP))
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...AppNavBar._navItems.map((i) => _HoverNavLink(item: i)),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.goNamed('merged-login'),
                      icon: const Icon(Icons.login),
                      label: const Text("Login"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // On mobile/tablet, show menu button
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Menu',
            ),
        ],
      ),
    );
  }
}

// ------------------------------
// MOBILE / TABLET NAVBAR
// ------------------------------
class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo - Make it flexible for very small screens
          Flexible(
            child: InkWell(
              onTap: () => context.go('/'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_hospital,
                    size: 26,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MedLab',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Hamburger Menu - Fixed size
          IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// HOVER NAV LINK
// ------------------------------
class _HoverNavLink extends StatefulWidget {
  final _NavItem item;
  const _HoverNavLink({required this.item});

  @override
  State<_HoverNavLink> createState() => _HoverNavLinkState();
}

class _HoverNavLinkState extends State<_HoverNavLink> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = currentPath == widget.item.route;

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: () => context.go(widget.item.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive
                    ? theme.colorScheme.primary
                    : hovering
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 20,
                color: isActive || hovering
                    ? theme.colorScheme.primary
                    : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                widget.item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive || hovering
                      ? theme.colorScheme.primary
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String title;
  final String route;
  final IconData icon;
  const _NavItem(this.title, this.route, this.icon);
}
