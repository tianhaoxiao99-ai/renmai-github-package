import 'package:flutter/material.dart';

class AnimationUtils {
  AnimationUtils._();

  static const Duration pageTransitionDuration = Duration(milliseconds: 280);
  static const Duration quickDuration = Duration(milliseconds: 160);
  static const Duration slowDuration = Duration(milliseconds: 420);

  static PageRouteBuilder<T> fadePageRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: pageTransitionDuration,
    );
  }

  static PageRouteBuilder<T> slideHorizontalPageRoute<T>({
    required Widget page,
    RouteSettings? settings,
    bool fromRight = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: fromRight ? const Offset(0.08, 0) : const Offset(-0.08, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(slide), child: child);
      },
      transitionDuration: pageTransitionDuration,
    );
  }
}

enum HoverCardTone {
  soft,
  standard,
  focus,
}

class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final HoverCardTone tone;
  final double hoverLift;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.tone = HoverCardTone.standard,
    this.hoverLift = 1.5,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = widget.borderRadius ?? BorderRadius.circular(24);
    final (surfaceAlpha, blendAmount, baseBorderAlpha, hoverBorderAlpha) =
        switch (widget.tone) {
      HoverCardTone.soft => (
          isDark ? 0.82 : 0.76,
          isDark ? 0.03 : 0.04,
          0.0,
          isDark ? 0.12 : 0.08
        ),
      HoverCardTone.standard => (
          isDark ? 0.9 : 0.86,
          isDark ? 0.05 : 0.06,
          isDark ? 0.06 : 0.03,
          isDark ? 0.18 : 0.09
        ),
      HoverCardTone.focus => (
          isDark ? 0.94 : 0.92,
          isDark ? 0.1 : 0.08,
          isDark ? 0.1 : 0.06,
          isDark ? 0.24 : 0.12
        ),
    };
    final blendedSurface = Color.lerp(
      theme.colorScheme.surface,
      theme.colorScheme.primary,
      blendAmount,
    )!;
    final baseColor = widget.backgroundColor ??
        blendedSurface.withValues(alpha: surfaceAlpha);
    final borderColor = _hovered
        ? theme.colorScheme.onSurface.withValues(alpha: hoverBorderAlpha)
        : theme.dividerColor.withValues(alpha: baseBorderAlpha);
    final shadowColor = theme.colorScheme.shadow.withValues(
      alpha: isDark ? (_hovered ? 0.22 : 0.12) : (_hovered ? 0.08 : 0.028),
    );
    final accentShadow = theme.colorScheme.primary.withValues(
      alpha: isDark ? (_hovered ? 0.07 : 0.0) : (_hovered ? 0.04 : 0.0),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AnimationUtils.quickDuration,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _hovered ? -widget.hoverLift : 0,
            0,
          ),
          transformAlignment: Alignment.center,
          padding: widget.padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: _hovered ? 0.9 : 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: _hovered ? 24 : 12,
                offset: Offset(0, _hovered ? 12 : 5),
              ),
              if (_hovered)
                BoxShadow(
                  color: accentShadow,
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const FadeInWidget({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 0.02),
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value.dy * 60),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class StaggeredFadeIn extends StatelessWidget {
  final Widget child;
  final int index;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInWidget(
      delay: Duration(milliseconds: 55 * index),
      child: child,
    );
  }
}
