import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_routes.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/comparison_report.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/relationship_provider.dart';
import 'package:renmai/screens/contacts/contacts_screen.dart';
import 'package:renmai/screens/feedback/platform_feedback_screen.dart';
import 'package:renmai/screens/home/dashboard_workbench.dart';
import 'package:renmai/screens/home/widgets/home_overview_sections.dart';
import 'package:renmai/screens/import/import_screen.dart';
import 'package:renmai/screens/report/report_screen.dart';
import 'package:renmai/screens/settings/ai_settings_screen.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeSection _selectedSection = HomeSection.overview;

  static const List<_SectionNavigation> _navigation = [
    _SectionNavigation(
      section: HomeSection.overview,
      icon: Icons.dashboard_rounded,
      label: '总览',
      keywords: ['首页', '总览', '工作台', 'dashboard', 'home'],
    ),
    _SectionNavigation(
      section: HomeSection.importData,
      icon: Icons.upload_file_rounded,
      label: '导入',
      keywords: ['导入', '采集', '微信', 'qq', '记录', 'import'],
    ),
    _SectionNavigation(
      section: HomeSection.report,
      icon: Icons.analytics_rounded,
      label: '报告',
      keywords: ['报告', '分析', '结果', '洞察', 'report'],
    ),
    _SectionNavigation(
      section: HomeSection.suggestions,
      icon: Icons.auto_awesome_rounded,
      label: '建议',
      keywords: ['建议', '反馈', '行动', '礼物', 'gift', 'plan'],
    ),
    _SectionNavigation(
      section: HomeSection.contacts,
      icon: Icons.people_rounded,
      label: '联系人',
      keywords: ['联系人', '关系', '好友', '人脉', 'contact', 'people'],
    ),
    _SectionNavigation(
      section: HomeSection.settings,
      icon: Icons.tune_rounded,
      label: '设置',
      keywords: ['设置', '配置', 'ai', '模型', 'setting'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AnalysisProvider>().initialize();
    });
  }

  void _openSection(HomeSection section) {
    if (_selectedSection == section) {
      return;
    }
    setState(() => _selectedSection = section);
  }

  Widget _buildPageForSection(
    HomeSection section,
    AnalysisProvider analysis,
    RelationshipProvider relation,
  ) {
    switch (section) {
      case HomeSection.overview:
        return DashboardWorkbench(onOpenSection: _openSection);
      case HomeSection.importData:
        return ImportScreen(
          onOpenSection: (index) => _openSection(
            index == 2
                ? HomeSection.report
                : index == 3
                    ? HomeSection.suggestions
                    : index == 4
                        ? HomeSection.contacts
                        : index == 5
                            ? HomeSection.settings
                            : HomeSection.importData,
          ),
        );
      case HomeSection.report:
        return const ReportScreen();
      case HomeSection.suggestions:
        return PlatformFeedbackScreen(
          onGoImport: () => _openSection(HomeSection.importData),
        );
      case HomeSection.contacts:
        return const ContactsScreen();
      case HomeSection.settings:
        return const AiSettingsScreen();
    }
  }

  int _sectionIndex(HomeSection section) {
    switch (section) {
      case HomeSection.overview:
        return 0;
      case HomeSection.importData:
        return 1;
      case HomeSection.report:
        return 2;
      case HomeSection.suggestions:
        return 3;
      case HomeSection.contacts:
        return 4;
      case HomeSection.settings:
        return 5;
    }
  }

  String _sectionLabel(HomeSection section) {
    for (final item in _navigation) {
      if (item.section == section) {
        return item.label;
      }
    }
    return '工作台';
  }

  String _focusSummary(
    ContactInsight? focusInsight,
    AnalysisProvider analysis,
  ) {
    if (focusInsight == null) {
      if (analysis.hasData) {
        return '已经有导入内容了，下一步优先看报告和建议，不必重新翻全量聊天。';
      }
      return '先完成第一批导入，系统才会开始判断重点联系人和节奏风险。';
    }

    final risks = focusInsight.riskPoints
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (risks.isNotEmpty) {
      return '当前最需要注意：${risks.first}';
    }

    final suggestions = focusInsight.suggestions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (suggestions.isNotEmpty) {
      return '下一步建议：${suggestions.first}';
    }

    final positives = focusInsight.positiveSignals
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (positives.isNotEmpty) {
      return positives.first;
    }

    return '先围绕这位联系人继续推进，不要把注意力重新散回全列表。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<AnalysisProvider, RelationshipProvider>(
      builder: (context, analysis, relation, _) {
        final insights =
            analysis.currentReport?.contactInsights ?? const <ContactInsight>[];
        ContactInsight? focusInsight;
        if (insights.isNotEmpty) {
          final selectedId = analysis.selectedContactId;
          if (selectedId != null) {
            for (final item in insights) {
              if (item.contactId == selectedId) {
                focusInsight = item;
                break;
              }
            }
          }
          focusInsight ??= insights.first;
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? AppTheme.darkPageGradient
                    : AppTheme.lightPageGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.surface.withValues(
                              alpha: isDark ? 0.06 : 0.32,
                            ),
                            Colors.transparent,
                            theme.colorScheme.surface.withValues(
                              alpha: isDark ? 0.02 : 0.1,
                            ),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      _SideDock(
                        selectedSection: _selectedSection,
                        onSelect: _openSection,
                        navigation: _navigation,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Column(
                            children: [
                              _WorkspaceFocusStrip(
                                currentSectionLabel:
                                    _sectionLabel(_selectedSection),
                                focusName: focusInsight?.contactName,
                                focusSummary:
                                    _focusSummary(focusInsight, analysis),
                                hasReport: analysis.currentReport != null,
                                hasData: analysis.hasData,
                                onOpenReport: () =>
                                    _openSection(HomeSection.report),
                                onOpenSuggestions: () =>
                                    _openSection(HomeSection.suggestions),
                                onOpenImport: () =>
                                    _openSection(HomeSection.importData),
                                onOpenFocus: focusInsight == null
                                    ? null
                                    : () {
                                        analysis.selectContact(
                                          focusInsight!.contactId,
                                        );
                                        Navigator.of(context).pushNamed(
                                          AppRoutes.contactDetail,
                                          arguments: focusInsight.contactId,
                                        );
                                      },
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: RepaintBoundary(
                                    key: ValueKey(_selectedSection),
                                    child: IndexedStack(
                                      index: _sectionIndex(_selectedSection),
                                      children: [
                                        _buildPageForSection(
                                          HomeSection.overview,
                                          analysis,
                                          relation,
                                        ),
                                        _buildPageForSection(
                                          HomeSection.importData,
                                          analysis,
                                          relation,
                                        ),
                                        _buildPageForSection(
                                          HomeSection.report,
                                          analysis,
                                          relation,
                                        ),
                                        _buildPageForSection(
                                          HomeSection.suggestions,
                                          analysis,
                                          relation,
                                        ),
                                        _buildPageForSection(
                                          HomeSection.contacts,
                                          analysis,
                                          relation,
                                        ),
                                        _buildPageForSection(
                                          HomeSection.settings,
                                          analysis,
                                          relation,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceFocusStrip extends StatelessWidget {
  final String currentSectionLabel;
  final String? focusName;
  final String focusSummary;
  final bool hasReport;
  final bool hasData;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSuggestions;
  final VoidCallback onOpenImport;
  final VoidCallback? onOpenFocus;

  const _WorkspaceFocusStrip({
    required this.currentSectionLabel,
    required this.focusName,
    required this.focusSummary,
    required this.hasReport,
    required this.hasData,
    required this.onOpenReport,
    required this.onOpenSuggestions,
    required this.onOpenImport,
    required this.onOpenFocus,
  });

  @override
  Widget build(BuildContext context) {
    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      borderRadius: BorderRadius.circular(26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final info = _FocusStripInfo(
            currentSectionLabel: currentSectionLabel,
            focusName: focusName,
            focusSummary: focusSummary,
          );
          final actions = _FocusStripActions(
            hasReport: hasReport,
            hasData: hasData,
            onOpenReport: onOpenReport,
            onOpenSuggestions: onOpenSuggestions,
            onOpenImport: onOpenImport,
            onOpenFocus: onOpenFocus,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: info),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _FocusStripInfo extends StatelessWidget {
  final String currentSectionLabel;
  final String? focusName;
  final String focusSummary;

  const _FocusStripInfo({
    required this.currentSectionLabel,
    required this.focusName,
    required this.focusSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            WorkspaceTag('当前页面 · $currentSectionLabel'),
            WorkspaceTag(
              focusName == null ? '等待识别重点对象' : '当前焦点 · $focusName',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          focusName == null ? '当前还没有重点对象。' : '当前焦点：$focusName',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          focusSummary,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            height: 1.55,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FocusStripActions extends StatelessWidget {
  final bool hasReport;
  final bool hasData;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSuggestions;
  final VoidCallback onOpenImport;
  final VoidCallback? onOpenFocus;

  const _FocusStripActions({
    required this.hasReport,
    required this.hasData,
    required this.onOpenReport,
    required this.onOpenSuggestions,
    required this.onOpenImport,
    required this.onOpenFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (onOpenFocus != null)
              OutlinedButton.icon(
                onPressed: onOpenFocus,
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('打开重点联系人'),
              ),
            if (hasReport)
              OutlinedButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.analytics_rounded, size: 18),
                label: const Text('看报告'),
              ),
            if (hasData)
              OutlinedButton.icon(
                onPressed: onOpenSuggestions,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('看建议'),
              ),
            OutlinedButton.icon(
              onPressed: onOpenImport,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(hasData ? '继续导入' : '先去导入'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FocusPill(
              icon: Icons.flag_rounded,
              label: hasReport ? '报告已就绪' : '待生成报告',
            ),
            _FocusPill(
              icon: Icons.layers_rounded,
              label: hasData ? '已有关系上下文' : '尚无导入',
            ),
            _FocusPill(
              icon: Icons.route_rounded,
              label: onOpenFocus != null ? '可直达详情' : '先走导入',
            ),
          ],
        ),
      ],
    );
  }
}

class _FocusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FocusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _SideDock extends StatelessWidget {
  final HomeSection selectedSection;
  final ValueChanged<HomeSection> onSelect;
  final List<_SectionNavigation> navigation;

  const _SideDock({
    required this.selectedSection,
    required this.onSelect,
    required this.navigation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 760;
          final ultraCompact = constraints.maxHeight < 690;
          final dockWidth = ultraCompact ? 96.0 : (compact ? 102.0 : 108.0);
          final outerPadding = ultraCompact ? 12.0 : 16.0;
          final logoSize = ultraCompact ? 48.0 : 56.0;
          final logoRadius = ultraCompact ? 16.0 : 18.0;
          final dividerSpacing = ultraCompact ? 10.0 : 14.0;
          final titleGap = ultraCompact ? 8.0 : 12.0;

          return Container(
            width: dockWidth,
            padding: EdgeInsets.symmetric(
              vertical: outerPadding,
              horizontal: ultraCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? AppTheme.darkSurface : AppTheme.lightSurface)
                      .withValues(alpha: isDark ? 0.96 : 0.95),
                  (isDark
                          ? AppTheme.darkSurfaceSoft
                          : AppTheme.lightSurfaceSoft)
                      .withValues(alpha: isDark ? 0.92 : 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkStroke.withValues(alpha: 0.54)
                    : AppTheme.lightStroke.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow
                      .withValues(alpha: isDark ? 0.18 : 0.06),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.06 : 0.03,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.18),
                        AppTheme.sun.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(logoRadius),
                  ),
                  child: Icon(
                    Icons.hub_rounded,
                    color: theme.colorScheme.primary,
                    size: ultraCompact ? 24 : 26,
                  ),
                ),
                SizedBox(height: titleGap),
                Text(
                  '仁迈',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '桌面工作台',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                    fontSize: ultraCompact ? 10.5 : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: titleGap),
                Container(
                  width: double.infinity,
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: theme.dividerColor.withValues(alpha: 0.45),
                ),
                SizedBox(height: dividerSpacing),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: ultraCompact ? 2 : 4,
                      ),
                      child: Column(
                        children: navigation
                            .map(
                              (item) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: ultraCompact ? 6 : 8,
                                ),
                                child: _DockButton(
                                  icon: item.icon,
                                  label: item.label,
                                  isSelected: selectedSection == item.section,
                                  onTap: () => onSelect(item.section),
                                  compact: compact,
                                  ultraCompact: ultraCompact,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      '桌面工作台',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final bool ultraCompact;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
    this.ultraCompact = false,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dense = widget.compact || widget.ultraCompact;
    final iconColor = widget.isSelected
        ? theme.colorScheme.primary
        : isDark
            ? theme.colorScheme.onSurface
                .withValues(alpha: _isHovered ? 0.92 : 0.7)
            : theme.colorScheme.onSurface
                .withValues(alpha: _isHovered ? 0.88 : 0.62);

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: widget.ultraCompact ? 72 : (widget.compact ? 78 : 84),
            padding: EdgeInsets.symmetric(
              vertical: widget.ultraCompact ? 9 : (widget.compact ? 10 : 12),
              horizontal: widget.ultraCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        AppTheme.sun.withValues(alpha: isDark ? 0.08 : 0.06),
                      ],
                    )
                  : isDark
                      ? LinearGradient(
                          colors: [
                            theme.colorScheme.primary
                                .withValues(alpha: _isHovered ? 0.06 : 0.0),
                            theme.colorScheme.surface
                                .withValues(alpha: _isHovered ? 0.04 : 0.0),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            theme.colorScheme.primary
                                .withValues(alpha: _isHovered ? 0.05 : 0.0),
                            theme.colorScheme.surface
                                .withValues(alpha: _isHovered ? 0.03 : 0.0),
                          ],
                        ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : theme.dividerColor.withValues(
                        alpha: _isHovered ? 0.16 : 0.0,
                      ),
              ),
              boxShadow: (widget.isSelected || _isHovered)
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(
                          alpha: isDark
                              ? (widget.isSelected ? 0.14 : 0.08)
                              : (widget.isSelected ? 0.05 : 0.025),
                        ),
                        blurRadius: widget.isSelected ? 12 : 10,
                        offset: Offset(0, widget.isSelected ? 6 : 4),
                      ),
                      if (_isHovered || widget.isSelected)
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: widget.isSelected ? 0.05 : 0.03,
                          ),
                          blurRadius: widget.isSelected ? 12 : 10,
                          offset: const Offset(0, 6),
                        ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Container(
                  width: dense ? 32 : 36,
                  height: dense ? 32 : 36,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? Colors.white.withValues(alpha: isDark ? 0.12 : 0.68)
                        : theme.colorScheme.surface.withValues(
                            alpha: _isHovered ? 0.82 : 0.74,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.16)
                          : theme.dividerColor.withValues(
                              alpha: _isHovered ? 0.14 : 0.1,
                            ),
                    ),
                  ),
                  child: Icon(widget.icon, color: iconColor, size: 18),
                ),
                SizedBox(height: dense ? 4 : 6),
                Text(
                  widget.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: iconColor,
                    fontWeight:
                        widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: widget.ultraCompact ? 10.5 : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionNavigation {
  final HomeSection section;
  final IconData icon;
  final String label;
  final List<String> keywords;

  const _SectionNavigation({
    required this.section,
    required this.icon,
    required this.label,
    required this.keywords,
  });
}
