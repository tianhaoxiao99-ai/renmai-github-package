import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _controller.forward();
    final analysis = context.read<AnalysisProvider>();
    await analysis.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _stageIndex(double value) {
    if (value < 0.34) return 0;
    if (value < 0.68) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isDark ? AppTheme.darkPageGradient : AppTheme.lightPageGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SplashBackdropPainter(
                  gridColor: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.06 : 0.045,
                  ),
                  tint: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.07 : 0.05,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: WorkspaceSurface(
                            tone: WorkspaceSurfaceTone.emphasis,
                            tint: theme.colorScheme.primary,
                            padding: const EdgeInsets.all(28),
                            borderRadius: BorderRadius.circular(32),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final value = _controller.value;
                                final stage = _stageIndex(value);
                                final progressText = switch (stage) {
                                  0 => '读取本地数据',
                                  1 => '校准视觉主题',
                                  _ => '进入工作台',
                                };

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 74,
                                          height: 74,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary,
                                                AppTheme.sun,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.primary
                                                    .withValues(
                                                  alpha: isDark ? 0.18 : 0.12,
                                                ),
                                                blurRadius: 26,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.hub_rounded,
                                            size: 34,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Wrap(
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: [
                                                  WorkspaceTag('本地优先'),
                                                  WorkspaceTag(
                                                    'V${AppConstants.appVersion}',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                '仁迈桌面工作台',
                                                style: theme
                                                    .textTheme.displaySmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.05,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                '正在整理本地关系数据、校准主题和准备分析面板。',
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.68),
                                                  height: 1.55,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 26),
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: theme.dividerColor
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  progressText,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                                style:
                                                    theme.textTheme.labelLarge,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: value,
                                              minHeight: 8,
                                              backgroundColor: theme
                                                  .colorScheme.onSurface
                                                  .withValues(alpha: 0.08),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: List.generate(3, (index) {
                                              final active = index <= stage;
                                              const labels = [
                                                '读取数据',
                                                '整理界面',
                                                '进入主页',
                                              ];
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 9,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: active
                                                      ? theme
                                                          .colorScheme.primary
                                                          .withValues(
                                                              alpha: 0.12)
                                                      : theme
                                                          .colorScheme.surface
                                                          .withValues(
                                                              alpha: 0.78),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: active
                                                        ? theme
                                                            .colorScheme.primary
                                                            .withValues(
                                                                alpha: 0.24)
                                                        : theme.dividerColor
                                                            .withValues(
                                                                alpha: 0.45),
                                                  ),
                                                ),
                                                child: Text(
                                                  labels[index],
                                                  style: theme
                                                      .textTheme.labelMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: active
                                                        ? theme
                                                            .colorScheme.primary
                                                        : theme.colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.62),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  final Color gridColor;
  final Color tint;

  const _SplashBackdropPainter({
    required this.gridColor,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final tintPaint = Paint()..color = tint;

    for (double y = 64; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (double x = 72; x < size.width; x += 120) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final topBand = Path()
      ..moveTo(size.width * 0.48, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.80, size.height * 0.34)
      ..close();
    canvas.drawPath(topBand, tintPaint);

    final lowerBand = Path()
      ..moveTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.32, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lowerBand, tintPaint);
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor || oldDelegate.tint != tint;
  }
}
