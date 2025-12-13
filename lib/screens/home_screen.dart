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
        centerTitle: true,
      ),
      body: Consumer<UnitService>(
        builder: (context, unitService, child) {
          return ListView.builder(
            itemCount: unitService.units.length,
            itemBuilder: (context, index) {
              final unit = unitService.units[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(unit.name),
                  subtitle: Text(
                    '${unit.scanRecords.length} 条记录 • ${_formatDate(unit.createdAt)}',
                  ),
                  trailing: PopupMenuButton<String>(
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
                          child: Text('重命名'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除'),
                        ),
                      ];
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UnitScreen(unitId: unit.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUnitDialog(context),
        child: const Icon(Icons.add),
        tooltip: '新建单元',
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