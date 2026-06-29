import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 弹出车牌选择器：从车牌库选择，或现场新建并入库。
/// 返回所选/新建的车牌号；用户取消返回 null。
Future<String?> pickPlate(BuildContext context, WidgetRef ref) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PlatePickerSheet(),
  );
}

class _PlatePickerSheet extends ConsumerWidget {
  const _PlatePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platesAsync = ref.watch(platesProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('选择车牌',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新建'),
                onPressed: () => _createNew(context, ref),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: platesAsync.when(
                loading: () =>
                    const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24), child: Text('加载失败：$e')),
                data: (plates) {
                  if (plates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('车牌库为空，点击右上角"新建"添加'),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final plate in plates)
                        ListTile(
                          leading: const Icon(Icons.directions_car),
                          title: Text(plate.number),
                          onTap: () => Navigator.pop(context, plate.number),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final number = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建车牌'),
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
              child: const Text('确定')),
        ],
      ),
    );
    if (number == null || number.isEmpty) return;

    final repo = ref.read(plateRepoProvider);
    // getOrCreate：已存在则提示并直接选中，否则入库
    final existed = await repo.exists(number);
    final plate = await repo.getOrCreate(number);
    ref.invalidate(platesProvider);
    if (!context.mounted) return;
    if (existed) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('车牌已存在，已为你选中：${plate.number}')));
    }
    Navigator.pop(context, plate.number);
  }
}
