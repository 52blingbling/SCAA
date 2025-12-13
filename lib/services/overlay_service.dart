import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final status = await Permission.systemAlertWindow.request();
    return status == PermissionStatus.granted;
  }

  // 显示悬浮窗
  static Future<void> showOverlay() async {
    if (await checkOverlayPermission()) {
      await FlutterOverlayWindow.showOverlay();
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
}