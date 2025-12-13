import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../services/permission_service.dart';
import '../services/audio_service.dart';
import 'dart:io' show Platform;

class ScannerScreen extends StatefulWidget {
  final String unitId;

  const ScannerScreen({Key? key, required this.unitId}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    final granted = await PermissionService.requestCameraPermission(context);
    setState(() {
      _permissionGranted = granted;
    });
    
    if (granted && mounted) {
      // 权限获取成功后初始化相机
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller != null) {
          controller!.resumeCamera();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码界面'),
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
                  child: QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.red,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: (result != null)
                        ? Text('扫描结果: ${result!.code}')
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

  void _onQRViewCreated(QRViewController controller) {
    if (!_permissionGranted) return;
    
    setState(() {
      this.controller = controller;
    });
    
    controller.scannedDataStream.listen((scanData) async {
      setState(() {
        result = scanData;
      });
      
      // 保存扫描结果到单元中
      if (result != null) {
        // 播放扫描成功音效
        AudioService.playScanSound();
        
        // 稍微延迟一下再保存，让用户看到扫描结果
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Provider.of<UnitService>(context, listen: false)
              .addScanRecord(widget.unitId, result!.code!);
          
          // 返回上一页面
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}