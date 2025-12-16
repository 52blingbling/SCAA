import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter/material.dart';

class PermissionService {
  // 请求相机权限
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await ph.Permission.camera.request();
    if (status != ph.PermissionStatus.granted) {
      if (context.mounted) {
        _showPermissionDeniedDialog(
          context,
          '相机权限被拒绝',
          '应用需要相机权限才能扫描二维码，请在设置中开启相机权限。',
        );
      }
      return false;
    }
    return true;
  }

  // 检查相机权限
  static Future<bool> checkCameraPermission() async {
    final status = await ph.Permission.camera.status;
    return status == ph.PermissionStatus.granted;
  }

  // 请求存储权限
  static Future<bool> requestStoragePermission(BuildContext context) async {
    final status = await ph.Permission.storage.request();
    if (status != ph.PermissionStatus.granted) {
      if (context.mounted) {
        _showPermissionDeniedDialog(
          context,
          '存储权限被拒绝',
          '应用需要存储权限才能保存数据，请在设置中开启存储权限。',
        );
      }
      return false;
    }
    return true;
  }

  // 检查存储权限
  static Future<bool> checkStoragePermission() async {
    final status = await ph.Permission.storage.status;
    return status == ph.PermissionStatus.granted;
  }

  // 打开应用设置页面
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  // 显示权限被拒绝对话框
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
  }
}
