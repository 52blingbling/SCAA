import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/unit_service.dart';
import 'screens/home_screen.dart';
import 'dart:ui';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UnitService(),
      child: const MyApp(),
    ),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _GlobalOverlay(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '润农扫码激活辅助',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _GlobalOverlay extends StatefulWidget {
  const _GlobalOverlay({Key? key}) : super(key: key);

  @override
  State<_GlobalOverlay> createState() => _GlobalOverlayState();
}

class _GlobalOverlayState extends State<_GlobalOverlay> {
  String unitLabel = '';
  String content = '';
  int sequence = 1;
  Color borderColor = Colors.white;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) async {
      if (event is Map) {
        final m = Map<String, dynamic>.from(event);
        setState(() {
          unitLabel = '${m['unit_name'] ?? ''}单元-${m['sequence'] ?? 1}';
          content = m['content'] ?? '';
          sequence = m['sequence'] ?? 1;
        });
        if (m['feedback'] == 'success') {
          setState(() => borderColor = Colors.greenAccent);
          HapticFeedback.lightImpact();
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) setState(() => borderColor = Colors.white);
        }
      } else if (event is String) {
        if (event == 'feedback_success') {
          setState(() => borderColor = Colors.greenAccent);
          HapticFeedback.lightImpact();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => borderColor = Colors.white);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unitLabel.isEmpty ? '未选择单元' : unitLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 220,
                        child: Text(
                          content.isEmpty ? '暂无内容' : content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                FlutterOverlayWindow.shareData({'action': 'prev'});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.chevron_left, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: content));
                                HapticFeedback.selectionClick();
                                FlutterOverlayWindow.shareData({'action': 'copied', 'sequence': sequence});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('粘贴'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                FlutterOverlayWindow.shareData({'action': 'next'});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.chevron_right, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                final pos = await FlutterOverlayWindow.getOverlayPosition();
                                FlutterOverlayWindow.shareData({'action': 'save_position', 'position': pos});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.push_pin, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        FlutterOverlayWindow.closeOverlay();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
