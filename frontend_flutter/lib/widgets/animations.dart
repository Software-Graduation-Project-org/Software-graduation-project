import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Common animation utilities for the app
class AppAnimations {
  // Page transition animations
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Curve pageTransitionCurve = Curves.easeInOut;

  // Fade in animation for content
  static Widget fadeIn(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .fadeIn(duration: 600.ms, delay: delay)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOut,
        );
  }

  // Scale animation for buttons and cards
  static Widget scaleIn(Widget child, {Duration delay = Duration.zero}) {
    return child.animate().scaleXY(
      begin: 0.8,
      end: 1.0,
      duration: 500.ms,
      delay: delay,
      curve: Curves.elasticOut,
    );
  }

  // Slide in from bottom
  static Widget slideInFromBottom(
    Widget child, {
    Duration delay = Duration.zero,
  }) {
    return child
        .animate()
        .slideY(
          begin: 1.0,
          end: 0,
          duration: 600.ms,
          delay: delay,
          curve: Curves.easeOut,
        )
        .fadeIn(duration: 600.ms, delay: delay);
  }

  // Slide in from left
  static Widget slideInFromLeft(
    Widget child, {
    Duration delay = Duration.zero,
  }) {
    return child
        .animate()
        .slideX(
          begin: -0.3,
          end: 0,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOut,
        )
        .fadeIn(duration: 500.ms, delay: delay);
  }

  // Slide in from right
  static Widget slideInFromRight(
    Widget child, {
    Duration delay = Duration.zero,
  }) {
    return child
        .animate()
        .slideX(
          begin: 0.3,
          end: 0,
          duration: 500.ms,
          delay: delay,
          curve: Curves.easeOut,
        )
        .fadeIn(duration: 500.ms, delay: delay);
  }

  // Bounce animation for icons
  static Widget bounce(Widget child, {bool repeat = false}) {
    return child
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.2,
          duration: 800.ms,
          curve: Curves.elasticOut,
        );
  }

  // Pulse animation for loading states
  static Widget pulse(Widget child) {
    return child
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 1000.ms,
          curve: Curves.easeInOut,
        );
  }

  // Rotate in animation
  static Widget rotateIn(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .rotate(begin: -0.2, end: 0, duration: 600.ms, delay: delay)
        .scaleXY(begin: 0.8, end: 1.0, duration: 600.ms, delay: delay)
        .fadeIn(duration: 600.ms, delay: delay);
  }

  // Flip animation (simplified without rotateY)
  static Widget flipIn(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .rotate(begin: 0.5, end: 0, duration: 700.ms, delay: delay)
        .scaleXY(begin: 0.8, end: 1.0, duration: 700.ms, delay: delay)
        .fadeIn(duration: 700.ms, delay: delay);
  }

  // Elastic slide animation
  static Widget elasticSlideIn(
    Widget child, {
    Duration delay = Duration.zero,
    double begin = 1.0,
  }) {
    return child
        .animate()
        .slideY(
          begin: begin,
          end: 0,
          duration: 800.ms,
          delay: delay,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 600.ms, delay: delay);
  }

  // Staggered fade with blur effect
  static Widget blurFadeIn(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .blurXY(begin: 4, end: 0, duration: 600.ms, delay: delay)
        .fadeIn(duration: 600.ms, delay: delay)
        .slideY(begin: 0.1, end: 0, duration: 600.ms, delay: delay);
  }

  // Breathing animation for highlights
  static Widget breathe(Widget child, {bool repeat = true}) {
    return child
        .animate(
          onPlay: repeat
              ? (controller) => controller.repeat(reverse: true)
              : null,
        )
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 2000.ms,
          curve: Curves.easeInOut,
        );
  }

  // Typing animation effect
  static Widget typingEffect(String text, TextStyle style) {
    return Text(
      text,
      style: style,
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0);
  }

  // Morphing animation
  static Widget morphIn(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .scaleXY(begin: 0.3, end: 1.2, duration: 400.ms, delay: delay)
        .then()
        .scaleXY(begin: 1.2, end: 1.0, duration: 300.ms)
        .fadeIn(duration: 700.ms, delay: delay);
  }

  // Wave animation for sequential elements
  static Widget waveIn(Widget child, int index) {
    return child
        .animate()
        .fadeIn(
          duration: 600.ms,
          delay: Duration(milliseconds: index * 100),
        )
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 600.ms,
          delay: Duration(milliseconds: index * 100),
          curve: Curves.elasticOut,
        );
  }

  // Glow pulse animation
  static Widget glowPulse(Widget child, {Color? glowColor}) {
    return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: (glowColor ?? Colors.blue).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: child,
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .boxShadow(
          begin: BoxShadow(
            color: (glowColor ?? Colors.blue).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
          end: BoxShadow(
            color: (glowColor ?? Colors.blue).withValues(alpha: 0.8),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          duration: 1500.ms,
        );
  }

  // Liquid morph animation
  static Widget liquidMorph(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .scaleXY(begin: 0.5, end: 1.1, duration: 500.ms, delay: delay)
        .then()
        .scaleXY(begin: 1.1, end: 0.95, duration: 300.ms)
        .then()
        .scaleXY(begin: 0.95, end: 1.0, duration: 200.ms)
        .fadeIn(duration: 1000.ms, delay: delay);
  }

  // 3D tilt animation (simplified)
  static Widget tilt3D(Widget child, {Duration delay = Duration.zero}) {
    return child
        .animate()
        .rotate(begin: 0.05, end: 0, duration: 600.ms, delay: delay)
        .scaleXY(begin: 0.9, end: 1.0, duration: 600.ms, delay: delay)
        .fadeIn(duration: 600.ms, delay: delay);
  }

  // Cascade animation for lists
  static Widget cascadeIn(Widget child, int index) {
    return child
        .animate()
        .fadeIn(
          duration: 500.ms,
          delay: Duration(milliseconds: index * 150),
        )
        .slideX(
          begin: 0.3,
          end: 0,
          duration: 600.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.elasticOut,
        )
        .scaleXY(
          begin: 0.8,
          end: 1.0,
          duration: 500.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.elasticOut,
        );
  }

  // Magnetic hover effect
  static Widget magneticHover(Widget child) {
    return AnimatedCard(child: child)
        .animate()
        .moveY(begin: 0, end: -8, duration: 300.ms)
        .then()
        .moveY(begin: -8, end: 0, duration: 300.ms);
  }

  // Page transition with depth
  static Widget pageDepthTransition(Widget child) {
    return child
        .animate()
        .scaleXY(begin: 0.95, end: 1.0, duration: 400.ms)
        .fadeIn(duration: 400.ms)
        .blurXY(begin: 2, end: 0, duration: 400.ms);
  }

  // Floating animation
  static Widget floating(Widget child, {bool repeat = true}) {
    return child
        .animate(
          onPlay: repeat
              ? (controller) => controller.repeat(reverse: true)
              : null,
        )
        .moveY(begin: 0, end: -10, duration: 2000.ms, curve: Curves.easeInOut);
  }

  // Ripple effect animation
  static Widget rippleEffect(Widget child, {Color? rippleColor}) {
    return Container(child: child)
        .animate(onPlay: (controller) => controller.repeat())
        .scaleXY(begin: 1.0, end: 1.2, duration: 1000.ms)
        .then()
        .scaleXY(begin: 1.2, end: 1.0, duration: 1000.ms)
        .boxShadow(
          begin: BoxShadow(
            color: (rippleColor ?? Colors.blue).withValues(alpha: 0.0),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          end: BoxShadow(
            color: (rippleColor ?? Colors.blue).withValues(alpha: 0.6),
            blurRadius: 50,
            spreadRadius: 20,
          ),
          duration: 1000.ms,
        );
  }
}

/// Animated list wrapper for staggered animations
class AnimatedListView extends StatelessWidget {
  final List<Widget> children;
  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;

  const AnimatedListView({
    super.key,
    required this.children,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    if (shrinkWrap) {
      // Use Column for non-scrollable layout (when inside SingleChildScrollView)
      return Container(
        padding: padding,
        child: AnimationLimiter(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 50.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: children,
              ),
            ),
          ),
        ),
      );
    } else {
      // Use ListView for primary scrollable content
      return AnimationLimiter(
        child: ListView(
          scrollDirection: scrollDirection,
          padding: padding,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(child: widget),
            ),
            children: children,
          ),
        ),
      );
    }
  }
}

/// Animated grid wrapper for staggered animations
class AnimatedGridView extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double? childAspectRatio;
  final EdgeInsetsGeometry? padding;

  const AnimatedGridView({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16.0,
    this.crossAxisSpacing = 16.0,
    this.childAspectRatio,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Container(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate((children.length / crossAxisCount).ceil(), (
            rowIndex,
          ) {
            final startIndex = rowIndex * crossAxisCount;
            final endIndex = (startIndex + crossAxisCount).clamp(
              0,
              children.length,
            );
            final rowChildren = children.sublist(startIndex, endIndex);

            return Padding(
              padding: EdgeInsets.only(
                bottom: rowIndex < (children.length / crossAxisCount).ceil() - 1
                    ? mainAxisSpacing
                    : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(rowChildren.length, (colIndex) {
                  final itemIndex = startIndex + colIndex;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: colIndex < rowChildren.length - 1
                            ? crossAxisSpacing
                            : 0,
                      ),
                      child: childAspectRatio != null
                          ? AspectRatio(
                              aspectRatio: childAspectRatio!,
                              child: AnimationConfiguration.staggeredGrid(
                                position: itemIndex,
                                duration: const Duration(milliseconds: 375),
                                columnCount: crossAxisCount,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: rowChildren[colIndex],
                                  ),
                                ),
                              ),
                            )
                          : AnimationConfiguration.staggeredGrid(
                              position: itemIndex,
                              duration: const Duration(milliseconds: 375),
                              columnCount: crossAxisCount,
                              child: ScaleAnimation(
                                child: FadeInAnimation(
                                  child: rowChildren[colIndex],
                                ),
                              ),
                            ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Animated card with hover effects
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? elevation;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.elevation,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isHovered = false;
  bool _isLaidOut = false;

  bool get _isMobile =>
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    // Delay hover effect initialization to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLaidOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: widget.padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: (_isHovered && _isLaidOut && !_isMobile)
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        transform: (_isHovered && _isLaidOut && !_isMobile)
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.translationValues(0, 0, 0),
        child: _isLaidOut
            ? _isMobile
                  ? (widget.onTap != null
                        ? Material(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            elevation: widget.elevation ?? 0,
                            child: InkWell(
                              onTap: widget.onTap,
                              borderRadius: BorderRadius.circular(12),
                              child: widget.child,
                            ),
                          )
                        : Material(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            elevation: widget.elevation ?? 0,
                            child: widget.child,
                          ))
                  : MouseRegion(
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      child: widget.onTap != null
                          ? Material(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              elevation: widget.elevation ?? 0,
                              child: InkWell(
                                onTap: widget.onTap,
                                borderRadius: BorderRadius.circular(12),
                                child: widget.child,
                              ),
                            )
                          : Material(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              elevation: widget.elevation ?? 0,
                              child: widget.child,
                            ),
                    )
            : widget.onTap != null
            ? Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                elevation: widget.elevation ?? 0,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: widget.child,
                ),
              )
            : Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                elevation: widget.elevation ?? 0,
                child: widget.child,
              ),
      ),
    );
  }
}

/// Loading shimmer widget
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const LoadingShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.5));
  }
}

/// Animated button with scale effect
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration animationDuration;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: widget.animationDuration,
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
