import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/money.dart';
import '../../services/ocr_service.dart';
import '../../state/providers.dart';
import '../date_utils.dart';
import '../fees/fee_preset_picker.dart';
import '../ocr/ocr_confirm_dialog.dart';
import '../plates/plate_picker.dart';

/// 账单录入/编辑页。bill 为 null 表示新增。
class BillEditPage extends ConsumerStatefulWidget {
  const BillEditPage({super.key, required this.ledgerId, this.bill});
  final int ledgerId;
  final Bill? bill;

  @override
  ConsumerState<BillEditPage> createState() => _BillEditPageState();
}

class _BillEditPageState extends ConsumerState<BillEditPage> {
  final _formKey = GlobalKey<FormState>();
  final OcrService _ocr = OcrService();

  late final TextEditingController _containerCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _freightCtrl;
  late String _date;
  String _plate = '';
  late List<_EditableFee> _fees;
  bool _saving = false;

  bool get _isEdit => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _containerCtrl = TextEditingController(text: b?.containerNo ?? '');
    _locationCtrl = TextEditingController(text: b?.location ?? '');
    _freightCtrl = TextEditingController(
      text: b == null ? '' : Money.formatCents(b.freightCents),
    );
    _date = b?.date ?? todayYmd();
    _plate = b?.plateNumber ?? '';
    _fees = (b?.extraFees ?? [])
        .map(
          (f) => _EditableFee(
            name: f.name,
            amountCtrl: TextEditingController(
              text: Money.formatCents(f.amountCents),
            ),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _containerCtrl.dispose();
    _locationCtrl.dispose();
    _freightCtrl.dispose();
    for (final f in _fees) {
      f.amountCtrl.dispose();
    }
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑账单' : '添加账单')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 日期
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '日期',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(formatChineseDate(_date)),
              ),
            ),
            const SizedBox(height: 16),

            // 柜号 + OCR
            TextFormField(
              controller: _containerCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '物流柜号',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_camera),
                      tooltip: '拍照识别',
                      onPressed: () => _runOcr(ImageSource.camera),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      tooltip: '相册识别',
                      onPressed: () => _runOcr(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 地点
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: '地点'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入地点' : null,
            ),
            const SizedBox(height: 16),

            // 运费
            TextFormField(
              controller: _freightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '运费',
                suffixText: '元',
              ),
              validator: _validateMoney,
            ),
            const SizedBox(height: 16),

            // 车牌
            InkWell(
              onTap: _pickPlate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '车牌号',
                  suffixIcon: Icon(Icons.directions_car),
                ),
                child: Text(_plate.isEmpty ? '点击选择车牌' : _plate),
              ),
            ),
            const SizedBox(height: 24),

            // 额外费用
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '额外费用',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: _addFee,
                  icon: const Icon(Icons.add),
                  label: const Text('添加'),
                ),
              ],
            ),
            for (var i = 0; i < _fees.length; i++) _buildFeeRow(i),

            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? '保存中' : '保存账单'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(int i) {
    final fee = _fees[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _pickFeeName(i),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '名称'),
                child: Text(fee.name.isEmpty ? '选择/输入' : fee.name),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: fee.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '金额',
                suffixText: '元',
              ),
              validator: _validateMoney,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => setState(() {
              _fees.removeAt(i).amountCtrl.dispose();
            }),
          ),
        ],
      ),
    );
  }

  String? _validateMoney(String? v) {
    if (v == null || v.trim().isEmpty) return '请输入金额';
    if (Money.parseToCents(v) == null) return '金额格式不正确';
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: parseYmd(_date),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = ymd.format(picked));
    }
  }

  Future<void> _pickPlate() async {
    final result = await pickPlate(context, ref);
    if (result != null && mounted) setState(() => _plate = result);
  }

  Future<void> _pickFeeName(int i) async {
    final result = await pickFeeName(context, ref);
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      // 手动输入
      final name = await _promptText('输入费用名称');
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _fees[i].name = name);
      }
    } else {
      setState(() => _fees[i].name = result);
    }
  }

  Future<String?> _promptText(String title) async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(controller: ctrl, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _addFee() {
    setState(
      () => _fees.add(
        _EditableFee(name: '', amountCtrl: TextEditingController()),
      ),
    );
  }

  Future<void> _runOcr(ImageSource source) async {
    try {
      final result = await _ocr.pickAndRecognize(source);
      if (result == null || !mounted) return;
      final confirmed = await showOcrConfirmDialog(context, result);
      if (confirmed != null && mounted) {
        setState(() => _containerCtrl.text = confirmed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('识别失败：$e')));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_plate.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择车牌号')));
      return;
    }
    final feeNames = <String>{};
    for (final f in _fees) {
      final name = f.name.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('额外费用名称不能为空')));
        return;
      }
      if (!feeNames.add(name.toLowerCase())) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('额外费用名称不能重复：$name')));
        return;
      }
    }

    final bill = Bill(
      id: widget.bill?.id,
      ledgerId: widget.ledgerId,
      containerNo: _containerCtrl.text.trim().toUpperCase(),
      date: _date,
      location: _locationCtrl.text.trim(),
      freightCents: Money.parseToCents(_freightCtrl.text)!,
      plateNumber: _plate,
      extraFees: _fees
          .map(
            (f) => ExtraFee(
              name: f.name.trim(),
              amountCents: Money.parseToCents(f.amountCtrl.text)!,
            ),
          )
          .toList(),
    );

    setState(() => _saving = true);
    try {
      await ref.read(ledgerRepoProvider).saveBill(bill);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }
}

class _EditableFee {
  _EditableFee({required this.name, required this.amountCtrl});
  String name;
  final TextEditingController amountCtrl;
}
