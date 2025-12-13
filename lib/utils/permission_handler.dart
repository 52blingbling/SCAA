import 'package:permission_handler/permission_handler.dart';

class PermissionHandler {
  // 请求相机权限
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  // 检查相机权限
  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status == PermissionStatus.granted;
  }

  // 请求悬浮窗权限（Android）
  static Future<bool> requestOverlayPermission() async {
    if (await Permission.systemAlertWindow.isDenied) {
      final status = await Permission.systemAlertWindow.request();
      return status == PermissionStatus.granted;
    }
    return true;
  }

  // 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    final status = await Permission.systemAlertWindow.status;
    return status == PermissionStatus.granted;
  }

  // 打开应用设置页面
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}