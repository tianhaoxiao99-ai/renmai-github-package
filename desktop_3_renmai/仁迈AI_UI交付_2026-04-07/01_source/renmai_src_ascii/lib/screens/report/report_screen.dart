import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        final report = provider.currentReport;
        final canRunAi = provider.hasData &&
            !provider.isAnalyzing &&
            provider.aiConfig.enabled;

        return WorkspacePage(
          eyebrow: '关系报告',
          title: '先判断重点对象，再决定今天怎么推进',
          subtitle: '把该先处理谁、风险在哪里、动作和礼物线索是否够用，一次整理成可执行判断。',
          actions: [
            OutlinedButton.icon(
              onPressed: provider.hasData && !provider.isAnalyzing
                  ? () => provider.rebuildLocalReport(
                        statusMessage: '本地报告已重新整理。',
                      )
                  : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新整理'),
            ),
            FilledButton.icon(
              onPressed: canRunAi ? provider.runAiAnalysis : null,
              icon: provider.isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(provider.isAnalyzing ? '正在分析' : 'AI 增强'),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((provider.statusMessage ?? '').isNotEmpty) ...[
                  WorkspaceHint(
                    icon: Icons.check_circle_rounded,
                    tint: AppTheme.accent,
                    child: Text(provider.statusMessage!),
                  ),
                  const SizedBox(height: 18),
                ],
                if (report == null)
                  const _PolishedEmptyReportState()
                else
                  _ReportBody(
                    report: report,
                    recordCount: provider.records.length,
                    aiEnabled: provider.aiConfig.enabled,
                    provider: provider,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ComparisonReport report;
  final int recordCount;
  final bool aiEnabled;
  final AnalysisProvider provider;

  const _ReportBody({
    required this.report,
    required this.recordCount,
    required this.aiEnabled,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final topInsight =
        report.contactInsights.isNotEmpty ? report.contactInsights.first : null;
    final topGift = topInsight?.giftSuggestion ??
        (report.giftRecommendations.isNotEmpty
            ? report.giftRecommendations.first
            : null);
    final averageScore = report.contactInsights.isEmpty
        ? 0.0
        : report.contactInsights.fold<double>(
              0,
              (sum, item) => sum + item.intimacyScore,
            ) /
            report.contactInsights.length;
    final suggestions = report.actionSuggestions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
    final positives = topInsight?.positiveSignals
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList() ??
        const <String>[];
    final risks = topInsight?.riskPoints
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(3)
            .toList() ??
        const <String>[];
    final quotes = topInsight?.evidenceQuotes
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(2)
            .toList() ??
        const <String>[];
    final reportEvidence = report.evidenceQuotes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final topAction = suggestions.isEmpty ? null : suggestions.first;
    final topEvidence = quotes.isNotEmpty
        ? quotes.first
        : (reportEvidence.isEmpty ? null : reportEvidence.first);
    final riskCount = report.contactInsights
        .where((item) => item.riskPoints.isNotEmpty)
        .length;

    void openContact(String contactId) {
      provider.selectContact(contactId);
      Navigator.of(context).pushNamed(
        AppRoutes.contactDetail,
        arguments: contactId,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            WorkspaceStatPill(
              label: '已导入记录',
              value: '$recordCount',
              icon: Icons.chat_bubble_outline_rounded,
            ),
            WorkspaceStatPill(
              label: '重点联系人',
              value: '${report.contactInsights.length}',
              icon: Icons.people_outline_rounded,
            ),
            WorkspaceStatPill(
              label: '平均关系分',
              value: averageScore.toStringAsFixed(1),
              icon: Icons.favorite_rounded,
            ),
            WorkspaceStatPill(
              label: '分析模式',
              value: report.usedAi ? 'AI 增强' : '本地规则',
              icon: Icons.tune_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),
        WorkspaceHint(
          icon: Icons.rule_rounded,
          tint: AppTheme.accent,
          child: Text(
            '评分会综合看最近互动、双向往来、持续活跃、关系基线和风险扣分，不是只看消息总量。',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1080;
            final overview = _Panel(
              title: '当前决策简报',
              subtitle: '先锁定主对象，再收拢今天的动作、风险和送礼切口。',
              tone: WorkspaceSurfaceTone.emphasis,
              child: LayoutBuilder(
                builder: (context, overviewConstraints) {
                  final railCompact = overviewConstraints.maxWidth < 880;
                  final summaryColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.overallSummary.isNotEmpty
                            ? report.overallSummary
                            : '当前还没有生成摘要，先导入聊天记录后再继续。',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.75),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MetaChip(
                            label: '第一优先',
                            value: topInsight?.contactName ?? '先补更多记录',
                          ),
                          _MetaChip(
                            label: '当前基调',
                            value: _tone(averageScore),
                          ),
                          _MetaChip(
                            label: '分析模式',
                            value: report.usedAi ? 'AI 增强' : '本地规则',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InsightBlock(
                        title: topInsight?.contactName ?? '等待形成重点对象',
                        body: topInsight == null
                            ? '当前还没有重点对象，先补更多聊天记录再回来判断。'
                            : topInsight.riskPoints.isNotEmpty
                                ? '当前最需要注意的是：${topInsight.riskPoints.first}'
                                : topInsight.suggestions.isNotEmpty
                                    ? '当前最适合直接执行的是：${topInsight.suggestions.first}'
                                    : '当前建议先围绕这位联系人推进，不要让注意力重新散回全列表。',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricBox(
                            label: '已整理重点关系',
                            value: '${report.contactInsights.length}',
                          ),
                          _MetricBox(label: '需要补节奏', value: '$riskCount'),
                          _MetricBox(
                            label: '可执行动作',
                            value: '${suggestions.length}',
                          ),
                        ],
                      ),
                    ],
                  );
                  final rail = _DecisionRail(
                    topInsight: topInsight,
                    topAction: topAction,
                    topGift: topGift,
                    topEvidence: topEvidence,
                    openContact: openContact,
                  );

                  if (railCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        summaryColumn,
                        const SizedBox(height: 18),
                        rail,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: summaryColumn),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: overviewConstraints.maxWidth < 1180 ? 300 : 332,
                        child: rail,
                      ),
                    ],
                  );
                },
              ),
            );
            final signalBoard = _Panel(
              title: '重点对象信号板',
              subtitle: topInsight != null
                  ? '围绕 ${topInsight.contactName} 看积极信号、风险点和原话证据。'
                  : '当前还没有重点对象。',
              child: LayoutBuilder(
                builder: (context, signalConstraints) {
                  final stackedSignals = signalConstraints.maxWidth < 760;
                  final signalGroups = stackedSignals
                      ? Column(
                          children: [
                            _SignalGroup(
                              title: '积极信号',
                              items: positives,
                              fallback: '当前还没有足够明显的积极信号。',
                              accent: const Color(0xFF2EC984),
                            ),
                            const SizedBox(height: 12),
                            _SignalGroup(
                              title: '风险提醒',
                              items: risks,
                              fallback: '当前没有明显风险提醒。',
                              accent: const Color(0xFFE59437),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SignalGroup(
                                title: '积极信号',
                                items: positives,
                                fallback: '当前还没有足够明显的积极信号。',
                                accent: const Color(0xFF2EC984),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SignalGroup(
                                title: '风险提醒',
                                items: risks,
                                fallback: '当前没有明显风险提醒。',
                                accent: const Color(0xFFE59437),
                              ),
                            ),
                          ],
                        );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      signalGroups,
                      if (quotes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _InsightBlock(
                          title: '原话摘录',
                          body: quotes.map((item) => '“$item”').join('\n\n'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
            if (stacked) {
              return Column(
                children: [
                  overview,
                  const SizedBox(height: 18),
                  signalBoard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: overview),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: signalBoard),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1120;
            final insightMap = {
              for (final item in report.contactInsights) item.contactId: item,
            };
            final rankingPanel = _Panel(
              title: '优先联系人',
              subtitle: '按当前该优先经营的顺序拉出来，而不是简单按热闹程度排序。',
              tone: WorkspaceSurfaceTone.emphasis,
              child: report.relationshipRanking.isEmpty
                  ? const _InlineEmpty('当前还没有重点联系人，先导入记录后系统会自动生成。')
                  : Column(
                      children: [
                        for (var i = 0;
                            i < report.relationshipRanking.length && i < 5;
                            i++) ...[
                          _RankingRow(
                            rank: i + 1,
                            item: report.relationshipRanking[i],
                            insight: insightMap[
                                report.relationshipRanking[i].contactId],
                            onOpen: () => openContact(
                              report.relationshipRanking[i].contactId,
                            ),
                          ),
                          if (i != report.relationshipRanking.length - 1 &&
                              i < 4)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
            );
            final actionPanel = _Panel(
              title: '执行面板',
              subtitle: '把报告里的判断压缩成今天能动手做的动作。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      WorkspaceTag(
                        topInsight != null
                            ? '今天先盯住：${topInsight.contactName}'
                            : '先补导入再判断重点对象',
                      ),
                      if (topAction != null) WorkspaceTag('首个动作：$topAction'),
                      if (topGift != null)
                        WorkspaceTag('礼物切口：${topGift.giftName}'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (topInsight != null || topGift != null) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (topInsight != null)
                          _DecisionCueCard(
                            icon: Icons.person_pin_circle_rounded,
                            title: '先盯住谁',
                            body:
                                '${topInsight.contactName} 目前最值得先推进，建议先把节奏和下一步话题定下来。',
                            tag: topInsight.referenceTier.isNotEmpty
                                ? topInsight.referenceTier
                                : topInsight.relationshipLevel,
                            onPressed: () => openContact(topInsight.contactId),
                            actionLabel: '查看详情',
                          ),
                        if (topGift != null)
                          _DecisionCueCard(
                            icon: Icons.local_mall_rounded,
                            title: '礼物线索',
                            body: '${topGift.giftName}\n${topGift.reason}',
                            tag: topGift.occasion.isNotEmpty
                                ? topGift.occasion
                                : topGift.budgetRange,
                            onPressed: topGift.contactId.isEmpty
                                ? null
                                : () => openContact(topGift.contactId),
                            actionLabel: '跟进联系人',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (suggestions.isEmpty)
                    const _InlineEmpty('当前还没有明确动作建议，先补更多记录或重新整理本地报告。')
                  else
                    for (var i = 0; i < suggestions.length; i++) ...[
                      _ActionStep(index: i + 1, text: suggestions[i]),
                      if (i != suggestions.length - 1)
                        const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 16),
                  _InsightBlock(
                    title: '礼物线索',
                    body: topGift == null
                        ? '当前还没有足够明确的礼物建议，先把关系节奏、场景和近期话题补得更清楚。'
                        : '${topGift.giftName}${topInsight != null ? '，优先结合 ${topInsight.contactName} 来看这条建议' : ''}\n${topGift.reason}',
                    tags: [
                      if (topGift != null && topGift.budgetRange.isNotEmpty)
                        topGift.budgetRange,
                      if (topGift != null && topGift.occasion.isNotEmpty)
                        topGift.occasion,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.usedAi
                        ? '这轮报告已经用了 AI 增强。现在更值得回到联系人和行动页去执行。'
                        : aiEnabled
                            ? '如果你想把措辞、礼物语境和风险判断做得更细，可以再跑一次 AI 增强。'
                            : '当前没有启用 AI，本地规则已经足够看清主要节奏。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                          height: 1.6,
                        ),
                  ),
                ],
              ),
            );
            if (stacked) {
              return Column(
                children: [
                  rankingPanel,
                  const SizedBox(height: 18),
                  actionPanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: rankingPanel),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: actionPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  String _tone(double score) {
    if (score >= 76) return '保持稳定联系';
    if (score >= 58) return '继续升温关系';
    if (score >= 36) return '优先补回节奏';
    return '先重新建立联系';
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final WorkspaceSurfaceTone tone;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.tone = WorkspaceSurfaceTone.soft,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurface(
      tone: tone,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(title: title, subtitle: subtitle),
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
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.92),
            theme.colorScheme.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.82),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final String body;
  final List<String> tags;

  const _InsightBlock({
    required this.title,
    required this.body,
    this.tags = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanTags = tags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.84),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
          if (cleanTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cleanTags.map(WorkspaceTag.new).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionCueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? tag;
  final VoidCallback? onPressed;
  final String? actionLabel;
  final bool compact;

  const _DecisionCueCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tag,
    this.onPressed,
    this.actionLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: compact ? double.infinity : 260,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.82),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                  theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (tag != null && tag!.trim().isNotEmpty) ...[
            WorkspaceTag(tag!),
            const SizedBox(height: 10),
          ],
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          if (onPressed != null && actionLabel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionRail extends StatelessWidget {
  final ContactInsight? topInsight;
  final String? topAction;
  final GiftRecommendation? topGift;
  final String? topEvidence;
  final void Function(String contactId) openContact;

  const _DecisionRail({
    required this.topInsight,
    required this.topAction,
    required this.topGift,
    required this.topEvidence,
    required this.openContact,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (topInsight != null)
        _DecisionCueCard(
          icon: Icons.radar_rounded,
          title: '当前主锚对象',
          body: topInsight!.riskPoints.isNotEmpty
              ? topInsight!.riskPoints.first
              : topInsight!.suggestions.isNotEmpty
                  ? topInsight!.suggestions.first
                  : topInsight!.relationshipLevel,
          tag: topInsight!.contactName,
          onPressed: () => openContact(topInsight!.contactId),
          actionLabel: '进入详情',
          compact: true,
        ),
      if (topAction != null) ...[
        const SizedBox(height: 12),
        _DecisionCueCard(
          icon: Icons.flash_on_rounded,
          title: '今天最先做',
          body: topAction!,
          tag: '执行动作',
          compact: true,
        ),
      ],
      if (topGift != null) ...[
        const SizedBox(height: 12),
        _DecisionCueCard(
          icon: Icons.card_giftcard_rounded,
          title: '送礼切口',
          body: '${topGift!.giftName}\n${topGift!.reason}',
          tag: topGift!.budgetRange,
          onPressed: topGift!.contactId.isEmpty
              ? null
              : () => openContact(topGift!.contactId),
          actionLabel: '查看联系人',
          compact: true,
        ),
      ],
      if (topEvidence != null) ...[
        const SizedBox(height: 12),
        _DecisionCueCard(
          icon: Icons.format_quote_rounded,
          title: '原话证据',
          body: '“$topEvidence”',
          tag: '原始信号',
          compact: true,
        ),
      ],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.84),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '决策线索',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }
}

class _SignalGroup extends StatelessWidget {
  final String title;
  final List<String> items;
  final String fallback;
  final Color accent;

  const _SignalGroup({
    required this.title,
    required this.items,
    required this.fallback,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(fallback, style: Theme.of(context).textTheme.bodyMedium)
          else
            for (var i = 0; i < items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.55),
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final RelationshipRankItem item;
  final ContactInsight? insight;
  final VoidCallback onOpen;

  const _RankingRow({
    required this.rank,
    required this.item,
    required this.insight,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstSuggestion = insight?.suggestions
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(1)
            .toList() ??
        const <String>[];
    final firstRisk = insight?.riskPoints
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .take(1)
            .toList() ??
        const <String>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;

        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.contactName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.referenceTier.isNotEmpty)
                  WorkspaceTag(item.referenceTier),
                if (item.relationDetail.isNotEmpty)
                  WorkspaceTag(item.relationDetail),
                if (insight?.activityLevel.isNotEmpty == true)
                  WorkspaceTag(insight!.activityLevel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.rationale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                height: 1.55,
              ),
            ),
          ],
        );

        final actionRow = Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (item.score / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('查看详情'),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface.withValues(alpha: 0.82),
                theme.colorScheme.primary
                    .withValues(alpha: rank == 1 ? 0.07 : 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: rank == 1
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : theme.dividerColor.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Text('$rank', style: theme.textTheme.titleSmall),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: infoColumn),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.score.toStringAsFixed(1)} 分',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$rank', style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: infoColumn),
                    const SizedBox(width: 12),
                    Text(
                      '${item.score.toStringAsFixed(1)} 分',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              if (firstSuggestion.isNotEmpty || firstRisk.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (firstSuggestion.isNotEmpty)
                      WorkspaceTag('行动: ${firstSuggestion.first}'),
                    if (firstRisk.isNotEmpty)
                      WorkspaceTag('风险: ${firstRisk.first}'),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    actionRow,
                  ],
                )
              else
                actionRow,
            ],
          ),
        );
      },
    );
  }
}

class _ActionStep extends StatelessWidget {
  final int index;
  final String text;

  const _ActionStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child:
                Text('$index', style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _PolishedEmptyReportState extends StatelessWidget {
  const _PolishedEmptyReportState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.all(36),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 52,
            color: theme.colorScheme.primary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 20),
          Text(
            '先导入记录，再生成报告。',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            '报告页会把重点联系人、风险提醒、行动建议和礼物线索收成一条可执行判断。现在空白，说明工作区里还没有足够的聊天记录。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetaChip(label: '会生成', value: '重点排序'),
              _MetaChip(label: '会提示', value: '风险与节奏'),
              _MetaChip(label: '会落地', value: '动作与礼物'),
            ],
          ),
          const SizedBox(height: 18),
          WorkspaceHint(
            icon: Icons.route_rounded,
            tint: AppTheme.accent,
            child: Text(
              '最快路径：先从左侧进入“导入”，上传最近一位你最在意联系人的聊天记录；本地报告生成后，再决定要不要开 AI 增强。',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _EmptyReportState extends StatelessWidget {
  const _EmptyReportState();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
/*
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.all(36),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 52,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 20),
            Text('先导入记录，再生成报告。', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '如果这里还是空白，说明系统还没有拿到足够的聊天记录。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.68),
                  ),
            ),
          ],
        ),
      ),
    );
*/
}
