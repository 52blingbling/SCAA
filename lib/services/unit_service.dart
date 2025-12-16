import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/unit.dart';
import '../models/scan_record.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'notification_service';

// 扩展List类，添加firstWhereOrNull方法（兼容旧Dart版本）
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class UnitService extends ChangeNotifier {
  List<Unit> _units = [];
  bool _isLoading = true;
  final StreamController<dynamic> _overlayEventController = StreamController<dynamic>.broadcast();
  StreamSubscription? _overlaySubscription;
  
  // 当前单元和位置管理
  String? _currentUnitId;
  int _currentPos = 0;
  
  // 通知服务实例
  final NotificationService _notificationService = NotificationService();

  List<Unit> get units => _units;
  bool get isLoading => _isLoading;
  Stream<dynamic> get overlayStream => _overlayEventController.stream;
  String? get currentUnitId => _currentUnitId;
  int get currentPos => _currentPos;

  UnitService() {
    loadUnits();
    _initOverlayListener();
    _initNotificationService();
  }
  
  // 初始化通知服务
  void _initNotificationService() async {
    await _notificationService.initialize();
  }
  
  // 获取当前单元
  Unit? getCurrentUnit() {
    if (_currentUnitId == null) return null;
    return _units.firstWhereOrNull((unit) => unit.id == _currentUnitId);
  }
  
  // 切换单元
  void switchUnit(String unitId) {
    _currentUnitId = unitId;
    _currentPos = 0;
    notifyListeners();
    _updateNotification();
  }
  
  // 上一条记录
  void goToPreviousRecord() {
    final currentUnit = getCurrentUnit();
    if (currentUnit == null || currentUnit.scanRecords.isEmpty) return;
    
    if (_currentPos > 0) {
      _currentPos--;
      notifyListeners();
      _updateNotification();
      _notifyOverlay();
    }
  }
  
  // 下一条记录
  void goToNextRecord() {
    final currentUnit = getCurrentUnit();
    if (currentUnit == null || currentUnit.scanRecords.isEmpty) return;
    
    if (_currentPos < currentUnit.scanRecords.length - 1) {
      _currentPos++;
      notifyListeners();
      _updateNotification();
      _notifyOverlay();
    }
  }
  
  // 复制当前内容到剪贴板
  Future<void> copyCurrentContent() async {
    final currentUnit = getCurrentUnit();
    if (currentUnit == null || currentUnit.scanRecords.isEmpty) return;
    
    final currentRecord = currentUnit.scanRecords[_currentPos];
    await Clipboard.setData(ClipboardData(text: currentRecord.content));
  }
  
  // 更新通知
  void _updateNotification() {
    final currentUnit = getCurrentUnit();
    if (currentUnit == null) return;
    
    if (currentUnit.scanRecords.isNotEmpty) {
      final currentRecord = currentUnit.scanRecords[_currentPos];
      _notificationService.updateNotification(
        unitName: currentUnit.name,
        content: currentRecord.content,
        sequence: currentRecord.index,
      );
    }
  }
  
  // 通知悬浮窗
  void _notifyOverlay() {
    final currentUnit = getCurrentUnit();
    if (currentUnit == null) return;
    
    if (currentUnit.scanRecords.isNotEmpty) {
      final currentRecord = currentUnit.scanRecords[_currentPos];
      FlutterOverlayWindow.shareData({
        'unit_name': currentUnit.name,
        'sequence': currentRecord.index,
        'content': currentRecord.content,
      });
    }
  }

  void _initOverlayListener() {
    try {
      _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is Map) {
          final m = Map<String, dynamic>.from(event);
          final action = m['action'];
          
          // 处理悬浮窗操作
          if (action == 'prev') {
            goToPreviousRecord();
          } else if (action == 'next') {
            goToNextRecord();
          } else if (action == 'copied') {
            copyCurrentContent();
          }
        }
        _overlayEventController.add(event);
      }, onError: (e) {
        developer.log('Overlay listener error: $e');
      });
    } catch (e) {
      developer.log('Failed to initialize overlay listener: $e');
    }
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _overlayEventController.close();
    super.dispose();
  }

  // 加载所有单元
  Future<void> loadUnits() async {
    _isLoading = true;
    
    final prefs = await SharedPreferences.getInstance();
    try {
      final unitsJson = prefs.getString('units') ?? '[]';
      final List<dynamic> unitsData = json.decode(unitsJson);
      _units = unitsData.map((data) => Unit.fromMap(data)).toList();
      
      // 如果有单元，设置第一个为当前单元
      if (_units.isNotEmpty && _currentUnitId == null) {
        _currentUnitId = _units.first.id;
        _currentPos = 0;
      }
    } catch (_) {
      _units = [];
      await prefs.remove('units');
    } finally {
      _isLoading = false;
      notifyListeners();
      _updateNotification();
    }
  }

  // 保存所有单元
  Future<void> saveUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final unitsJson = json.encode(_units.map((unit) => unit.toMap()).toList());
    await prefs.setString('units', unitsJson);
    notifyListeners();
  }

  // 添加新单元
  Future<void> addUnit(String name) async {
    final newUnit = Unit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
    );
    _units.add(newUnit);
    await saveUnits();
  }

  // 删除单元
  Future<void> deleteUnit(String id) async {
    _units.removeWhere((unit) => unit.id == id);
    await saveUnits();
  }

  // 重命名单元
  Future<void> renameUnit(String id, String newName) async {
    final index = _units.indexWhere((unit) => unit.id == id);
    if (index != -1) {
      _units[index] = _units[index].copyWith(name: newName);
      await saveUnits();
    }
  }

  // 获取指定单元
  Unit? getUnitById(String id) {
    try {
      return _units.firstWhere((unit) => unit.id == id);
    } catch (e) {
      return null;
    }
  }

  // 添加扫描记录到指定单元
  Future<void> addScanRecord(String unitId, String content) async {
    final unitIndex = _units.indexWhere((unit) => unit.id == unitId);
    if (unitIndex != -1) {
      final unit = _units[unitIndex];
      final newRecord = ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        index: unit.scanRecords.length + 1,
        content: content,
        scannedAt: DateTime.now(),
      );
      
      final updatedUnit = unit.copyWith(
        scanRecords: [...unit.scanRecords, newRecord],
      );
      
      _units[unitIndex] = updatedUnit;
      await saveUnits();
      
      // 如果当前单元是添加记录的单元，则更新当前位置并通知
      if (_currentUnitId == unitId) {
        _currentPos = updatedUnit.scanRecords.length - 1;
        notifyListeners();
        _updateNotification();
      }
    }
  }

  // 删除扫描记录
  Future<void> deleteScanRecord(String unitId, String recordId) async {
    final unitIndex = _units.indexWhere((unit) => unit.id == unitId);
    if (unitIndex != -1) {
      final unit = _units[unitIndex];
      final updatedRecords = unit.scanRecords.where((record) => record.id != recordId).toList();
      
      // 更新索引
      for (int i = 0; i < updatedRecords.length; i++) {
        updatedRecords[i] = updatedRecords[i].copyWith(index: i + 1);
      }
      
      final updatedUnit = unit.copyWith(scanRecords: updatedRecords);
      _units[unitIndex] = updatedUnit;
      await saveUnits();
    }
  }
}
