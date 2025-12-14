import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

class OverlayService {
  // 初始化悬浮窗
  static Future<void> initializeOverlay() async {
    // v0.5.0 无需初始化
  }

  // 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    return (await FlutterOverlayWindow.isPermissionGranted()) == true;
  }

  // 请求悬浮窗权限
  static Future<bool> requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    if (granted == true) return true;
    final status = await ph.Permission.systemAlertWindow.request();
    return status == ph.PermissionStatus.granted;
  }

  // 显示悬浮窗
  static Future<void> showOverlay() async {
    if (await checkOverlayPermission()) {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getInt('overlay_x');
      final y = prefs.getInt('overlay_y');
      if (x != null && y != null) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          flag: OverlayFlag.defaultFlag,
          positionGravity: PositionGravity.auto,
          overlayTitle: '快捷助手已开启',
          overlayContent: '跨应用悬浮窗',
          startPosition: OverlayPosition(x.toDouble(), y.toDouble()),
        );
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          flag: OverlayFlag.defaultFlag,
          positionGravity: PositionGravity.auto,
          overlayTitle: '快捷助手已开启',
          overlayContent: '跨应用悬浮窗',
          alignment: OverlayAlignment.center,
        );
      }
    }
  }

  // 隐藏悬浮窗
  static Future<void> hideOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  // 检查悬浮窗是否可见
  static Future<bool> isOverlayVisible() async {
    return await FlutterOverlayWindow.isActive();
  }

  // 共享数据到悬浮窗
  static Future<void> sendData(Map<String, dynamic> data) async {
    await FlutterOverlayWindow.shareData(data);
  }

  // 保存悬浮窗位置
  static Future<void> savePosition() async {
    final pos = await FlutterOverlayWindow.getOverlayPosition();
    if (pos != null) {
      final prefs = await SharedPreferences.getInstance();
      final dynamic d = pos;
      final double ox = (d.x is double) ? d.x : (d.dx is double ? d.dx : 0.0);
      final double oy = (d.y is double) ? d.y : (d.dy is double ? d.dy : 0.0);
      await prefs.setInt('overlay_x', ox.toInt());
      await prefs.setInt('overlay_y', oy.toInt());
    }
  }
}
