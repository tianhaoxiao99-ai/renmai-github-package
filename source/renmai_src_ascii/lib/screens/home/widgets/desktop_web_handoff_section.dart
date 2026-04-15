import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/services/web_handoff_service.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';

class DesktopWebHandoffSection extends StatelessWidget {
  final VoidCallback onOpenImport;
  final VoidCallback onOpenReport;

  const DesktopWebHandoffSection({
    super.key,
    required this.onOpenImport,
    required this.onOpenReport,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, analysis, _) {
        final report = analysis.currentReport;
        final latestPackage = analysis.importedPackages.isNotEmpty
            ? analysis.importedPackages.first
            : null;
        final contactCount = report?.contactInsights.length ?? 0;
        final reportState =
            report == null ? '等待生成' : (report.usedAi ? 'AI 增强报告' : '本地报告');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WorkspaceSectionHeader(
              title: '桌面端与 Web 端交接',
              subtitle: '桌面端负责直读和本地整理，网页版负责查看结果、继续经营和在线追问。只需要一份桥接包，不会改掉你原来的流程。',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1080;
                final desktopCard = _HandoffInfoCard(
                  eyebrow: 'Desktop',
                  title: '本地直读和原始整理，继续在桌面端完成',
                  body: '电脑版微信直读、本地多年记录导入、原始附件补充，都继续留在桌面端，不需要为了互通改掉当前用法。',
                  bullets: [
                    latestPackage == null
                        ? '当前还没有导入数据，先从“导入”页开始。'
                        : '最近一次导入：${latestPackage.contactCount} 位联系人 / ${latestPackage.messageCount} 条消息。',
                    '当前报告状态：$reportState。',
                    '桌面工作区继续独立保存，不会因为交接给网页端而被覆盖。',
                  ],
                  action: OutlinedButton.icon(
                    onPressed: onOpenImport,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('继续在桌面端导入'),
                  ),
                );

                final webCard = _HandoffInfoCard(
                  eyebrow: 'Web',
                  title: '把当前结果带到网页端继续看',
                  body: '导出一份轻量桥接包后，网页端就能继续看联系人、报告、消息建议和礼物，不需要再重复直读微信。',
                  bullets: [
                    report == null
                        ? '先生成一份桌面端报告，再带到网页端会更完整。'
                        : '当前可同步：$contactCount 位联系人、${analysis.records.length} 条消息摘要、1 份报告。',
                    '网页端接收的是“结果桥接包”，不是直接读你的本机数据库。',
                    '原来的“导出网页 JSON / 导入网页 JSON”流程依然保留。',
                  ],
                  action: FilledButton.icon(
                    onPressed: () => showDesktopWebHandoffDialog(context),
                    icon: const Icon(Icons.sync_alt_rounded),
                    label: const Text('打开交接窗口'),
                  ),
                  secondaryAction: TextButton(
                    onPressed: onOpenReport,
                    child: const Text('先看当前报告'),
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      desktopCard,
                      const SizedBox(height: 12),
                      webCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: desktopCard),
                    const SizedBox(width: 16),
                    Expanded(child: webCard),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

Future<void> showDesktopWebHandoffDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DesktopWebHandoffDialog(),
  );
}

class _DesktopWebHandoffDialog extends StatefulWidget {
  const _DesktopWebHandoffDialog();

  @override
  State<_DesktopWebHandoffDialog> createState() =>
      _DesktopWebHandoffDialogState();
}

class _DesktopWebHandoffDialogState extends State<_DesktopWebHandoffDialog> {
  bool _busy = false;
  String? _lastExportPath;
  String? _feedback;
  bool _feedbackIsError = false;

  Future<void> _exportBridge({required bool chooseLocation}) async {
    final provider = context.read<AnalysisProvider>();
    String? outputPath;
    if (chooseLocation) {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存仁迈网页版交接包',
        fileName: WebHandoffService.defaultBridgeFileName(),
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      if (!outputPath.toLowerCase().endsWith('.json')) {
        outputPath = '$outputPath.json';
      }
    }

    setState(() {
      _busy = true;
      _feedback = null;
      _feedbackIsError = false;
    });

    try {
      final file =
          await provider.exportWebBridgePackage(outputPath: outputPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _lastExportPath = file.path;
        _feedback = chooseLocation
            ? '交接包已另存为 JSON。接下来到网页版点“接收桌面交接包”。'
            : '交接包已直接放到桌面。接下来到网页版点“接收桌面交接包”。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _feedbackIsError = true;
        _feedback = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openExportFolder() async {
    final exportPath = _lastExportPath;
    if (exportPath == null || exportPath.trim().isEmpty) {
      return;
    }
    final folderPath = File(exportPath).parent.path;
    try {
      await Process.start('explorer.exe', [folderPath]);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackIsError = true;
        _feedback = '导出已成功，但系统没有打开文件夹。你可以手动去这个路径查看。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysis = context.watch<AnalysisProvider>();
    final report = analysis.currentReport;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: WorkspaceSurface(
          tone: WorkspaceSurfaceTone.emphasis,
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          '桌面 / Web 交接窗口',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '这条交接是额外能力。桌面端继续负责直读微信和本地整理；网页版继续负责在线查看结果、继续经营和 AI 追问。',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.76),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatPill(
                    label: '联系人',
                    value: '${report?.contactInsights.length ?? 0}',
                    icon: Icons.people_alt_rounded,
                  ),
                  _StatPill(
                    label: '消息',
                    value: '${analysis.records.length}',
                    icon: Icons.forum_rounded,
                  ),
                  _StatPill(
                    label: '当前报告',
                    value: report == null
                        ? '等待生成'
                        : (report.usedAi ? 'AI 增强' : '本地报告'),
                    icon: Icons.analytics_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 760;
                  final exportCard = _DialogCard(
                    title: '把桌面结果导给网页版',
                    body:
                        '导出的桥接包会把联系人、报告、消息摘要和礼物线索整理成网页端能直接接收的 JSON。它不会改掉你的桌面工作区，也不会让网页版直接读你的微信数据库。',
                    steps: const [
                      '1. 在桌面端完成直读或导入，先得到一份当前报告。',
                      '2. 点下面按钮导出桌面桥接包。',
                      '3. 去网页版点“接收桌面交接包”，继续看结果。',
                    ],
                    footer: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _exportBridge(chooseLocation: false),
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_rounded),
                              label: Text(_busy ? '正在导出...' : '导出到桌面'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _exportBridge(chooseLocation: true),
                              icon: const Icon(Icons.save_as_rounded),
                              label: const Text('另存为...'),
                            ),
                            if (_lastExportPath != null)
                              TextButton.icon(
                                onPressed: _busy ? null : _openExportFolder,
                                icon: const Icon(Icons.folder_open_rounded),
                                label: const Text('打开所在文件夹'),
                              ),
                          ],
                        ),
                        if (_lastExportPath != null) ...[
                          const SizedBox(height: 12),
                          _PathBox(path: _lastExportPath!),
                        ],
                      ],
                    ),
                  );

                  final webCard = _DialogCard(
                    title: '网页版接力做什么',
                    body:
                        '网页版继续负责看结果、点联系人、看报告、看礼物和在线追问。它不替代桌面直读，只承接桌面已经整理好的结果。',
                    steps: const [
                      '网页版可接收桌面桥接包，也保留原来的网页 JSON 导入。',
                      '接收后默认先回总览，再按“总览 → 联系人 → 报告 → 消息 → 礼物”继续走。',
                      '需要再次直读微信本地数据库时，仍然回桌面端。',
                    ],
                    footer: Text(
                      '建议对外把这条链路讲成：桌面端做重整理，网页版做轻查看和继续经营。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        height: 1.6,
                      ),
                    ),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        exportCard,
                        const SizedBox(height: 12),
                        webCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: exportCard),
                      const SizedBox(width: 12),
                      Expanded(child: webCard),
                    ],
                  );
                },
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (_feedbackIsError
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: (_feedbackIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    _feedback!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _feedbackIsError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HandoffInfoCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
  final Widget action;
  final Widget? secondaryAction;

  const _HandoffInfoCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
    required this.action,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverCard(
      tone: HoverCardTone.soft,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: WorkspaceSurface(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EyebrowPill(label: eyebrow),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                height: 1.65,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            ...bullets.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BulletLine(text: item),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                action,
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogCard extends StatelessWidget {
  final String title;
  final String body;
  final List<String> steps;
  final Widget footer;

  const _DialogCard({
    required this.title,
    required this.body,
    required this.steps,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceSurface(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
              height: 1.55,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          ...steps.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BulletLine(text: item),
            ),
          ),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _EyebrowPill extends StatelessWidget {
  final String label;

  const _EyebrowPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              height: 1.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PathBox extends StatelessWidget {
  final String path;

  const _PathBox({
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.26),
        ),
      ),
      child: SelectableText(
        path,
        style: theme.textTheme.bodySmall?.copyWith(
          height: 1.55,
        ),
        maxLines: 2,
      ),
    );
  }
}
