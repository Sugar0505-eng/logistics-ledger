import 'package:flutter/material.dart';

import 'fees/fee_preset_list_page.dart';
import 'ledgers/ledger_list_page.dart';
import 'plates/plate_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = [
    LedgerListPage(),
    PlateListPage(),
    FeePresetListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: '账目'),
          NavigationDestination(
              icon: Icon(Icons.directions_car), label: '车牌'),
          NavigationDestination(
              icon: Icon(Icons.sell), label: '费用预设'),
        ],
      ),
    );
  }
}
