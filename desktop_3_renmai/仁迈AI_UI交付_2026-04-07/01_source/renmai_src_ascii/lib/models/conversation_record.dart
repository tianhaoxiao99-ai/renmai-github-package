class ConversationRecord {
  final String id;
  final String packageId;
  final String source;
  final String contactId;
  final String contactName;
  final String senderName;
  final bool isSelf;
  final DateTime sentAt;
  final String content;
  final String messageType;
  final String evidenceSnippet;
  final String sourceFile;
  final String attachmentPath;
  final String searchText;

  ConversationRecord({
    required this.id,
    required this.packageId,
    required this.source,
    required this.contactId,
    required this.contactName,
    required this.senderName,
    required this.isSelf,
    required this.sentAt,
    required this.content,
    required this.messageType,
    required this.evidenceSnippet,
    required this.sourceFile,
    this.attachmentPath = '',
    String? searchText,
  }) : searchText = (searchText == null || searchText.trim().isEmpty)
            ? buildSearchText(
                contactId: contactId,
                contactName: contactName,
                senderName: senderName,
                content: content,
                messageType: messageType,
                evidenceSnippet: evidenceSnippet,
              )
            : searchText.trim();

  ConversationRecord copyWith({
    String? id,
    String? packageId,
    String? source,
    String? contactId,
    String? contactName,
    String? senderName,
    bool? isSelf,
    DateTime? sentAt,
    String? content,
    String? messageType,
    String? evidenceSnippet,
    String? sourceFile,
    String? attachmentPath,
    String? searchText,
  }) {
    return ConversationRecord(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      source: source ?? this.source,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      senderName: senderName ?? this.senderName,
      isSelf: isSelf ?? this.isSelf,
      sentAt: sentAt ?? this.sentAt,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      evidenceSnippet: evidenceSnippet ?? this.evidenceSnippet,
      sourceFile: sourceFile ?? this.sourceFile,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      searchText: searchText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'package_id': packageId,
      'source': source,
      'contact_id': contactId,
      'contact_name': contactName,
      'sender_name': senderName,
      'is_self': isSelf,
      'sent_at': sentAt.toIso8601String(),
      'content': content,
      'message_type': messageType,
      'evidence_snippet': evidenceSnippet,
      'source_file': sourceFile,
      'attachment_path': attachmentPath,
      'search_text': searchText,
    };
  }

  factory ConversationRecord.fromJson(Map<String, dynamic> json) {
    return ConversationRecord(
      id: (json['id'] ?? '').toString(),
      packageId: (json['package_id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      contactId: (json['contact_id'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      isSelf: json['is_self'] == true,
      sentAt: DateTime.tryParse((json['sent_at'] ?? '').toString()) ??
          DateTime.now(),
      content: (json['content'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      evidenceSnippet: (json['evidence_snippet'] ?? '').toString(),
      sourceFile: (json['source_file'] ?? '').toString(),
      attachmentPath: (json['attachment_path'] ?? '').toString(),
      searchText: (json['search_text'] ?? '').toString(),
    );
  }

  static String buildSearchText({
    required String contactId,
    required String contactName,
    required String senderName,
    required String content,
    required String messageType,
    required String evidenceSnippet,
  }) {
    final fields = <String>{};

    void addField(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return;
      }
      fields.add(trimmed);
    }

    addField(contactId);
    addField(contactName);
    addField(senderName);
    addField(content);
    addField(evidenceSnippet);
    addField(messageType);

    switch (messageType) {
      case 'image':
        addField('图片 图像 照片 截图 海报 OCR 识图 图片文字');
        break;
      case 'voice':
        addField('语音 音频 录音 说话 发言 转写 听写');
        break;
      case 'emoji':
        addField('表情 表情包 贴纸 动图 情绪');
        break;
      case 'file':
        addField('文件 附件 文档 摘录');
        break;
      case 'video':
        addField('视频 影像 片段');
        break;
      default:
        break;
    }

    final semanticAliases = <String, String>{
      '语音转写': '说了什么 音频内容 录音内容',
      '图片文字识别': '图里写了什么 截图文字 海报文字',
      '表情内容识别': '表情意思 表情含义 情绪表达',
      '汗': '尴尬 无语',
      '哭': '难过 伤心 委屈',
      '开心': '高兴 快乐',
      '晕': '无奈 崩溃',
      '吃瓜': '围观 看戏',
      '倒下': '累 崩溃',
      '会好的': '安慰 鼓励',
      '好朋友': '朋友 关系好',
      '上车': '出发 一起走',
      '水枪': '打水 仔细玩笑',
    };

    final combined = '$content\n$evidenceSnippet';
    semanticAliases.forEach((key, aliases) {
      if (combined.contains(key)) {
        addField(aliases);
      }
    });

    final labelPattern = RegExp(r'[【\[]([^\]】]{1,32})[\]】]');
    for (final match in labelPattern.allMatches(combined)) {
      addField(match.group(1) ?? '');
    }

    return fields.join('\n');
  }
}
