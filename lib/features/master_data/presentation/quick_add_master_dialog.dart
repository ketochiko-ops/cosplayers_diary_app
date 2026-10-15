import 'package:flutter/material.dart';

typedef QuickAddMaster = ({String name, bool isGeneral});

Future<QuickAddMaster?> showQuickAddMasterDialog({
  required BuildContext context,
  required String title,
  String? parentLabel,
  bool allowGeneral = false,
}) => showDialog<QuickAddMaster>(
  context: context,
  builder: (_) => _QuickAddMasterDialog(
    title: title,
    parentLabel: parentLabel,
    allowGeneral: allowGeneral,
  ),
);

class _QuickAddMasterDialog extends StatefulWidget {
  const _QuickAddMasterDialog({
    required this.title,
    required this.parentLabel,
    required this.allowGeneral,
  });
  final String title;
  final String? parentLabel;
  final bool allowGeneral;

  @override
  State<_QuickAddMasterDialog> createState() => _QuickAddMasterDialogState();
}

class _QuickAddMasterDialogState extends State<_QuickAddMasterDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _isGeneral = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (name: _name.text.trim(), isGeneral: _isGeneral));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.parentLabel != null) Text(widget.parentLabel!),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '名前'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '名前を入力してください' : null,
            ),
            if (widget.allowGeneral)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('汎用衣装'),
                subtitle: const Text('どのキャラクターでも使用できます'),
                value: _isGeneral,
                onChanged: (value) => setState(() => _isGeneral = value!),
              ),
            const SizedBox(height: 12),
            const Text('追加した項目はマスターにも保存されます。'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _submit, child: const Text('追加して選択')),
    ],
  );
}
