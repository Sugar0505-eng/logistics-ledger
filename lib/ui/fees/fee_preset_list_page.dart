import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../state/providers.dart';

class FeePresetListPage extends ConsumerWidget {
  const FeePresetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(feePresetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('费用预设')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (presets) {
          if (presets.isEmpty) {
            return const Center(child: Text('暂无费用预设，点击右下角添加'));
          }
          return ListView.separated(
            itemCount: presets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final preset = presets[i];
              return ListTile(
                leading: const Icon(Icons.sell),
                title: Text(preset.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(context, ref, preset),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, preset),
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

  Future<void> _edit(
      BuildContext context, WidgetRef ref, FeePreset? preset) async {
    final controller = TextEditingController(text: preset?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(preset == null ? '新增费用预设' : '编辑费用预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '费用名称'),
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

    final repo = ref.read(feePresetRepoProvider);
    try {
      if (preset == null) {
        await repo.add(result);
      } else {
        await repo.update(preset.id!, result);
      }
      ref.invalidate(feePresetsProvider);
    } on DuplicateException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, FeePreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除费用预设'),
        content: Text('确定删除「${preset.name}」？已写入账单的同名费用不受影响。'),
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
    await ref.read(feePresetRepoProvider).delete(preset.id!);
    ref.invalidate(feePresetsProvider);
  }
}
