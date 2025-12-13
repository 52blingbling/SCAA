import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionHandler {
  // 请求相机权限
  static Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return status == ph.PermissionStatus.granted;
  }

  // 检查相机权限
  static Future<bool> checkCameraPermission() async {
    final status = await ph.Permission.camera.status;
    return status == ph.PermissionStatus.granted;
  }

  // 请求悬浮窗权限（Android）
  static Future<bool> requestOverlayPermission() async {
    if (await ph.Permission.systemAlertWindow.isDenied) {
      final status = await ph.Permission.systemAlertWindow.request();
      return status == ph.PermissionStatus.granted;
    }
    return true;
  }

  // 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    final status = await ph.Permission.systemAlertWindow.status;
    return status == ph.PermissionStatus.granted;
  }

  // 打开应用设置页面
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
