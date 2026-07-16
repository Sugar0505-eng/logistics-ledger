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
            labelText: '名称/备注（可选）',
            hintText: '如：6月港口批次',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('创建'),
          ),
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
      MaterialPageRoute(builder: (_) => LedgerDetailPage(ledgerId: ledger.id!)),
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
      title: Text(
        ledger.name?.isNotEmpty == true ? ledger.name! : '账目 #${ledger.id}',
      ),
      subtitle: Text('${ledger.createdAt} · $count 条账单'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(completed ? '已完成' : '编辑中'),
            backgroundColor: completed
                ? Colors.green.shade100
                : Colors.orange.shade100,
          ),
          PopupMenuButton<_LedgerAction>(
            tooltip: '账目操作',
            onSelected: (action) {
              switch (action) {
                case _LedgerAction.edit:
                  _edit(context, ref);
                  break;
                case _LedgerAction.delete:
                  _delete(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _LedgerAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('编辑'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _LedgerAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('删除'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LedgerDetailPage(ledgerId: ledger.id!),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    try {
      final result = await showDialog<_LedgerEditResult>(
        context: context,
        builder: (ctx) => _LedgerEditDialog(ledger: ledger),
      );
      if (result == null) return;

      await ref
          .read(ledgerRepoProvider)
          .updateLedger(
            Ledger(
              id: ledger.id,
              name: result.name.isEmpty ? null : result.name,
              createdAt: ledger.createdAt,
              status: result.status,
            ),
          );
      ref.invalidate(ledgersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败：$e')));
      }
    }
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(ledgerRepoProvider).deleteLedger(ledger.id!);
    ref.invalidate(ledgersProvider);
  }
}

enum _LedgerAction { edit, delete }

class _LedgerEditDialog extends StatefulWidget {
  const _LedgerEditDialog({required this.ledger});

  final Ledger ledger;

  @override
  State<_LedgerEditDialog> createState() => _LedgerEditDialogState();
}

class _LedgerEditDialogState extends State<_LedgerEditDialog> {
  late final TextEditingController _controller;
  late LedgerStatus _status;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.ledger.name ?? '');
    _status = widget.ledger.status;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('编辑账目记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '名称/备注（可选）'),
          ),
          const SizedBox(height: 20),
          const Text('状态'),
          const SizedBox(height: 8),
          SegmentedButton<LedgerStatus>(
            segments: const [
              ButtonSegment(
                value: LedgerStatus.editing,
                icon: Icon(Icons.edit_note),
                label: Text('编辑中'),
              ),
              ButtonSegment(
                value: LedgerStatus.completed,
                icon: Icon(Icons.check_circle_outline),
                label: Text('已完成'),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) {
              setState(() => _status = selection.first);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _LedgerEditResult(name: _controller.text.trim(), status: _status),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _LedgerEditResult {
  const _LedgerEditResult({required this.name, required this.status});

  final String name;
  final LedgerStatus status;
}
