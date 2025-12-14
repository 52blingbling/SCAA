import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unit_service.dart';
import '../models/unit.dart';
import 'unit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单元管理'),
        actions: [
          IconButton(
            onPressed: () => _showAddUnitDialog(context),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            tooltip: '新建单元',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<UnitService>(
        builder: (context, unitService, child) {
          if (unitService.units.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(
                     '暂无单元',
                     style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                   ),
                   const SizedBox(height: 8),
                   TextButton(
                     onPressed: () => _showAddUnitDialog(context),
                     child: const Text('创建一个新单元'),
                   ),
                 ],
               ),
             );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unitService.units.length,
            itemBuilder: (context, index) {
              final unit = unitService.units[index];
              return Container(
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UnitScreen(unitId: unit.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder_rounded, color: Color(0xFF007AFF), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unit.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${unit.scanRecords.length} 条记录',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[400]),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'rename') {
                                _showRenameDialog(context, unitService, unit);
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, unitService, unit);
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 20),
                                      SizedBox(width: 12),
                                      Text('重命名'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('删除', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context) {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新建单元'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: '请输入单元名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  Provider.of<UnitService>(context, listen: false)
                      .addUnit(_nameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, UnitService unitService, Unit unit) {
    _nameController.text = unit.name;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重命名单元'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: '请输入新的单元名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  unitService.renameUnit(unit.id, _nameController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, UnitService unitService, Unit unit) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除单元 "${unit.name}" 吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                unitService.deleteUnit(unit.id);
                Navigator.pop(context);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}