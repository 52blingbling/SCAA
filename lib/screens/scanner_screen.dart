import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../services/permission_service.dart';
import '../services/audio_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../widgets/camera_scanner.dart';

class ScannerScreen extends StatefulWidget {
  final String unitId;
  final bool isMasterScan;

  const ScannerScreen({Key? key, required this.unitId, this.isMasterScan = false}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // 使用自定义 CameraScanner
  final MethodChannel _nativeChannel = const MethodChannel('scan_assistant/native');
  String? _resultCode;
  bool _permissionGranted = false;
  bool _scanSuccess = false;
  bool _isProcessing = false;
  bool _invalidFeedback = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Camera lifecycle handled inside CameraScanner
  }

  Future<void> _requestCameraPermission() async {
    final granted = await PermissionService.requestCameraPermission(context);
    setState(() {
      _permissionGranted = granted;
    });
    
    if (granted && mounted) {
      // CameraScanner 会在自身初始化时打开相机
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMasterScan ? '主控扫码' : '扫码界面'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _permissionGranted
          ? Column(
              children: [
                Expanded(
                  flex: 4,
                  child: LayoutBuilder(builder: (context, constraints) {
                    return Stack(
                        fit: StackFit.expand,
                        children: [
                              // 使用自定义 CameraScanner 替代 mobile_scanner 以便支持对焦/曝光/变焦手势
                              CameraScanner(
                                onDetect: (text) async {
                                  // reuse existing _onDetect flow by constructing a fake BarcodeCapture flow
                                  if (_isProcessing) return;
                                  _isProcessing = true;
                                  setState(() {
                                    _resultCode = text;
                                    _scanSuccess = true;
                                  });
                                  AudioService.playScanSound();
                                  HapticFeedback.lightImpact();
                                  await Future.delayed(const Duration(milliseconds: 300));
                                  if (mounted) {
                                    if (widget.isMasterScan) {
                                      Provider.of<UnitService>(context, listen: false).setMasterCode(widget.unitId, text);
                                    } else {
                                      Provider.of<UnitService>(context, listen: false).addScanRecord(widget.unitId, text);
                                    }
                                    setState(() => _scanSuccess = false);
                                    Navigator.pop(context);
                                  }
                                  _isProcessing = false;
                                },
                              ),
                      // 扫描框和遮罩 - 加入 IgnorePointer 允许手势穿透到底层 CameraScanner
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
                                      hole: RRect.fromRectAndRadius(rect, const Radius.circular(16)),
                                      borderColor: _invalidFeedback
                                          ? Colors.redAccent
                                          : (_scanSuccess ? Colors.greenAccent : Colors.white),
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
                                  '将二维码置于白色框内',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: (_resultCode != null)
                    ? Text('扫描结果: ${_resultCode!}')
                    : const Text('请将二维码对准扫描框'),
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
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final RRect hole;
  final Color borderColor;
  _ScannerOverlayPainter({required this.hole, required this.borderColor});
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final overlayPaint = Paint()..color = const Color(0x88000000);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(hole);
    canvas.drawPath(cutout, overlayPaint);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(hole, borderPaint);
  }
  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.hole != hole;
  }
}
