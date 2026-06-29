import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories.dart';
import '../models/models.dart';

/// 在 main() 中通过 override 注入已初始化的数据库实例。
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider 必须在 main 中 override'),
);

final plateRepoProvider =
    Provider<PlateRepository>((ref) => PlateRepository(ref.watch(databaseProvider)));

final feePresetRepoProvider = Provider<FeePresetRepository>(
    (ref) => FeePresetRepository(ref.watch(databaseProvider)));

final ledgerRepoProvider =
    Provider<LedgerRepository>((ref) => LedgerRepository(ref.watch(databaseProvider)));

/// 车牌列表。变更后用 `ref.invalidate(platesProvider)` 刷新。
final platesProvider = FutureProvider<List<Plate>>(
    (ref) => ref.watch(plateRepoProvider).all());

/// 费用预设列表。
final feePresetsProvider = FutureProvider<List<FeePreset>>(
    (ref) => ref.watch(feePresetRepoProvider).all());

/// 账目记录列表。
final ledgersProvider = FutureProvider<List<Ledger>>(
    (ref) => ref.watch(ledgerRepoProvider).allLedgers());

/// 某账目记录下的账单列表。
final billsProvider = FutureProvider.family<List<Bill>, int>(
    (ref, ledgerId) => ref.watch(ledgerRepoProvider).billsOf(ledgerId));

/// 某账目记录的账单数量。
final billCountProvider = FutureProvider.family<int, int>(
    (ref, ledgerId) => ref.watch(ledgerRepoProvider).billCount(ledgerId));
