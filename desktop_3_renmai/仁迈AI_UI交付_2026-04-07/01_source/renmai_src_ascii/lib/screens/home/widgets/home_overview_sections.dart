import 'package:flutter/material.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class HomeHeroSection extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final String? supportText;
  final List<Widget> actions;

  const HomeHeroSection({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.supportText,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.16),
                AppTheme.sun.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            badge,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 40,
              height: 1.04,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
              height: 1.6,
            ),
          ),
        ),
        if (supportText != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    supportText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.64),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          WorkspaceSurface(
            tone: WorkspaceSurfaceTone.soft,
            borderRadius: BorderRadius.circular(26),
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions,
            ),
          ),
        ],
      ],
    );
  }
}

class HomeWorkflowSection extends StatelessWidget {
  final List<HomeWorkflowStepData> steps;

  const HomeWorkflowSection({
    super.key,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return const WorkspaceSectionHeader(
      title: '怎么做',
      subtitle: '把聊天记录导入后，系统会按三步完成整理、分析和建议。',
    ).withBody(
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 920;

          if (stacked) {
            return Column(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  _WorkflowStepCard(data: steps[index]),
                  if (index != steps.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          }

          return WorkspaceSurface(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  if (index != 0)
                    Container(
                      width: 1,
                      height: 110,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: theme.dividerColor.withValues(alpha: 0.42),
                    ),
                  Expanded(
                    child: _WorkflowStepCard(
                      data: steps[index],
                      embedded: true,
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

class HomeSnapshotSection extends StatelessWidget {
  final List<HomeSnapshotData> items;

  const HomeSnapshotSection({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return const WorkspaceSectionHeader(
      title: '当前状态',
      subtitle: '只保留最有决策价值的信息，方便你知道现在该做什么。',
    ).withBody(
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 760
              ? 1
              : constraints.maxWidth < 1120
                  ? 2
                  : 3;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 2.9 : 2.1,
            children: items.map((item) => _SnapshotCard(data: item)).toList(),
          );
        },
      ),
    );
  }
}

class HomeStatusPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<HomeSnapshotData> items;

  const HomeStatusPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        return WorkspaceSurface(
          tone: WorkspaceSurfaceTone.emphasis,
          borderRadius: BorderRadius.circular(compact ? 28 : 32),
          padding: EdgeInsets.all(compact ? 20 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 48 : 58,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.72),
                      AppTheme.sun.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  eyebrow,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.6,
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              for (var index = 0; index < items.length; index++) ...[
                _StatusPanelRow(data: items[index]),
                if (index != items.length - 1) ...[
                  const SizedBox(height: 12),
                  Divider(
                    color: theme.dividerColor.withValues(alpha: 0.34),
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class HomeActionRow extends StatelessWidget {
  final List<HomeActionData> actions;

  const HomeActionRow({
    super.key,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return const WorkspaceSectionHeader(
      title: '怎么开始',
      subtitle: '先点最关键的入口，再根据需要继续查看报告或联系人。',
    ).withBody(
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.map((action) => _ActionButton(data: action)).toList(),
      ),
    );
  }
}

class HomeCommandBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const HomeCommandBar({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverCard(
      tone: HoverCardTone.focus,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final button = FilledButton(
            onPressed: onSubmit,
            child: const Text('执行'),
          );

          final searchField = TextField(
            controller: controller,
            onSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              hintText: '输入“导入记录”“查看报告”或“搜索 张三”',
              border: InputBorder.none,
              isDense: true,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: searchField),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: searchField),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

class HomeFocusSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? focusTitle;
  final String? focusBody;
  final List<String> evidence;
  final VoidCallback? onTap;

  const HomeFocusSection({
    super.key,
    required this.title,
    required this.subtitle,
    this.focusTitle,
    this.focusBody,
    this.evidence = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (focusTitle != null) ...[
            Text(
              focusTitle!,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (focusBody != null) ...[
            Text(
              focusBody!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (evidence.isNotEmpty)
            Column(
              children: [
                for (var index = 0; index < evidence.length; index++) ...[
                  _FocusEvidenceLine(text: evidence[index]),
                  if (index != evidence.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );

    return WorkspaceSectionHeader(
      title: title,
      subtitle: subtitle,
      trailing: null,
    ).withBody(
      onTap == null
          ? surface
          : HoverCard(
              onTap: onTap,
              tone: HoverCardTone.focus,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              child: surface,
            ),
    );
  }
}

class HomeWorkflowStepData {
  final String index;
  final String title;
  final String description;

  const HomeWorkflowStepData({
    required this.index,
    required this.title,
    required this.description,
  });
}

class HomeSnapshotData {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const HomeSnapshotData({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });
}

class HomeActionData {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  const HomeActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });
}

enum HomeSection {
  overview,
  importData,
  report,
  suggestions,
  contacts,
  settings,
}

class _WorkflowStepCard extends StatelessWidget {
  final HomeWorkflowStepData data;
  final bool embedded;

  const _WorkflowStepCard({
    required this.data,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.8),
                AppTheme.sun.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.18),
                AppTheme.sun.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            data.index,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          data.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.55,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return WorkspaceSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: content,
    );
  }
}

class _StatusPanelRow extends StatelessWidget {
  final HomeSnapshotData data;

  const _StatusPanelRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.16),
                AppTheme.sun.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            data.icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                data.detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.55,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final HomeSnapshotData data;

  const _SnapshotCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverCard(
      tone: HoverCardTone.focus,
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
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
          const SizedBox(height: 14),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.16),
                  AppTheme.sun.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Icon(data.icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            data.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FocusEvidenceLine extends StatelessWidget {
  final String text;

  const _FocusEvidenceLine({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 36,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final HomeActionData data;

  const _ActionButton({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.primary) {
      return FilledButton.icon(
        onPressed: data.onPressed,
        icon: Icon(data.icon),
        label: Text(data.label),
      );
    }

    return OutlinedButton.icon(
      onPressed: data.onPressed,
      icon: Icon(data.icon),
      label: Text(data.label),
    );
  }
}

extension _WorkspaceSectionBody on WorkspaceSectionHeader {
  Widget withBody(Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this,
        const SizedBox(height: 14),
        body,
      ],
    );
  }
}
