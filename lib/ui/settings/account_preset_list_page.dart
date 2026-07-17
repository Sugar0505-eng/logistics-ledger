import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../state/providers.dart';

class AccountPresetListPage extends ConsumerWidget {
  const AccountPresetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(accountPresetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账户预设')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        data: (presets) {
          if (presets.isEmpty) {
            return const Center(child: Text('暂无账户预设，点击右下角添加'));
          }
          return ListView.separated(
            itemCount: presets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final preset = presets[index];
              return ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text(preset.accountName),
                subtitle: Text(preset.companyAccount),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, preset: preset),
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
    BuildContext context,
    WidgetRef ref, {
    AccountPreset? preset,
  }) async {
    final accountController = TextEditingController(
      text: preset?.companyAccount ?? '',
    );
    final nameController = TextEditingController(
      text: preset?.accountName ?? '',
    );
    try {
      final result = await showDialog<_AccountInput>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(preset == null ? '新增账户预设' : '编辑账户预设'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accountController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '公司账户',
                  hintText: '例：招商银行某支行 6214 0000 0000 0000',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '账户名'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                _AccountInput(
                  companyAccount: accountController.text.trim(),
                  accountName: nameController.text.trim(),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (result == null) return;

      final repo = ref.read(accountPresetRepoProvider);
      if (preset == null) {
        await repo.add(
          companyAccount: result.companyAccount,
          accountName: result.accountName,
        );
      } else {
        await repo.update(
          preset.id!,
          companyAccount: result.companyAccount,
          accountName: result.accountName,
        );
      }
      ref.invalidate(accountPresetsProvider);
    } on DuplicateException catch (error) {
      if (context.mounted) _showError(context, error.message);
    } on ValidationException catch (error) {
      if (context.mounted) _showError(context, error.message);
    } finally {
      accountController.dispose();
      nameController.dispose();
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AccountPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账户预设'),
        content: Text('确定删除「${preset.accountName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(accountPresetRepoProvider).delete(preset.id!);
      ref.invalidate(accountPresetsProvider);
    } on ValidationException catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountInput {
  const _AccountInput({
    required this.companyAccount,
    required this.accountName,
  });

  final String companyAccount;
  final String accountName;
}
