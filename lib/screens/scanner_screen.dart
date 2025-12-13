import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../services/permission_service.dart';
import '../services/audio_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class ScannerScreen extends StatefulWidget {
  final String unitId;

  const ScannerScreen({Key? key, required this.unitId}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  String? _resultCode;
  bool _permissionGranted = false;
  bool _scanSuccess = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _controller?.stop();
    } else if (Platform.isIOS) {
      _controller?.start();
    }
  }

  Future<void> _requestCameraPermission() async {
    final granted = await PermissionService.requestCameraPermission(context);
    setState(() {
      _permissionGranted = granted;
    });
    
    if (granted && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller ??= MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          detectionTimeoutMs: 300,
        );
        _controller!.start();
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller ??= MobileScannerController(
                          detectionSpeed: DetectionSpeed.normal,
                          detectionTimeoutMs: 300,
                        ),
                        onDetect: _onDetect,
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.2),
                      ),
                      Center(
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _scanSuccess ? Colors.greenAccent : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '对准二维码',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  void _onDetect(BarcodeCapture capture) async {
    if (!_permissionGranted) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final first = barcodes.first;
    final code = first.rawValue ?? first.displayValue;
    if (code == null || code.isEmpty) return;
    setState(() {
      _resultCode = code;
      _scanSuccess = true;
    });
    AudioService.playScanSound();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Provider.of<UnitService>(context, listen: false)
          .addScanRecord(widget.unitId, code);
      setState(() => _scanSuccess = false);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
