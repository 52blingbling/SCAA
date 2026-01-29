import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../widgets/camera_scanner.dart';
import '../services/qr_service.dart';
import '../services/unit_service.dart';
import '../models/unit.dart';

class ImportQRScreen extends StatefulWidget {
  final Function(Unit) onUnitImported;

  const ImportQRScreen({Key? key, required this.onUnitImported})
      : super(key: key);

  @override
  State<ImportQRScreen> createState() => _ImportQRScreenState();
}

class _ImportQRScreenState extends State<ImportQRScreen> {
  bool _permissionGranted = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    // 简化权限逻辑，实际权限在 CameraScanner 内部处理
    setState(() {
      _permissionGranted = true;
    });
  }

  void _handleQRData(String text) async {
    final unitService = Provider.of<UnitService>(context, listen: false);
    
    // 尝试解析为单元分享码（包含主控码和记录列表）
    final importedUnit = QRService.decodeUnit(text);
    
    if (importedUnit != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入单元: ${importedUnit.name}'), backgroundColor: Colors.green),
        );
        widget.onUnitImported(importedUnit);
        Navigator.pop(context);
      }
    } else {
      // 如果解析失败，说明扫到的可能是一个普通的设备码，而不是分享码
      // 提供“快速创建”功能
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('识别为设备编码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('该二维码不是标准的“单元分享码”，看起来是一个设备编码：'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100], 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!)
                  ),
                  child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                ),
                const SizedBox(height: 12),
                const Text('是否以此编码创建一个新单元？'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final unitName = '新设备单元_${DateTime.now().hour}${DateTime.now().minute}';
                  await unitService.addUnit(unitName);
                  final units = unitService.units;
                  if (units.isNotEmpty) {
                    await unitService.addScanRecord(units.last.id, text);
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('立即创建'),
              ),
            ],
          ),
        );
      }
    }
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

      final channel = const MethodChannel('scan_assistant/native');
      final String? decoded = await channel.invokeMethod('decodeImage', {'path': pickedFile.path});

      if (decoded != null && decoded.isNotEmpty) {
        _handleQRData(decoded);
      } else {
        setState(() {
          _errorMessage = '未能识别图片中的二维码，请选择清晰的图片';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '读取图片失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
                CameraScanner(
                  onDetect: (text) async {
                    if (_isProcessing) return;
                    setState(() { _isProcessing = true; });
                    try {
                      _handleQRData(text);
                    } finally {
                      if (mounted) setState(() { _isProcessing = false; });
                    }
                  },
                ),
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
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
          : const Center(child: CircularProgressIndicator()),
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
    final overlayPaint = Paint()..color = const Color(0xAA000000);
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
