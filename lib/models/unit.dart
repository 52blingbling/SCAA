import 'scan_record.dart';
class Unit {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? masterCode;
  final List<ScanRecord> scanRecords;

  Unit({
    required this.id,
    required this.name,
    required this.createdAt,
    this.masterCode,
    List<ScanRecord>? scanRecords,
  }) : scanRecords = scanRecords ?? [];

  // 创建副本方法，用于更新
  Unit copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? masterCode,
    List<ScanRecord>? scanRecords,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      masterCode: masterCode ?? this.masterCode,
      scanRecords: scanRecords ?? this.scanRecords,
    );
  }

  // 转换为Map，用于存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'masterCode': masterCode,
      'scanRecords': scanRecords.map((record) => record.toMap()).toList(),
    };
  }

  // 从Map创建Unit实例
  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
      masterCode: map['masterCode'],
      scanRecords: (map['scanRecords'] as List)
          .map((record) => ScanRecord.fromMap(record))
          .toList(),
    );
  }
}
