import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../widgets/camera_scanner.dart';
// image-from-gallery decoding removed to avoid native-decode dependency
import '../services/qr_service.dart';
import '../models/unit.dart';

class ImportQRScreen extends StatefulWidget {
  final Function(Unit) onUnitImported;

  const ImportQRScreen({Key? key, required this.onUnitImported})
      : super(key: key);

  @override
  State<ImportQRScreen> createState() => _ImportQRScreenState();
}

class _ImportQRScreenState extends State<ImportQRScreen> {
  // 使用 CameraScanner；移除 MobileScannerController 以避免冲突
  final MethodChannel _nativeChannel = const MethodChannel('scan_assistant/native');
  bool _permissionGranted = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await _checkCameraPermission();
    setState(() {
      _permissionGranted = status;
    });
  }

  Future<bool> _checkCameraPermission() async {
    return true;
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() => _isProcessing = true);
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final channel = MethodChannel('scan_assistant/native');
      final String? decoded = await channel.invokeMethod('decodeImage', {'path': pickedFile.path});

      if (decoded != null && decoded.isNotEmpty) {
        _handleQRData(decoded);
      } else {
        setState(() {
          _errorMessage = '未能识别图片中的二维码，请选择清晰的图片';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '读取图片失败: $e';
        _isProcessing = false;
      });
    }
  }

  void _handleQRData(String qrData) {
    try {
      final unit = QRService.decodeUnit(qrData);
      
      if (unit != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onUnitImported(unit);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功导入单元: ${unit.name}（${unit.scanRecords.length}条记录）'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = '无效的二维码格式';
          _isProcessing = false;
        });
        HapticFeedback.vibrate();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
        _isProcessing = false;
      });
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('导入单元', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _permissionGranted
          ? Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  return CameraScanner(
                    onDetect: (text) async {
                      if (_isProcessing) return;
                      setState(() { _isProcessing = true; });
                      try {
                        _handleQRData(text);
                      } finally {
                        if (mounted) setState(() { _isProcessing = false; });
                      }
                    },
                  );
                }),
                // 扫描框和提示文字 - 加入 IgnorePointer 允许手势穿透到底层 CameraScanner
                IgnorePointer(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final size = 260.0;
                          final rect = Rect.fromCenter(
                            center: Offset(
                              constraints.maxWidth / 2,
                              constraints.maxHeight / 2,
                            ),
                            width: size,
                            height: size,
                          );
                          return SizedBox.expand(
                            child: CustomPaint(
                              painter: _ScannerOverlayPainter(
                                hole: RRect.fromRectAndRadius(
                                  rect,
                                  const Radius.circular(16),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Center(
                        child: Container(
                          width: 260,
                          height: 260,
                          alignment: Alignment.center,
                          child: const Text(
                            '将二维码置于框内',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 错误提示
                if (_errorMessage != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.redAccent.withOpacity(0.9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _errorMessage = null);
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    '需要相机权限才能扫描二维码',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requestCameraPermission,
                    child: const Text('重新请求权限'),
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _pickImageFromGallery,
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(20),
        ),
        icon: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.photo_library_rounded, color: Colors.white),
        label: Text(
          _isProcessing ? '处理中...' : '从相册导入',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final RRect hole;

  _ScannerOverlayPainter({required this.hole});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final overlayPaint = Paint()..color = const Color(0x88000000);
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(hole);
    canvas.drawPath(cutout, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(hole, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
