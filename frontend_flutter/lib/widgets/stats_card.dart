import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 28);
    final padding = ResponsiveUtils.getResponsivePadding(
      context,
      horizontal: 16,
      vertical: 16,
    );
    final spacing = ResponsiveUtils.getResponsiveSpacing(context, 16);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveSpacing(context, 12),
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
              SizedBox(height: spacing),
              ResponsiveText(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    isMobile ? 24 : 32,
                  ),
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 4),
              ),
              ResponsiveText(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    isMobile ? 12 : 14,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8),
                ),
                ResponsiveText(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
