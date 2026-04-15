// ignore_for_file: prefer_const_constructors

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class PlatformFeedbackScreen extends StatefulWidget {
  final VoidCallback? onGoImport;
  const PlatformFeedbackScreen({super.key, this.onGoImport});

  @override
  State<PlatformFeedbackScreen> createState() => _PlatformFeedbackScreenState();
}

class _PlatformFeedbackScreenState extends State<PlatformFeedbackScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreController;
  final Set<String> _completedActions = {};

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        final report = provider.currentReport;
        final hasData = provider.hasData;
        final isAnalyzing = provider.isAnalyzing;

        return WorkspacePage(
          eyebrow: '平台反馈',
          title: '你的关系经营报告',
          subtitle: '基于导入的聊天记录，平台为你整理了最值得行动的人、最合适的送礼方向，以及下一步建议。',
          actions: [
            if (hasData && !isAnalyzing)
              FilledButton.icon(
                onPressed:
                    provider.aiConfig.isReady && provider.aiConfig.enabled
                        ? () => provider.runAiAnalysis()
                        : () => _showAiSetupTip(context),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  provider.aiConfig.enabled ? '重新生成 AI 反馈' : '配置 AI 后生成',
                ),
              ),
            if (isAnalyzing) const _LoadingChip(label: 'AI 正在整理你的关系报告...'),
          ],
          child: !hasData
              ? _PolishedEmptyFeedbackState(
                  onGoImport: widget.onGoImport ?? () {},
                )
              : _FeedbackBody(
                  report: report,
                  provider: provider,
                  scoreController: _scoreController,
                  completedActions: _completedActions,
                  onToggleAction: (id) {
                    setState(() {
                      if (_completedActions.contains(id)) {
                        _completedActions.remove(id);
                      } else {
                        _completedActions.add(id);
                      }
                    });
                  },
                ),
        );
      },
    );
  }

  void _showAiSetupTip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('请先在"设置"页面配置并启用 AI，再点击生成 AI 反馈。'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── 主反馈内容 ────────────────────────────────────────────────────────
class _FeedbackBody extends StatelessWidget {
  final ComparisonReport? report;
  final AnalysisProvider provider;
  final AnimationController scoreController;
  final Set<String> completedActions;
  final ValueChanged<String> onToggleAction;

  const _FeedbackBody({
    required this.report,
    required this.provider,
    required this.scoreController,
    required this.completedActions,
    required this.onToggleAction,
  });

  @override
  Widget build(BuildContext context) {
    final insights = provider.contactInsights;
    final actionSuggestions = provider.actionSuggestions;
    final giftRecs = provider.giftRecommendations;
    final sortedInsights = [...insights]
      ..sort((a, b) => b.intimacyScore.compareTo(a.intimacyScore));
    final focusInsight = sortedInsights.isEmpty ? null : sortedInsights.first;
    final riskCount =
        insights.where((item) => item.riskPoints.isNotEmpty).length;
    final topAction = actionSuggestions
        .map((item) => item.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    final topGift = giftRecs.isEmpty ? null : giftRecs.first;
    final avgScore = insights.isEmpty
        ? 0.0
        : insights.map((e) => e.intimacyScore).reduce((a, b) => a + b) /
            insights.length;
    final healthScore = (avgScore / 100).clamp(0.0, 1.0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInWidget(
            delay: const Duration(milliseconds: 20),
            child: _FeedbackBrief(
              focusInsight: focusInsight,
              actionCount: actionSuggestions.length,
              giftCount: giftRecs.length,
              riskCount: riskCount,
              completedActions: completedActions.length,
              topAction: topAction.isEmpty ? null : topAction,
              topGift: topGift,
              onOpenFocus: focusInsight == null
                  ? null
                  : () {
                      provider.selectContact(focusInsight.contactId);
                      Navigator.of(context).pushNamed(
                        AppRoutes.contactDetail,
                        arguments: focusInsight.contactId,
                      );
                    },
            ),
          ),
          const SizedBox(height: 20),
          FadeInWidget(
            delay: const Duration(milliseconds: 40),
            child: _HealthDashboard(
              score: healthScore,
              controller: scoreController,
              report: report,
              contactCount: insights.length,
              usedAi: report?.usedAi ?? false,
            ),
          ),
          const SizedBox(height: 20),
          if ((report?.overallSummary ?? '').isNotEmpty)
            FadeInWidget(
              delay: const Duration(milliseconds: 80),
              child: _AiSummaryCard(
                summary: report!.overallSummary,
                usedAi: report!.usedAi,
              ),
            ),
          const SizedBox(height: 20),
          if (actionSuggestions.isNotEmpty || insights.isNotEmpty)
            FadeInWidget(
              delay: const Duration(milliseconds: 120),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackedWorkflow = constraints.maxWidth < 1180;
                  final timeline = actionSuggestions.isEmpty
                      ? null
                      : _ActionTimeline(
                          suggestions: actionSuggestions,
                          completed: completedActions,
                          onToggle: onToggleAction,
                        );
                  final prioritySection = insights.isEmpty
                      ? null
                      : _ContactPrioritySection(
                          insights: insights,
                          onOpenContact: (contactId) {
                            provider.selectContact(contactId);
                            Navigator.of(context).pushNamed(
                              AppRoutes.contactDetail,
                              arguments: contactId,
                            );
                          },
                        );

                  if (stackedWorkflow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (timeline != null) timeline,
                        if (timeline != null && prioritySection != null)
                          const SizedBox(height: 20),
                        if (prioritySection != null) prioritySection,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeline != null) Expanded(flex: 5, child: timeline),
                      if (timeline != null && prioritySection != null)
                        const SizedBox(width: 20),
                      if (prioritySection != null)
                        Expanded(flex: 5, child: prioritySection),
                    ],
                  );
                },
              ),
            ),
          if (actionSuggestions.isNotEmpty && insights.isNotEmpty)
            const SizedBox(height: 20),
          if (giftRecs.isNotEmpty)
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: _GiftRecommendationSection(
                gifts: giftRecs,
                onOpenContact: (contactId) {
                  provider.selectContact(contactId);
                  Navigator.of(context).pushNamed(
                    AppRoutes.contactDetail,
                    arguments: contactId,
                  );
                },
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeedbackBrief extends StatelessWidget {
  final ContactInsight? focusInsight;
  final int actionCount;
  final int giftCount;
  final int riskCount;
  final int completedActions;
  final String? topAction;
  final GiftRecommendation? topGift;
  final VoidCallback? onOpenFocus;

  const _FeedbackBrief({
    required this.focusInsight,
    required this.actionCount,
    required this.giftCount,
    required this.riskCount,
    required this.completedActions,
    required this.topAction,
    required this.topGift,
    required this.onOpenFocus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.all(26),
      borderRadius: BorderRadius.circular(30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final leadColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceTag(
                    focusInsight == null
                        ? '等待识别重点对象'
                        : '当前第一优先 · ${focusInsight!.contactName}',
                  ),
                  WorkspaceTag(
                    riskCount > 0 ? '优先处理风险' : '当前以推进为主',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _BriefMetric(
                    label: '待执行动作',
                    value: '$actionCount',
                    icon: Icons.checklist_rounded,
                    tint: AppTheme.primary,
                  ),
                  _BriefMetric(
                    label: '已完成动作',
                    value: '$completedActions',
                    icon: Icons.task_alt_rounded,
                    tint: const Color(0xFF2EC984),
                  ),
                  _BriefMetric(
                    label: '送礼线索',
                    value: '$giftCount',
                    icon: Icons.card_giftcard_rounded,
                    tint: const Color(0xFFE59437),
                  ),
                  _BriefMetric(
                    label: '风险联系人',
                    value: '$riskCount',
                    icon: Icons.warning_amber_rounded,
                    tint: const Color(0xFFE85555),
                  ),
                ],
              ),
              if (focusInsight != null) ...[
                const SizedBox(height: 16),
                WorkspaceHint(
                  icon: Icons.person_pin_circle_rounded,
                  tint: theme.colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前第一优先：${focusInsight!.contactName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppConstants.displayRelationshipLevel(focusInsight!.relationshipLevel)} · ${focusInsight!.activityLevel} · ${focusInsight!.intimacyScore.toStringAsFixed(1)} 分',
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                      if (focusInsight!.suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '建议动作：${focusInsight!.suggestions.first}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.72),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );

          final rightRail = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (focusInsight != null)
                _BriefCueCard(
                  title: '当前聚焦',
                  body:
                      '${focusInsight!.contactName} · ${AppConstants.displayRelationshipLevel(focusInsight!.relationshipLevel)}',
                  icon: Icons.person_pin_circle_rounded,
                  tint: AppTheme.primary,
                ),
              if (topAction != null) ...[
                const SizedBox(height: 12),
                _BriefCueCard(
                  title: '最先执行',
                  body: topAction!,
                  icon: Icons.bolt_rounded,
                  tint: AppTheme.primary,
                ),
              ],
              if (topGift != null) ...[
                const SizedBox(height: 12),
                _BriefCueCard(
                  title: '礼物切口',
                  body: '${topGift!.giftName} · 给 ${topGift!.contactName}',
                  icon: Icons.card_giftcard_rounded,
                  tint: const Color(0xFFE59437),
                ),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkspaceSectionHeader(
                title: '经营简报',
                subtitle: '先锁定最值得处理的人，再分配动作、礼物和风险处理顺序。',
                trailing: focusInsight == null
                    ? null
                    : FilledButton.icon(
                        onPressed: onOpenFocus,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('看重点联系人'),
                      ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 72,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.92),
                      AppTheme.accent.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              if (stacked)
                leadColumn
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: leadColumn),
                    const SizedBox(width: 18),
                    SizedBox(width: 300, child: rightRail),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BriefMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _BriefMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.14),
            tint.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefCueCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color tint;

  const _BriefCueCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: 0.12),
              tint.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tint.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthDashboard extends StatelessWidget {
  final double score;
  final AnimationController controller;
  final ComparisonReport? report;
  final int contactCount;
  final bool usedAi;

  const _HealthDashboard({
    required this.score,
    required this.controller,
    required this.report,
    required this.contactCount,
    required this.usedAi,
  });

  String get _scoreLabel {
    if (score >= 0.8) return '优秀';
    if (score >= 0.65) return '良好';
    if (score >= 0.5) return '一般';
    if (score >= 0.3) return '待加强';
    return '刚起步';
  }

  String? get _encourageText {
    if (score < 0.3) {
      return '继续导入更多聊天记录，仁迈会随着数据增多给出更准确的分析。';
    }
    return null;
  }

  Color _scoreColor(BuildContext context) {
    if (score >= 0.8) return const Color(0xFF2EC984);
    if (score >= 0.65) return AppTheme.primary;
    if (score >= 0.5) return const Color(0xFFE8A838);
    return const Color(0xFFE85555);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _scoreColor(context);

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final gauge = _AnimatedGauge(
            score: score,
            color: color,
            controller: controller,
            label: _scoreLabel,
          );
          final stats = _DashboardStats(
            contactCount: contactCount,
            score: score,
            usedAi: usedAi,
            theme: theme,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHeader(theme: theme),
                const SizedBox(height: 20),
                Center(child: gauge),
                if (_encourageText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFFE8A838).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: Color(0xFFE8A838)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _encourageText!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFB87A00),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                stats,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  gauge,
                  if (_encourageText != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 160,
                      child: Text(
                        _encourageText!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB87A00),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeader(theme: theme),
                    const SizedBox(height: 16),
                    stats,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final ThemeData theme;
  const _DashboardHeader({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '仁迈平台分析',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('关系经营整体概览', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '基于你导入的聊天记录，仁迈从互动频次、情感信号、双向程度等维度为你计算出整体关系健康度。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final int contactCount;
  final double score;
  final bool usedAi;
  final ThemeData theme;

  const _DashboardStats({
    required this.contactCount,
    required this.score,
    required this.usedAi,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatChip(
          icon: Icons.people_alt_outlined,
          label: '联系人',
          value: '$contactCount 位',
        ),
        _StatChip(
          icon: Icons.favorite_border_rounded,
          label: '健康度',
          value: '${(score * 100).toInt()} 分',
        ),
        _StatChip(
          icon:
              usedAi ? Icons.auto_awesome_rounded : Icons.rule_folder_outlined,
          label: '分析方式',
          value: usedAi ? 'AI 增强' : '本地规则',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.84),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.54)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 动画圆形进度仪表盘 ────────────────────────────────────────────────
class _AnimatedGauge extends StatelessWidget {
  final double score;
  final Color color;
  final AnimationController controller;
  final String label;

  const _AnimatedGauge({
    required this.score,
    required this.color,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final animated =
            CurvedAnimation(parent: controller, curve: Curves.easeOutCubic)
                .value;
        final displayScore = score * animated;
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _GaugePainter(
                  progress: displayScore,
                  color: color,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.18),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(displayScore * 100).toInt()}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    if (progress > 0) {
      final fgPaint = Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.6), color],
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle * progress,
          tileMode: TileMode.clamp,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ─── AI 总结卡 ─────────────────────────────────────────────────────────
class _AiSummaryCard extends StatelessWidget {
  final String summary;
  final bool usedAi;

  const _AiSummaryCard({required this.summary, required this.usedAi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              usedAi ? Icons.auto_awesome_rounded : Icons.analytics_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      usedAi ? '平台 AI 综合建议' : '平台本地分析摘要',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: usedAi
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : theme.colorScheme.secondary
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        usedAi ? 'AI 增强' : '规则分析',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: usedAi
                              ? AppTheme.primary
                              : theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.65,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 行动时间轴 ────────────────────────────────────────────────────────
class _ActionTimeline extends StatelessWidget {
  final List<String> suggestions;
  final Set<String> completed;
  final ValueChanged<String> onToggle;

  const _ActionTimeline({
    required this.suggestions,
    required this.completed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: '近期行动清单',
            subtitle: '点击可以标记为已完成，帮你追踪执行进度。',
            trailing: Text(
              '${completed.length}/${suggestions.length} 已完成',
              style: theme.textTheme.bodySmall?.copyWith(
                color: completed.length == suggestions.length
                    ? const Color(0xFF2EC984)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ...suggestions.asMap().entries.map((entry) {
            final index = entry.key;
            final suggestion = entry.value;
            final isLast = index == suggestions.length - 1;
            final isDone = completed.contains(suggestion);
            return _ActionTimelineItem(
              index: index + 1,
              text: suggestion,
              isDone: isDone,
              isLast: isLast,
              onToggle: () => onToggle(suggestion),
            );
          }),
        ],
      ),
    );
  }
}

class _ActionTimelineItem extends StatefulWidget {
  final int index;
  final String text;
  final bool isDone;
  final bool isLast;
  final VoidCallback onToggle;

  const _ActionTimelineItem({
    required this.index,
    required this.text,
    required this.isDone,
    required this.isLast,
    required this.onToggle,
  });

  @override
  State<_ActionTimelineItem> createState() => _ActionTimelineItemState();
}

class _ActionTimelineItemState extends State<_ActionTimelineItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widget.isDone
                            ? const Color(0xFF2EC984)
                            : _hovered
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : theme.colorScheme.surface
                                    .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: widget.isDone
                              ? const Color(0xFF2EC984)
                              : AppTheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.isDone
                            ? Icons.check_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: widget.isDone
                            ? Colors.white
                            : AppTheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    if (!widget.isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: theme.dividerColor.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.isLast ? 0 : 16,
                    top: 4,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: (theme.textTheme.bodyLarge ?? const TextStyle())
                        .copyWith(
                      color: widget.isDone
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.88),
                      decoration: widget.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                    child: Text(widget.text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactPrioritySection extends StatelessWidget {
  final List<ContactInsight> insights;
  final ValueChanged<String> onOpenContact;

  const _ContactPrioritySection({
    required this.insights,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...insights]
      ..sort((a, b) => b.intimacyScore.compareTo(a.intimacyScore));

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: '重点联系人排序',
            subtitle: '从这里挑出最该跟进的人，再进入详情页看证据、时间轴和具体原话。',
          ),
          const SizedBox(height: 18),
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final insight = entry.value;
            return _ContactPriorityRow(
              rank: rank,
              insight: insight,
              theme: theme,
              onOpen: () => onOpenContact(insight.contactId),
            );
          }),
        ],
      ),
    );
  }
}

class _ContactPriorityRow extends StatelessWidget {
  final int rank;
  final ContactInsight insight;
  final ThemeData theme;
  final VoidCallback onOpen;

  const _ContactPriorityRow({
    required this.rank,
    required this.insight,
    required this.theme,
    required this.onOpen,
  });

  Color get _levelColor {
    switch (insight.relationshipLevel) {
      case '重点经营':
        return const Color(0xFF2EC984);
      case '稳定升温':
        return AppTheme.primary;
      case '保持联系':
        return const Color(0xFFE8A838);
      default:
        return const Color(0xFF8D97A8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (insight.intimacyScore / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.84),
            _levelColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _levelColor.withValues(alpha: 0.14),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 700;
          final identityRow = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: rank == 1
                        ? AppTheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _levelColor.withValues(alpha: 0.7),
                      _levelColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: _isNumericOrSymbol(insight.contactName)
                      ? const Icon(Icons.person_rounded,
                          color: Colors.white, size: 20)
                      : Text(
                          insight.contactName.isNotEmpty
                              ? insight.contactName.substring(0, 1)
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight.contactName,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${insight.intimacyScore.toInt()}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: _levelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        WorkspaceTag(
                          AppConstants.displayRelationshipLevel(
                            insight.relationshipLevel,
                          ),
                        ),
                        WorkspaceTag(insight.activityLevel),
                        if (insight.relationDetail.isNotEmpty)
                          WorkspaceTag(insight.relationDetail),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final compactIdentity = identityRow;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) compactIdentity else identityRow,
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(_levelColor),
                ),
              ),
              const SizedBox(height: 8),
              if (insight.suggestions.isNotEmpty)
                Text(
                  insight.suggestions.first,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 12),
              if (stacked)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('查看详情'),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('查看详情'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static bool _isNumericOrSymbol(String name) {
    if (name.isEmpty) return false;
    final first = name.substring(0, 1);
    return RegExp(r'^[0-9+\-@#\$%&*!]').hasMatch(first);
  }
}

class _GiftRecommendationSection extends StatelessWidget {
  final List<GiftRecommendation> gifts;
  final ValueChanged<String> onOpenContact;

  const _GiftRecommendationSection({
    required this.gifts,
    required this.onOpenContact,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fullWidthCards = constraints.maxWidth < 720;
          final cardWidth = fullWidthCards
              ? constraints.maxWidth
              : constraints.maxWidth < 1040
                  ? 240.0
                  : 220.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkspaceSectionHeader(
                title: '送礼建议',
                subtitle: '根据关系阶段和聊天关键词生成，选择最合适的时机和方式。',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: gifts
                    .take(6)
                    .map(
                      (gift) => SizedBox(
                        width: cardWidth,
                        child: _GiftCard(
                          gift: gift,
                          onOpen: () => onOpenContact(gift.contactId),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GiftCard extends StatefulWidget {
  final GiftRecommendation gift;
  final VoidCallback onOpen;

  const _GiftCard({
    required this.gift,
    required this.onOpen,
  });

  @override
  State<_GiftCard> createState() => _GiftCardState();
}

class _GiftCardState extends State<_GiftCard> {
  bool _hovered = false;

  static IconData _iconForGift(String name) {
    final n = name.toLowerCase();
    if (n.contains('花') || n.contains('植物') || n.contains('绿植')) {
      return Icons.local_florist_outlined;
    }
    if (n.contains('茶') || n.contains('咖啡') || n.contains('酒')) {
      return Icons.local_cafe_outlined;
    }
    if (n.contains('耳机') ||
        n.contains('音箱') ||
        n.contains('音响') ||
        n.contains('电子') ||
        n.contains('手机') ||
        n.contains('数码')) {
      return Icons.headphones_outlined;
    }
    if (n.contains('按摩') ||
        n.contains('护肤') ||
        n.contains('美容') ||
        n.contains('spa') ||
        n.contains('健康')) {
      return Icons.self_improvement_outlined;
    }
    if (n.contains('书') ||
        n.contains('手账') ||
        n.contains('文具') ||
        n.contains('笔记')) {
      return Icons.book_outlined;
    }
    if (n.contains('香水') || n.contains('香薰') || n.contains('精油')) {
      return Icons.spa_outlined;
    }
    if (n.contains('零食') ||
        n.contains('美食') ||
        n.contains('糕点') ||
        n.contains('巧克力') ||
        n.contains('坚果')) {
      return Icons.cake_outlined;
    }
    if (n.contains('衣') ||
        n.contains('包') ||
        n.contains('丝巾') ||
        n.contains('围巾') ||
        n.contains('配饰')) {
      return Icons.checkroom_outlined;
    }
    if (n.contains('运动') ||
        n.contains('健身') ||
        n.contains('球') ||
        n.contains('瑜伽')) {
      return Icons.fitness_center_outlined;
    }
    if (n.contains('旅行') || n.contains('出行') || n.contains('行李')) {
      return Icons.luggage_outlined;
    }
    if (n.contains('游戏') || n.contains('玩具') || n.contains('手办')) {
      return Icons.sports_esports_outlined;
    }
    return Icons.card_giftcard_outlined;
  }

  IconData get _icon => _iconForGift(widget.gift.giftName);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hovered
                  ? [
                      AppTheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.surface.withValues(alpha: 0.84),
                    ]
                  : [
                      theme.colorScheme.surface.withValues(alpha: 0.82),
                      AppTheme.sun.withValues(alpha: 0.04),
                    ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.22)
                  : theme.dividerColor.withValues(alpha: 0.6),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              Text(widget.gift.giftName, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '给 ${widget.gift.contactName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.gift.budgetRange,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF2EC984),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.gift.occasion,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.gift.reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: widget.gift.confidence,
                        minHeight: 3,
                        backgroundColor:
                            theme.dividerColor.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(widget.gift.confidence * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('查看联系人'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolishedEmptyFeedbackState extends StatelessWidget {
  final VoidCallback onGoImport;

  const _PolishedEmptyFeedbackState({required this.onGoImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: WorkspaceSurface(
            tone: WorkspaceSurfaceTone.emphasis,
            padding: const EdgeInsets.all(28),
            borderRadius: BorderRadius.circular(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '先导入聊天记录，再生成经营建议。',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  '建议页会把最值得行动的人、可直接执行的动作、送礼线索和风险联系人整理成一页。现在空白，说明你的工作区还没形成第一版判断。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BriefMetric(
                      label: '行动清单',
                      value: '待生成',
                      icon: Icons.checklist_rounded,
                      tint: AppTheme.primary,
                    ),
                    const _BriefMetric(
                      label: '送礼线索',
                      value: '待生成',
                      icon: Icons.card_giftcard_rounded,
                      tint: Color(0xFFE59437),
                    ),
                    _BriefMetric(
                      label: '风险提醒',
                      value: '待生成',
                      icon: Icons.warning_amber_rounded,
                      tint: Color(0xFFE85555),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BriefCueCard(
                      title: '第一步',
                      body: '先导入最近互动最多、你最在意的一位联系人。',
                      icon: Icons.looks_one_rounded,
                      tint: AppTheme.primary,
                    ),
                    _BriefCueCard(
                      title: '第二步',
                      body: '先看本地报告，再决定要不要启用 AI 增强。',
                      icon: Icons.looks_two_rounded,
                      tint: Color(0xFFE59437),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onGoImport,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('去导入聊天记录'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _EmptyFeedbackState extends StatelessWidget {
  final VoidCallback onGoImport;
  const _EmptyFeedbackState({required this.onGoImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有可分析的聊天记录',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '先去"导入"页面上传聊天记录，平台就会为你生成关系经营报告、送礼建议和行动清单。',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onGoImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('去导入聊天记录'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 加载中 Chip ───────────────────────────────────────────────────────
class _LoadingChip extends StatelessWidget {
  final String label;
  const _LoadingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
