import 'dart:convert';
import '../models/unit.dart';
import '../models/scan_record.dart';

class QRService {
  // 将Unit编码为二维码数据
  static String encodeUnit(Unit unit) {
    // 检测是否可以压缩（检查后四位是否只有变化）
    final compressed = _tryCompressRecords(unit.scanRecords);
    
    final Map<String, dynamic> data = {
      'v': 3, // 版本3 - 支持主控码
      'n': unit.name,
      'm': unit.masterCode, // 主控码
    };

    if (compressed != null) {
      data['c'] = compressed;
    } else {
      data['r'] = unit.scanRecords
          .map((r) => {'i': r.index, 't': r.content})
          .toList();
    }
    
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  // 从二维码数据解码为Unit
  static Unit? decodeUnit(String qrData) {
    try {
      final decoded = utf8.decode(base64Decode(qrData));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      
      final version = json['v'] as int?;
      final unitName = json['n'] as String?;
      final masterCode = json['m'] as String?;
      
      if (unitName == null) return null;
      
      List<ScanRecord> records = [];
      
      if (json.containsKey('c')) {
        // 压缩格式
        final compressed = json['c'];
        records = _decompressRecords(compressed);
      } else if (json.containsKey('r')) {
        // 标准格式
        final recordsList = json['r'] as List?;
        if (recordsList != null) {
          records = recordsList
              .map((r) => ScanRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString() +
                        recordsList.indexOf(r).toString(),
                    index: r['i'] as int,
                    content: r['t'] as String,
                    scannedAt: DateTime.now(),
                  ))
              .toList();
        }
      }
      
      return Unit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: unitName,
        masterCode: masterCode,
        createdAt: DateTime.now(),
        scanRecords: records,
      );
    } catch (e) {
      print('Failed to decode QR data: $e');
      return null;
    }
  }

  // 检测并压缩记录 - 如果检测到后四位变化模式，使用压缩格式
  static dynamic _tryCompressRecords(List<ScanRecord> records) {
    if (records.isEmpty || records.length < 3) return null;
    
    // 获取所有内容
    final contents = records.map((r) => r.content).toList();
    
    // 检查是否满足压缩条件：至少80%的记录长度相同，且只有后四位不同
    if (_canCompressWithSuffix(contents)) {
      return _compressWithSuffix(records);
    }
    
    // 如果长度都一样，可以只保存每条的差异部分
    if (_allSameLength(contents)) {
      return _compressWithDelta(records);
    }
    
    return null;
  }

  // 检查是否可以用后四位压缩方案
  static bool _canCompressWithSuffix(List<String> contents) {
    if (contents.isEmpty) return false;
    
    // 找出最长的公共前缀
    final maxLen = contents.map((c) => c.length).reduce((a, b) => a > b ? a : b);
    
    // 检查是否至少有70%的记录长度相同
    final lengths = contents.map((c) => c.length).toList();
    final mostCommonLen =
        lengths.fold<Map<int, int>>({}, (map, len) {
          map[len] = (map[len] ?? 0) + 1;
          return map;
        }).entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
    
    final sameRatios =
        lengths.where((l) => l == mostCommonLen).length / lengths.length;
    return sameRatios >= 0.7 && mostCommonLen >= 16;
  }

  // 使用后四位差异压缩
  static dynamic _compressWithSuffix(List<ScanRecord> records) {
    final contents = records.map((r) => r.content).toList();
    
    // 找出前缀（除去后四位）
    String? prefix;
    final suffixes = <String>[];
    
    for (final content in contents) {
      final len = content.length;
      if (len >= 4) {
        final p = content.substring(0, len - 4);
        if (prefix == null) {
          prefix = p;
        }
        suffixes.add(content.substring(len - 4));
      } else {
        return null; // 无法压缩
      }
    }
    
    if (prefix == null || !suffixes.every((s) => s.length == 4)) {
      return null;
    }
    
    return {
      'p': prefix, // 前缀
      's': suffixes, // 后缀列表
    };
  }

  // 检查所有内容长度是否相同
  static bool _allSameLength(List<String> contents) {
    if (contents.isEmpty) return false;
    final firstLen = contents.first.length;
    return contents.every((c) => c.length == firstLen);
  }

  // 使用Delta压缩（只保存变化）
  static dynamic _compressWithDelta(List<ScanRecord> records) {
    if (records.isEmpty) return null;
    
    final first = records.first.content;
    final deltas = <String>[];
    
    for (final record in records) {
      deltas.add(record.content);
    }
    
    return {
      'f': first, // 第一个完整记录
      'd': deltas, // 所有记录（因为长度相同，可以直接列出）
    };
  }

  // 解压缩记录
  static List<ScanRecord> _decompressRecords(dynamic compressed) {
    if (compressed == null) return [];
    
    final records = <ScanRecord>[];
    
    if (compressed is Map) {
      if (compressed.containsKey('p') && compressed.containsKey('s')) {
        // 后四位压缩格式
        final prefix = compressed['p'] as String;
        final suffixes = compressed['s'] as List;
        
        int index = 1;
        for (final suffix in suffixes) {
          records.add(ScanRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString() +
                index.toString(),
            index: index,
            content: prefix + (suffix as String),
            scannedAt: DateTime.now(),
          ));
          index++;
        }
      } else if (compressed.containsKey('f') && compressed.containsKey('d')) {
        // Delta压缩格式
        final deltas = compressed['d'] as List;
        
        int index = 1;
        for (final delta in deltas) {
          records.add(ScanRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString() +
                index.toString(),
            index: index,
            content: delta as String,
            scannedAt: DateTime.now(),
          ));
          index++;
        }
      }
    }
    
    return records;
  }

  // 估算编码后的大小（用于显示支持的最大条数）
  static int estimateCapacity(Unit unit) {
    try {
      final encoded = encodeUnit(unit);
      
      // Base64编码后的大小
      return encoded.length;
    } catch (e) {
      return -1;
    }
  }

  // 检查数据是否能放入二维码（QR Code Version 40的约2500字节限制）
  static bool canFitInQR(Unit unit) {
    return estimateCapacity(unit) <= 2500;
  }
}
