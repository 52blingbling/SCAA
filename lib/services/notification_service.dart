import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/unit.dart';

class NotificationService {
  // 单例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // FlutterLocalNotificationsPlugin实例
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 初始化通知服务
  Future<void> initialize() async {
    // Android初始化设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS初始化设置
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    // 初始化设置
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 初始化通知插件
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // 处理通知点击事件
        _handleNotificationAction(details);
      },
      onDidReceiveBackgroundNotificationResponse: _handleNotificationAction,
    );

    // 创建通知渠道
    await _createNotificationChannel();
  }

  // 创建通知渠道（Android 8.0+）
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'scan_assistant_channel', // 渠道ID
      '扫码助手通知', // 渠道名称
      description: '用于快速复制扫码内容', // 渠道描述
      importance: Importance.high, // 重要性
    );

    // 注册通知渠道
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 显示常驻通知
  Future<void> showPersistentNotification({
    required String unitName,
    required String content,
    required int sequence,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'scan_assistant_channel',
      '扫码助手通知',
      channelDescription: '用于快速复制扫码内容',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'prev_action',
          '上一个',
        ),
        AndroidNotificationAction(
          'copy_action',
          '复制',
        ),
        AndroidNotificationAction(
          'next_action',
          '下一个',
        ),
      ],
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // 显示通知
    await _flutterLocalNotificationsPlugin.show(
      1, // 通知ID
      '$unitName - 第$sequence条', // 通知标题
      content, // 通知内容
      platformChannelSpecifics,
      payload: 'scan_assistant', // 通知负载
    );
  }

  // 更新通知
  Future<void> updateNotification({
    required String unitName,
    required String content,
    required int sequence,
  }) async {
    await showPersistentNotification(
      unitName: unitName,
      content: content,
      sequence: sequence,
    );
  }

  // 取消通知
  Future<void> cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(1);
  }

  // 复制内容到剪贴板
  Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }

  // 处理通知操作
  static void _handleNotificationAction(NotificationResponse response) {
    final String? payload = response.payload;
    final String? actionId = response.actionId;

    if (payload == 'scan_assistant') {
      switch (actionId) {
        case 'copy_action':
          // 复制操作会在unit_service中处理
          break;
        case 'prev_action':
          // 上一个操作会在unit_service中处理
          break;
        case 'next_action':
          // 下一个操作会在unit_service中处理
          break;
      }
    }
  }
}
