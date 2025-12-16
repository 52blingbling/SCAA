import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../services/permission_service.dart';
import '../models/unit.dart';
import 'scanner_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/overlay_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class UnitScreen extends StatefulWidget {
  final String unitId;

  const UnitScreen({Key? key, required this.unitId}) : super(key: key);

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  bool _showFloatingHelper = false;
  int _currentRecordIndex = 1;
  bool _overlayPermissionGranted = false;
  StreamSubscription? _overlaySub;
  int _currentPos = 0;
  Timer? _overlayActiveTimer;

  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
    // Use the broadcast stream from UnitService instead of direct listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final unitService = Provider.of<UnitService>(context, listen: false);
      
      _overlaySub = unitService.overlayStream.listen((event) {
        if (!mounted) return;
        final unit = unitService.getUnitById(widget.unitId);
        if (unit == null) return;
        if (event is Map) {
          final m = Map<String, dynamic>.from(event);
          final action = m['action'];
          if (action == 'prev') {
            setState(() {
              if (_currentPos > 0) _currentPos -= 1;
            });
          } else if (action == 'next') {
            setState(() {
              if (_currentPos < unit.scanRecords.length - 1) _currentPos += 1;
            });
          } else if (action == 'save_position') {
            OverlayService.savePosition();
          } else if (action == 'closed') {
            setState(() {
              _showFloatingHelper = false;
            });
          } else if (action == 'copied') {
            // 处理悬浮窗复制事件，实现与文本栏复制按钮相同的功能
            final content = m['content'] as String?;
            if (content != null) {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('复制成功'),
                  duration: Duration(milliseconds: 1000),
                ),
              );
            }
          }
          if (unit.scanRecords.isEmpty) return;
          _currentRecordIndex = unit.scanRecords[_currentPos].index;
          final currentContent = unit.scanRecords[_currentPos].content;
          OverlayService.sendData({
            'unit_name': unit.name,
            'sequence': unit.scanRecords[_currentPos].index,
            'content': currentContent,
          });
        }
      });
    });
  }

  Future<void> _checkOverlayPermission() async {
    final granted = await PermissionService.checkOverlayPermission();
    setState(() {
      _overlayPermissionGranted = granted;
    });
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await PermissionService.requestOverlayPermission(context);
    setState(() {
      _overlayPermissionGranted = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnitService>(
      builder: (context, unitService, child) {
        if (unitService.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final unit = unitService.getUnitById(widget.unitId);
        if (unit == null) {
          return const Scaffold(
            body: Center(child: Text('单元不存在')),
          );
        }

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(unit.name),
                centerTitle: true,
              ),
              body: unit.scanRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            '暂无扫描记录',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScannerScreen(unitId: widget.unitId),
                                ),
                              );
                            },
                            child: const Text('点击扫码'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Bottom padding for floating bar
                      itemCount: unit.scanRecords.length,
                      itemBuilder: (context, index) {
                        final record = unit.scanRecords[index];
                        return Dismissible(
                          key: Key(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('确认删除'),
                                  content: const Text('确定要删除这条记录吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('删除', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            unitService.deleteScanRecord(unit.id, record.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          '${record.index}. ${record.content}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          await Clipboard.setData(ClipboardData(text: record.content));
                                          // Show a snackbar to indicate successful copy
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('复制成功'),
                                                duration: Duration(milliseconds: 1000),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          color: Color(0xFF007AFF),
                                          size: 20,
                                        ),
                                        tooltip: '复制内容',
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _formatDateTime(record.scannedAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              bottomNavigationBar: Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
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
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScannerScreen(unitId: widget.unitId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('扫码'),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _overlayPermissionGranted
                            ? () {
                                setState(() {
                                  _showFloatingHelper = !_showFloatingHelper;
                                });
                                if (_showFloatingHelper) {
                                  _currentPos = 0;
                                  _currentRecordIndex = unit.scanRecords.isNotEmpty
                                      ? unit.scanRecords[_currentPos].index
                                      : 1;
                                  OverlayService.showOverlay().then((_) {
                                    if (unit.scanRecords.isEmpty) return;
                                    final currentContent = unit.scanRecords[_currentPos].content;
                                    OverlayService.sendData({
                                      'unit_name': unit.name,
                                      'sequence': unit.scanRecords[_currentPos].index,
                                      'content': currentContent,
                                      'records': unit.scanRecords
                                          .map((r) => {
                                                'index': r.index,
                                                'content': r.content,
                                              })
                                          .toList(),
                                    });
                                  });
                                  _overlayActiveTimer?.cancel();
                                  _overlayActiveTimer = Timer.periodic(const Duration(milliseconds: 800), (t) async {
                                    final active = await OverlayService.isOverlayVisible();
                                    if (!active && mounted) {
                                      setState(() {
                                        _showFloatingHelper = false;
                                      });
                                      t.cancel();
                                    }
                                  });
                                } else {
                                  OverlayService.hideOverlay();
                                  _overlayActiveTimer?.cancel();
                                }
                              }
                            : _requestOverlayPermission,
                        icon: const Icon(Icons.view_agenda_outlined),
                        label: const Text('助手'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _showFloatingHelper 
                            ? Colors.orange 
                            : Colors.white,
                          foregroundColor: _showFloatingHelper 
                            ? Colors.white 
                            : Colors.black87,
                          elevation: 0,
                          side: _showFloatingHelper 
                            ? BorderSide.none 
                            : BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    _overlayActiveTimer?.cancel();
    super.dispose();
  }
}
