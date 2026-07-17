import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';

class ExportSettingsPage extends ConsumerWidget {
  const ExportSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(exportSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账户预设')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        data: (settings) => _ExportSettingsForm(settings: settings),
      ),
    );
  }
}

class _ExportSettingsForm extends ConsumerStatefulWidget {
  const _ExportSettingsForm({required this.settings});

  final ExportSettings settings;

  @override
  ConsumerState<_ExportSettingsForm> createState() =>
      _ExportSettingsFormState();
}

class _ExportSettingsFormState extends ConsumerState<_ExportSettingsForm> {
  late final TextEditingController _companyAccountCtrl;
  late final TextEditingController _accountNameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companyAccountCtrl = TextEditingController(
      text: widget.settings.companyAccount,
    );
    _accountNameCtrl = TextEditingController(text: widget.settings.accountName);
  }

  @override
  void dispose() {
    _companyAccountCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('以下信息会自动添加到 Excel 导出文件的最后两行。'),
        const SizedBox(height: 20),
        TextField(
          controller: _companyAccountCtrl,
          decoration: const InputDecoration(
            labelText: '公司账户',
            hintText: '例：招商银行某支行 6214 0000 0000 0000',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _accountNameCtrl,
          decoration: const InputDecoration(labelText: '账户名'),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? '保存中' : '保存预设'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(exportSettingsRepoProvider)
          .save(
            ExportSettings(
              companyAccount: _companyAccountCtrl.text,
              accountName: _accountNameCtrl.text,
            ),
          );
      ref.invalidate(exportSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('账户预设已保存')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
