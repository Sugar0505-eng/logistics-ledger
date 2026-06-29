import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 弹出费用名称选择器：从预设选择，或选择"手动输入"返回特殊标记。
/// 返回所选预设名称；选择手动输入返回空字符串 ''；取消返回 null。
Future<String?> pickFeeName(BuildContext context, WidgetRef ref) async {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => const _FeePresetPickerSheet(),
  );
}

class _FeePresetPickerSheet extends ConsumerWidget {
  const _FeePresetPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(feePresetsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('选择费用名称',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('手动输入'),
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(height: 1),
          Flexible(
            child: presetsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24), child: Text('加载失败：$e')),
              data: (presets) {
                if (presets.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无预设，请选择"手动输入"'),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final preset in presets)
                      ListTile(
                        leading: const Icon(Icons.sell),
                        title: Text(preset.name),
                        onTap: () => Navigator.pop(context, preset.name),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
