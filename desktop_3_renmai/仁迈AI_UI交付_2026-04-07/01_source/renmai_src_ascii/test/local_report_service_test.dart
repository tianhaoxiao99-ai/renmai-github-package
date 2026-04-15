import 'package:flutter_test/flutter_test.dart';
import 'package:renmai/models/conversation_record.dart';
import 'package:renmai/models/imported_package.dart';
import 'package:renmai/services/local_report_service.dart';

void main() {
  test('builds an empty-state report when no records are available', () {
    final report = LocalReportService.instance.buildReport(
      packages: const [],
      records: const [],
    );

    expect(report.relationshipRanking, isEmpty);
    expect(report.contactInsights, isEmpty);
    expect(report.overallSummary, contains('当前还没有可分析的聊天记录'));
    expect(report.actionSuggestions, isNotEmpty);
  });

  test('prioritizes recent positive contacts in the ranking', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_main')],
      records: [
        _record(
          id: '1',
          contactId: 'xiaowang',
          contactName: '小王',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '谢谢你，周末一起见面吃饭吧',
        ),
        _record(
          id: '2',
          contactId: 'xiaowang',
          contactName: '小王',
          senderName: '小王',
          isSelf: false,
          sentAt: now.subtract(const Duration(hours: 12)),
          content: '好呀，我给你准备个小礼物',
        ),
        _record(
          id: '3',
          contactId: 'old_friend',
          contactName: '老同学',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 50)),
          content: '最近忙吗',
        ),
        _record(
          id: '4',
          contactId: 'old_friend',
          contactName: '老同学',
          senderName: '老同学',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 49)),
          content: '改天再说吧',
        ),
      ],
    );

    expect(report.relationshipRanking.first.contactName, '小王');
    expect(report.giftRecommendations, isNotEmpty);
    expect(report.actionSuggestions, isNotEmpty);
  });

  test('uses family keywords to recommend a care-oriented gift', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_family')],
      records: [
        _record(
          id: 'family_1',
          contactId: 'mama',
          contactName: '妈妈',
          senderName: '妈妈',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '周末记得回家吃饭',
        ),
        _record(
          id: 'family_2',
          contactId: 'mama',
          contactName: '妈妈',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '好，我回家给你带礼物',
        ),
      ],
    );

    final insight = report.contactInsights.single;
    expect(insight.contactName, '妈妈');
    expect(insight.giftSuggestion, isNotNull);
    expect(insight.giftSuggestion!.giftName, '按摩仪');
  });

  test(
      'adds low-pressure follow-up guidance when the latest message is unanswered',
      () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_unanswered')],
      records: [
        _record(
          id: 'u_1',
          contactId: 'lujun',
          contactName: '陆军',
          senderName: '陆军',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 6)),
          content: '这周有空吗',
        ),
        _record(
          id: 'u_2',
          contactId: 'lujun',
          contactName: '陆军',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 5)),
          content: '我周四晚上可以',
        ),
        _record(
          id: 'u_3',
          contactId: 'lujun',
          contactName: '陆军',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 4)),
          content: '你确定时间后告诉我',
        ),
      ],
    );

    final insight = report.contactInsights.single;
    expect(
      insight.riskPoints.any((item) => item.contains('最近一次消息由你发出')),
      isTrue,
    );
    expect(
      insight.suggestions.any((item) => item.contains('先不要连续追发')),
      isTrue,
    );
  });
  test('does not mark transactional high-frequency chats as priority by default',
      () {
    final now = DateTime.now();
    final records = <ConversationRecord>[];
    for (var index = 0; index < 28; index++) {
      final sentAt = now.subtract(Duration(days: index ~/ 2, hours: index));
      records.add(
        _record(
          id: 'work_$index',
          contactId: 'teacher',
          contactName: '福州大学生家教No.17',
          senderName: index.isEven ? '我' : '福州大学生家教No.17',
          isSelf: index.isEven,
          sentAt: sentAt,
          content: index.isEven ? '这周课程时间确认一下' : '好的，课表和地址我发你',
        ),
      );
    }

    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_work')],
      records: records,
    );

    final insight = report.contactInsights.single;
    expect(insight.relationshipLevel, '保持联系');
    expect(insight.relationshipLevel, isNot('重点经营'));
  });

  test('keeps explicit care signals above raw message volume', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_signal')],
      records: [
        _record(
          id: 's_1',
          contactId: 'warm_friend',
          contactName: '陆军',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '周末一起吃饭吧，我给你带生日礼物',
        ),
        _record(
          id: 's_2',
          contactId: 'warm_friend',
          contactName: '陆军',
          senderName: '陆军',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2, hours: -2)),
          content: '好啊，谢谢你还记得我生日',
        ),
        _record(
          id: 's_3',
          contactId: 'warm_friend',
          contactName: '陆军',
          senderName: '陆军',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '到时候见面我请你吃饭',
        ),
      ],
    );

    final insight = report.contactInsights.single;
    expect(['重点经营', '稳定升温'].contains(insight.relationshipLevel), isTrue);
    expect(insight.intimacyScore, greaterThan(55));
  });
  test('explains ranking in concrete user-facing terms', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_rationale')],
      records: [
        _record(
          id: 'r_1',
          contactId: 'friend_a',
          contactName: '闄嗗啗',
          senderName: '闄嗗啗',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '杩欏懆鏈変笅娆″悆楗殑璁″垝鍚?',
        ),
        _record(
          id: 'r_2',
          contactId: 'friend_a',
          contactName: '闄嗗啗',
          senderName: '鎴?',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '濂藉晩锛屽埌鏃跺€欐垜甯︾ぜ鐗?',
        ),
        _record(
          id: 'r_3',
          contactId: 'friend_a',
          contactName: '闄嗗啗',
          senderName: '闄嗗啗',
          isSelf: false,
          sentAt: now,
          content: '濂界殑锛屾櫄涓婅鍕樺彲浠?',
        ),
      ],
    );

    final rationale = report.relationshipRanking.single.rationale;
    expect(rationale, contains('今天还有互动'));
    expect(rationale, contains('3 条消息'));
    expect(rationale, contains('3 天有互动'));
    expect(rationale, contains('互动'));
  });

  test('keeps parents above ordinary relatives when activity is similar', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_family_priority')],
      records: [
        _record(
          id: 'parent_1',
          contactId: 'father',
          contactName: '爸爸',
          senderName: '爸爸',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '到家了没，记得早点休息',
        ),
        _record(
          id: 'parent_2',
          contactId: 'father',
          contactName: '爸爸',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '到了，周末回家吃饭',
        ),
        _record(
          id: 'relative_1',
          contactId: 'aunt',
          contactName: '姑姑',
          senderName: '姑姑',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '最近还好吗，有空来家里坐坐',
        ),
        _record(
          id: 'relative_2',
          contactId: 'aunt',
          contactName: '姑姑',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '好，等我有空过去看看',
        ),
      ],
    );

    final father = report.contactInsights.firstWhere((item) => item.contactId == 'father');
    final aunt = report.contactInsights.firstWhere((item) => item.contactId == 'aunt');

    expect(father.relationDetail, '父母');
    expect(aunt.relationDetail, '亲戚');
    expect(father.intimacyScore, greaterThan(aunt.intimacyScore));
    expect(father.referenceTier, '好');
  });

  test('does not let family fall below strangers when both are low activity', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_family_floor')],
      records: [
        _record(
          id: 'family_low_1',
          contactId: 'uncle',
          contactName: '舅舅',
          senderName: '舅舅',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 65)),
          content: '最近忙不忙',
        ),
        _record(
          id: 'family_low_2',
          contactId: 'uncle',
          contactName: '舅舅',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 64)),
          content: '有点忙，改天回你',
        ),
        _record(
          id: 'stranger_1',
          contactId: 'visitor',
          contactName: '客户A',
          senderName: '客户A',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 65)),
          content: '你好，方便留个联系方式吗',
        ),
        _record(
          id: 'stranger_2',
          contactId: 'visitor',
          contactName: '客户A',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 64)),
          content: '先这样吧，下次再说',
        ),
      ],
    );

    final uncle = report.contactInsights.firstWhere((item) => item.contactId == 'uncle');
    final stranger = report.contactInsights.firstWhere((item) => item.contactId == 'visitor');

    expect(uncle.referenceTier, isNot('不好'));
    expect(uncle.intimacyScore, greaterThan(stranger.intimacyScore));
    expect(uncle.referenceReason, contains('家人'));
  });

  test('lets high-frequency friends rank above ordinary relatives', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_friend_vs_relative')],
      records: [
        _record(
          id: 'friend_1',
          contactId: 'zheng',
          contactName: '郑成一',
          senderName: '郑成一',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 2)),
          content: '晚上一起打球吗，顺便聊聊最近的事',
        ),
        _record(
          id: 'friend_2',
          contactId: 'zheng',
          contactName: '郑成一',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 2, hours: -2)),
          content: '好啊，我到时候给你带点喝的',
        ),
        _record(
          id: 'friend_3',
          contactId: 'zheng',
          contactName: '郑成一',
          senderName: '郑成一',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '行，那我们照旧见面',
        ),
        _record(
          id: 'relative_3',
          contactId: 'uncle_b',
          contactName: '姑姑',
          senderName: '姑姑',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 9)),
          content: '有空来家里吃饭',
        ),
        _record(
          id: 'relative_4',
          contactId: 'uncle_b',
          contactName: '姑姑',
          senderName: '我',
          isSelf: true,
          sentAt: now.subtract(const Duration(days: 8)),
          content: '好的，下次有空过去',
        ),
      ],
    );

    final friend = report.contactInsights.firstWhere((item) => item.contactId == 'zheng');
    final relative = report.contactInsights.firstWhere((item) => item.contactId == 'uncle_b');

    expect(friend.relationDetail, '朋友');
    expect(relative.relationDetail, '亲戚');
    expect(friend.intimacyScore, greaterThan(relative.intimacyScore));
  });

  test('explains why the reference tier was assigned', () {
    final now = DateTime.now();
    final report = LocalReportService.instance.buildReport(
      packages: [_package('pkg_reference_reason')],
      records: [
        _record(
          id: 'reason_1',
          contactId: 'father_reason',
          contactName: '爸爸',
          senderName: '爸爸',
          isSelf: false,
          sentAt: now.subtract(const Duration(days: 1)),
          content: '记得吃饭，周末回家',
        ),
        _record(
          id: 'reason_2',
          contactId: 'father_reason',
          contactName: '爸爸',
          senderName: '我',
          isSelf: true,
          sentAt: now,
          content: '好，晚上给你回电话',
        ),
      ],
    );

    final insight = report.contactInsights.single;
    expect(insight.referenceTier, '好');
    expect(insight.referenceReason, contains('父母属于直系家人'));
    expect(insight.referenceReason, anyOf(contains('最近互动'), contains('互动')));
    expect(report.relationshipRanking.single.rationale, contains('好（仅供参考）'));
  });

}

ConversationRecord _record({
  required String id,
  required String contactId,
  required String contactName,
  required String senderName,
  required bool isSelf,
  required DateTime sentAt,
  required String content,
}) {
  return ConversationRecord(
    id: id,
    packageId: 'pkg_test',
    source: 'wechat',
    contactId: contactId,
    contactName: contactName,
    senderName: senderName,
    isSelf: isSelf,
    sentAt: sentAt,
    content: content,
    messageType: 'text',
    evidenceSnippet: content,
    sourceFile: 'memory',
  );
}

ImportedPackage _package(String id) {
  return ImportedPackage(
    id: id,
    source: 'wechat',
    originPaths: const ['memory'],
    discoveredFiles: const ['memory'],
    importedAt: DateTime.now(),
    status: 'completed',
    contactCount: 1,
    messageCount: 1,
    packageSummary: 'test package',
  );
}


