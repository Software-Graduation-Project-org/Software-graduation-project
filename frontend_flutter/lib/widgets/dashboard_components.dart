import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/animations.dart';
import '../utils/responsive_utils.dart';

/// Data classes for dashboard components

class HeroMetric {
  final String label;
  final String value;
  final IconData icon;
  final String? change;

  const HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.change,
  });
}

class StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? change;

  const StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.change,
  });
}

class QuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? subtitle;

  const QuickAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });
}

class ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? timestamp;

  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.timestamp,
  });
}

/// Standardized dashboard components for consistent design across all user roles

class DashboardComponents {
  /// Statistics grid section
  static Widget buildStatsGrid({
    required BuildContext context,
    required String title,
    required List<StatCard> stats,
    bool isMobile = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveIsMobile = ResponsiveUtils.isMobile(context);
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          responsiveIsMobile ? 24 : 32,
        );
        final horizontalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: responsiveIsMobile ? 20 : 40,
          vertical: 0,
        );
        final verticalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 0,
          vertical: responsiveIsMobile ? 40 : 60,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(
          context,
          responsiveIsMobile ? 32 : 48,
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding.horizontal,
            vertical: verticalPadding.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAnimations.fadeIn(
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
              ),
              SizedBox(height: spacing),
              AnimatedGridView(
                crossAxisCount: responsiveIsMobile
                    ? 1
                    : (stats.length <= 3 ? stats.length : 3),
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                padding: EdgeInsets.zero,
                children: stats.map((stat) => _buildStatCard(stat)).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildStatCard(StatCard stat) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final isVeryNarrow =
            constraints.maxWidth < 120; // Very narrow constraint
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 28);
        final valueFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 28 : 32,
        );
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 14 : 16,
        );
        final subtitleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 12 : 14,
        );
        final changeFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 10 : 12,
        );
        final padding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: isVeryNarrow ? 12 : 24,
          vertical: isVeryNarrow ? 12 : 24,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(context, 16);

        // Use column layout for very narrow spaces
        if (isVeryNarrow) {
          return AnimatedCard(
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveSpacing(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stat.icon,
                      color: stat.color,
                      size: iconSize * 0.7,
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8),
                  ),
                  Text(
                    stat.value,
                    style: TextStyle(
                      fontSize: valueFontSize * 0.8,
                      fontWeight: FontWeight.bold,
                      color: stat.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 4),
                  ),
                  Text(
                    stat.title,
                    style: TextStyle(
                      fontSize: titleFontSize * 0.9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (stat.subtitle != null) ...[
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 2),
                    ),
                    Text(
                      stat.subtitle!,
                      style: TextStyle(
                        fontSize: subtitleFontSize * 0.8,
                        color: AppTheme.textLight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Original row layout for normal spaces
        return AnimatedCard(
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.getResponsiveSpacing(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: stat.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(stat.icon, color: stat.color, size: iconSize),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (stat.subtitle != null) ...[
                            SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                4,
                              ),
                            ),
                            Text(
                              stat.subtitle!,
                              style: TextStyle(
                                fontSize: subtitleFontSize,
                                color: AppTheme.textLight,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                Text(
                  stat.value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: stat.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stat.change != null) ...[
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        8,
                      ),
                      vertical: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        4,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color:
                          stat.change!.startsWith('+') ||
                              stat.change!.startsWith('↑')
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stat.change!,
                      style: TextStyle(
                        color:
                            stat.change!.startsWith('+') ||
                                stat.change!.startsWith('↑')
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: changeFontSize,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Quick actions grid
  static Widget buildQuickActions({
    required BuildContext context,
    required String title,
    required List<QuickAction> actions,
    bool isMobile = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveIsMobile = ResponsiveUtils.isMobile(context);
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          responsiveIsMobile ? 24 : 32,
        );
        final horizontalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: responsiveIsMobile ? 20 : 40,
          vertical: 0,
        );
        final verticalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 0,
          vertical: responsiveIsMobile ? 40 : 60,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(
          context,
          responsiveIsMobile ? 32 : 48,
        );

        return Container(
          width: double.infinity,
          color: AppTheme.backgroundColor,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding.horizontal,
            vertical: verticalPadding.vertical,
          ),
          child: Column(
            children: [
              AppAnimations.fadeIn(
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: spacing),
              AnimatedGridView(
                crossAxisCount: responsiveIsMobile ? 2 : 4,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                padding: EdgeInsets.zero,
                children: actions
                    .map((action) => _buildActionCard(action))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildActionCard(QuickAction action) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 32);
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 14 : 16,
        );
        final subtitleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 10 : 12,
        );
        final padding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 24,
          vertical: 24,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(context, 16);

        return AnimatedCard(
          onTap: action.onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.getResponsiveSpacing(context, 16),
                  ),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, color: action.color, size: iconSize),
                ),
                SizedBox(height: spacing),
                Text(
                  action.title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action.subtitle != null) ...[
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8),
                  ),
                  Text(
                    action.subtitle!,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color: AppTheme.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Activity feed section
  static Widget buildActivityFeed({
    required BuildContext context,
    required String title,
    required List<ActivityItem> activities,
    bool isMobile = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsiveIsMobile = ResponsiveUtils.isMobile(context);
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          responsiveIsMobile ? 24 : 32,
        );
        final horizontalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: responsiveIsMobile ? 20 : 40,
          vertical: 0,
        );
        final verticalPadding = ResponsiveUtils.getResponsivePadding(
          context,
          horizontal: 0,
          vertical: responsiveIsMobile ? 40 : 60,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(
          context,
          responsiveIsMobile ? 32 : 48,
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding.horizontal,
            vertical: verticalPadding.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAnimations.fadeIn(
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                ),
              ),
              SizedBox(height: spacing),
              if (activities.isEmpty)
                AnimatedCard(
                  child: Container(
                    width: double.infinity,
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                      horizontal: 48,
                      vertical: 48,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            64,
                          ),
                          color: AppTheme.textLight,
                        ),
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            16,
                          ),
                        ),
                        Text(
                          'All caught up!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.textLight,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  responsiveIsMobile ? 20 : 24,
                                ),
                              ),
                        ),
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            8,
                          ),
                        ),
                        Text(
                          'No recent activity to show',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppTheme.textLight,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  responsiveIsMobile ? 14 : 16,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                AnimatedCard(
                  child: Container(
                    width: double.infinity,
                    padding: ResponsiveUtils.getResponsivePadding(
                      context,
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: ResponsiveUtils.getResponsiveIconSize(
                                context,
                                32,
                              ),
                              color: AppTheme.primaryBlue,
                            ),
                            SizedBox(
                              width: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                16,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Activity',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize:
                                              ResponsiveUtils.getResponsiveFontSize(
                                                context,
                                                responsiveIsMobile ? 18 : 22,
                                              ),
                                        ),
                                  ),
                                  Text(
                                    'Latest updates and notifications',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppTheme.textLight,
                                          fontSize:
                                              ResponsiveUtils.getResponsiveFontSize(
                                                context,
                                                responsiveIsMobile ? 12 : 14,
                                              ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing),
                        ...activities.map(
                          (activity) => _buildActivityItem(activity),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildActivityItem(ActivityItem activity) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 24);
        final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 14 : 16,
        );
        final subtitleFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 12 : 14,
        );
        final timestampFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          isMobile ? 10 : 12,
        );
        final spacing = ResponsiveUtils.getResponsiveSpacing(context, 16);

        return Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context, 16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveSpacing(context, 12),
                ),
                decoration: BoxDecoration(
                  color: activity.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: iconSize,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 4),
                    ),
                    Text(
                      activity.subtitle,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: AppTheme.textLight,
                      ),
                    ),
                    if (activity.timestamp != null) ...[
                      SizedBox(
                        height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          4,
                        ),
                      ),
                      Text(
                        activity.timestamp!,
                        style: TextStyle(
                          fontSize: timestampFontSize,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Charts placeholder section
  static Widget buildChartsSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    bool isMobile = false,
  }) {
    return Container(
      width: double.infinity,
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: isMobile ? 40 : 60,
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 24 : 32,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isMobile ? 32 : 48),
          AnimatedCard(
            child: Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 80, color: AppTheme.textLight),
                  const SizedBox(height: 24),
                  Text(
                    'Analytics Coming Soon',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.textLight),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
