import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/money.dart';
import '../../services/ocr_service.dart';
import '../../services/pasted_bill_parser.dart';
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
  late final TextEditingController _sealCtrl;
  late final TextEditingController _bookingCtrl;
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
    _sealCtrl = TextEditingController(text: b?.sealNumber ?? '');
    _bookingCtrl = TextEditingController(text: b?.bookingNumber ?? '');
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
    _sealCtrl.dispose();
    _bookingCtrl.dispose();
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
      appBar: AppBar(
        title: Text(_isEdit ? '编辑账单' : '添加账单'),
        actions: [
          if (!_isEdit)
            IconButton(
              icon: const Icon(Icons.content_paste_search),
              tooltip: '粘贴文本识别',
              onPressed: _importFromText,
            ),
        ],
      ),
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入柜号' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sealCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '封条号（可选）',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _bookingCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '订舱号（可选）',
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

  Future<void> _importFromText() async {
    final text = await _promptPastedText();
    if (text == null || text.trim().isEmpty || !mounted) return;

    final presets = await ref.read(feePresetRepoProvider).all();
    final parsed = PastedBillParser.parse(
      text,
      feePresetNames: presets.map((preset) => preset.name),
    );
    if (!mounted) return;
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未识别到可填入账单的信息，请检查文本格式')),
      );
      return;
    }

    final confirmed = await _confirmParsedData(parsed);
    if (confirmed != true || !mounted) return;
    await _applyParsedData(parsed);
  }

  Future<String?> _promptPastedText() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: const Text('粘贴账单文本'),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                hintText: '例：柜号 CSQU3054383\n封条号 SL12345\n订舱号 BK98765\n吊柜费 200',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, controller.text),
              icon: const Icon(Icons.manage_search),
              label: const Text('识别'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool?> _confirmParsedData(PastedBillData data) {
    final lines = <String>[
      if (data.containerNumber != null) '柜号：${data.containerNumber}',
      if (data.sealNumber != null) '封条号：${data.sealNumber}',
      if (data.bookingNumber != null) '订舱号：${data.bookingNumber}',
      if (data.date != null) '日期：${data.date}',
      if (data.location != null) '地点：${data.location}',
      if (data.plateNumber != null) '车牌：${data.plateNumber}',
      if (data.freightCents != null)
        '运费：${Money.formatCents(data.freightCents!)} 元',
      for (final entry in data.feeAmountsCents.entries)
        '${entry.key}：${Money.formatCents(entry.value)} 元',
    ];
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认识别结果'),
        content: SingleChildScrollView(child: Text(lines.join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('填入账单'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyParsedData(PastedBillData data) async {
    if (data.plateNumber != null) {
      await ref.read(plateRepoProvider).getOrCreate(data.plateNumber!);
      ref.invalidate(platesProvider);
    }
    if (!mounted) return;
    setState(() {
      if (data.containerNumber != null) {
        _containerCtrl.text = data.containerNumber!;
      }
      if (data.sealNumber != null) _sealCtrl.text = data.sealNumber!;
      if (data.bookingNumber != null) {
        _bookingCtrl.text = data.bookingNumber!;
      }
      if (data.date != null) _date = data.date!;
      if (data.location != null) _locationCtrl.text = data.location!;
      if (data.plateNumber != null) _plate = data.plateNumber!;
      if (data.freightCents != null) {
        _freightCtrl.text = Money.formatCents(data.freightCents!);
      }
      for (final entry in data.feeAmountsCents.entries) {
        final existingIndex = _fees.indexWhere(
          (fee) => fee.name.toLowerCase() == entry.key.toLowerCase(),
        );
        if (existingIndex >= 0) {
          _fees[existingIndex].amountCtrl.text = Money.formatCents(entry.value);
        } else {
          _fees.add(
            _EditableFee(
              name: entry.key,
              amountCtrl: TextEditingController(
                text: Money.formatCents(entry.value),
              ),
            ),
          );
        }
      }
    });
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
      sealNumber: _sealCtrl.text.trim().toUpperCase(),
      bookingNumber: _bookingCtrl.text.trim().toUpperCase(),
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
