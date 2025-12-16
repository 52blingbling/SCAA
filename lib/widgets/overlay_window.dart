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
  bool _isCopied = false;
  bool _showToast = false;
  String _toastMessage = '已复制';
  bool _isToastError = false;

  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 监听窗口调整
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOverlaySize();
    });

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
          
          // 预计算尺寸并调整窗口
          _preCalculateAndResize();
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

  // 预计算尺寸逻辑
  void _preCalculateAndResize() {
    try {
      // 1. 基础参数定义 (与 build 方法中的布局参数保持一致)
      const double containerWidth = 360;
      const double horizontalPadding = 28; // 16 + 12
      const double contentWidth = containerWidth - horizontalPadding;
      
      // 2. 计算 Unit Label 高度
      final labelHeight = _calculateTextHeight(
        unitLabel.isEmpty ? '未选择' : unitLabel,
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: '.SF Pro Text',
          height: 1.3,
        ),
        contentWidth,
        2, // maxLines
      );
      
      // 3. 计算 Content 高度
      // 内部 Container padding: vertical 12 * 2 = 24
      // Text height: fontSize 16 * 1.2 = 19.2
      // Total box height = 24 + 19.2 = 43.2 (approx)
      const double contentBoxHeight = 44.0; // 固定一行的高度近似值
      
      // 4. 其他固定高度
      const double spacer1 = 8;
      const double spacer2 = 12;
      const double controlsHeight = 44;
      const double containerVerticalPadding = 32; // 16 top + 16 bottom
      const double shadowMargin = 0;
      
      // 5. 总高度计算
      final double totalHeight = labelHeight + spacer1 + contentBoxHeight + spacer2 + controlsHeight + containerVerticalPadding + shadowMargin;
      
      // 6. 执行调整（width/height 使用逻辑像素，插件内部会换算）
      final int w = containerWidth.toInt();
      final int h = totalHeight.toInt();
      
      // 使用 resizeOverlay 调整 native 窗口
      FlutterOverlayWindow.resizeOverlay(w, h, true);
      
    } catch (e) {
      debugPrint('Error pre-calculating size: $e');
      // Fallback to post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateOverlaySize();
      });
    }
  }

  double _calculateTextHeight(String text, TextStyle style, double maxWidth, int maxLines) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    textPainter.layout(minWidth: 0, maxWidth: maxWidth);
    return textPainter.height;
  }


  Future<void> _updateOverlaySize() async {
    if (!mounted) return;
    try {
      final RenderBox? renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final size = renderBox.size;
        final int w = size.width.toInt();
        final int h = size.height.toInt();
        await FlutterOverlayWindow.resizeOverlay(w, h, true);
      }
    } catch (e) {
      debugPrint('Error resizing overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Center(
            child: Container(
              key: _containerKey,
              width: 360,
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
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
                        border: Border.all(
                          color: borderColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
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
                                  Text(
                                    unitLabel.isEmpty ? '未选择' : unitLabel,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.decelerate,
                                      child: Text(
                                        content.isEmpty ? '暂无内容' : content,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white70,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildIconButton(
                                        icon: Icons.chevron_left_rounded,
                                        onTap: () {
                                          if (records.isNotEmpty &&
                                              currentPos > 0) {
                                            setState(() {
                                              currentPos -= 1;
                                              content =
                                                  records[currentPos]
                                                          ['content'] ??
                                                      '';
                                              sequence =
                                                  records[currentPos]['index'] ??
                                                      sequence - 1;
                                              if (unitLabel.contains('-')) {
                                                final parts =
                                                    unitLabel.split('-');
                                                if (parts.isNotEmpty) {
                                                  unitLabel =
                                                      '${parts[0]}-$sequence';
                                                }
                                              }
                                              _isCopied = false;
                                              _showToast = false;
                                              _isToastError = false;
                                              _toastMessage = '已复制';
                                              _preCalculateAndResize();
                                            });
                                          }
                                          FlutterOverlayWindow.shareData(
                                            {'action': 'prev'},
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _OverlayButton(
                                          onTap: () async {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _isCopied = true;
                                              _showToast = true;
                                              _toastMessage = '已复制';
                                              _isToastError = false;
                                            });
                                            FlutterOverlayWindow.shareData({
                                              'action': 'copied',
                                              'sequence': sequence,
                                              'content': content,
                                            });
                                            try {
                                              await Clipboard.setData(
                                                ClipboardData(text: content),
                                              );
                                            } catch (e) {
                                              debugPrint('Clipboard error: $e');
                                              setState(() {
                                                _toastMessage = '复制失败';
                                                _isToastError = true;
                                              });
                                            }

                                            Future.delayed(
                                              const Duration(
                                                seconds: 1,
                                                milliseconds: 500,
                                              ),
                                              () {
                                                if (mounted) {
                                                  setState(() {
                                                    _isCopied = false;
                                                  });
                                                }
                                              },
                                            );
                                            Future.delayed(
                                              const Duration(seconds: 2),
                                              () {
                                                if (mounted) {
                                                  setState(() {
                                                    _showToast = false;
                                                    _isToastError = false;
                                                    _toastMessage = '已复制';
                                                  });
                                                }
                                              },
                                            );
                                          },
                                          height: 44,
                                          backgroundColor: _isCopied
                                              ? Colors.green
                                              : const Color(0xFF007AFF),
                                          pressedColor: _isCopied
                                              ? Colors.green[700]!
                                              : const Color(0xFF0056B3),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          child: Text(
                                            _isCopied ? '已复制' : '复制',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildIconButton(
                                        icon: Icons.chevron_right_rounded,
                                        onTap: () {
                                          if (records.isNotEmpty &&
                                              currentPos < records.length - 1) {
                                            setState(() {
                                              currentPos += 1;
                                              content =
                                                  records[currentPos]
                                                          ['content'] ??
                                                      '';
                                              sequence =
                                                  records[currentPos]['index'] ??
                                                      sequence + 1;
                                              if (unitLabel.contains('-')) {
                                                final parts =
                                                    unitLabel.split('-');
                                                if (parts.isNotEmpty) {
                                                  unitLabel =
                                                      '${parts[0]}-$sequence';
                                                }
                                              }
                                              _isCopied = false;
                                              _showToast = false;
                                              _isToastError = false;
                                              _toastMessage = '已复制';
                                              _preCalculateAndResize();
                                            });
                                          }
                                          FlutterOverlayWindow.shareData(
                                            {'action': 'next'},
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                FlutterOverlayWindow.shareData(
                                  {'action': 'closed'},
                                );
                                FlutterOverlayWindow.closeOverlay();
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
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
          _showToast ? Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _isToastError
                    ? Colors.red.withOpacity(0.9)
                    : Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _isToastError
                        ? Icons.error_outline
                        : Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _toastMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ) : Container(),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return _OverlayButton(
      onTap: onTap,
      width: 44,
      height: 44,
      backgroundColor: Colors.white.withOpacity(0.15),
      pressedColor: Colors.white.withOpacity(0.4),
      shape: BoxShape.circle,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _OverlayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color pressedColor;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  const _OverlayButton({
    Key? key,
    required this.child,
    required this.onTap,
    required this.backgroundColor,
    required this.pressedColor,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
    this.alignment,
  }) : super(key: key);

  @override
  State<_OverlayButton> createState() => _OverlayButtonState();
}

class _OverlayButtonState extends State<_OverlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment ?? Alignment.center,
        decoration: BoxDecoration(
          color: _isPressed ? widget.pressedColor : widget.backgroundColor,
          borderRadius: widget.shape == BoxShape.circle ? null : widget.borderRadius,
          shape: widget.shape,
        ),
        child: widget.child,
      ),
    );
  }
}
