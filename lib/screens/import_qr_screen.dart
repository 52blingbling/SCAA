import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
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
  MobileScannerController? _controller;
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
    
    if (status && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller ??= MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          detectionTimeoutMs: 300,
        );
        _controller!.start();
      });
    }
  }

  Future<bool> _checkCameraPermission() async {
    // 这里应该使用真实的权限检查
    return true;
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        setState(() => _isProcessing = true);
        
        // 读取图片文件
        final imageBytes = await File(pickedFile.path).readAsBytes();
        
        // 解码二维码
        final qrData = await _decodeQRFromImage(imageBytes);
        
        if (qrData != null) {
          _handleQRData(qrData);
        } else {
          setState(() {
            _errorMessage = '未能识别二维码，请选择包含二维码的图片';
          });
        }
        
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '读取图片失败: $e';
        _isProcessing = false;
      });
    }
  }

  Future<String?> _decodeQRFromImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // 使用 Google ML Kit 进行二维码识别
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final barcodeScanner = BarcodeScanner();
      final barcodes = await barcodeScanner.processImage(inputImage);

      for (final barcode in barcodes) {
        if (barcode.type == BarcodeType.qrCode && barcode.rawValue != null) {
          await barcodeScanner.close();
          return barcode.rawValue;
        }
      }

      await barcodeScanner.close();
      return null;
    } catch (e) {
      print('二维码解码错误: $e');
      return null;
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
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '解析失败: $e';
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() => _isProcessing = true);
        _handleQRData(barcode.rawValue!);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入单元'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _permissionGranted
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller ??= MobileScannerController(
                    detectionSpeed: DetectionSpeed.normal,
                    detectionTimeoutMs: 300,
                  ),
                  onDetect: _onDetect,
                ),
                // 扫描框
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
                    return CustomPaint(
                      painter: _ScannerOverlayPainter(
                        hole: RRect.fromRectAndRadius(
                          rect,
                          const Radius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
                // 中心提示文字
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _pickImageFromGallery,
        icon: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.photo_library_rounded),
        label: Text(_isProcessing ? '处理中...' : '从相册导入'),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final RRect hole;

  _ScannerOverlayPainter({required this.hole});

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
