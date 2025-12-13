class ScanRecord {
  final String id;
  final int index;
  final String content;
  final DateTime scannedAt;

  ScanRecord({
    required this.id,
    required this.index,
    required this.content,
    required this.scannedAt,
  });

  // 创建副本方法，用于更新
  ScanRecord copyWith({
    String? id,
    int? index,
    String? content,
    DateTime? scannedAt,
  }) {
    return ScanRecord(
      id: id ?? this.id,
      index: index ?? this.index,
      content: content ?? this.content,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }

  // 转换为Map，用于存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'index': index,
      'content': content,
      'scannedAt': scannedAt.toIso8601String(),
    };
  }

  // 从Map创建ScanRecord实例
  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'],
      index: map['index'],
      content: map['content'],
      scannedAt: DateTime.parse(map['scannedAt']),
    );
  }
}