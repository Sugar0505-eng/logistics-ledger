import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../state/providers.dart';

class PlateListPage extends ConsumerWidget {
  const PlateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platesAsync = ref.watch(platesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('车牌库')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: platesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (plates) {
          if (plates.isEmpty) {
            return const Center(child: Text('暂无车牌，点击右下角添加'));
          }
          return ListView.separated(
            itemCount: plates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final plate = plates[i];
              return ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(plate.number),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(context, ref, plate),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, plate),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Plate? plate) async {
    final controller = TextEditingController(text: plate?.number ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plate == null ? '新增车牌' : '编辑车牌'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: '车牌号'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    final repo = ref.read(plateRepoProvider);
    try {
      if (plate == null) {
        await repo.add(result);
      } else {
        await repo.update(plate.id!, result);
      }
      ref.invalidate(platesProvider);
    } on DuplicateException catch (e) {
      _toast(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Plate plate) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除车牌'),
        content: Text('确定删除 ${plate.number}？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(plateRepoProvider).delete(plate.id!);
    ref.invalidate(platesProvider);
  }

  void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
