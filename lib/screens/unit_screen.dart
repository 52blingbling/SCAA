import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../services/permission_service.dart';
import '../models/unit.dart';
import 'scanner_screen.dart';
import '../widgets/floating_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _checkOverlayPermission();
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
                  ? const Center(
                      child: Text(
                        '暂无扫描记录\n点击底部扫码按钮开始扫描',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: unit.scanRecords.length,
                      itemBuilder: (context, index) {
                        final record = unit.scanRecords[index];
                        return Dismissible(
                          key: Key(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
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
                                      child: const Text('删除'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            unitService.deleteScanRecord(unit.id, record.id);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: SelectableText('${record.index}. ${record.content}'),
                              subtitle: Text(_formatDateTime(record.scannedAt)),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        );
                      },
                    ),
              bottomNavigationBar: BottomAppBar(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('扫码'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _overlayPermissionGranted
                            ? () {
                                setState(() {
                                  _showFloatingHelper = !_showFloatingHelper;
                                  if (_showFloatingHelper) {
                                    // 设置当前记录索引为第一条记录或1
                                    _currentRecordIndex = unit.scanRecords.isNotEmpty 
                                      ? unit.scanRecords.first.index 
                                      : 1;
                                  }
                                });
                              }
                            : _requestOverlayPermission,
                        icon: const Icon(Icons.extension),
                        label: const Text('快捷助手'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: _showFloatingHelper 
                            ? Colors.orange 
                            : null,
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 快捷助手悬浮窗
            if (_showFloatingHelper)
              FloatingHelper(
                unit: unit,
                currentIndex: _currentRecordIndex,
                onIndexChanged: (index) {
                  setState(() {
                    _currentRecordIndex = index;
                  });
                },
                onClose: () {
                  setState(() {
                    _showFloatingHelper = false;
                  });
                },
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
}