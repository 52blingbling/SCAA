import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

class OverlayService {
  // 初始化悬浮窗
  static Future<void> initializeOverlay() async {
    await FlutterOverlayWindow.initialize();
  }

  // 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  // 请求悬浮窗权限
  static Future<bool> requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    if (granted) return true;
    final status = await ph.Permission.systemAlertWindow.request();
    return status == ph.PermissionStatus.granted;
  }

  // 显示悬浮窗
  static Future<void> showOverlay() async {
    if (await checkOverlayPermission()) {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getInt('overlay_x');
      final y = prefs.getInt('overlay_y');
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        positionGravity: PositionGravity.auto,
        overlayTitle: '快捷助手已开启',
        overlayContent: '跨应用悬浮窗',
        startPosition: (x != null && y != null) ? OverlayPosition(x, y) : null,
      );
    }
  }

  // 隐藏悬浮窗
  static Future<void> hideOverlay() async {
    await FlutterOverlayWindow.hideOverlay();
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
      await prefs.setInt('overlay_x', pos.dx.toInt());
      await prefs.setInt('overlay_y', pos.dy.toInt());
    }
  }
}
