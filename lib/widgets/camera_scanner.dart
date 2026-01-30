import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
  double _currentExposure = -2.0;
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
      // Try to set auto focus mode if supported
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('Focus mode error: $e');
      }
      // 尝试设置较低的默认曝光度，提高二维码识别率
      try {
        await _controller!.setExposureOffset(-2.0);
      } catch (e) {
        debugPrint('Set exposure error: $e');
      }
      
      // start image stream for real-time decoding
      try {
        await _controller!.startImageStream(_handleCameraImage);
      } catch (e) {
        // fallback to periodic capture if stream fails
        _captureTimer = Timer.periodic(widget.captureInterval, (_) => _periodicCapture());
      }
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
      try { File(path).deleteSync(); } catch (_) {}
    } catch (e) {
      // ignore
    } finally {
      _busy = false;
    }
  }

  // imageStream handler and YUV -> NV21 converter
  DateTime _lastDecode = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _minInterval = const Duration(milliseconds: 200);

  void _handleCameraImage(CameraImage image) async {
    // throttle
    if (DateTime.now().difference(_lastDecode) < _minInterval) return;
    if (_busy) return;
    _busy = true;
    _lastDecode = DateTime.now();
    try {
      if (Platform.isAndroid) {
        final nv21 = _convertYUV420ToNV21(image);
        try {
          final decoded = await _native.invokeMethod('decodeImageBytes', {
            'bytes': nv21,
            'width': image.width,
            'height': image.height,
          });
          if (decoded != null && decoded is String && decoded.isNotEmpty) {
            widget.onDetect(decoded);
          }
        } catch (e) {
          // ignore decode errors
        }
      } else {
        // iOS fallback: periodic file capture
        final XFile file = await _controller!.takePicture();
        final path = file.path;
        final decoded = await _native.invokeMethod('decodeImage', {'path': path});
        if (decoded != null && decoded is String && decoded.isNotEmpty) {
          widget.onDetect(decoded);
        }
        try { File(path).deleteSync(); } catch (_) {}
      }
    } catch (e) {
      // ignore
    } finally {
      _busy = false;
    }
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    // copy Y
    if (yPlane.bytes.length == ySize) {
      nv21.setRange(0, ySize, yPlane.bytes);
    } else {
      int dst = 0;
      for (int i = 0; i < height; i++) {
        final int srcOffset = i * yPlane.bytesPerRow;
        nv21.setRange(dst, dst + width, yPlane.bytes.sublist(srcOffset, srcOffset + width));
        dst += width;
      }
    }

    // interleave V and U (NV21: VU VU ...)
    int dst = ySize;
    final int chromaHeight = (height / 2).floor();
    final int chromaWidth = (width / 2).floor();
    for (int row = 0; row < chromaHeight; row++) {
      for (int col = 0; col < chromaWidth; col++) {
        final int uIndex = ((row * (uPlane.bytesPerRow ?? 0)) + (col * (uPlane.bytesPerPixel ?? 1))).toInt();
        final int vIndex = ((row * (vPlane.bytesPerRow ?? 0)) + (col * (vPlane.bytesPerPixel ?? 1))).toInt();
        // V
        nv21[dst++] = vPlane.bytes[vIndex];
        // U
        nv21[dst++] = uPlane.bytes[uIndex];
      }
    }
    return nv21;
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

  Offset? _focusPoint;
  bool _showFocusCircle = false;

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () async {
              final newZoom = _currentZoom > 1.0 ? 1.0 : 2.0;
              setState(() => _currentZoom = newZoom);
              try {
                if (_controller != null) {
                  await _controller!.setZoomLevel(newZoom);
                } else {
                  await _native.invokeMethod('setZoom', {'scale': newZoom});
                }
              } catch (e) {
                try {
                  await _native.invokeMethod('setZoom', {'scale': newZoom});
                } catch (_) {}
              }
            },
            onTapDown: (details) async {
              final dx = details.localPosition.dx / constraints.maxWidth;
              final dy = details.localPosition.dy / constraints.maxHeight;
              
              setState(() {
                _focusPoint = details.localPosition;
                _showFocusCircle = true;
              });

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

              // Hide focus circle after a delay
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _showFocusCircle = false;
                  });
                }
              });
            },
            onVerticalDragUpdate: (details) async {
              final delta = -details.delta.dy / constraints.maxHeight; // normalized
              // 先尝试 camera 插件的 setExposureOffset（如果支持）；失败则回退到原生
              try {
                // 使用类字段跟踪当前曝光偏移
                final newOffset = (_currentExposure + delta).clamp(-2.0, 2.0);
                await _controller!.setExposureOffset(newOffset);
                _currentExposure = newOffset;
              } catch (e) {
                try {
                  await _native.invokeMethod('setExposure', {'delta': delta});
                } catch (_) {}
              }
            },
            onScaleStart: (details) => _baseZoom = _currentZoom,
            onScaleUpdate: (details) async {
              final scale = (_baseZoom * details.scale).clamp(1.0, 6.0);
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
            child: ClipRect(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: Builder(builder: (context) {
                    var ratio = _controller!.value.aspectRatio;
                    // For portrait apps, we want the taller ratio.
                    // If ratio > 1 (e.g. 1.33), it means it's returning landscape.
                    // We invert it to get the portrait aspect ratio (0.75).
                    if (ratio > 1) ratio = 1 / ratio;
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxWidth / ratio,
                      child: CameraPreview(_controller!),
                    );
                  }),
                ),
              ),
            ),
          ),
          if (_showFocusCircle && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    });
  }
}
