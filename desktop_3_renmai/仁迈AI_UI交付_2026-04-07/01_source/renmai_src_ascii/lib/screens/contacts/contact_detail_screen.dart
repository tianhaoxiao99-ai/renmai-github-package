import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class ContactDetailScreen extends StatefulWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  Timer? _searchDebounce;
  String _draftKeyword = '';
  String _keyword = '';
  String? _timelineScopeLabel;
  double _timelineValue = 1;
  bool _syncingTimeline = false;
  String _viewportKey = '';

  @override
  void initState() {
    super.initState();
    _chatScrollController.addListener(_syncTimelineFromScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _chatScrollController
      ..removeListener(_syncTimelineFromScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleKeywordUpdate(String value) {
    setState(() => _draftKeyword = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || _keyword == value) {
        return;
      }
      setState(() => _keyword = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _draftKeyword = '';
      _keyword = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        final insight = provider.findInsightByContactId(widget.contactId);
        final allRecords = provider.recordsForContact(widget.contactId);
        final filteredRecords = _filterRecords(allRecords);
        final dayGroups = _buildDayGroups(filteredRecords);
        final timelineAnchors = _buildTimelineAnchors(dayGroups);
        _scheduleScrollToBottom(filteredRecords);

        return WorkspacePage(
          eyebrow: '联系人详情',
          title: insight?.contactName ?? '联系人详情',
          subtitle: insight == null
              ? '没有找到这个联系人的聊天数据。'
              : '先看关系判断和下一步，再带着搜索与时间轴回到原话，不再让长聊天记录变成纯滚动列表。',
          actions: [
            if (insight != null)
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteContact(
                  context,
                  provider,
                  insight,
                  allRecords,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('删除联系人'),
              ),
            OutlinedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('返回列表'),
            ),
          ],
          maxWidth: 1380,
          child: insight == null
              ? const _EmptyContact()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1120;
                    final workspace = _buildChatWorkspace(
                      context,
                      provider,
                      insight,
                      allRecords,
                      filteredRecords,
                      dayGroups,
                    );
                    final timeline = _buildTimelinePanel(
                      context,
                      timelineAnchors,
                    );

                    if (compact) {
                      return Column(
                        children: [
                          Expanded(child: RepaintBoundary(child: workspace)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child: RepaintBoundary(child: timeline),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: RepaintBoundary(child: workspace)),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 312,
                          child: RepaintBoundary(child: timeline),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildChatWorkspace(
    BuildContext context,
    AnalysisProvider provider,
    ContactInsight insight,
    List<ConversationRecord> allRecords,
    List<ConversationRecord> filteredRecords,
    List<_DayGroup> dayGroups,
  ) {
    final theme = Theme.of(context);
    final positiveLead = _firstMeaningful(insight.positiveSignals);
    final riskLead = _firstMeaningful(insight.riskPoints);
    final suggestionLead = _firstMeaningful(insight.suggestions);

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      borderRadius: BorderRadius.circular(30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summaryMaxHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight * 0.62).clamp(280.0, 520.0).toDouble()
              : 420.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: summaryMaxHeight),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceSectionHeader(
                            title: '关系工作台',
                            subtitle: '先看判断和下一步，再带着搜索与时间轴回到具体原话。',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _DetailMetricPill(
                                label: '消息总量',
                                value: '${insight.totalMessages}',
                                icon: Icons.chat_bubble_outline_rounded,
                                tint: theme.colorScheme.primary,
                              ),
                              _DetailMetricPill(
                                label: '活跃天数',
                                value: '${insight.activeDays}',
                                icon: Icons.calendar_month_rounded,
                                tint: const Color(0xFF2EC984),
                              ),
                              _DetailMetricPill(
                                label: '最近互动',
                                value: insight.lastInteractionAt == null
                                    ? '待补记录'
                                    : _formatDateOnly(
                                        insight.lastInteractionAt!),
                                icon: Icons.schedule_rounded,
                                tint: const Color(0xFFE59437),
                              ),
                              _DetailMetricPill(
                                label: '关系关键词',
                                value: '${insight.keywords.length}',
                                icon: Icons.sell_outlined,
                                tint: theme.colorScheme.tertiary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (insight.referenceTier.isNotEmpty)
                                WorkspaceTag(
                                  AppConstants.displayReferenceTier(
                                      insight.referenceTier),
                                ),
                              if (insight.relationDetail.isNotEmpty)
                                WorkspaceTag(insight.relationDetail),
                              WorkspaceTag(
                                AppConstants.displayRelationshipLevel(
                                  insight.relationshipLevel,
                                ),
                              ),
                              WorkspaceTag(insight.activityLevel),
                              WorkspaceTag(
                                  '参考分 ${insight.intimacyScore.toStringAsFixed(1)}'),
                              WorkspaceTag('共 ${allRecords.length} 条'),
                              WorkspaceTag('当前匹配 ${filteredRecords.length} 条'),
                              if (_timelineScopeLabel != null)
                                WorkspaceTag('已载入 $_timelineScopeLabel'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 860;
                              final cards = [
                                _DetailSnapshotCard(
                                  title: '关系判断',
                                  value: AppConstants.displayRelationshipLevel(
                                    insight.relationshipLevel,
                                  ),
                                  helper:
                                      '参考分 ${insight.intimacyScore.toStringAsFixed(1)} · ${insight.activityLevel}',
                                  tint: theme.colorScheme.primary,
                                ),
                                _DetailSnapshotCard(
                                  title: '积极信号',
                                  value: positiveLead ?? '等待补充更多正向互动',
                                  helper: insight.positiveSignals.isNotEmpty
                                      ? '已识别 ${insight.positiveSignals.length} 条正向线索'
                                      : '先从原话里确认回应质量',
                                  tint: const Color(0xFF2EC984),
                                ),
                                _DetailSnapshotCard(
                                  title: '下一步',
                                  value: riskLead ??
                                      suggestionLead ??
                                      '继续查看原话后再判断',
                                  helper: riskLead != null
                                      ? '当前优先处理风险点'
                                      : suggestionLead != null
                                          ? '这是最接近可执行的一步'
                                          : '还没有收束出明确动作',
                                  tint: const Color(0xFFE59437),
                                ),
                              ];

                              if (compact) {
                                return Column(
                                  children: [
                                    for (var i = 0; i < cards.length; i++) ...[
                                      cards[i],
                                      if (i != cards.length - 1)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  for (var i = 0; i < cards.length; i++) ...[
                                    Expanded(child: cards[i]),
                                    if (i != cards.length - 1)
                                      const SizedBox(width: 10),
                                  ],
                                ],
                              );
                            },
                          ),
                          if (insight.referenceReason.isNotEmpty ||
                              insight.evidenceQuotes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            WorkspaceSurface(
                              tone: WorkspaceSurfaceTone.soft,
                              tint: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(24),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 820;
                                  final reasonPanel =
                                      insight.referenceReason.isNotEmpty
                                          ? WorkspaceHint(
                                              icon: Icons.rule_rounded,
                                              tint: theme.colorScheme.primary,
                                              child: Text(
                                                insight.referenceReason,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(height: 1.6),
                                              ),
                                            )
                                          : const SizedBox.shrink();
                                  final quotePanel = insight
                                          .evidenceQuotes.isNotEmpty
                                      ? Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            14,
                                            12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                theme.colorScheme.primary
                                                    .withValues(alpha: 0.08),
                                                theme.colorScheme.surface
                                                    .withValues(alpha: 0.92),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.14),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '聊天原话',
                                                style: theme
                                                    .textTheme.labelMedium
                                                    ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                insight.evidenceQuotes.first,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  height: 1.55,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink();

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const WorkspaceSectionHeader(
                                        title: '证据摘录',
                                        subtitle: '先确认这条判断为什么成立，再决定今天要做什么。',
                                      ),
                                      const SizedBox(height: 12),
                                      if (compact) ...[
                                        if (insight.referenceReason.isNotEmpty)
                                          reasonPanel,
                                        if (insight
                                                .referenceReason.isNotEmpty &&
                                            insight.evidenceQuotes.isNotEmpty)
                                          const SizedBox(height: 10),
                                        if (insight.evidenceQuotes.isNotEmpty)
                                          quotePanel,
                                      ] else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (insight
                                                .referenceReason.isNotEmpty)
                                              Expanded(child: reasonPanel)
                                            else
                                              const Expanded(
                                                child: SizedBox.shrink(),
                                              ),
                                            if (insight.referenceReason
                                                    .isNotEmpty &&
                                                insight
                                                    .evidenceQuotes.isNotEmpty)
                                              const SizedBox(width: 12),
                                            if (insight
                                                .evidenceQuotes.isNotEmpty)
                                              Expanded(child: quotePanel)
                                            else
                                              const Expanded(
                                                child: SizedBox.shrink(),
                                              ),
                                          ],
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                          if (insight.suggestions.isNotEmpty ||
                              insight.giftSuggestion != null) ...[
                            const SizedBox(height: 14),
                            WorkspaceSurface(
                              tone: WorkspaceSurfaceTone.soft,
                              borderRadius: BorderRadius.circular(24),
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 920;
                                  final actionCues = insight.suggestions
                                      .take(3)
                                      .map(
                                        (item) => _ActionCueCard(
                                          text: item,
                                          icon: Icons.bolt_rounded,
                                          tint: theme.colorScheme.primary,
                                        ),
                                      )
                                      .toList();

                                  final actionRail = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const WorkspaceSectionHeader(
                                        title: '行动与送礼建议',
                                        subtitle:
                                            '把这位联系人的洞察直接翻成下一步动作，避免停留在“知道了”。',
                                      ),
                                      const SizedBox(height: 12),
                                      if (actionCues.isNotEmpty)
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: actionCues,
                                        ),
                                    ],
                                  );

                                  final giftRail = insight.giftSuggestion ==
                                          null
                                      ? const SizedBox.shrink()
                                      : WorkspaceSurface(
                                          tone: WorkspaceSurfaceTone.emphasis,
                                          tint: const Color(0xFFE59437),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            16,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  const WorkspaceTag('送礼切口'),
                                                  Text(
                                                    insight.giftSuggestion!
                                                        .giftName,
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${insight.giftSuggestion!.occasion} · ${insight.giftSuggestion!.budgetRange}',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(height: 1.5),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                insight.giftSuggestion!.reason,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                  height: 1.55,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                  final railLayout = compact
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            actionRail,
                                            if (insight.giftSuggestion !=
                                                null) ...[
                                              const SizedBox(height: 14),
                                              giftRail,
                                            ],
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: actionRail),
                                            if (insight.giftSuggestion !=
                                                null) ...[
                                              const SizedBox(width: 16),
                                              SizedBox(
                                                width: 362,
                                                child: giftRail,
                                              ),
                                            ],
                                          ],
                                        );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      railLayout,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                          if (_timelineScopeLabel != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _timelineScopeLabel = null);
                                },
                                icon: const Icon(Icons.filter_alt_off_rounded),
                                label: const Text('清除时间载入'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: _scheduleKeywordUpdate,
                decoration: InputDecoration(
                  hintText: '搜索聊天内容、发送方、日期、图片文字、语音转写或表情含义',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _draftKeyword.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.44),
                    ),
                  ),
                  child: dayGroups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _keyword.isEmpty ? '这里还没有可展示的聊天记录。' : '没有找到匹配内容。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _chatScrollController,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: _chatScrollController,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                            itemCount: dayGroups.length,
                            itemBuilder: (context, index) {
                              final group = dayGroups[index];
                              final label =
                                  '${group.day.year}-${group.day.month.toString().padLeft(2, '0')}-${group.day.day.toString().padLeft(2, '0')}';
                              return Container(
                                key: group.anchorKey,
                                margin: EdgeInsets.only(
                                  bottom:
                                      index == dayGroups.length - 1 ? 0 : 18,
                                ),
                                child: Column(
                                  children: [
                                    _DateLabel(label: label),
                                    const SizedBox(height: 16),
                                    ...group.records.map(
                                      (record) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _MessageBubble(
                                          record: record,
                                          onEdit: () => _editRecord(
                                              context, provider, record),
                                          onDelete: () => _confirmDeleteRecord(
                                            context,
                                            provider,
                                            record,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelinePanel(
    BuildContext context,
    List<_TimelineAnchor> anchors,
  ) {
    final theme = Theme.of(context);
    final hasScope = _timelineScopeLabel != null;

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: '时间轴副驾',
            subtitle: '单击跳到对应月份，双击把聊天收拢到该时间段。',
            trailing: WorkspaceTag('${(_timelineValue * 100).round()}%'),
          ),
          const SizedBox(height: 14),
          WorkspaceHint(
            icon: hasScope ? Icons.filter_alt_rounded : Icons.timeline_rounded,
            tint: hasScope ? theme.colorScheme.primary : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasScope ? '当前已载入单月聊天' : '当前查看的是完整时间轴',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasScope
                      ? '已锁定到 $_timelineScopeLabel。你可以继续搜索原话，或清除载入回到完整历史。'
                      : '用月份列表快速定位聊天节奏，用右侧滑杆判断自己现在位于历史的哪一段。',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: anchors.isEmpty
                ? Center(
                    child: Text(
                      '当前筛选下没有可跳转的时间段。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            itemCount: anchors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final anchor = anchors[index];
                              final isLoaded =
                                  _timelineScopeLabel == anchor.label;
                              return InkWell(
                                onTap: () => _jumpToAnchor(anchor),
                                onDoubleTap: () => _loadTimelineScope(anchor),
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLoaded
                                        ? theme.colorScheme.primary
                                            .withValues(alpha: 0.12)
                                        : theme.colorScheme.surface
                                            .withValues(alpha: 0.84),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isLoaded
                                          ? theme.colorScheme.primary
                                              .withValues(alpha: 0.36)
                                          : theme.dividerColor
                                              .withValues(alpha: 0.46),
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
                                              anchor.label,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                color: isLoaded
                                                    ? theme.colorScheme.primary
                                                    : null,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (isLoaded)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        anchor.sublabel,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isLoaded ? '已载入本月聊天' : '单击跳转 · 双击载入',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: isLoaded
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 34,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _timelineValue.clamp(0.0, 1.0),
                            onChanged: _jumpBySlider,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (hasScope) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _timelineScopeLabel = null);
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('回到完整时间轴'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _jumpBySlider(double value) {
    if (!_chatScrollController.hasClients) {
      setState(() => _timelineValue = value);
      return;
    }
    final max = _chatScrollController.position.maxScrollExtent;
    setState(() => _timelineValue = value);
    _syncingTimeline = true;
    _chatScrollController.jumpTo((max * value).clamp(0.0, max));
    _syncingTimeline = false;
  }

  void _syncTimelineFromScroll() {
    if (_syncingTimeline || !_chatScrollController.hasClients) {
      return;
    }
    final max = _chatScrollController.position.maxScrollExtent;
    final next =
        max <= 0 ? 1.0 : (_chatScrollController.offset / max).clamp(0.0, 1.0);
    if ((_timelineValue - next).abs() < 0.01) {
      return;
    }
    setState(() => _timelineValue = next);
  }

  void _scheduleScrollToBottom(List<ConversationRecord> filteredRecords) {
    final nextKey = filteredRecords.isEmpty
        ? 'empty'
        : '${filteredRecords.length}_${filteredRecords.first.id}_${filteredRecords.last.id}_$_keyword';
    if (_viewportKey == nextKey) {
      return;
    }
    _viewportKey = nextKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) {
        return;
      }
      _syncingTimeline = true;
      _chatScrollController
          .jumpTo(_chatScrollController.position.maxScrollExtent);
      _timelineValue = 1;
      _syncingTimeline = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  List<ConversationRecord> _filterRecords(List<ConversationRecord> records) {
    final keyword = _keyword.trim().toLowerCase();
    final ordered = [...records]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final scoped = _timelineScopeLabel == null
        ? ordered
        : ordered.where((record) {
            final month =
                '${record.sentAt.year}-${record.sentAt.month.toString().padLeft(2, '0')}';
            return month == _timelineScopeLabel;
          }).toList();
    if (keyword.isEmpty) {
      return scoped;
    }
    return scoped.where((record) {
      final timeText = _formatTime(record.sentAt).toLowerCase();
      return record.contactName.toLowerCase().contains(keyword) ||
          record.senderName.toLowerCase().contains(keyword) ||
          record.searchText.toLowerCase().contains(keyword) ||
          timeText.contains(keyword);
    }).toList();
  }

  List<_DayGroup> _buildDayGroups(List<ConversationRecord> records) {
    final groups = <_DayGroup>[];
    for (final record in records) {
      final dayKey =
          '${record.sentAt.year}-${record.sentAt.month}-${record.sentAt.day}';
      if (groups.isNotEmpty && groups.last.dayKey == dayKey) {
        groups.last.records.add(record);
      } else {
        groups.add(
          _DayGroup(
            dayKey: dayKey,
            day: record.sentAt,
            anchorKey: GlobalKey(),
            records: [record],
          ),
        );
      }
    }
    return groups;
  }

  List<_TimelineAnchor> _buildTimelineAnchors(List<_DayGroup> groups) {
    final seen = <String>{};
    final anchors = <_TimelineAnchor>[];
    for (final group in groups) {
      final month =
          '${group.day.year}-${group.day.month.toString().padLeft(2, '0')}';
      if (!seen.add(month)) {
        continue;
      }
      anchors.add(
        _TimelineAnchor(
          label: month,
          sublabel:
              '${group.day.month.toString().padLeft(2, '0')}/${group.day.day.toString().padLeft(2, '0')}',
          anchorKey: group.anchorKey,
        ),
      );
    }
    return anchors;
  }

  Future<void> _jumpToAnchor(_TimelineAnchor anchor) async {
    final target = anchor.anchorKey.currentContext;
    if (target == null) {
      return;
    }
    _syncingTimeline = true;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    _syncingTimeline = false;
  }

  void _loadTimelineScope(_TimelineAnchor anchor) {
    setState(() {
      _timelineScopeLabel =
          _timelineScopeLabel == anchor.label ? null : anchor.label;
    });
  }

  Future<void> _editRecord(
    BuildContext context,
    AnalysisProvider provider,
    ConversationRecord record,
  ) async {
    final contentController = TextEditingController(text: record.content);
    final updated = await showDialog<ConversationRecord>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑聊天记录'),
          content: TextField(
            controller: contentController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: '消息正文'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                record.copyWith(content: contentController.text.trim()),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    contentController.dispose();
    if (updated != null && updated.content.trim().isNotEmpty) {
      await provider.updateConversationRecord(updated);
    }
  }

  Future<void> _confirmDeleteRecord(
    BuildContext context,
    AnalysisProvider provider,
    ConversationRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除聊天记录'),
        content: Text('确认删除这条消息吗？\n\n${record.content}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteConversationRecord(record.id);
    }
  }

  Future<void> _confirmDeleteContact(
    BuildContext context,
    AnalysisProvider provider,
    ContactInsight insight,
    List<ConversationRecord> records,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text(
          '确认删除 ${insight.contactName} 的全部聊天记录吗？\n\n共 ${records.length} 条消息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除联系人'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await provider.deleteContact(insight.contactId);
    if (!mounted) {
      return;
    }
    if (Navigator.of(this.context).canPop()) {
      Navigator.of(this.context).pop();
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String? _firstMeaningful(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}

class _DateLabel extends StatelessWidget {
  final String label;

  const _DateLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.56),
            ),
          ),
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MessageBubble({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelf = record.isSelf;
    final messageTypeLabel = _messageTypeLabel(record.messageType);
    final evidence = record.evidenceSnippet.trim();
    final showEvidence =
        evidence.isNotEmpty && evidence != record.content.trim();
    final sourceLabel = _sourceLabel(record.source);
    final time =
        '${record.sentAt.hour.toString().padLeft(2, '0')}:${record.sentAt.minute.toString().padLeft(2, '0')}';

    return Row(
      mainAxisAlignment:
          isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelf
                    ? [
                        theme.colorScheme.primary.withValues(alpha: 0.16),
                        theme.colorScheme.surface.withValues(alpha: 0.88),
                      ]
                    : [
                        theme.colorScheme.surface.withValues(alpha: 0.96),
                        theme.colorScheme.surface.withValues(alpha: 0.88),
                      ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isSelf ? 22 : 8),
                bottomRight: Radius.circular(isSelf ? 8 : 22),
              ),
              border: Border.all(
                color: isSelf
                    ? theme.colorScheme.primary.withValues(alpha: 0.24)
                    : theme.dividerColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(
                    alpha: isSelf ? 0.06 : 0.04,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            isSelf ? '我' : record.senderName,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isSelf
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(time, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        }
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('编辑'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('删除'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      label: messageTypeLabel,
                      icon: _messageTypeIcon(record.messageType),
                      tint: isSelf
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                    _MetaPill(
                      label: sourceLabel,
                      icon: Icons.devices_rounded,
                      tint: theme.colorScheme.tertiary,
                    ),
                    if (record.attachmentPath.trim().isNotEmpty)
                      const _MetaPill(
                        label: '含附件',
                        icon: Icons.attach_file_rounded,
                        tint: Color(0xFFE59437),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  record.content,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.58),
                ),
                if (showEvidence) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                          theme.colorScheme.surface.withValues(alpha: 0.88),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '证据摘录',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          evidence,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.78),
                            height: 1.52,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyContact extends StatelessWidget {
  const _EmptyContact();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.all(36),
      borderRadius: BorderRadius.circular(30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 18),
            Text(
              '没有找到这个联系人的洞察数据',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '可以先回到列表重新选择联系人，或者重新导入这位联系人的聊天记录后再查看。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSnapshotCard extends StatelessWidget {
  final String title;
  final String value;
  final String helper;
  final Color tint;

  const _DetailSnapshotCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      tint: tint,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _DetailMetricPill({
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
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
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

class _ActionCueCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color tint;

  const _ActionCueCard({
    required this.text,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: 0.12),
              tint.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tint.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tint;

  const _MetaPill({
    required this.label,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroup {
  final String dayKey;
  final DateTime day;
  final GlobalKey anchorKey;
  final List<ConversationRecord> records;

  _DayGroup({
    required this.dayKey,
    required this.day,
    required this.anchorKey,
    required this.records,
  });
}

class _TimelineAnchor {
  final String label;
  final String sublabel;
  final GlobalKey anchorKey;

  const _TimelineAnchor({
    required this.label,
    required this.sublabel,
    required this.anchorKey,
  });
}

String _messageTypeLabel(String messageType) {
  switch (messageType.trim().toLowerCase()) {
    case 'image':
      return '图片';
    case 'voice':
      return '语音';
    case 'emoji':
      return '表情';
    case 'file':
      return '文件';
    case 'video':
      return '视频';
    default:
      return '文本';
  }
}

IconData _messageTypeIcon(String messageType) {
  switch (messageType.trim().toLowerCase()) {
    case 'image':
      return Icons.image_outlined;
    case 'voice':
      return Icons.mic_none_rounded;
    case 'emoji':
      return Icons.emoji_emotions_outlined;
    case 'file':
      return Icons.insert_drive_file_outlined;
    case 'video':
      return Icons.smart_display_outlined;
    default:
      return Icons.chat_bubble_outline_rounded;
  }
}

String _sourceLabel(String source) {
  final normalized = source.trim().toLowerCase();
  if (normalized.contains('wechat') || source.contains('微信')) {
    return '微信';
  }
  if (normalized.contains('qq') || source.contains('QQ')) {
    return 'QQ';
  }
  if (normalized.contains('telegram') || source.contains('Telegram')) {
    return 'Telegram';
  }
  if (normalized.contains('import')) {
    return '导入包';
  }
  if (source.trim().isEmpty) {
    return '未知来源';
  }
  return source.trim();
}
