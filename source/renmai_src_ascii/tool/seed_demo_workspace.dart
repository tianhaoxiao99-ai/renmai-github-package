import 'dart:convert';
import 'dart:io';

import 'package:renmai/config/app_constants.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/import_service.dart';
import 'package:renmai/services/local_report_service.dart';

const _filePointerPrefix = '__renmai_file__:';

Future<void> main(List<String> args) async {
  final clearOnly = args.contains('--clear');
  final rootPath = _readOption(
        args,
        '--root',
      ) ??
      r'C:\rmai\build\windows\x64\runner\Debug\RenmaiData';
  final root = Directory(rootPath);

  await _resetRoot(root);

  if (clearOnly) {
    stdout.writeln('Cleared demo workspace at ${root.path}');
    return;
  }

  final sessions = await Future.wait([
    _importSession(
      sourceFile: 'zhou_teacher_april.txt',
      text: '''
[2026-04-10 09:10] Me: 这周你辛苦了，周末想请你吃饭放松一下
[2026-04-10 09:22] 周老师: 哈哈谢谢你记得，周末见面可以啊
[2026-04-10 09:26] Me: 上次说的生日礼物我也顺手带给你
[2026-04-10 09:30] 周老师: 太贴心了，我最近一直想你们这群老朋友
[2026-04-11 20:02] 周老师: 你明天几点到？我给你留座位
[2026-04-11 20:05] Me: 我六点半到，到时候一起吃饭
[2026-04-11 20:07] 周老师: 好呀，见面聊，最近有些想法想当面说
[2026-04-13 08:15] Me: 昨晚见面很开心，谢谢你还送我回去
[2026-04-13 08:33] 周老师: 我也很开心，记得早点休息
[2026-04-14 21:10] 周老师: 周末电影票我先看一下，想一起去的话我来订
[2026-04-14 21:18] Me: 可以呀，你定好告诉我
[2026-04-15 09:05] 周老师: 那就周六见，礼物别太破费，能见面就很好
''',
    ),
    _importSession(
      sourceFile: 'linyuan_april.txt',
      text: '''
[2026-04-06 22:10] Me: 上次你说最近忙，我就没继续打扰
[2026-04-07 09:20] 林予安: 谢谢你体谅，这周确实有点忙
[2026-04-07 09:24] Me: 等你忙完我们找个晚上吃饭
[2026-04-07 09:31] 林予安: 好，改天我来约你
[2026-04-10 23:11] Me: 你昨天发的歌单我听了，挺喜欢
[2026-04-10 23:16] 林予安: 哈哈你喜欢就好，周末想见面也可以
[2026-04-12 13:05] Me: 周日晚上电影或者散步都行
[2026-04-12 13:32] 林予安: 先看看吧，今天有点累
[2026-04-13 18:50] Me: 那你先休息，别太辛苦
[2026-04-13 19:06] 林予安: 你总是这么照顾人，谢谢
[2026-04-14 22:15] Me: 等你状态好一点我们再定
[2026-04-15 08:55] 林予安: 好呀，过两天我主动找你
''',
    ),
    _importSession(
      sourceFile: 'chence_april.txt',
      text: '''
[2026-04-02 10:01] 陈策: 项目排期我已经更新，你看下有没有问题
[2026-04-02 10:18] Me: 收到，辛苦了，我中午前给你反馈
[2026-04-04 17:40] Me: 合作方案我补了一版，你晚点方便看吗
[2026-04-04 19:12] 陈策: 可以，我下班后看一下
[2026-04-08 09:10] 陈策: 这周工作有点满，我们先把关键节点对齐
[2026-04-08 09:36] Me: 行，那我把两个时间点整理成清单发你
[2026-04-08 09:41] 陈策: 好，你发我就行
[2026-04-11 16:14] Me: 你上次提的地址和资料我都补上了
[2026-04-11 16:48] 陈策: 好的，谢谢
[2026-04-12 11:05] Me: 那我先按这个版本推进
[2026-04-12 11:26] 陈策: 可以，先按这个版本推进，改天再复盘
''',
    ),
  ]);

  final packages = <ImportedPackage>[
    for (final session in sessions) session.importedPackage,
  ];
  final records = <ConversationRecord>[
    for (final session in sessions) ...session.records,
  ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  final report = LocalReportService.instance.buildReport(
    packages: packages,
    records: records,
  );
  final selectedContactId = report.relationshipRanking.isNotEmpty
      ? report.relationshipRanking.first.contactId
      : (records.isEmpty ? '' : records.first.contactId);

  await _persistWorkspace(
    root: root,
    packages: packages,
    records: records,
    report: report.toJson(),
    selectedContactId: selectedContactId,
  );

  stdout.writeln('Seeded demo workspace at ${root.path}');
  stdout.writeln('Packages: ${packages.length}');
  stdout.writeln('Records: ${records.length}');
  stdout.writeln(
    'Top contacts: ${report.relationshipRanking.take(3).map((item) => item.contactName).join('、')}',
  );
}

Future<ImportSessionData> _importSession({
  required String sourceFile,
  required String text,
}) {
  return ImportService.instance.importPlainText(
    text.trim(),
    sourceFile: sourceFile,
  );
}

Future<void> _resetRoot(Directory root) async {
  if (root.existsSync()) {
    await root.delete(recursive: true);
  }
  await Directory('${root.path}\\storage').create(recursive: true);
  await File('${root.path}\\portable_secure_preferences.json').writeAsString(
    '{}',
    flush: true,
  );
}

Future<void> _persistWorkspace({
  required Directory root,
  required List<ImportedPackage> packages,
  required List<ConversationRecord> records,
  required Map<String, dynamic> report,
  required String selectedContactId,
}) async {
  final storageDir = Directory('${root.path}\\storage');
  final packagesFile =
      File('${storageDir.path}\\${AppConstants.keyImportedPackages}.json');
  final recordsFile =
      File('${storageDir.path}\\${AppConstants.keyConversationRecords}.json');
  final reportFile =
      File('${storageDir.path}\\${AppConstants.keyComparisonReport}.json');

  await packagesFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      packages.map((item) => item.toJson()).toList(),
    ),
    flush: true,
  );
  await recordsFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      records.map((item) => item.toJson()).toList(),
    ),
    flush: true,
  );
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );

  final values = <String, String>{
    AppConstants.keyImportedPackages: '$_filePointerPrefix${packagesFile.path}',
    AppConstants.keyConversationRecords:
        '$_filePointerPrefix${recordsFile.path}',
    AppConstants.keyComparisonReport: '$_filePointerPrefix${reportFile.path}',
    AppConstants.keySelectedContactId: selectedContactId,
  };
  await File('${root.path}\\preferences.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(values),
    flush: true,
  );
}

String? _readOption(List<String> args, String name) {
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == name) {
      return args[i + 1];
    }
  }
  return null;
}
