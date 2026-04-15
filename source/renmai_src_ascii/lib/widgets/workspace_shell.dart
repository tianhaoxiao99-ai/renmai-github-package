import 'package:flutter/material.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/utils/animation_utils.dart';

class WorkspacePage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  const WorkspacePage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(28, 28, 28, 24),
    this.maxWidth = 1280,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? AppTheme.darkPageGradient
                      : AppTheme.lightPageGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface.withValues(
                        alpha: isDark ? 0.08 : 0.38,
                      ),
                      Colors.transparent,
                      theme.colorScheme.surface.withValues(
                        alpha: isDark ? 0.03 : 0.12,
                      ),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WorkspaceDustPainter(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.06 : 0.05,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInWidget(
                        child: _WorkspaceHeader(
                          eyebrow: eyebrow,
                          title: title,
                          subtitle: subtitle,
                          actions: actions,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum WorkspaceSurfaceTone {
  soft,
  emphasis,
}

class WorkspaceSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final WorkspaceSurfaceTone tone;
  final Color? tint;

  const WorkspaceSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.tone = WorkspaceSurfaceTone.soft,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = tint ?? theme.colorScheme.primary;
    final secondaryTint = Color.lerp(accent, AppTheme.sun, 0.45)!;
    final surface = theme.colorScheme.surface;

    final colors = switch (tone) {
      WorkspaceSurfaceTone.soft => [
          Color.lerp(surface, accent, isDark ? 0.05 : 0.07)!
              .withValues(alpha: isDark ? 0.92 : 0.95),
          Color.lerp(surface, Colors.white, isDark ? 0.01 : 0.08)!
              .withValues(alpha: isDark ? 0.84 : 0.92),
        ],
      WorkspaceSurfaceTone.emphasis => [
          Color.lerp(surface, accent, isDark ? 0.08 : 0.09)!
              .withValues(alpha: isDark ? 0.97 : 0.985),
          Color.lerp(surface, secondaryTint, isDark ? 0.055 : 0.11)!
              .withValues(alpha: isDark ? 0.92 : 0.96),
        ],
    };
    final borderColor = switch (tone) {
      WorkspaceSurfaceTone.soft => theme.dividerColor.withValues(
          alpha: isDark ? 0.42 : 0.28,
        ),
      WorkspaceSurfaceTone.emphasis => Color.lerp(
          theme.dividerColor,
          accent,
          isDark ? 0.16 : 0.12,
        )!
            .withValues(alpha: isDark ? 0.52 : 0.4),
    };
    final shadowColor = theme.colorScheme.shadow.withValues(
      alpha: switch (tone) {
        WorkspaceSurfaceTone.soft => isDark ? 0.12 : 0.04,
        WorkspaceSurfaceTone.emphasis => isDark ? 0.16 : 0.065,
      },
    );
    final accentGlow = accent.withValues(
      alpha: switch (tone) {
        WorkspaceSurfaceTone.soft => isDark ? 0.03 : 0.02,
        WorkspaceSurfaceTone.emphasis => isDark ? 0.055 : 0.035,
      },
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: tone == WorkspaceSurfaceTone.emphasis ? 30 : 18,
              offset: Offset(
                0,
                tone == WorkspaceSurfaceTone.emphasis ? 12 : 7,
              ),
            ),
            BoxShadow(
              color: accentGlow,
              blurRadius: tone == WorkspaceSurfaceTone.emphasis ? 26 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDark ? 0.1 : 0.42),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (tone == WorkspaceSurfaceTone.emphasis)
              Positioned(
                left: 0,
                top: 18,
                bottom: 18,
                child: IgnorePointer(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(999),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.38 : 0.34),
                          secondaryTint.withValues(
                            alpha: isDark ? 0.26 : 0.22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class WorkspaceSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const WorkspaceSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: subtitle == null ? 28 : 42,
          margin: const EdgeInsets.only(top: 2, right: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.primary,
                Color.lerp(theme.colorScheme.primary, AppTheme.sun, 0.5)!,
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class WorkspaceStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const WorkspaceStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverCard(
      tone: HoverCardTone.soft,
      hoverLift: 1.2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: BorderRadius.circular(22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 17,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.titleLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkspaceHint extends StatelessWidget {
  final Widget child;
  final IconData icon;
  final Color? tint;

  const WorkspaceHint({
    super.key,
    required this.child,
    this.icon = Icons.info_outline_rounded,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tint ?? theme.colorScheme.primary;
    return WorkspaceSurface(
      tone: tint == null
          ? WorkspaceSurfaceTone.soft
          : WorkspaceSurfaceTone.emphasis,
      tint: color,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: tint == null ? theme.colorScheme.primary : color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceTag extends StatelessWidget {
  final String label;

  const WorkspaceTag(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.98),
            theme.colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.56),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeaderBadge extends StatelessWidget {
  final String label;

  const _WorkspaceHeaderBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.92),
            theme.colorScheme.primary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _WorkspaceHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHeaderBadge(label: eyebrow.toUpperCase()),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 860;
            final headerText = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.84),
                      height: 1.46,
                    ),
                  ),
                ),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerText,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _WorkspaceHeaderActionTray(actions: actions),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: headerText),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: _WorkspaceHeaderActionTray(actions: actions),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WorkspaceHeaderActionTray extends StatelessWidget {
  final List<Widget> actions;

  const _WorkspaceHeaderActionTray({
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface.withValues(alpha: 0.76),
              theme.colorScheme.primary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.36),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              right: 18,
              top: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDustPainter extends CustomPainter {
  final Color color;

  const _WorkspaceDustPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (var x = 24.0; x < size.width; x += 86) {
      for (var y = 30.0; y < size.height; y += 74) {
        final radius = ((x + y) % 3 == 0) ? 1.15 : 0.8;
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }

    final linePaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.06,
        size.width * 0.86,
        size.height * 0.24,
      )
      ..moveTo(size.width * 0.18, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.7,
        size.width * 0.92,
        size.height * 0.88,
      );

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WorkspaceDustPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
