import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  // 播放扫描成功音效
  static Future<void> playScanSound() async {
    try {
      // 注意：需要在assets/audio/目录下放置实际的音频文件
      await _player.play(AssetSource('audio/scan_success.mp3'));
    } catch (e) {
      // 如果音频文件不存在，则不播放
      print('Failed to play scan sound: $e');
    }
  }

  // 偿试播放音效（静默处理）
  static Future<void> _playSoundSafely(String assetPath) async {
    try {
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      // 静默处理，不打印错误
    }
  }

  // 停止所有音效
  static Future<void> stopAllSounds() async {
    await _player.stop();
  }
  
  // 释放资源
  static Future<void> dispose() async {
    await _player.dispose();
  }
}