import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/unit.dart';
import '../services/qr_service.dart';

class ShareQRScreen extends StatefulWidget {
  final Unit unit;

  const ShareQRScreen({Key? key, required this.unit}) : super(key: key);

  @override
  State<ShareQRScreen> createState() => _ShareQRScreenState();
}

class _ShareQRScreenState extends State<ShareQRScreen> {
  // no global key needed; render QR with QrPainter
  bool _isSaving = false;
  String? _qrData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 先检查是否能放入二维码容量
    if (!QRService.canFitInQR(widget.unit.scanRecords)) {
      _errorMessage = '生成失败：数据超出二维码最大容量，无法生成二维码。';
      _qrData = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('生成失败'),
            content: Text(_errorMessage!),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
            ],
          ),
        );
      });
    } else {
      _qrData = QRService.encodeUnit(widget.unit);
    }
    // init done
  }

  Future<void> _saveQRCode() async {
    setState(() => _isSaving = true);
    
    try {
      // 创建一个包含二维码和标题的图片
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      const width = 600.0;
      const height = 750.0;
      
      // 白色背景
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white,
      );
      
      // 使用 QrPainter 在画布上直接绘制二维码
      final painter = QrPainter(
        data: _qrData!,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        embeddedImageStyle: null,
      );

      canvas.save();
      canvas.translate(50, 80);
      painter.paint(canvas, const Size(500, 500));
      canvas.restore();
      
      // 绘制单元名称标题
      final textPainter = TextPainter(
        text: TextSpan(
          text: '单元: ${widget.unit.name}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (width - textPainter.width) / 2,
          620,
        ),
      );
      
      // 绘制记录数信息
      final infoText = '共 ${widget.unit.scanRecords.length} 条记录';
      final infoPainter = TextPainter(
        text: TextSpan(
          text: infoText,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      infoPainter.layout();
      infoPainter.paint(
        canvas,
        Offset(
          (width - infoPainter.width) / 2,
          670,
        ),
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        width.toInt(),
        height.toInt(),
      );
      
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final String base64Str = base64Encode(bytes);

        try {
          final channel = MethodChannel('scan_assistant/native');
          final bool? ok = await channel.invokeMethod('saveImage', {
            'bytes': base64Str,
            'name': 'unit_${widget.unit.name}_qr.png',
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok == true ? '保存成功' : '保存失败'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存失败: $e'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分享单元'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 二维码显示
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _qrData != null
                        ? SizedBox(
                            width: 300,
                            height: 300,
                            child: CustomPaint(
                              painter: QrPainter(
                                data: _qrData!,
                                version: QrVersions.auto,
                                gapless: true,
                                color: Colors.black,
                                embeddedImageStyle: null,
                              ),
                            ),
                          )
                        : (_errorMessage != null)
                            ? Center(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                  ),
                  const SizedBox(height: 24),
                  // 单元信息
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '单元名称',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.unit.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '扫码记录数',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${widget.unit.scanRecords.length}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '二维码大小',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${QRService.estimateCapacity(widget.unit.scanRecords)} 字节',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // 底部按钮（外层白色卡片 + 内层蓝色按钮，文本居中）
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSaving || _qrData == null) ? null : _saveQRCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Center(
                          child: Text('保存到相册', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
