// 占位冒烟测试，替代 `flutter create` 生成的默认计数器模板（其引用不存在的 MyApp）。
// 应用真正的入口是 LogisticsLedgerApp，其依赖已初始化的数据库，不适合在此处直接 pump。
// 业务核心逻辑的验证见 container_number_test / money_test / csv_exporter_test。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp 能正常构建', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Text('物流账目')))),
    );
    expect(find.text('物流账目'), findsOneWidget);
  });
}
