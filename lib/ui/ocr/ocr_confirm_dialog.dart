import 'package:flutter/material.dart';

import '../../services/container_number.dart';
import '../../services/ocr_service.dart';

/// 展示 OCR 识别结果，让用户确认或修改候选柜号。
/// 返回确认后的柜号；取消返回 null。
Future<String?> showOcrConfirmDialog(
  BuildContext context,
  OcrResult result,
) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _OcrConfirmDialog(result: result),
  );
}

class _OcrConfirmDialog extends StatefulWidget {
  const _OcrConfirmDialog({required this.result});
  final OcrResult result;

  @override
  State<_OcrConfirmDialog> createState() => _OcrConfirmDialogState();
}

class _OcrConfirmDialogState extends State<_OcrConfirmDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.result.best ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.result.candidates;
    final noCandidate = candidates.isEmpty;
    return AlertDialog(
      title: const Text('确认柜号'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noCandidate)
              const Text(
                '未识别到符合格式的柜号，请手动输入。',
                style: TextStyle(color: Colors.orange),
              )
            else ...[
              const Text('识别到以下候选，请确认或修改：'),
              const SizedBox(height: 8),
              for (final c in candidates)
                _CandidateChip(
                  text: c,
                  valid: ContainerNumber.isValid(c),
                  onTap: () => setState(() => _controller.text = c),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '柜号'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _controller.text.trim().toUpperCase()),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _CandidateChip extends StatelessWidget {
  const _CandidateChip({
    required this.text,
    required this.valid,
    required this.onTap,
  });
  final String text;
  final bool valid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ActionChip(
        avatar: Icon(
          valid ? Icons.check_circle : Icons.error_outline,
          color: valid ? Colors.green : Colors.orange,
          size: 18,
        ),
        label: Text('$text  ${valid ? '校验通过' : '校验未通过'}'),
        onPressed: onTap,
      ),
    );
  }
}
