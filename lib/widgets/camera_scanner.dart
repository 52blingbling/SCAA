import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// CameraScanner
/// - 使用 camera 插件做预览与控制（变焦、曝光、点击对焦）
/// - 周期性调用 takePicture 并通过 MethodChannel 调用原生 decodeImage(path)
/// - onDetect 回调在成功解析到二维码文本时触发
class CameraScanner extends StatefulWidget {
  final void Function(String) onDetect;
  final Duration captureInterval;
  const CameraScanner({Key? key, required this.onDetect, this.captureInterval = const Duration(milliseconds: 800)}) : super(key: key);

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  Timer? _captureTimer;
  bool _busy = false;
  final MethodChannel _native = const MethodChannel('scan_assistant/native');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      CameraDescription? back;
      for (var c in _cameras!) {
        if (c.lensDirection == CameraLensDirection.back) { back = c; break; }
      }
      final cam = back ?? (_cameras!.isNotEmpty ? _cameras!.first : null);
      if (cam == null) return;
      _controller = CameraController(cam, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await _controller!.initialize();
      // start periodic capture
      _captureTimer = Timer.periodic(widget.captureInterval, (_) => _periodicCapture());
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _periodicCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_busy) return;
    _busy = true;
    try {
      final XFile file = await _controller!.takePicture();
      final path = file.path;
      final decoded = await _native.invokeMethod('decodeImage', {'path': path});
      if (decoded != null && decoded is String && decoded.isNotEmpty) {
        widget.onDetect(decoded);
      }
      // remove temp file to save space
      try { File(path).deleteSync(); } catch (_) {}
    } catch (e) {
      // ignore occasional failures
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameras();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) async {
          final dx = details.localPosition.dx / constraints.maxWidth;
          final dy = details.localPosition.dy / constraints.maxHeight;
          // 尝试使用 camera 插件的对焦 API；若不可用则回退到原生 MethodChannel
          try {
            await _controller!.setFocusPoint(Offset(dx, dy));
            HapticFeedback.selectionClick();
          } catch (e) {
            try {
              await _native.invokeMethod('focusAt', {'x': dx, 'y': dy});
              HapticFeedback.selectionClick();
            } catch (e2) {
              // 最终忽略错误
            }
          }
        },
        onVerticalDragUpdate: (details) async {
          final delta = -details.delta.dy / constraints.maxHeight; // normalized
          // 先尝试 camera 插件的 setExposureOffset（如果支持）；失败则回退到原生
          try {
            // 使用一个经验范围 -2.0..2.0
            double current = 0.0;
            try {
              current = await _controller!.getExposureOffset();
            } catch (_) {}
            final newOffset = (current + delta).clamp(-2.0, 2.0);
            await _controller!.setExposureOffset(newOffset);
          } catch (e) {
            try {
              await _native.invokeMethod('setExposure', {'delta': delta});
            } catch (_) {}
          }
        },
        onScaleStart: (details) => _baseZoom = _currentZoom,
        onScaleUpdate: (details) async {
          final scale = (_baseZoom * details.scale).clamp(0.5, 6.0);
          try {
            if (_controller != null) {
              await _controller!.setZoomLevel(scale);
              _currentZoom = scale;
            } else {
              await _native.invokeMethod('setZoom', {'scale': scale});
            }
          } catch (e) {
            try { await _native.invokeMethod('setZoom', {'scale': scale}); } catch(_){}
          }
        },
        child: CameraPreview(_controller!),
      );
    });
  }
}
