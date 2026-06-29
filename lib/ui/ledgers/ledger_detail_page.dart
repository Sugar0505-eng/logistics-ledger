import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../services/csv_exporter.dart';
import '../../services/money.dart';
import '../../state/providers.dart';
import 'bill_edit_page.dart';

class LedgerDetailPage extends ConsumerWidget {
  const LedgerDetailPage({super.key, required this.ledgerId});
  final int ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider(ledgerId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('账目详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: '导出 CSV',
            onPressed: () => _export(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editBill(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('添加账单'),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (bills) {
          if (bills.isEmpty) {
            return const Center(child: Text('暂无账单，点击下方添加'));
          }
          final total = bills.fold<int>(0, (s, b) => s + b.subtotalCents);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: bills.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _BillTile(ledgerId: ledgerId, bill: bills[i]),
                ),
              ),
              Material(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('共 ${bills.length} 条账单'),
                      Text('总计 ${Money.formatCents(total)} 元',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBill(
      BuildContext context, WidgetRef ref, Bill? bill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillEditPage(ledgerId: ledgerId, bill: bill),
      ),
    );
    ref.invalidate(billsProvider(ledgerId));
    ref.invalidate(billCountProvider(ledgerId));
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final bills = await ref.read(ledgerRepoProvider).billsOf(ledgerId);
    if (bills.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('该账目记录无账单可导出')));
      }
      return;
    }

    final csv = CsvExporter.toCsv(bills);
    final dir = await getTemporaryDirectory();
    final fileName = 'ledger_${ledgerId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], subject: '账目导出 $fileName');
  }
}

class _BillTile extends ConsumerWidget {
  const _BillTile({required this.ledgerId, required this.bill});
  final int ledgerId;
  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeSummary = bill.extraFees
        .map((f) => '${f.name}:${Money.formatCents(f.amountCents)}')
        .join('，');
    return ListTile(
      leading: const Icon(Icons.local_shipping),
      title: Text(bill.containerNo),
      subtitle: Text([
        '${bill.date} · ${bill.plateNumber}',
        '运费 ${Money.formatCents(bill.freightCents)}',
        if (feeSummary.isNotEmpty) '额外：$feeSummary',
      ].join('\n')),
      isThreeLine: feeSummary.isNotEmpty,
      trailing: Text('${Money.formatCents(bill.subtotalCents)} 元',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BillEditPage(ledgerId: ledgerId, bill: bill)),
        );
        ref.invalidate(billsProvider(ledgerId));
        ref.invalidate(billCountProvider(ledgerId));
      },
      onLongPress: () => _delete(context, ref),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除账单'),
        content: Text('确定删除柜号 ${bill.containerNo}？'),
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
    await ref.read(ledgerRepoProvider).deleteBill(bill.id!);
    ref.invalidate(billsProvider(ledgerId));
    ref.invalidate(billCountProvider(ledgerId));
  }
}
