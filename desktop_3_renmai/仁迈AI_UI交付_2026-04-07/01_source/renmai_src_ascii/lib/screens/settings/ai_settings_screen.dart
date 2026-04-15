import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/ai_provider_config.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/providers/display_settings_provider.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  bool _enabled = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<AnalysisProvider>().aiConfig;
    _baseUrlController = TextEditingController(text: config.baseUrl);
    _apiKeyController = TextEditingController(text: config.apiKey);
    _modelController = TextEditingController(text: config.model);
    _enabled = config.enabled;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = AiProviderConfig(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      enabled: _enabled,
    );
    await context.read<AnalysisProvider>().saveAiConfig(config);
  }

  Future<void> _confirmClearWorkspace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重置工作区'),
          content: const Text(
            '这会清空导入记录、聊天内容、当前报告和当前选择，但会保留主题和 AI 配置。确认后不可恢复。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认重置'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await context.read<AnalysisProvider>().clearWorkspace();
    }
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AnalysisProvider, DisplaySettingsProvider>(
      builder: (context, provider, displaySettings, _) {
        final theme = Theme.of(context);
        final aiConfigReady = provider.aiConfig.isReady;
        final canRunAi = !provider.isAnalyzing &&
            provider.hasData &&
            provider.aiConfig.enabled;
        final activePalette = AppTheme.paletteFor(displaySettings.themePreset);

        return WorkspacePage(
          eyebrow: '设置中心',
          title: '把仁迈调成更顺手的工作台',
          subtitle: '外观、AI 连接和维护动作都收在同一页，调整时更少打扰。',
          actions: [
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存设置'),
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkspaceSurface(
                  tone: WorkspaceSurfaceTone.emphasis,
                  tint: activePalette.primary,
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '先把界面调顺，再把 AI 接上。',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '这页把主题、对比度、AI 连接和清理入口放在一起，少跳转，少找按钮。',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.76),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 250),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.end,
                              children: [
                                WorkspaceTag('当前主题 ${activePalette.label}'),
                                WorkspaceTag(
                                  _themeModeLabel(displaySettings.themeMode),
                                ),
                                WorkspaceTag(
                                  displaySettings.highContrast
                                      ? '高对比已开'
                                      : '标准显示',
                                ),
                                WorkspaceTag(
                                  provider.hasData ? '已有数据' : '尚未导入',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          WorkspaceStatPill(
                            icon: Icons.palette_outlined,
                            label: '当前主题',
                            value: activePalette.label,
                          ),
                          WorkspaceStatPill(
                            icon: Icons.light_mode_outlined,
                            label: '外观模式',
                            value: _themeModeLabel(displaySettings.themeMode),
                          ),
                          WorkspaceStatPill(
                            icon: Icons.contrast_rounded,
                            label: '高对比',
                            value: displaySettings.highContrast ? '已开启' : '标准',
                          ),
                          WorkspaceStatPill(
                            icon: Icons.storage_rounded,
                            label: '当前数据',
                            value: provider.hasData ? '已导入' : '待导入',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1060;
                    final appearancePanel = FadeInWidget(
                      delay: const Duration(milliseconds: 20),
                      child: HoverCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const WorkspaceSectionHeader(
                              title: '外观与主题',
                              subtitle: '先把界面调成你愿意长期盯着的样子，再决定其他设置。',
                            ),
                            const SizedBox(height: 16),
                            Text('显示模式', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 10),
                            SegmentedButton<ThemeMode>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.devices_rounded, size: 18),
                                  label: Text('跟随系统'),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  icon:
                                      Icon(Icons.light_mode_rounded, size: 18),
                                  label: Text('浅色'),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                                  label: Text('深色'),
                                ),
                              ],
                              selected: {displaySettings.themeMode},
                              onSelectionChanged: (selection) {
                                if (selection.isEmpty) {
                                  return;
                                }
                                displaySettings.setThemeMode(selection.first);
                              },
                            ),
                            const SizedBox(height: 18),
                            Text('主题风格', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            Text(
                              '每套主题都会保留同样的层级，只切换背景气质、主色和表面温度。',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 880;
                                final cardWidth = compact
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 12) / 2;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: AppTheme.palettes
                                      .map(
                                        (palette) => SizedBox(
                                          width: cardWidth,
                                          child: _ThemePresetCard(
                                            palette: palette,
                                            selected:
                                                displaySettings.themePreset ==
                                                    palette.preset,
                                            onTap: () => displaySettings
                                                .setThemePreset(palette.preset),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.contrast_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '高对比模式',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '让标题、正文和重点区域的区分更明显，适合长时间阅读。',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Switch.adaptive(
                                    value: displaySettings.highContrast,
                                    onChanged: displaySettings.setHighContrast,
                                    activeThumbColor: theme.colorScheme.primary,
                                    activeTrackColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.35),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            WorkspaceHint(
                              icon: Icons.lightbulb_outline_rounded,
                              child: Text(
                                '主题调整会立即生效，不需要额外保存；如果你只想改外观，这里切完就可以直接离开。',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final aiPanel = FadeInWidget(
                      delay: const Duration(milliseconds: 50),
                      child: HoverCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const WorkspaceSectionHeader(
                              title: 'AI 连接',
                              subtitle: '只有你主动开启时，仁迈才会把内容交给外部模型处理。',
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                WorkspaceStatPill(
                                  icon: Icons.toggle_on_outlined,
                                  label: 'AI 开关',
                                  value:
                                      provider.aiConfig.enabled ? '已开启' : '已关闭',
                                ),
                                WorkspaceStatPill(
                                  icon: Icons.key_outlined,
                                  label: '配置完整',
                                  value: aiConfigReady ? '已满足' : '待补全',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color:
                                      theme.dividerColor.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            Icons.bolt_rounded,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '启用 AI 增强',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '关闭后仍可使用本地规则报告，打开后会在需要时调用外部接口。',
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.72),
                                                  height: 1.45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Switch.adaptive(
                                          value: _enabled,
                                          onChanged: (value) =>
                                              setState(() => _enabled = value),
                                          activeThumbColor:
                                              theme.colorScheme.primary,
                                          activeTrackColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.35),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    child: !_enabled
                                        ? Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                18, 0, 18, 18),
                                            child: WorkspaceHint(
                                              icon: Icons.info_outline_rounded,
                                              child: Text(
                                                '打开开关后再填写 Base URL、API Key 和模型名称。这样你可以先保留本地工作流，等准备好再接入外部模型。',
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                          )
                                        : Column(
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18),
                                                child: Divider(
                                                  height: 1,
                                                  color: theme.dividerColor
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(18),
                                                child: Column(
                                                  children: [
                                                    TextField(
                                                      controller:
                                                          _baseUrlController,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText: 'Base URL',
                                                        hintText:
                                                            '例如：https://api.openai.com/v1',
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextField(
                                                      controller:
                                                          _apiKeyController,
                                                      obscureText:
                                                          _obscureApiKey,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: 'API Key',
                                                        suffixIcon: IconButton(
                                                          onPressed: () =>
                                                              setState(
                                                            () => _obscureApiKey =
                                                                !_obscureApiKey,
                                                          ),
                                                          icon: Icon(
                                                            _obscureApiKey
                                                                ? Icons
                                                                    .visibility_off_outlined
                                                                : Icons
                                                                    .visibility_outlined,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextField(
                                                      controller:
                                                          _modelController,
                                                      decoration:
                                                          const InputDecoration(
                                                        labelText: '模型名称',
                                                        hintText:
                                                            '例如：gpt-4.1-mini',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            WorkspaceHint(
                              icon: Icons.tips_and_updates_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('推荐配置',
                                      style: theme.textTheme.titleSmall),
                                  const SizedBox(height: 6),
                                  Text(
                                    '大多数兼容服务只需要 Base URL、API Key 和模型名称。保存后可以直接用“当前数据校验”快速确认配置是否可用。',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: _save,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('保存'),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      canRunAi ? provider.runAiAnalysis : null,
                                  icon: provider.isAnalyzing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded),
                                  label: Text(
                                    provider.isAnalyzing ? '正在校验' : '当前数据校验',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _confirmClearWorkspace,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: const Text('重置工作区'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    final maintenancePanel = FadeInWidget(
                      delay: const Duration(milliseconds: 80),
                      child: WorkspaceHint(
                        icon: Icons.restart_alt_rounded,
                        tint: theme.colorScheme.error,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('工作区维护', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            Text(
                              '清空后会重置导入记录、聊天内容、当前报告和当前选择，但主题和 AI 配置会保留。',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _confirmClearWorkspace,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text('重置工作区'),
                            ),
                          ],
                        ),
                      ),
                    );

                    final privacyPanel = FadeInWidget(
                      delay: const Duration(milliseconds: 100),
                      child: WorkspaceHint(
                        icon: Icons.shield_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('隐私说明', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            Text(
                              '应用不会自动上传聊天记录。只有你手动开启 AI 增强时，系统才会按分块方式提交必要的分析上下文。',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                appearancePanel,
                                const SizedBox(height: 14),
                                maintenancePanel,
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                aiPanel,
                                const SizedBox(height: 14),
                                privacyPanel,
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        appearancePanel,
                        const SizedBox(height: 14),
                        aiPanel,
                        const SizedBox(height: 14),
                        maintenancePanel,
                        const SizedBox(height: 14),
                        privacyPanel,
                      ],
                    );
                  },
                ),
                if ((provider.statusMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  WorkspaceHint(
                    icon: Icons.check_circle_outline_rounded,
                    child: Text(
                      provider.statusMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if ((provider.errorMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  WorkspaceHint(
                    icon: Icons.error_outline_rounded,
                    tint: theme.colorScheme.error,
                    child: Text(
                      provider.errorMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (!_enabled) ...[
                  const SizedBox(height: 10),
                  Text(
                    '提示：启用 AI 之后，报告页和这里的 AI 校验按钮才会可用。',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  final AppThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePresetCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HoverCard(
      onTap: onTap,
      backgroundColor: palette.lightSurface.withValues(alpha: 0.92),
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.previewColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Row(
                    children: palette.previewColors
                        .map(
                          (color) => Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '已选中',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.primaryDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  palette.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? palette.primaryDeep : null,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected
                    ? palette.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            palette.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
