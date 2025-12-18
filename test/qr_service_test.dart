import 'package:flutter_test/flutter_test.dart';
import 'package:scan_assistant/models/unit.dart';
import 'package:scan_assistant/models/scan_record.dart';
import 'package:scan_assistant/services/qr_service.dart';

void main() {
  group('QRService Tests', () {
    test('Encode and decode standard unit', () {
      final unit = Unit(
        id: 'test-1',
        name: 'Test Unit',
        createdAt: DateTime.now(),
        scanRecords: [
          ScanRecord(
            id: 'record-1',
            index: 1,
            content: 'ABC123456789ABC1',
            scannedAt: DateTime.now(),
          ),
          ScanRecord(
            id: 'record-2',
            index: 2,
            content: 'ABC123456789ABC2',
            scannedAt: DateTime.now(),
          ),
        ],
      );

      final encoded = QRService.encodeUnit(unit);
      expect(encoded.isNotEmpty, true);

      final decoded = QRService.decodeUnit(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.name, equals(unit.name));
      expect(decoded.scanRecords.length, equals(unit.scanRecords.length));
    });

    test('Compress with suffix pattern (same prefix, different suffix)', () {
      final records = List.generate(
        60,
        (index) => ScanRecord(
          id: 'record-$index',
          index: index + 1,
          content: 'SN20240001A${(index).toString().padLeft(3, '0')}',
          scannedAt: DateTime.now(),
        ),
      );

      final unit = Unit(
        id: 'test-2',
        name: 'Device Batch A',
        createdAt: DateTime.now(),
        scanRecords: records,
      );

      final encoded = QRService.encodeUnit(unit);
      final encodedSize = encoded.length;

      print('Encoded size for 60 records: $encodedSize bytes');
      expect(encodedSize < 2500, true);

      // Verify it can be decoded back
      final decoded = QRService.decodeUnit(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.scanRecords.length, equals(60));
    });

    test('Capacity check', () {
      final records = List.generate(
        50,
        (index) => ScanRecord(
          id: 'record-$index',
          index: index + 1,
          content: 'CONTENT_${(index).toString().padLeft(6, '0')}',
          scannedAt: DateTime.now(),
        ),
      );

      final unit = Unit(
        id: 'test-3',
        name: 'Test Unit',
        createdAt: DateTime.now(),
        scanRecords: records,
      );

      final capacity = QRService.estimateCapacity(unit.scanRecords);
      final canFit = QRService.canFitInQR(unit.scanRecords);

      print('Capacity for 50 records: $capacity bytes');
      print('Can fit in QR: $canFit');

      expect(capacity > 0, true);
      expect(canFit, true);
    });

    test('Large dataset compression test', () {
      // 测试100条记录的压缩效果
      final records = List.generate(
        100,
        (index) => ScanRecord(
          id: 'record-$index',
          index: index + 1,
          content: 'DEVICE0001A${(index).toString().padLeft(4, '0')}',
          scannedAt: DateTime.now(),
        ),
      );

      final unit = Unit(
        id: 'test-4',
        name: 'Large Batch',
        createdAt: DateTime.now(),
        scanRecords: records,
      );

      final encoded = QRService.encodeUnit(unit);
      final encodedSize = encoded.length;

      print('Encoded size for 100 records: $encodedSize bytes');

      final decoded = QRService.decodeUnit(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.scanRecords.length, equals(100));

      if (encoded.length <= 2500) {
        print('✓ Successfully compressed 100 records into QR code');
      } else {
        print('✗ Cannot fit 100 records, size exceeded');
      }
    });
  });
}
