import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import '../models/unit.dart';
import '../services/qr_service.dart';

class ShareQRScreen extends StatefulWidget {
  final Unit unit;

  const ShareQRScreen({Key? key, required this.unit}) : super(key: key);

  @override
  State<ShareQRScreen> createState() => _ShareQRScreenState();
}

class _ShareQRScreenState extends State<ShareQRScreen> {
  late GlobalKey<QrImageViewState> qrKey;
  bool _isSaving = false;
  String? _qrData;

  @override
  void initState() {
    super.initState();
    qrKey = GlobalKey<QrImageViewState>();
    _qrData = QRService.encodeUnit(widget.unit);
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
      
      // 生成二维码图像
      final qrImage = await QrImage(
        data: _qrData!,
        version: QrVersions.auto,
        size: 500,
      ).toImage(context);
      
      // 绘制二维码（居中）
      canvas.drawImage(
        qrImage,
        const Offset(50, 80),
        Paint(),
      );
      
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
        // 将图片写入临时文件，再调用 gallery_saver 保存到相册
        final tempDir = Directory.systemTemp;
        final file = await File('${tempDir.path}/unit_${widget.unit.name}_qr.png')
            .writeAsBytes(byteData.buffer.asUint8List());

        final bool? success = await GallerySaver.saveImage(file.path, albumName: 'ScanAssistant');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success == true ? '保存成功' : '保存失败'),
              duration: const Duration(seconds: 2),
            ),
          );
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
                        ? QrImage(
                            key: qrKey,
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: 300,
                            backgroundColor: Colors.white,
                            errorStateBuilder: (context, error) {
                              return Center(
                                child: Text('数据过大: $error'),
                              );
                            },
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
          // 底部按钮
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom + 16,
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
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveQRCode,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(_isSaving ? '保存中...' : '保存到相册'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
