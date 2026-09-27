import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/database/settings_store.dart';
import '../../backup/application/backup_coordinator.dart';
import '../domain/backup_reminder.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.settingsStore,
    required this.persistence,
    super.key,
  });
  final SettingsStore? settingsStore;
  final AppStatePersistence? persistence;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _policy = BackupReminderPolicy();
  DateTime? _lastBackup;
  String _photoMode = 'spaceSaving';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settingsStore = widget.settingsStore;
    if (settingsStore == null) return;
    final backup = await settingsStore.readSetting('last_backup_at');
    final mode = await settingsStore.readSetting('photo_save_mode');
    if (mounted) {
      setState(() {
        _lastBackup = backup == null ? null : DateTime.tryParse(backup);
        _photoMode = mode ?? 'spaceSaving';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = _policy.shouldRemind(
      lastBackupAt: _lastBackup,
      now: DateTime.now(),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (kIsWeb)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: const ListTile(
              leading: Icon(Icons.install_mobile_outlined),
              title: Text('ホーム画面に追加して利用できます'),
              subtitle: Text(
                'データはこのブラウザ内に保存されます。端末変更やブラウザデータ削除に備えて、定期的にZIPバックアップを作成してください。',
              ),
            ),
          ),
        if (due)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.backup_outlined),
              title: Text('バックアップを作成してください'),
              subtitle: Text('前回から30日以上経過、または未作成です。通常利用はそのまま続けられます。'),
            ),
          ),
        Text('写真', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _photoMode,
          decoration: const InputDecoration(labelText: '画像保存モード'),
          items: const [
            DropdownMenuItem(value: 'original', child: Text('オリジナル保存')),
            DropdownMenuItem(
              value: 'spaceSaving',
              child: Text('容量節約（長辺 2,048px）'),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => _photoMode = value);
            await widget.settingsStore?.writeSetting('photo_save_mode', value);
          },
        ),
        const SizedBox(height: 24),
        Text('バックアップ', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('最終バックアップ'),
          subtitle: Text(
            _lastBackup == null ? '未作成' : _lastBackup!.toLocal().toString(),
          ),
        ),
        FilledButton.icon(
          onPressed: widget.persistence == null ? null : _create,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('ZIPバックアップを作成'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.persistence == null ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('ZIPから復元'),
        ),
        const SizedBox(height: 12),
        const Text('バックアップにはCSVとアプリ状態が含まれます。復元前にZIP構造・形式バージョン・パス・サイズを検証します。'),
      ],
    );
  }

  Future<void> _create() async {
    final now = DateTime.now();
    final bytes = BackupCoordinator(widget.persistence!).create(now);
    final uri = await FilePicker.saveFile(
      fileName:
          'CosplayDiary_Backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.zip',
      bytes: bytes,
      mimeType: 'application/zip',
      dialogTitle: 'バックアップの保存先を選択',
    );
    if (uri == null) return;
    await widget.settingsStore!.writeSetting(
      'last_backup_at',
      now.toIso8601String(),
    );
    if (mounted) {
      setState(() => _lastBackup = now);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('バックアップを保存しました')));
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('バックアップを復元しますか？'),
        content: const Text('検証に成功した場合、現在の登録内容をバックアップの内容で置換します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('検証して復元'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await BackupCoordinator(widget.persistence!)
        .restore(await picked.readAsBytes());
    if (!mounted) return;
    final message = result.isValid ? '復元しました' : result.errors.join('\n');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    setState(() {});
  }
}
