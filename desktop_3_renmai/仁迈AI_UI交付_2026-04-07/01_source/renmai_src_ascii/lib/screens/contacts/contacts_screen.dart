import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_constants.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';
import 'package:renmai/config/app_theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _draftKeyword = '';
  String _keyword = '';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  Widget _buildOverviewHero(
    BuildContext context, {
    required int totalContacts,
    required int filteredContacts,
    required String filterLabel,
  }) {
    final theme = Theme.of(context);

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      borderRadius: BorderRadius.circular(34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkspaceTag('关系经营工作台'),
              const SizedBox(height: 12),
              Text(
                '先把候选人缩到最值得处理的那一批。',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '支持按联系人名字、备注、聊天内容、图片文字、语音转写和表情含义搜索。先选人，再回原话看证据。',
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceTag('先看证据'),
                  WorkspaceTag('再进详情'),
                  WorkspaceTag('按当前筛选聚焦'),
                  WorkspaceTag('原话可追溯'),
                ],
              ),
              const SizedBox(height: 18),
              WorkspaceHint(
                icon: Icons.visibility_rounded,
                tint: AppTheme.primary,
                child: Text(
                  '当前分类是「$filterLabel」，列表只负责帮你缩小候选范围，真正的判断还在联系人详情页完成。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            ],
          );

          final stats = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  WorkspaceStatPill(
                    icon: Icons.people_outline_rounded,
                    label: '当前联系人',
                    value: '$totalContacts',
                  ),
                  WorkspaceStatPill(
                    icon: Icons.filter_list_rounded,
                    label: '筛选结果',
                    value: '$filteredContacts',
                  ),
                  WorkspaceStatPill(
                    icon: Icons.local_offer_outlined,
                    label: '当前分类',
                    value: filterLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WorkspaceHint(
                icon: Icons.track_changes_rounded,
                tint: const Color(0xFFE59437),
                child: Text(
                  '先把重点联系人筛出来，再点进详情看证据、风险点和下一步动作。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                stats,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 18),
              SizedBox(width: 396, child: stats),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RelationshipProvider, AnalysisProvider>(
      builder: (context, relationshipProvider, analysisProvider, _) {
        final filtered = _buildFilteredList(
          relationshipProvider,
          analysisProvider,
        );
        final totalContacts = relationshipProvider.relationships.isNotEmpty
            ? relationshipProvider.relationships.length
            : analysisProvider.contactInsights.length;
        final hasContacts = totalContacts > 0;

        return WorkspacePage(
          eyebrow: '联系人',
          title: '先锁定重点联系人，再回到原话做判断',
          subtitle: '先搜名字、备注或聊天内容，再进入单人详情查看证据、风险点、节奏和后续建议。',
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                _clearSearch();
                relationshipProvider.setFilterType('all');
              },
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('重置筛选'),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewHero(
                  context,
                  totalContacts: totalContacts,
                  filteredContacts: filtered.length,
                  filterLabel: _labelForFilter(relationshipProvider.filterType),
                ),
                const SizedBox(height: 16),
                FadeInWidget(
                  delay: const Duration(milliseconds: 40),
                  child: WorkspaceSurface(
                    tone: WorkspaceSurfaceTone.emphasis,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WorkspaceSectionHeader(
                          title: '搜索与筛选',
                          subtitle: '支持搜索联系人名称、关键词、聊天内容、图片文字、语音转写和表情含义。',
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchController,
                          onChanged: _scheduleKeywordUpdate,
                          decoration: InputDecoration(
                            hintText: '搜索联系人、备注、聊天内容、图片文字或语音转写',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _draftKeyword.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: _clearSearch,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TypeChip(
                              label: '全部',
                              selected:
                                  relationshipProvider.filterType == 'all',
                              onTap: () =>
                                  relationshipProvider.setFilterType('all'),
                            ),
                            ...AppConstants.relationTypeLabels.entries.map(
                              (entry) {
                                return _TypeChip(
                                  label: entry.value,
                                  selected: relationshipProvider.filterType ==
                                      entry.key,
                                  onTap: () => relationshipProvider
                                      .setFilterType(entry.key),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInWidget(
                  delay: const Duration(milliseconds: 80),
                  child: RepaintBoundary(
                    child: hasContacts
                        ? _ContactList(
                            list: filtered,
                            analysisProvider: analysisProvider,
                            relationshipProvider: relationshipProvider,
                          )
                        : const _NoDataCard(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ContactInsight> _buildFilteredList(
    RelationshipProvider relationshipProvider,
    AnalysisProvider analysisProvider,
  ) {
    final source = _baseList(relationshipProvider, analysisProvider);
    final keyword = _normalize(_keyword);
    if (keyword.isEmpty) {
      return source;
    }

    return source
        .where(
          (item) => _matchesContact(
            insight: item,
            keyword: keyword,
            records: analysisProvider.recordsForContact(item.contactId),
          ),
        )
        .toList();
  }

  List<ContactInsight> _baseList(
    RelationshipProvider relationshipProvider,
    AnalysisProvider analysisProvider,
  ) {
    if (relationshipProvider.relationships.isNotEmpty) {
      return relationshipProvider.filteredRelationships;
    }

    final fallback = analysisProvider.contactInsights;
    if (fallback.isEmpty) {
      return const [];
    }

    if (relationshipProvider.filterType == 'all') {
      return fallback;
    }

    final expectedLabel =
        AppConstants.relationTypeLabels[relationshipProvider.filterType];
    if (expectedLabel == null) {
      return fallback;
    }

    return fallback
        .where(
          (item) =>
              relationshipProvider.relationTypeLabel(item) == expectedLabel,
        )
        .toList();
  }

  bool _matchesContact({
    required ContactInsight insight,
    required String keyword,
    required List<ConversationRecord> records,
  }) {
    final textFields = <String>[
      insight.contactId,
      insight.contactName,
      insight.relationshipLevel,
      insight.referenceTier,
      insight.relationDetail,
      insight.referenceReason,
      AppConstants.displayRelationshipLevel(insight.relationshipLevel),
      AppConstants.displayReferenceTier(insight.referenceTier),
      insight.activityLevel,
      ...insight.keywords,
      ...insight.positiveSignals,
      ...insight.riskPoints,
      ...insight.suggestions,
      ...insight.evidenceQuotes,
      if (insight.giftSuggestion != null) insight.giftSuggestion!.giftName,
      if (insight.giftSuggestion != null) insight.giftSuggestion!.reason,
      if (insight.giftSuggestion != null) insight.giftSuggestion!.occasion,
    ];

    for (final field in textFields) {
      if (_normalize(field).contains(keyword)) {
        return true;
      }
    }

    for (final record in records) {
      if (_normalize(record.contactId).contains(keyword) ||
          _normalize(record.contactName).contains(keyword) ||
          _normalize(record.senderName).contains(keyword) ||
          _normalize(record.searchText).contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  String _labelForFilter(String filterType) {
    if (filterType == 'all') {
      return '全部';
    }
    return AppConstants.relationTypeLabels[filterType] ?? '未知';
  }
}

class _ContactList extends StatelessWidget {
  final List<ContactInsight> list;
  final AnalysisProvider analysisProvider;
  final RelationshipProvider relationshipProvider;

  const _ContactList({
    required this.list,
    required this.analysisProvider,
    required this.relationshipProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.soft,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceSectionHeader(
            title: '优先联系人',
            subtitle: list.isEmpty
                ? '先从搜索和筛选里找到候选，再进入单人详情页查看证据和下一步。'
                : '列表按当前筛选和搜索结果收敛，优先处理更值得跟进的人。',
            trailing: WorkspaceTag('${list.length} 位'),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: WorkspaceHint(
                icon: Icons.person_off_outlined,
                tint: theme.colorScheme.primary,
                child: Text(
                  '没有匹配到联系人。你可以试试联系人名字、聊天关键词、某句原话或发言人名称。',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            )
          else
            Column(
              children: list.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final relationType =
                    relationshipProvider.relationTypeLabel(item);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StaggeredFadeIn(
                    index: index,
                    child: HoverCard(
                      onTap: () {
                        analysisProvider.selectContact(item.contactId);
                        relationshipProvider.selectRelation(item);
                        Navigator.of(context).pushNamed(
                          AppRoutes.contactDetail,
                          arguments: item.contactId,
                        );
                      },
                      tone: index == 0
                          ? HoverCardTone.focus
                          : HoverCardTone.standard,
                      borderRadius: BorderRadius.circular(28),
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final compact = cardConstraints.maxWidth < 640;
                          final scoreCard = Container(
                            width: compact ? double.infinity : 118,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary
                                      .withValues(alpha: 0.13),
                                  theme.colorScheme.surface
                                      .withValues(alpha: 0.82),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.intimacyScore.toStringAsFixed(1),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '参考分',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );

                          final titleBlock = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.contactName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$relationType · ${item.activityLevel}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.64),
                                ),
                              ),
                            ],
                          );

                          final statusTags = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (item.referenceTier.isNotEmpty)
                                WorkspaceTag(
                                  AppConstants.displayReferenceTier(
                                    item.referenceTier,
                                  ),
                                ),
                              if (item.relationDetail.isNotEmpty)
                                WorkspaceTag(item.relationDetail),
                              WorkspaceTag(
                                AppConstants.displayRelationshipLevel(
                                  item.relationshipLevel,
                                ),
                              ),
                            ],
                          );

                          final cueTags = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (item.suggestions.isNotEmpty)
                                WorkspaceTag('动作 · ${item.suggestions.first}'),
                              if (item.riskPoints.isNotEmpty)
                                WorkspaceTag('风险 · ${item.riskPoints.first}'),
                            ],
                          );

                          final evidenceCard = Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(
                              14,
                              12,
                              14,
                              12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface
                                  .withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.38),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '证据摘要',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.64),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _buildSnippet(item),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(height: 1.55),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildGradientAvatar(item, relationType),
                                    const SizedBox(width: 14),
                                    Expanded(child: titleBlock),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                scoreCard,
                                const SizedBox(height: 12),
                                statusTags,
                                const SizedBox(height: 10),
                                cueTags,
                                const SizedBox(height: 10),
                                evidenceCard,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildGradientAvatar(item, relationType),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: titleBlock),
                                        const SizedBox(width: 12),
                                        scoreCard,
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    statusTags,
                                    const SizedBox(height: 10),
                                    cueTags,
                                    const SizedBox(height: 10),
                                    evidenceCard,
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _buildSnippet(ContactInsight item) {
    if (item.referenceReason.isNotEmpty) {
      return item.referenceReason;
    }
    if (item.evidenceQuotes.isNotEmpty) {
      return item.evidenceQuotes.first;
    }
    if (item.positiveSignals.isNotEmpty) {
      return item.positiveSignals.first;
    }
    if (item.riskPoints.isNotEmpty) {
      return item.riskPoints.first;
    }
    return '当前还没有可展示的摘要。';
  }

  Widget _buildGradientAvatar(ContactInsight item, String relationType) {
    Color levelColor;
    switch (item.relationshipLevel) {
      case '重点经营':
        levelColor = const Color(0xFF2EC984);
        break;
      case '稳定升温':
        levelColor = AppTheme.primary;
        break;
      case '保持联系':
        levelColor = const Color(0xFFE8A838);
        break;
      default:
        // Hash the name to pick a vibrant color
        final colors = [
          const Color(0xFF4F46E5), // Indigo
          const Color(0xFFEC4899), // Pink
          const Color(0xFF0EA5E9), // Light Blue
          const Color(0xFF8B5CF6), // Violet
          const Color(0xFF14B8A6), // Teal
          const Color(0xFFF59E0B), // Amber
        ];
        final hash = item.contactName.codeUnits.fold<int>(0, (p, c) => p + c);
        levelColor = colors[hash % colors.length];
        break;
    }

    final hasDigitOrSymbol = RegExp(r'^[0-9+\-@#\$%&*!]').hasMatch(
      item.contactName.isNotEmpty ? item.contactName.substring(0, 1) : '',
    );

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            levelColor.withValues(alpha: 0.7),
            levelColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: hasDigitOrSymbol
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
            : Text(
                item.contactName.isNotEmpty
                    ? item.contactName.characters.first
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}

class _TypeChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TypeChip> createState() => _TypeChipState();
}

class _TypeChipState extends State<_TypeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = widget.selected
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : theme.colorScheme.onSurface.withValues(
            alpha: _hovered ? 0.08 : 0.04,
          );
    final border = widget.selected
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.22)
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.08);
    final textColor = widget.selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoDataCard extends StatelessWidget {
  const _NoDataCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverCard(
      tone: HoverCardTone.soft,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('还没有联系人数据', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            '先去导入页上传微信或 QQ 的聊天记录文件，系统会自动生成联系人列表，并给出关系强弱判断。',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
