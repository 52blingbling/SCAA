import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWindow extends StatefulWidget {
  const OverlayWindow({Key? key}) : super(key: key);

  @override
  State<OverlayWindow> createState() => _OverlayWindowState();
}

class _OverlayWindowState extends State<OverlayWindow> {
  String unitLabel = '';
  String content = '';
  int sequence = 1;
  Color borderColor = Colors.white;
  List<Map<String, dynamic>> records = [];
  int currentPos = 0;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) async {
      if (event is Map) {
        final m = Map<String, dynamic>.from(event);
        setState(() {
          // 只更新非空字段，防止覆盖已有数据
          if (m.containsKey('unit_name')) {
            unitLabel = '${m['unit_name']}-${m['sequence'] ?? 1}';
          }
          // 只有在明确传入 content 时才更新，或者 records 为空时
          if (m.containsKey('content')) {
            content = m['content'];
          }
          if (m.containsKey('sequence')) {
            sequence = m['sequence'];
          }
          
          if (m['records'] is List) {
            records = List<Map<String, dynamic>>.from(m['records']);
            // 如果传入了 sequence，尝试定位到对应 index
            if (m.containsKey('sequence')) {
               final seq = m['sequence'];
               final idx = records.indexWhere((r) => r['index'] == seq);
               if (idx != -1) {
                 currentPos = idx;
               } else {
                 currentPos = 0;
               }
            } else {
               currentPos = 0;
            }
            
            // 刷新当前显示内容
            if (records.isNotEmpty && currentPos < records.length) {
              content = records[currentPos]['content'] ?? '';
              sequence = records[currentPos]['index'] ?? 1;
              // 更新标题中的序号
              if (unitLabel.contains('-')) {
                 final parts = unitLabel.split('-');
                 if (parts.isNotEmpty) {
                    unitLabel = '${parts[0]}-$sequence';
                 }
              }
            } else {
               content = '暂无内容';
               // sequence 保持不变或设为 1
            }
          }
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
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: '.SF Pro Text',
                      letterSpacing: -0.5,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header: Title and Pin
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      unitLabel.isEmpty ? '未选择' : unitLabel,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final pos = await FlutterOverlayWindow.getOverlayPosition();
                                      FlutterOverlayWindow.shareData({'action': 'save_position', 'position': pos});
                                      HapticFeedback.lightImpact();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.push_pin_rounded, color: Colors.white70, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Content
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  content.isEmpty ? '暂无内容' : content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildIconButton(
                                    icon: Icons.chevron_left_rounded,
                                    onTap: () {
                                      if (records.isNotEmpty && currentPos > 0) {
                                        setState(() {
                                          currentPos -= 1;
                                          content = records[currentPos]['content'] ?? '';
                                          sequence = records[currentPos]['index'] ?? sequence - 1;
                                          if (unitLabel.contains('-')) {
                                             final parts = unitLabel.split('-');
                                             if (parts.isNotEmpty) {
                                                unitLabel = '${parts[0]}-$sequence';
                                             }
                                          }
                                        });
                                      }
                                      FlutterOverlayWindow.shareData({'action': 'prev'});
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        await Clipboard.setData(ClipboardData(text: content));
                                        HapticFeedback.selectionClick();
                                        FlutterOverlayWindow.shareData({'action': 'copied', 'sequence': sequence});
                                      },
                                      child: Container(
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF007AFF),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          '粘贴',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildIconButton(
                                    icon: Icons.chevron_right_rounded,
                                    onTap: () {
                                      if (records.isNotEmpty && currentPos < records.length - 1) {
                                        setState(() {
                                          currentPos += 1;
                                          content = records[currentPos]['content'] ?? '';
                                          sequence = records[currentPos]['index'] ?? sequence + 1;
                                          if (unitLabel.contains('-')) {
                                             final parts = unitLabel.split('-');
                                             if (parts.isNotEmpty) {
                                                unitLabel = '${parts[0]}-$sequence';
                                             }
                                          }
                                        });
                                      }
                                      FlutterOverlayWindow.shareData({'action': 'next'});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Close Button
                        GestureDetector(
                          onTap: () {
                            FlutterOverlayWindow.shareData({'action': 'closed'});
                            FlutterOverlayWindow.closeOverlay();
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
