import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:renmai/config/app_theme.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/providers/analysis_provider.dart';
import 'package:renmai/services/import_service.dart';
import 'package:renmai/utils/animation_utils.dart';
import 'package:renmai/widgets/workspace_shell.dart';

String _sourceLabel(String source) {
  switch (source.toLowerCase()) {
    case 'wechat':
      return '微信';
    case 'qq':
      return 'QQ';
    case 'mixed':
      return '微信 + QQ';
    case 'attachment':
      return '附件补充';
    default:
      return '聊天记录';
  }
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

enum _ImportFailureKind {
  timeout,
  environment,
  noWeChatDirectory,
  generic,
}

class _ImportFailurePresentation {
  final _ImportFailureKind kind;
  final IconData icon;
  final Color accent;
  final String title;
  final String lead;
  final List<String> suggestions;

  const _ImportFailurePresentation({
    required this.kind,
    required this.icon,
    required this.accent,
    required this.title,
    required this.lead,
    required this.suggestions,
  });
}

class _ContactChoice {
  final String contactId;
  final String contactName;
  final int messageCount;

  const _ContactChoice({
    required this.contactId,
    required this.contactName,
    required this.messageCount,
  });

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return contactName.toLowerCase().contains(normalized) ||
        contactId.toLowerCase().contains(normalized);
  }
}

class _DeleteSelectionResult {
  final String packageId;
  final bool clearAll;
  final Set<String> contactIds;

  const _DeleteSelectionResult({
    required this.packageId,
    required this.clearAll,
    required this.contactIds,
  });
}

enum _WeChatRawImportMode {
  pickContacts,
  importAll,
}

List<_ContactChoice> _buildContactChoices(
    Iterable<ConversationRecord> records) {
  final counts = <String, int>{};
  final names = <String, String>{};

  for (final record in records) {
    final contactId = record.contactId.trim();
    if (contactId.isEmpty) {
      continue;
    }
    counts[contactId] = (counts[contactId] ?? 0) + 1;
    names.putIfAbsent(contactId, () {
      final contactName = record.contactName.trim();
      return contactName.isEmpty ? contactId : contactName;
    });
  }

  final items = counts.entries
      .map(
        (entry) => _ContactChoice(
          contactId: entry.key,
          contactName: names[entry.key] ?? entry.key,
          messageCount: entry.value,
        ),
      )
      .toList()
    ..sort((a, b) {
      final countCompare = b.messageCount.compareTo(a.messageCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.contactName.compareTo(b.contactName);
    });

  return items;
}

ImportSessionData _filterImportSessionByContacts(
  ImportSessionData session,
  Set<String> selectedContactIds,
) {
  final filteredRecords = session.records
      .where((item) => selectedContactIds.contains(item.contactId))
      .toList(growable: false);
  final totalContactCount =
      session.records.map((item) => item.contactId).toSet().length;
  final selectedContactCount =
      filteredRecords.map((item) => item.contactId).toSet().length;
  final skippedContactCount = totalContactCount - selectedContactCount;
  final warnings = [...session.warnings];

  if (skippedContactCount > 0) {
    warnings.add('这次只导入了已勾选的联系人，另外跳过 $skippedContactCount 位联系人。');
  }

  return ImportSessionData(
    importedPackage: session.importedPackage.copyWith(
      contactCount: selectedContactCount,
      messageCount: filteredRecords.length,
      packageSummary: skippedContactCount > 0
          ? '已导入 $selectedContactCount 位联系人，共 ${filteredRecords.length} 条消息；跳过 $skippedContactCount 位未勾选联系人。'
          : session.importedPackage.packageSummary,
    ),
    records: filteredRecords,
    warnings: warnings,
  );
}

_ImportFailurePresentation _resolveImportFailurePresentation(
  BuildContext context,
  String rawMessage,
) {
  final theme = Theme.of(context);
  final message = rawMessage.trim();
  final normalized = message.toLowerCase();
  final timeoutIssue = normalized.contains('超时') ||
      (message.contains('直读微信本地数据库') && message.contains('还没有完成'));
  final noWeChatDirectory =
      message.contains('没有找到可直读的微信目录') || message.contains('没有找到可直读的微信账号目录');
  final envIssue = normalized.contains('cryptodome') ||
      normalized.contains('python') ||
      message.contains('环境') ||
      message.contains('脚本') ||
      message.contains('运行包') ||
      message.contains('缺少');

  if (timeoutIssue) {
    return const _ImportFailurePresentation(
      kind: _ImportFailureKind.timeout,
      icon: Icons.timer_off_rounded,
      accent: Color(0xFFE98C3D),
      title: '直读等待时间过长',
      lead: '目录已经识别到了，但这次解析耗时太久。先改用更可控的文件入口更稳，稍后再回来重试直读。',
      suggestions: [
        '先用“选择记录文件”继续导入，避免自动扫描把日志或缓存一起带进来。',
        '如果必须直读，请保持电脑版微信登录，再重试一次。',
      ],
    );
  }

  if (noWeChatDirectory) {
    return const _ImportFailurePresentation(
      kind: _ImportFailureKind.noWeChatDirectory,
      icon: Icons.folder_open_rounded,
      accent: Color(0xFF3B82F6),
      title: '没有找到可直读的微信目录',
      lead: '这不是账号对错的问题。当前只是没在常见位置找到可直读目录，你可以手动选目录，或者直接改用文件入口。',
      suggestions: [
        '先确认电脑版微信已经打开并保持登录。',
        '如果微信数据不在默认文档目录，请手动选择 xwechat_files 或具体账号目录。',
        '如果想先继续使用，优先改用“选择记录文件”；只有在导出目录已经整理干净时，再用“扫描导出记录”。',
      ],
    );
  }

  if (envIssue) {
    return _ImportFailurePresentation(
      kind: _ImportFailureKind.environment,
      icon: Icons.build_circle_outlined,
      accent: AppTheme.primary,
      title: '当前直读入口还不可用',
      lead: '这不是你的操作问题。当前运行包缺少直读所需组件或运行环境时，先切到文件入口会更稳。',
      suggestions: const [
        '优先用“选择记录文件”，不需要自己改脚本；只有在导出目录很干净时，再考虑“扫描导出记录”。',
        '如果你必须直读本地数据库，请换带完整直读组件的安装包。',
      ],
    );
  }

  return _ImportFailurePresentation(
    kind: _ImportFailureKind.generic,
    icon: Icons.error_outline_rounded,
    accent: theme.colorScheme.error,
    title: '导入失败',
    lead: '这次没有成功生成可用聊天记录。先切到更稳的入口，或查看技术详情后再决定是否重试。',
    suggestions: const [
      '先试“直读并选择联系人”；如果当前机器不支持，再用“选择记录文件”。',
      '如果问题持续，再展开技术详情排查。',
    ],
  );
}

String _normalizeImportFailureDetails(String rawMessage) {
  return rawMessage
      .trim()
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

Future<void> showImportSuccessDialog(
  BuildContext context,
  ImportedPackage importedPackage,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('已导入 ${importedPackage.contactCount} 位联系人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '仁迈已从${_sourceLabel(importedPackage.source)}整理出 ${importedPackage.messageCount} 条消息。',
            ),
            const SizedBox(height: 12),
            const Text('建议下一步：先看报告，再按联系人和关键词继续翻找。'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('查看结果'),
          ),
        ],
      );
    },
  );
}

Future<void> showImportFailureDialog(
  BuildContext context, {
  required String message,
  VoidCallback? onScanExportRecords,
  VoidCallback? onPickFiles,
}) async {
  final failure = _resolveImportFailurePresentation(context, message);
  final details = _normalizeImportFailureDetails(message);
  final theme = Theme.of(context);

  await showDialog<void>(
    context: context,
    builder: (context) {
      var showDetails = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: WorkspaceSurface(
                tone: WorkspaceSurfaceTone.emphasis,
                borderRadius: BorderRadius.circular(32),
                padding: const EdgeInsets.all(28),
                tint: failure.accent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: failure.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            failure.icon,
                            color: failure.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                failure.title,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                failure.lead,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (failure.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: failure.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: failure.accent.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '建议你先这样处理',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            for (final item in failure.suggestions) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Icon(
                                      Icons.subdirectory_arrow_right_rounded,
                                      size: 16,
                                      color: failure.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item != failure.suggestions.last)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '技术详情',
                            style: theme.textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => showDetails = !showDetails),
                            icon: Icon(
                              showDetails
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: Text(showDetails ? '收起' : '查看'),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: details),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text('技术详情已复制'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('复制'),
                          ),
                        ],
                      ),
                    ],
                    if (showDetails && details.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.72),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            details,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (onPickFiles != null)
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onPickFiles();
                            },
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('选择记录文件'),
                          ),
                        if (onScanExportRecords != null)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onScanExportRecords();
                            },
                            icon: const Icon(Icons.folder_zip_rounded),
                            label: const Text('扫描导出记录'),
                          ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('返回'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<Set<String>?> _showContactSelectionDialog(
  BuildContext context, {
  required List<_ContactChoice> choices,
}) async {
  if (choices.isEmpty) {
    return <String>{};
  }
  if (choices.length == 1) {
    return {choices.single.contactId};
  }

  final allIds = choices.map((item) => item.contactId).toSet();

  return showDialog<Set<String>>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      var query = '';
      final selectedIds = {...allIds};

      return StatefulBuilder(
        builder: (context, setState) {
          final filteredChoices = choices
              .where((item) => item.matches(query))
              .toList(growable: false);

          return AlertDialog(
            title: const Text('选择要导入的联系人'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '直读已经完成。先勾选这次真正要带入仁迈的人，避免把无关群聊或历史联系人一次性全塞进来。',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      WorkspaceTag('共 ${choices.length} 位联系人'),
                      WorkspaceTag('已选 ${selectedIds.length} 位'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: '按联系人名称或 ID 筛选',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          selectedIds
                            ..clear()
                            ..addAll(allIds);
                        }),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('全选'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(selectedIds.clear),
                        icon: const Icon(Icons.remove_done_rounded, size: 18),
                        label: const Text('清空'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredChoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final choice = filteredChoices[index];
                          return CheckboxListTile(
                            value: selectedIds.contains(choice.contactId),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(choice.contactName),
                            subtitle: Text(
                              '${choice.messageCount} 条消息 · ${choice.contactId}',
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedIds.add(choice.contactId);
                                } else {
                                  selectedIds.remove(choice.contactId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop({...selectedIds}),
                child: Text('导入已选 ${selectedIds.length} 位联系人'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<_WeChatRawImportMode?> _showWeChatRawImportModeDialog(
  BuildContext context,
) {
  final theme = Theme.of(context);

  return showDialog<_WeChatRawImportMode>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('选择直读导入方式'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '直读会先从微信本地数据库拉出联系人和聊天内容。推荐先读完再勾选联系人，这样更容易避开无关群聊，也不会把所有历史关系一次性全塞进来。',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 18),
              _ImportModeOptionCard(
                icon: Icons.filter_list_rounded,
                title: '读取后勾选联系人',
                subtitle: '推荐。先读出联系人清单，再只导入这次真正要看的联系人。',
                accent: AppTheme.primary,
                actionLabel: '按联系人筛选导入',
                onTap: () => Navigator.of(context).pop(
                  _WeChatRawImportMode.pickContacts,
                ),
                emphasized: true,
              ),
              const SizedBox(height: 12),
              _ImportModeOptionCard(
                icon: Icons.playlist_add_check_circle_outlined,
                title: '整批直读导入',
                subtitle: '适合你明确知道这次就要整批带进仁迈，不再额外筛联系人。',
                accent: theme.colorScheme.secondary,
                actionLabel: '整批导入',
                onTap: () => Navigator.of(context).pop(
                  _WeChatRawImportMode.importAll,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

class _ImportModeOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final String actionLabel;
  final VoidCallback onTap;
  final bool emphasized;

  const _ImportModeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: emphasized ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withValues(alpha: emphasized ? 0.28 : 0.16),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.78),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onTap,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

Future<_DeleteSelectionResult?> _showDeleteImportedContactsDialog(
  BuildContext context, {
  required ImportedPackage importedPackage,
  required List<_ContactChoice> choices,
}) async {
  if (choices.isEmpty) {
    return null;
  }

  final allIds = choices.map((item) => item.contactId).toSet();

  return showDialog<_DeleteSelectionResult>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      var query = '';
      final selectedIds = {...allIds};

      return StatefulBuilder(
        builder: (context, setState) {
          final filteredChoices = choices
              .where((item) => item.matches(query))
              .toList(growable: false);

          return AlertDialog(
            title: const Text('删除这次导入的内容'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你可以只删掉这次导入中的部分联系人，也可以把这次导入整批移除。来源：${_sourceLabel(importedPackage.source)} · ${_formatDateTime(importedPackage.importedAt)}',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: '按联系人名称或 ID 筛选',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      WorkspaceTag('共 ${choices.length} 位联系人'),
                      WorkspaceTag('已选 ${selectedIds.length} 位'),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          selectedIds
                            ..clear()
                            ..addAll(allIds);
                        }),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('全选'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(selectedIds.clear),
                        icon: const Icon(Icons.remove_done_rounded, size: 18),
                        label: const Text('清空'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredChoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final choice = filteredChoices[index];
                          return CheckboxListTile(
                            value: selectedIds.contains(choice.contactId),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(choice.contactName),
                            subtitle: Text(
                              '${choice.messageCount} 条消息 · ${choice.contactId}',
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedIds.add(choice.contactId);
                                } else {
                                  selectedIds.remove(choice.contactId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  _DeleteSelectionResult(
                    packageId: importedPackage.id,
                    clearAll: true,
                    contactIds: allIds,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('删除本次全部内容'),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          _DeleteSelectionResult(
                            packageId: importedPackage.id,
                            clearAll: false,
                            contactIds: {...selectedIds},
                          ),
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: const Text('删除已选内容'),
              ),
            ],
          );
        },
      );
    },
  );
}

class ImportScreen extends StatefulWidget {
  final ValueChanged<int>? onOpenSection;
  final List<String> Function()? discoverWeChatAccountRoots;

  const ImportScreen({
    super.key,
    this.onOpenSection,
    this.discoverWeChatAccountRoots,
  });

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<String> _selectedPaths = [];

  bool _shouldOfferExportFallback(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('xwechat_files') ||
        normalized.contains('python') ||
        message.contains('微信目录') ||
        message.contains('账号目录') ||
        message.contains('可直读') ||
        message.contains('环境') ||
        message.contains('脚本') ||
        message.contains('直读微信');
  }

  bool _looksLikeWeChatDatabasePath(String path) {
    final normalized = path.replaceAll('/', '\\').toLowerCase();
    return normalized.contains('\\xwechat_files\\') ||
        normalized.endsWith('\\xwechat_files') ||
        normalized.contains('\\wechat files\\') ||
        normalized.endsWith('\\wechat files') ||
        normalized.contains('\\db_storage\\') ||
        normalized.endsWith('\\db_storage') ||
        normalized.contains('\\wxid_');
  }

  Future<String> _readClipboardChatText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text?.trim() ?? '';
  }

  List<String> _discoverWeChatAccountRoots() {
    final loader = widget.discoverWeChatAccountRoots;
    if (loader != null) {
      return loader();
    }
    return ImportService.instance.discoverWeChatBackupAccountRoots();
  }

  String? _latestImportedPackageId(AnalysisProvider provider) {
    if (provider.importedPackages.isEmpty) {
      return null;
    }
    return provider.importedPackages.first.id;
  }

  String? _attachmentTargetLabel(AnalysisProvider provider) {
    final appendName = provider.clipboardAppendContactName;
    if ((appendName ?? '').isNotEmpty) {
      return appendName;
    }
    final selected = provider.selectedContactId;
    if (selected == null || selected.isEmpty) {
      return null;
    }
    return provider.findInsightByContactId(selected)?.contactName;
  }

  Future<ImportSessionData?> _reviewWeChatImportSession(
    ImportSessionData session,
  ) async {
    final choices = _buildContactChoices(session.records);
    if (choices.length <= 1) {
      return session;
    }

    final selectedIds = await _showContactSelectionDialog(
      context,
      choices: choices,
    );
    if (!mounted || selectedIds == null) {
      return null;
    }
    if (selectedIds.isEmpty || selectedIds.length == choices.length) {
      return selectedIds.isEmpty ? null : session;
    }
    return _filterImportSessionByContacts(session, selectedIds);
  }

  Future<void> _showImportFailure(String message) async {
    final offerFallback = _shouldOfferExportFallback(message);
    await showImportFailureDialog(
      context,
      message: message,
      onScanExportRecords: offerFallback ? _startSmartImport : null,
      onPickFiles: offerFallback ? _pickFiles : null,
    );
  }

  Future<void> _showImportManagementDialog(
    AnalysisProvider provider,
    ImportedPackage importedPackage,
  ) async {
    final records = provider.recordsForPackage(importedPackage.id);
    final choices = _buildContactChoices(records);
    if (choices.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('这次导入当前没有可删除的联系人记录。'),
        ),
      );
      return;
    }

    final selection = await _showDeleteImportedContactsDialog(
      context,
      importedPackage: importedPackage,
      choices: choices,
    );
    if (!mounted || selection == null) {
      return;
    }

    final removedIds = selection.clearAll
        ? choices.map((item) => item.contactId).toList(growable: false)
        : selection.contactIds.toList(growable: false);
    await provider.deleteImportedContacts(
      packageId: importedPackage.id,
      contactIds: removedIds,
    );
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择微信 / QQ 聊天记录导出目录',
    );
    if (path == null || !mounted) {
      return;
    }
    setState(() => _selectedPaths = [path]);
    if (_looksLikeWeChatDatabasePath(path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('已识别为微信本地数据库目录，仁迈将直接开始导入。'),
        ),
      );
      await _startImport();
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'html', 'htm', 'zip'],
      dialogTitle: '选择聊天记录文件或导出压缩包',
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _selectedPaths = result.paths.whereType<String>().toList());
  }

  Future<void> _pickAttachmentFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'md',
        'markdown',
        'csv',
        'json',
        'log',
        'png',
        'jpg',
        'jpeg',
        'bmp',
        'webp',
        'mp3',
        'wav',
        'm4a',
        'aac',
        'opus',
        'amr',
        'ogg',
      ],
      dialogTitle: '选择要补充的图片、文本或语音附件',
    );
    if (result == null || !mounted) {
      return;
    }
    final paths = result.paths.whereType<String>().toList();
    if (paths.isEmpty) {
      return;
    }
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.importAttachmentFiles(paths);
    await _handleImportCompletion(provider, previousImportId: previousImportId);
  }

  Future<void> _startImport() async {
    if (_selectedPaths.isEmpty) {
      return;
    }
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.importPaths(_selectedPaths);
    await _handleImportCompletion(
      provider,
      previousImportId: previousImportId,
      clearSelectedPaths: true,
    );
  }

  Future<void> _startSmartImport() async {
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.scanExportRecords();
    await _handleImportCompletion(provider, previousImportId: previousImportId);
  }

  Future<List<String>?> _pickWeChatAccountRoots() async {
    final accountRoots = _discoverWeChatAccountRoots();
    if (accountRoots.isEmpty) {
      final manualPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '手动选择 xwechat_files 或具体账号目录',
      );
      if (manualPath != null && manualPath.trim().isNotEmpty) {
        return [manualPath.trim()];
      }
      await _showImportFailure(
        '没有找到可直读的微信目录。请先打开电脑端微信并保持登录；如果微信数据不在默认目录，请重新点击直读并手动选择 xwechat_files 或具体账号目录。',
      );
      return null;
    }
    if (accountRoots.length == 1) {
      return accountRoots;
    }
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择要读取的微信账号'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.done_all_rounded),
                  title: const Text('读取全部账号'),
                  subtitle: Text('共 ${accountRoots.length} 个账号目录'),
                  onTap: () => Navigator.of(context).pop(accountRoots),
                ),
                const Divider(),
                ...accountRoots.map(
                  (root) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(p.basename(root)),
                    subtitle: Text(root),
                    onTap: () => Navigator.of(context).pop([root]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startWeChatRawImport() async {
    final accountRoots = await _pickWeChatAccountRoots();
    if (!mounted || accountRoots == null || accountRoots.isEmpty) {
      return;
    }
    final importMode = await _showWeChatRawImportModeDialog(context);
    if (!mounted || importMode == null) {
      return;
    }
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.importWeChatLocalBackup(
      accountRoots: accountRoots,
      reviewSession: importMode == _WeChatRawImportMode.pickContacts
          ? _reviewWeChatImportSession
          : null,
    );
    await _handleImportCompletion(
      provider,
      previousImportId: previousImportId,
      clearSelectedPaths: true,
    );
  }

  Future<void> _captureFromChatWindow() async {
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.captureFromChatWindow();
    await _handleImportCompletion(
      provider,
      previousImportId: previousImportId,
      clearSelectedPaths: true,
    );
  }

  Future<void> _appendFromChatWindow() async {
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.appendFromChatWindow();
    await _handleImportCompletion(provider, previousImportId: previousImportId);
  }

  Future<void> _importFromClipboard() async {
    final text = await _readClipboardChatText();
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('剪贴板里还没有聊天文本，请先在微信或 QQ 里复制聊天内容。'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.importClipboardText(text);
    await _handleImportCompletion(
      provider,
      previousImportId: previousImportId,
      clearSelectedPaths: true,
    );
  }

  Future<void> _appendFromClipboard() async {
    final text = await _readClipboardChatText();
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('剪贴板里还没有聊天文本，请先复制一段需要补充的聊天内容。'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    final provider = context.read<AnalysisProvider>();
    final previousImportId = _latestImportedPackageId(provider);
    await provider.appendClipboardText(text);
    await _handleImportCompletion(provider, previousImportId: previousImportId);
  }

  Future<void> _handleImportCompletion(
    AnalysisProvider provider, {
    required String? previousImportId,
    bool clearSelectedPaths = false,
  }) async {
    if (!mounted) {
      return;
    }
    final errorMessage = (provider.errorMessage ?? '').trim();
    if (errorMessage.isNotEmpty) {
      await _showImportFailure(errorMessage);
      return;
    }
    if (provider.importedPackages.isEmpty) {
      return;
    }
    final latestPackage = provider.importedPackages.first;
    final hasNewImport = latestPackage.id != previousImportId;
    final hasUsefulResult =
        latestPackage.contactCount > 0 && latestPackage.messageCount > 0;
    if (!hasNewImport || !hasUsefulResult) {
      return;
    }
    if (clearSelectedPaths && _selectedPaths.isNotEmpty) {
      setState(() => _selectedPaths = []);
    }
    await showImportSuccessDialog(context, latestPackage);
    widget.onOpenSection?.call(2);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        final latestPackage = provider.importedPackages.isNotEmpty
            ? provider.importedPackages.first
            : null;
        final targetLabel = _attachmentTargetLabel(provider);
        final statusText = (provider.statusMessage ?? '').trim();
        final isBusy = provider.isImporting;
        final selectedCount = _selectedPaths.length;
        final onOpenReport = widget.onOpenSection == null
            ? null
            : () => widget.onOpenSection!.call(2);
        final onOpenContacts = widget.onOpenSection == null
            ? null
            : () => widget.onOpenSection!.call(4);

        return WorkspacePage(
          eyebrow: '数据导入',
          title: '把聊天记录整理成可搜索的关系档案',
          subtitle: '直读、扫描、窗口采集、剪贴板和附件补充都集中在这里，普通用户不需要自己改脚本或文件结构。',
          actions: [
            if (latestPackage != null)
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _showImportManagementDialog(
                          provider,
                          latestPackage,
                        ),
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('管理已导入内容'),
              ),
            if (latestPackage != null) const SizedBox(width: 12),
            if (isBusy || _selectedPaths.isNotEmpty)
              FilledButton.icon(
                onPressed: isBusy ? null : _startImport,
                icon: Icon(
                  isBusy ? Icons.sync_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isBusy ? '处理中...' : '开始导入'),
              ),
          ],
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImportHeroPanel(
                  latestPackage: latestPackage,
                  recordCount: provider.records.length,
                  selectedCount: selectedCount,
                  isBusy: isBusy,
                  statusText: statusText,
                  onStartWeChatRawImport: isBusy ? null : _startWeChatRawImport,
                  onStartSmartImport: isBusy ? null : _startSmartImport,
                  onPickFiles: isBusy ? null : _pickFiles,
                  onCaptureFromChatWindow:
                      isBusy ? null : _captureFromChatWindow,
                  onStartSelectedImport:
                      isBusy || _selectedPaths.isEmpty ? null : _startImport,
                ),
                const SizedBox(height: 18),
                _ImportRouteGuidePanel(
                  latestPackage: latestPackage,
                  recordCount: provider.records.length,
                  selectedCount: selectedCount,
                  isBusy: isBusy,
                  statusText: statusText,
                  targetLabel: targetLabel,
                  onStartSelectedImport:
                      isBusy || _selectedPaths.isEmpty ? null : _startImport,
                  onStartSmartImport: isBusy ? null : _startSmartImport,
                  onPickFiles: isBusy ? null : _pickFiles,
                  onCaptureFromChatWindow:
                      isBusy ? null : _captureFromChatWindow,
                  onStartWeChatRawImport: isBusy ? null : _startWeChatRawImport,
                  onOpenReport: onOpenReport,
                  onOpenContacts: onOpenContacts,
                ),
                if (_selectedPaths.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  HoverCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkspaceSectionHeader(
                          title: '当前待导入队列',
                          subtitle:
                              '已选择 $selectedCount 项内容。确认无误后直接开始导入，不需要重复选目录。',
                          trailing: FilledButton.icon(
                            onPressed: isBusy ? null : _startImport,
                            icon: Icon(
                              isBusy
                                  ? Icons.sync_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(isBusy ? '处理中...' : '开始导入'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._selectedPaths.take(5).map(
                              (path) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PathTile(path: path),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1040;
                    final manualPanel = HoverCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const WorkspaceSectionHeader(
                            title: '备用入口',
                            subtitle: '主入口不适合时，再用这些更可控的方式手动补录或导入。',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _QuickActionTile(
                                icon: Icons.folder_open_rounded,
                                title: '选择导出目录',
                                subtitle: '适合已经整理好的聊天导出文件夹。',
                                onTap: isBusy ? null : _pickDirectory,
                              ),
                              _QuickActionTile(
                                icon: Icons.note_add_outlined,
                                title: '选择记录文件',
                                subtitle: '直接选 txt、html 或 zip。',
                                onTap: isBusy ? null : _pickFiles,
                              ),
                              _QuickActionTile(
                                icon: Icons.content_paste_rounded,
                                title: '导入剪贴板文本',
                                subtitle: '适合快速补几段聊天内容。',
                                onTap: isBusy ? null : _importFromClipboard,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    final recentPanel = latestPackage == null
                        ? HoverCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const WorkspaceSectionHeader(
                                  title: '最近一次导入',
                                  subtitle: '当前还没有导入结果，先从上面的主入口开始。',
                                ),
                                const SizedBox(height: 14),
                                WorkspaceHint(
                                  child: Text(
                                    '推荐顺序：先试“直读并选择联系人”；如果当前机器不支持或目录没识别到，再用“选择记录文件”；“扫描导出记录”放在最后。',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : HoverCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                WorkspaceSectionHeader(
                                  title: '最近一次导入',
                                  subtitle:
                                      '${_sourceLabel(latestPackage.source)} · ${_formatDateTime(latestPackage.importedAt)}',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    WorkspaceTag(
                                        '${latestPackage.contactCount} 位联系人'),
                                    WorkspaceTag(
                                        '${latestPackage.messageCount} 条消息'),
                                    WorkspaceTag(
                                        '${latestPackage.discoveredFiles.length} 个文件'),
                                  ],
                                ),
                                if (latestPackage.packageSummary
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(latestPackage.packageSummary),
                                ],
                                if (onOpenReport != null ||
                                    onOpenContacts != null) ...[
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      if (onOpenReport != null)
                                        FilledButton.icon(
                                          onPressed: onOpenReport,
                                          icon: const Icon(
                                            Icons.analytics_rounded,
                                          ),
                                          label: const Text('看报告'),
                                        ),
                                      if (onOpenContacts != null)
                                        OutlinedButton.icon(
                                          onPressed: onOpenContacts,
                                          icon:
                                              const Icon(Icons.people_rounded),
                                          label: const Text('看联系人'),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );

                    if (compact) {
                      return Column(
                        children: [
                          manualPanel,
                          const SizedBox(height: 18),
                          recentPanel,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: manualPanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: recentPanel),
                      ],
                    );
                  },
                ),
                if (targetLabel != null) ...[
                  const SizedBox(height: 18),
                  HoverCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkspaceSectionHeader(
                          title: '继续补充给 $targetLabel',
                          subtitle: '把新抓到的窗口内容、剪贴板文本或附件继续并到这个联系人名下。',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: isBusy ? null : _appendFromChatWindow,
                              icon:
                                  const Icon(Icons.screenshot_monitor_rounded),
                              label: const Text('继续采集窗口'),
                            ),
                            OutlinedButton.icon(
                              onPressed: isBusy ? null : _appendFromClipboard,
                              icon: const Icon(Icons.content_paste_rounded),
                              label: const Text('追加剪贴板内容'),
                            ),
                            OutlinedButton.icon(
                              onPressed: isBusy ? null : _pickAttachmentFiles,
                              icon: const Icon(Icons.attach_file_rounded),
                              label: const Text('补充图片/语音附件'),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _ImportHeroPanel extends StatelessWidget {
  final ImportedPackage? latestPackage;
  final int recordCount;
  final int selectedCount;
  final bool isBusy;
  final String statusText;
  final VoidCallback? onStartWeChatRawImport;
  final VoidCallback? onStartSmartImport;
  final VoidCallback? onPickFiles;
  final VoidCallback? onCaptureFromChatWindow;
  final VoidCallback? onStartSelectedImport;

  const _ImportHeroPanel({
    required this.latestPackage,
    required this.recordCount,
    required this.selectedCount,
    required this.isBusy,
    required this.statusText,
    required this.onStartWeChatRawImport,
    required this.onStartSmartImport,
    required this.onPickFiles,
    required this.onCaptureFromChatWindow,
    required this.onStartSelectedImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestSource =
        latestPackage != null ? _sourceLabel(latestPackage!.source) : '未导入';

    return HoverCard(
      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '推荐主入口',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '默认先用直读，把联系人选准再导进来',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '这台已登录微信的电脑上，首选应该始终是“直读并选择联系人”。扫描和文件入口保留在下面，只作为备用路线。',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 18),
              const WorkspaceSurface(
                tone: WorkspaceSurfaceTone.soft,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    WorkspaceTag('直读优先'),
                    WorkspaceTag('先选联系人'),
                    WorkspaceTag('只导入本次目标'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ImportSignalTag(
                    icon: Icons.hub_outlined,
                    label: '最近来源：$latestSource',
                  ),
                  _ImportSignalTag(
                    icon: Icons.topic_outlined,
                    label: '当前记录：$recordCount 条',
                  ),
                  if (selectedCount > 0)
                    _ImportSignalTag(
                      icon: Icons.inventory_2_outlined,
                      label: '已选择：$selectedCount 项',
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.22),
                      const Color(0xFFFFF8F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.storage_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '默认首选',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '直读并选择联系人',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '先读出联系人清单，再只把这次真正要分析的人带进仁迈。这样既能避开日志误扫，也不会一口气把所有历史关系都塞进来。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.82,
                        ),
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ImportFocusPill(
                          icon: Icons.fact_check_outlined,
                          label: '先看联系人清单',
                        ),
                        _ImportFocusPill(
                          icon: Icons.shield_outlined,
                          label: '避免日志误扫',
                        ),
                        _ImportFocusPill(
                          icon: Icons.filter_alt_outlined,
                          label: '只导入本次目标',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStartWeChatRawImport,
                        icon: const Icon(Icons.bolt_rounded),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 22,
                          ),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        label: const Text('立即直读并选择联系人'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '如果这台电脑当前不支持直读，再退回下面的备用入口。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: onPickFiles,
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text('改用文件入口'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '备用入口',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickFiles,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('选择记录文件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onStartSmartImport,
                    icon: const Icon(Icons.folder_zip_rounded),
                    label: const Text('扫描导出记录'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCaptureFromChatWindow,
                    icon: const Icon(Icons.screenshot_monitor_rounded),
                    label: const Text('从聊天窗口采集'),
                  ),
                  if (selectedCount > 0)
                    FilledButton.tonalIcon(
                      onPressed: onStartSelectedImport,
                      icon: Icon(
                        isBusy ? Icons.sync_rounded : Icons.play_arrow_rounded,
                      ),
                      label: Text(isBusy ? '处理中...' : '开始导入已选内容'),
                    ),
                ],
              ),
            ],
          );

          final side = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ImportMetricCard(
                    label: '联系人',
                    value: latestPackage != null
                        ? '${latestPackage!.contactCount}'
                        : '0',
                    icon: Icons.people_alt_outlined,
                  ),
                  _ImportMetricCard(
                    label: '消息',
                    value: latestPackage != null
                        ? '${latestPackage!.messageCount}'
                        : '$recordCount',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                  _ImportMetricCard(
                    label: '状态',
                    value: isBusy ? '处理中' : '就绪',
                    icon: isBusy
                        ? Icons.sync_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.72),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前进度', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      statusText.isEmpty
                          ? '还没有正在处理的导入任务。你可以从左侧主入口直接开始。'
                          : statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 20),
                side,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: intro),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: side),
            ],
          );
        },
      ),
    );
  }
}

class _ImportMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ImportMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ImportRouteGuidePanel extends StatelessWidget {
  final ImportedPackage? latestPackage;
  final int recordCount;
  final int selectedCount;
  final bool isBusy;
  final String statusText;
  final String? targetLabel;
  final VoidCallback? onStartSelectedImport;
  final VoidCallback? onStartSmartImport;
  final VoidCallback? onPickFiles;
  final VoidCallback? onCaptureFromChatWindow;
  final VoidCallback? onStartWeChatRawImport;
  final VoidCallback? onOpenReport;
  final VoidCallback? onOpenContacts;

  const _ImportRouteGuidePanel({
    required this.latestPackage,
    required this.recordCount,
    required this.selectedCount,
    required this.isBusy,
    required this.statusText,
    required this.targetLabel,
    required this.onStartSelectedImport,
    required this.onStartSmartImport,
    required this.onPickFiles,
    required this.onCaptureFromChatWindow,
    required this.onStartWeChatRawImport,
    required this.onOpenReport,
    required this.onOpenContacts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decision = _resolveDecision();

    return WorkspaceSurface(
      tone: WorkspaceSurfaceTone.emphasis,
      borderRadius: BorderRadius.circular(32),
      tint: AppTheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1020;
          final lead = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  decision.badge,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                decision.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                decision.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.65,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  WorkspaceTag('现有记录 $recordCount 条'),
                  if (latestPackage != null)
                    WorkspaceTag('最近导入 ${latestPackage!.contactCount} 位联系人'),
                  if (selectedCount > 0) WorkspaceTag('已选队列 $selectedCount 项'),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: decision.onPrimary,
                    icon: Icon(decision.primaryIcon),
                    label: Text(decision.primaryLabel),
                  ),
                  if (decision.secondaryLabel != null)
                    OutlinedButton.icon(
                      onPressed: decision.onSecondary,
                      icon: Icon(decision.secondaryIcon),
                      label: Text(decision.secondaryLabel!),
                    ),
                ],
              ),
              if (decision.steps.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (var i = 0; i < decision.steps.length; i++) ...[
                  _ImportRouteStepLine(
                    index: i + 1,
                    text: decision.steps[i],
                  ),
                  if (i != decision.steps.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ],
          );

          final side = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImportRouteMiniCard(
                icon: Icons.storage_rounded,
                title: '直读主入口',
                subtitle: '微信保持登录时先用这条。会先读出联系人清单，再只导入你勾选的人。',
                buttonLabel: '直读并选择联系人',
                onTap: onStartWeChatRawImport,
                highlighted: true,
                width: double.infinity,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ImportRouteMiniCard(
                    icon: Icons.note_add_outlined,
                    title: '文件入口',
                    subtitle: '直读不可用时优先用这个，手动挑聊天文件最可控。',
                    buttonLabel: '选择记录文件',
                    onTap: onPickFiles,
                  ),
                  _ImportRouteMiniCard(
                    icon: Icons.folder_zip_rounded,
                    title: '扫描入口',
                    subtitle: '只在导出目录已经整理干净时再用，避免把日志和缓存一起扫进来。',
                    buttonLabel: '扫描导出记录',
                    onTap: onStartSmartImport,
                  ),
                  _ImportRouteMiniCard(
                    icon: Icons.screenshot_monitor_rounded,
                    title: '补录入口',
                    subtitle: '补窗口内容或临时抓到的聊天片段。',
                    buttonLabel: '从聊天窗口采集',
                    onTap: onCaptureFromChatWindow,
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lead,
                const SizedBox(height: 18),
                side,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: lead),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: side),
            ],
          );
        },
      ),
    );
  }

  _ImportRouteDecision _resolveDecision() {
    if (isBusy) {
      return _ImportRouteDecision(
        badge: '当前任务',
        title: '先让这轮导入处理完，再决定是否继续切入口。',
        body: statusText.isEmpty
            ? '系统正在整理导入内容。处理中时不建议重复点多个入口，等状态回到就绪再补录或跳去看结果。'
            : statusText,
        primaryLabel: '处理中...',
        primaryIcon: Icons.sync_rounded,
        onPrimary: null,
        secondaryLabel: latestPackage != null ? '看这轮导入结果' : null,
        secondaryIcon: Icons.analytics_rounded,
        onSecondary: latestPackage != null ? onOpenReport : null,
        steps: const [
          '保持当前任务运行，不必重复选择目录或文件。',
          '等导入完成后，再决定是继续补录，还是直接去看报告和联系人。',
        ],
      );
    }

    if (selectedCount > 0) {
      return _ImportRouteDecision(
        badge: '最适合现在',
        title: '队列已经准备好，直接导入已选内容就行。',
        body: '你已经选好了 $selectedCount 项内容，现在最省事的动作就是直接开始导入，不用再回头重复选目录。',
        primaryLabel: '开始导入已选内容',
        primaryIcon: Icons.play_arrow_rounded,
        onPrimary: onStartSelectedImport,
        secondaryLabel: '再补一个文件',
        secondaryIcon: Icons.note_add_outlined,
        onSecondary: onPickFiles,
        steps: const [
          '先把当前队列导进来，让桌面端先生成一轮稳定结果。',
          '导入完成后先看报告，再按联系人页继续补节奏。',
        ],
      );
    }

    if (targetLabel != null && targetLabel!.trim().isNotEmpty) {
      return _ImportRouteDecision(
        badge: '继续补录',
        title: '把新内容继续并到 $targetLabel 这条关系线上。',
        body: '当前已经有明确联系人可继续补充。窗口采集、剪贴板和附件补录都应该优先服务这一条关系，而不是重新开散。',
        primaryLabel: '继续采集窗口',
        primaryIcon: Icons.screenshot_monitor_rounded,
        onPrimary: onCaptureFromChatWindow,
        secondaryLabel: '看联系人页',
        secondaryIcon: Icons.people_rounded,
        onSecondary: onOpenContacts,
        steps: const [
          '先把新内容并到同一联系人名下，避免关系线再次分裂。',
          '补完后去联系人页确认节奏，再决定是否追加附件或继续分析。',
        ],
      );
    }

    if (latestPackage == null) {
      return _ImportRouteDecision(
        badge: '推荐路线',
        title: '第一次导入，先试“直读并选择联系人”这条主路线。',
        body:
            '如果电脑端微信保持登录，直读更容易拿到干净聊天内容，而且读完后还能先勾选联系人，再决定这次只带谁进仁迈；如果当前机器不支持，再退回文件入口。',
        primaryLabel: '直读并选择联系人',
        primaryIcon: Icons.storage_rounded,
        onPrimary: onStartWeChatRawImport,
        secondaryLabel: '选择记录文件',
        secondaryIcon: Icons.note_add_outlined,
        onSecondary: onPickFiles,
        steps: const [
          '先试直读；读完后先勾选联系人，再正式导入需要的人。',
          '如果当前机器不支持或目录没识别到，再用“选择记录文件”。',
          '“扫描导出记录”放在最后，只在导出目录已经整理干净时再用。',
        ],
      );
    }

    return _ImportRouteDecision(
      badge: '下一步',
      title: '这轮导入已经完成，先去看报告和联系人。',
      body: '你已经拿到一轮可用结果，现在更值得做的是读报告、看优先联系人，再决定是否继续补导入，而不是一直停留在导入页。',
      primaryLabel: '去看报告',
      primaryIcon: Icons.analytics_rounded,
      onPrimary: onOpenReport,
      secondaryLabel: '看联系人',
      secondaryIcon: Icons.people_rounded,
      onSecondary: onOpenContacts,
      steps: const [
        '先看报告里的总结和当前建议动作，明确今天最优先的对象。',
        '再去联系人页深入处理对应关系，需要时再回来补录窗口或附件。',
      ],
    );
  }
}

class _ImportRouteDecision {
  final String badge;
  final String title;
  final String body;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final IconData secondaryIcon;
  final VoidCallback? onSecondary;
  final List<String> steps;

  const _ImportRouteDecision({
    required this.badge,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondaryLabel,
    this.secondaryIcon = Icons.arrow_forward_rounded,
    this.onSecondary,
    this.steps = const [],
  });
}

class _ImportRouteStepLine extends StatelessWidget {
  final int index;
  final String text;

  const _ImportRouteStepLine({
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRouteMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onTap;
  final bool highlighted;
  final double width;

  const _ImportRouteMiniCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.highlighted = false,
    this.width = 230,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: highlighted
                ? theme.colorScheme.primary.withValues(alpha: 0.24)
                : theme.dividerColor.withValues(alpha: 0.66),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: highlighted
                      ? [
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                          AppTheme.sun.withValues(alpha: 0.48),
                        ]
                      : [
                          theme.dividerColor.withValues(alpha: 0.12),
                          theme.dividerColor.withValues(alpha: 0.04),
                        ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: highlighted ? 48 : 42,
              height: highlighted ? 48 : 42,
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.86)
                    : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            if (highlighted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '先点这里',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.55,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            highlighted
                ? FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(buttonLabel),
                  )
                : OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(buttonLabel),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ImportFocusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ImportFocusPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportSignalTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ImportSignalTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: HoverCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PathTile extends StatelessWidget {
  final String path;

  const _PathTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(path),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  path,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
