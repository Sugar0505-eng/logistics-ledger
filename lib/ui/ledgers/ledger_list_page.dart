import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../date_utils.dart';
import 'ledger_detail_page.dart';

class LedgerListPage extends ConsumerWidget {
  const LedgerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgersAsync = ref.watch(ledgersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账目记录')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建账目'),
      ),
      body: ledgersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (ledgers) {
          if (ledgers.isEmpty) {
            return const Center(child: Text('暂无账目记录，点击下方新建'));
          }
          return ListView.separated(
            itemCount: ledgers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _LedgerTile(ledger: ledgers[i]),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建账目记录'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: '名称/备注（可选）', hintText: '如：6月港口批次'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('创建')),
        ],
      ),
    );
    if (name == null) return; // 取消

    final ledger = await ref
        .read(ledgerRepoProvider)
        .createLedger(name: name.isEmpty ? null : name, createdAt: todayYmd());
    ref.invalidate(ledgersProvider);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LedgerDetailPage(ledgerId: ledger.id!)),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({required this.ledger});
  final Ledger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(billCountProvider(ledger.id!));
    final count = countAsync.maybeWhen(data: (c) => c, orElse: () => 0);
    final completed = ledger.status == LedgerStatus.completed;
    return ListTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(ledger.name?.isNotEmpty == true
          ? ledger.name!
          : '账目 #${ledger.id}'),
      subtitle: Text('${ledger.createdAt} · $count 条账单'),
      trailing: Chip(
        label: Text(completed ? '已完成' : '编辑中'),
        backgroundColor:
            completed ? Colors.green.shade100 : Colors.orange.shade100,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LedgerDetailPage(ledgerId: ledger.id!)),
      ),
      onLongPress: () => _delete(context, ref),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账目记录'),
        content: const Text('将同时删除其下所有账单与额外费用，确定？'),
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
    await ref.read(ledgerRepoProvider).deleteLedger(ledger.id!);
    ref.invalidate(ledgersProvider);
  }
}
