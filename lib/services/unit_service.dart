import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/unit.dart';
import '../models/scan_record.dart';

class UnitService extends ChangeNotifier {
  List<Unit> _units = [];
  List<Unit> get units => _units;

  UnitService() {
    loadUnits();
  }

  // 加载所有单元
  Future<void> loadUnits() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final unitsJson = prefs.getString('units') ?? '[]';
      final List<dynamic> unitsData = json.decode(unitsJson);
      _units = unitsData.map((data) => Unit.fromMap(data)).toList();
    } catch (_) {
      _units = [];
      await prefs.remove('units');
    }
    notifyListeners();
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
