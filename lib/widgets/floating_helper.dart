import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';

class FloatingHelper extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final String currentContent;

  const FloatingHelper({
    Key? key,
    required this.onNext,
    required this.onPrevious,
    required this.currentContent,
  }) : super(key: key);

  @override
  State<FloatingHelper> createState() => _FloatingHelperState();
}

class _FloatingHelperState extends State<FloatingHelper> {
  double _xOffset = 100;
  double _yOffset = 100;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _xOffset,
      top: _yOffset,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _xOffset += details.delta.dx;
            _yOffset += details.delta.dy;
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: Container(
          width: 120,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 上一个按钮
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.blue),
                onPressed: widget.onPrevious,
              ),
              
              // 粘贴按钮
              IconButton(
                icon: const Icon(Icons.content_paste, color: Colors.green),
                onPressed: () async {
                  // 播放按钮点击音效
                  AudioService.playScanSound(); // 使用扫描音效作为按钮音效
                  
                  // 将当前内容复制到剪贴板
                  await Clipboard.setData(ClipboardData(text: widget.currentContent));
                  
                  // 显示短暂的提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制到剪贴板'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              
              // 下一个按钮
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.blue),
                onPressed: widget.onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}