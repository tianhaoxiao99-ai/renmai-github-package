import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/screens/home/widgets/desktop_web_handoff_section.dart';
import 'package:renmai/screens/home/widgets/home_overview_sections.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class DashboardWorkbench extends StatelessWidget {
  final ValueChanged<HomeSection> onOpenSection;

  const DashboardWorkbench({
    super.key,
    required this.onOpenSection,
  });

  static const List<HomeWorkflowStepData> _workflowSteps = [
    HomeWorkflowStepData(
      index: '01',
      title: '导入首批记录',
      description: '先把最近一批聊天记录导进来，让桌面端拿到真实关系节奏和联系人上下文。',
    ),
    HomeWorkflowStepData(
      index: '02',
      title: '判断优先级',
      description: '系统会拉出最值得先处理的关系、掉线风险和可执行建议，不用你自己翻列表。',
    ),
    HomeWorkflowStepData(
      index: '03',
      title: '执行下一步',
      description: '带着报告、联系人页和行动建议去推进，而不是继续在首页堆更多信息。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<AnalysisProvider, RelationshipProvider>(
      builder: (context, analysis, relation, _) {
        final latestPackage = analysis.importedPackages.isNotEmpty
            ? analysis.importedPackages.last
            : null;
        final report = analysis.currentReport;
        final prioritizedInsights =
            _resolvePrioritizedInsights(report, relation);
        final topInsight = prioritizedInsights.isNotEmpty
            ? prioritizedInsights.first
            : (relation.relationships.isNotEmpty
                ? relation.relationships.first
                : null);
        final actionSuggestions = report?.actionSuggestions
                .where((item) => item.trim().isNotEmpty)
                .take(4)
                .toList() ??
            const <String>[];

        final statusItems = [
          HomeSnapshotData(
            icon: Icons.inbox_rounded,
            title: '最近导入',
            value: latestPackage != null
                ? '${latestPackage.contactCount} 位联系人 / ${latestPackage.messageCount} 条消息'
                : '还没有导入数据',
            detail: latestPackage != null
                ? _shortSummary(latestPackage.packageSummary, '本次导入已经完成')
                : '先完成第一次导入，系统就会开始整理你的关系工作区。',
          ),
          HomeSnapshotData(
            icon: Icons.analytics_rounded,
            title: '当前报告',
            value: report != null ? '已生成关系摘要' : '等待生成',
            detail: report != null
                ? _shortSummary(report.overallSummary, '报告已经准备好')
                : '先用本地报告看清节奏，想看得更细时再主动启用 AI 增强。',
          ),
          HomeSnapshotData(
            icon: Icons.flag_rounded,
            title: '今天先看',
            value: topInsight != null ? topInsight.contactName : '等待识别重点对象',
            detail: topInsight != null
                ? _focusBody(topInsight)
                : '导入之后，首页只保留一位值得先联系的对象，避免信息再次堆满。',
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 36, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 1020;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLeadSection(compact, statusItems),
                      const SizedBox(height: 22),
                      _buildDecisionSection(
                        context: context,
                        compact: compact,
                        analysis: analysis,
                        report: report,
                        topInsight: topInsight,
                        actionSuggestions: actionSuggestions,
                      ),
                      const SizedBox(height: 22),
                      _buildLowerSection(
                        compact: compact,
                        analysis: analysis,
                        topInsight: topInsight,
                        prioritizedInsights: prioritizedInsights,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadSection(bool compact, List<HomeSnapshotData> statusItems) {
    final hero = HomeHeroSection(
      badge: '仁迈桌面工作区',
      title: '先判断今天该先处理哪段关系。',
      subtitle: '桌面端负责把本地聊天记录和关系结果整理成一个清晰工作区，不再像一堆松散卡片。',
      supportText: '默认先用本地整理；需要更细的判断时，再主动启用 AI 增强。',
      actions: [
        FilledButton.icon(
          onPressed: () => onOpenSection(HomeSection.importData),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('立即导入'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpenSection(HomeSection.contacts),
          icon: const Icon(Icons.people_rounded),
          label: const Text('先看联系人'),
        ),
        OutlinedButton.icon(
          onPressed: () => onOpenSection(HomeSection.report),
          icon: const Icon(Icons.analytics_rounded),
          label: const Text('查看报告'),
        ),
      ],
    );

    final panel = HomeStatusPanel(
      eyebrow: '当前摘要',
      title: '先看判断，再决定今天先做什么。',
      subtitle: '只保留会影响当前决策的三条核心信息，不再让大块表面层抢走注意力。',
      items: statusItems,
    );

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      borderRadius: BorderRadius.circular(34),
      padding: const EdgeInsets.all(26),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hero,
                const SizedBox(height: 20),
                panel,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: hero),
                const SizedBox(width: 22),
                Expanded(flex: 5, child: panel),
              ],
            ),
    );
  }

  Widget _buildDecisionSection({
    required BuildContext context,
    required bool compact,
    required AnalysisProvider analysis,
    required ComparisonReport? report,
    required ContactInsight? topInsight,
    required List<String> actionSuggestions,
  }) {
    final theme = Theme.of(context);
    final averageScore = _averageScore(report);
    final insightCount = report?.contactInsights.length ?? 0;
    final riskCount = report?.contactInsights
            .where((item) => item.riskPoints.isNotEmpty)
            .length ??
        0;
    final suggestionCount = report?.actionSuggestions.length ?? 0;
    final giftCount = report?.giftRecommendations.length ?? 0;
    final currentActionTitle = topInsight != null
        ? '今天先把 ${topInsight.contactName} 这段关系判断清楚'
        : insightCount > 0
            ? '先把最近导入结果读成一份可执行判断'
            : '先完成第一批导入，再让桌面端开始整理';
    final currentActionBody = topInsight != null
        ? _focusBody(topInsight)
        : insightCount > 0
            ? '桌面端已经把聊天内容整理进工作区，下一步先看联系人排序和风险提示，再决定要不要继续补导入。'
            : '没有导入内容时，不要急着点联系人和报告。先完成一次导入，桌面端才会真的开始判断。';
    final primaryAction = topInsight != null
        ? () {
            analysis.selectContact(topInsight.contactId);
            onOpenSection(HomeSection.contacts);
          }
        : () => onOpenSection(HomeSection.importData);
    final primaryLabel = topInsight != null ? '打开重点联系人' : '先去导入';

    final metrics = [
      _DesktopMomentumMetric(
        label: '已整理联系人',
        value: '$insightCount',
        helper: insightCount > 0 ? '已经进入关系判断' : '等待第一批导入',
        progress: insightCount == 0 ? 0.12 : (insightCount / 8).clamp(0.18, 1),
      ),
      _DesktopMomentumMetric(
        label: '需要补节奏',
        value: '$riskCount',
        helper: riskCount > 0 ? '优先处理高风险关系' : '当前没有明显掉线提醒',
        progress: insightCount == 0
            ? 0.0
            : (riskCount / insightCount).clamp(0.0, 1.0),
      ),
      _DesktopMomentumMetric(
        label: '可执行建议',
        value: '${suggestionCount + giftCount}',
        helper: giftCount > 0 ? '已经带出礼物和行动线索' : '先看本地建议，再决定要不要开 AI',
        progress: insightCount == 0
            ? 0.0
            : ((suggestionCount + giftCount) / (insightCount * 2))
                .clamp(0.0, 1.0),
      ),
    ];

    final radar = WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      borderRadius: BorderRadius.circular(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: '桌面经营雷达',
            subtitle: '先看覆盖、风险和可执行建议，再决定今天先补导入、看联系人还是读报告。',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      _DesktopMomentumCard(data: metrics[i]),
                      if (i != metrics.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    Expanded(child: _DesktopMomentumCard(data: metrics[i])),
                    if (i != metrics.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );

    final currentAction = WorkspaceSurface(
      borderRadius: BorderRadius.circular(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSectionHeader(
            title: '当前建议动作',
            subtitle: '只保留对今天最有帮助的一步，不把桌面端重新做成信息墙。',
          ),
          const SizedBox(height: 18),
          Text(
            currentActionTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            currentActionBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.65,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (averageScore > 0)
                WorkspaceTag('平均关系分 ${averageScore.toStringAsFixed(1)}'),
              if (report?.usedAi == true)
                const WorkspaceTag('当前报告已启用 AI 增强')
              else
                const WorkspaceTag('当前优先使用本地规则'),
              if ((report?.giftRecommendations.length ?? 0) > 0)
                WorkspaceTag('礼物线索 ${report!.giftRecommendations.length} 条'),
            ],
          ),
          if (actionSuggestions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              '今天能直接执行的动作',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < actionSuggestions.length; i++) ...[
              _ActionSuggestionLine(
                index: i + 1,
                text: actionSuggestions[i],
              ),
              if (i != actionSuggestions.length - 1) const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: primaryAction,
                icon: Icon(topInsight != null
                    ? Icons.flag_rounded
                    : Icons.upload_file_rounded),
                label: Text(primaryLabel),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenSection(HomeSection.report),
                icon: const Icon(Icons.analytics_rounded),
                label: const Text('查看报告'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenSection(HomeSection.suggestions),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('看行动建议'),
              ),
              OutlinedButton.icon(
                onPressed: () => onOpenSection(HomeSection.importData),
                icon: const Icon(Icons.folder_zip_rounded),
                label: const Text('继续导入'),
              ),
            ],
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        children: [
          radar,
          const SizedBox(height: 18),
          currentAction,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: radar),
        const SizedBox(width: 20),
        Expanded(flex: 5, child: currentAction),
      ],
    );
  }

  Widget _buildLowerSection({
    required bool compact,
    required AnalysisProvider analysis,
    required ContactInsight? topInsight,
    required List<ContactInsight> prioritizedInsights,
  }) {
    const workflow = HomeWorkflowSection(steps: _workflowSteps);
    final queue = _buildPriorityQueueSection(
      analysis: analysis,
      topInsight: topInsight,
      prioritizedInsights: prioritizedInsights,
    );
    final handoff = DesktopWebHandoffSection(
      onOpenImport: () => onOpenSection(HomeSection.importData),
      onOpenReport: () => onOpenSection(HomeSection.report),
    );

    if (compact) {
      return Column(
        children: [
          workflow,
          const SizedBox(height: 18),
          queue,
          const SizedBox(height: 18),
          handoff,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              workflow,
              const SizedBox(height: 18),
              queue,
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: handoff,
        ),
      ],
    );
  }

  Widget _buildPriorityQueueSection({
    required AnalysisProvider analysis,
    required ContactInsight? topInsight,
    required List<ContactInsight> prioritizedInsights,
  }) {
    if (prioritizedInsights.isEmpty) {
      return HomeFocusSection(
        title: '今日优先队列',
        subtitle: '桌面端还没形成明确排序时，先完成导入，再回来判断谁该优先处理。',
        focusTitle: topInsight != null ? topInsight.contactName : '还没有重点联系人',
        focusBody: topInsight != null
            ? _focusBody(topInsight)
            : '先导入记录，再让系统把联系人、风险点和下一步动作整理成一条可执行的优先队列。',
        evidence: topInsight?.evidenceQuotes
                .where((item) => item.trim().isNotEmpty)
                .take(2)
                .toList() ??
            const <String>[],
        onTap: topInsight != null
            ? () => onOpenSection(HomeSection.contacts)
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkspaceSectionHeader(
          title: '今日优先队列',
          subtitle: '先把最值得处理的 3 段关系拉出来，避免桌面端一打开又是满屏信息。',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 860;
            if (stacked) {
              return Column(
                children: [
                  for (var i = 0; i < prioritizedInsights.length; i++) ...[
                    _PriorityInsightCard(
                      rank: i + 1,
                      insight: prioritizedInsights[i],
                      onOpenContact: () {
                        analysis
                            .selectContact(prioritizedInsights[i].contactId);
                        onOpenSection(HomeSection.contacts);
                      },
                      onOpenReport: () => onOpenSection(HomeSection.report),
                      onOpenSuggestions: () =>
                          onOpenSection(HomeSection.suggestions),
                    ),
                    if (i != prioritizedInsights.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < prioritizedInsights.length; i++) ...[
                  Expanded(
                    child: _PriorityInsightCard(
                      rank: i + 1,
                      insight: prioritizedInsights[i],
                      onOpenContact: () {
                        analysis
                            .selectContact(prioritizedInsights[i].contactId);
                        onOpenSection(HomeSection.contacts);
                      },
                      onOpenReport: () => onOpenSection(HomeSection.report),
                      onOpenSuggestions: () =>
                          onOpenSection(HomeSection.suggestions),
                    ),
                  ),
                  if (i != prioritizedInsights.length - 1)
                    const SizedBox(width: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _shortSummary(String text, String fallback) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (trimmed.length <= 58) {
      return trimmed;
    }
    return '${trimmed.substring(0, 58)}...';
  }

  String _focusBody(ContactInsight insight) {
    final level = insight.relationshipLevel.trim();
    if (level.isEmpty) {
      return '当前建议先关注这位联系人，补上联系节奏和下一步动作。';
    }
    return '当前判断为$level，优先把节奏拉回稳定，再考虑更深的推进动作。';
  }

  double _averageScore(ComparisonReport? report) {
    if (report == null || report.contactInsights.isEmpty) {
      return 0;
    }
    final total = report.contactInsights.fold<double>(
      0,
      (sum, item) => sum + item.intimacyScore,
    );
    return total / report.contactInsights.length;
  }

  List<ContactInsight> _resolvePrioritizedInsights(
    ComparisonReport? report,
    RelationshipProvider relation,
  ) {
    if (report == null) {
      return relation.relationships.take(3).toList();
    }

    final insightsById = {
      for (final insight in report.contactInsights) insight.contactId: insight,
    };
    final prioritized = <ContactInsight>[];
    for (final rank in report.relationshipRanking) {
      final insight = insightsById[rank.contactId];
      if (insight != null) {
        prioritized.add(insight);
      }
      if (prioritized.length == 3) {
        break;
      }
    }

    if (prioritized.isNotEmpty) {
      return prioritized;
    }
    return report.contactInsights.take(3).toList();
  }
}

class _DesktopMomentumMetric {
  final String label;
  final String value;
  final String helper;
  final double progress;

  const _DesktopMomentumMetric({
    required this.label,
    required this.value,
    required this.helper,
    required this.progress,
  });
}

class _DesktopMomentumCard extends StatelessWidget {
  final _DesktopMomentumMetric data;

  const _DesktopMomentumCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WorkspaceSurface(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.72),
                  AppTheme.sun.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityInsightCard extends StatelessWidget {
  final int rank;
  final ContactInsight insight;
  final VoidCallback onOpenContact;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSuggestions;

  const _PriorityInsightCard({
    required this.rank,
    required this.insight,
    required this.onOpenContact,
    required this.onOpenReport,
    required this.onOpenSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryLine = insight.riskPoints.isNotEmpty
        ? insight.riskPoints.first
        : (insight.suggestions.isNotEmpty
            ? insight.suggestions.first
            : '建议先打开联系人页查看这段关系的具体判断。');

    return WorkspaceSurface(
      tone:
          rank == 1 ? WorkspaceSurfaceTone.emphasis : WorkspaceSurfaceTone.soft,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.72),
                  AppTheme.sun.withValues(alpha: 0.42),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$rank',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.contactName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.relationshipLevel.isNotEmpty
                          ? insight.relationshipLevel
                          : '等待补充关系标签',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${insight.intimacyScore.toStringAsFixed(0)} 分',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            primaryLine,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            _buildInsightMeta(insight),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (insight.referenceTier.isNotEmpty)
                WorkspaceTag(insight.referenceTier),
              if (insight.relationDetail.isNotEmpty)
                WorkspaceTag(insight.relationDetail),
              if (insight.activityLevel.isNotEmpty)
                WorkspaceTag(insight.activityLevel),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenContact,
                icon: const Icon(Icons.people_rounded),
                label: const Text('看联系人页'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.analytics_rounded),
                label: const Text('去报告页'),
              ),
              if (insight.suggestions.isNotEmpty ||
                  insight.giftSuggestion != null)
                OutlinedButton.icon(
                  onPressed: onOpenSuggestions,
                  icon: Icon(
                    insight.giftSuggestion != null
                        ? Icons.card_giftcard_rounded
                        : Icons.auto_awesome_rounded,
                  ),
                  label: Text(
                    insight.giftSuggestion != null ? '看礼物建议' : '看行动建议',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildInsightMeta(ContactInsight insight) {
    final parts = <String>[
      '${insight.totalMessages} 条消息',
      '${insight.activeDays} 天互动',
    ];
    if (insight.lastInteractionAt != null) {
      final last = insight.lastInteractionAt!;
      final month = last.month.toString().padLeft(2, '0');
      final day = last.day.toString().padLeft(2, '0');
      parts.add('最近互动 $month-$day');
    }
    return parts.join(' · ');
  }
}

class _ActionSuggestionLine extends StatelessWidget {
  final int index;
  final String text;

  const _ActionSuggestionLine({
    required this.index,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.64),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
