import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/database/project_sync_controller.dart';
import '../../../core/database/settings_store.dart';
import '../../backup/application/backup_coordinator.dart';
import '../domain/backup_reminder.dart';
import '../domain/calendar_week_start.dart';
import '../../calendar_sync/application/calendar_sync_controller.dart';
import '../../calendar_sync/presentation/calendar_sync_card.dart';
import '../../../core/services/file_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.settingsStore,
    required this.persistence,
    this.projectSync,
    this.calendarSync,
    this.onProjectLoaded,
    this.photoFiles,
    this.weekStart = CalendarWeekStart.monday,
    this.onWeekStartChanged,
    super.key,
  });
  final SettingsStore? settingsStore;
  final AppStatePersistence? persistence;
  final ProjectSyncController? projectSync;
  final CalendarSyncController? calendarSync;
  final VoidCallback? onProjectLoaded;
  final FileStore? photoFiles;
  final CalendarWeekStart weekStart;
  final ValueChanged<CalendarWeekStart>? onWeekStartChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _policy = BackupReminderPolicy();
  DateTime? _lastBackup;
  String _photoMode = 'spaceSaving';
  bool _working = false;
  bool _savingWeekStart = false;
  int _weekStartVersion = 0;

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
          const Card(
            child: ListTile(
              leading: Icon(Icons.install_mobile_outlined),
              title: Text('ホーム画面に追加して利用できます'),
              subtitle: Text('保存モードは下で変更できます。データ交換には圧縮しないJSONファイルを使用します。'),
            ),
          ),
        if ((kIsWeb ||
                widget.projectSync?.storage.supportsLocalFolder == true) &&
            widget.projectSync != null) ...[
          Text('プロジェクト保存', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: widget.projectSync!,
            builder: (context, _) {
              final sync = widget.projectSync!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sync.browserMode
                        ? 'ブラウザ保存モード（Safari対応）'
                        : '指定フォルダへ自動保存: ${sync.name ?? "未指定"}',
                  ),
                  Text(
                    sync.browserMode
                        ? '変更内容はこのブラウザ内へ自動保存します。外部ファイルへの保存は「JSONファイルの控えを保存」で行ってください。'
                        : '変更のたびに指定したフォルダへ登録情報と画像を自動保存します。保存先にアクセスできない場合は、その場で再指定を求めます。',
                  ),
                  if (sync.message != null) Text(sync.message!),
                  OutlinedButton(
                    onPressed: _working || sync.busy ? null : _changeMode,
                    child: const Text('保存モード・プロジェクトフォルダを変更'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
        Text('カレンダー表示', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<CalendarWeekStart>(
          key: ValueKey((widget.weekStart, _weekStartVersion)),
          initialValue: widget.weekStart,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '週の始まり'),
          items: [
            for (final value in CalendarWeekStart.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: _savingWeekStart || widget.onWeekStartChanged == null
              ? null
              : _changeWeekStart,
        ),
        const SizedBox(height: 24),
        if (widget.calendarSync != null) ...[
          CalendarSyncCard(sync: widget.calendarSync!),
          const SizedBox(height: 24),
        ],
        if (due)
          const Card(
            child: ListTile(
              leading: Icon(Icons.backup_outlined),
              title: Text('JSONファイルの控えを保存してください'),
              subtitle: Text(
                '前回から30日以上経過、または未作成です。端末変更やブラウザデータ削除に備えて保存してください。',
              ),
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
        Text('プロジェクトの控え・読み込み', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('最後に控えの保存を実行した日時'),
          subtitle: Text(
            _lastBackup == null ? '未作成' : _lastBackup!.toLocal().toString(),
          ),
        ),
        FilledButton.icon(
          onPressed: widget.persistence == null || _working ? null : _create,
          icon: const Icon(Icons.save_alt),
          label: const Text('JSONファイルの控えを保存'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.persistence == null || _working ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('プロジェクトJSONを読み込む'),
        ),
        const SizedBox(height: 12),
        const Text(
          '圧縮しないJSONに日記・マスター・カラコンのデータを保存します。画像も同梱します。以前のZIPバックアップも移行用に読み込めます。読み込み前に形式を検証します。',
        ),
      ],
    );
  }

  Future<void> _changeMode() async {
    try {
      await widget.projectSync!.disconnect();
    } catch (error) {
      _message('保存方法を変更できませんでした: $error');
    }
  }

  Future<void> _changeWeekStart(CalendarWeekStart? value) async {
    if (value == null || _savingWeekStart) return;
    setState(() => _savingWeekStart = true);
    try {
      await widget.settingsStore?.writeSetting(
        CalendarWeekStart.settingKey,
        value.name,
      );
      if (mounted) widget.onWeekStartChanged?.call(value);
    } catch (error) {
      if (mounted) {
        _message('週の始まりを保存できませんでした: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingWeekStart = false;
          // Recreate the field even if a failed write completed before a frame.
          _weekStartVersion++;
        });
      }
    }
  }

  Future<void> _create() async {
    setState(() => _working = true);
    try {
      final now = DateTime.now();
      final bytes = await BackupCoordinator(
        widget.persistence!,
        files: widget.photoFiles,
      ).create();
      final uri = await FilePicker.saveFile(
        fileName:
            'CosplayDiary_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.project.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'プロジェクトJSONの保存先を選択',
      );
      // Web starts a download and returns null; native null means cancellation.
      if (uri == null && !kIsWeb) return;
      await widget.settingsStore!.writeSetting(
        'last_backup_at',
        now.toIso8601String(),
      );
      if (mounted) setState(() => _lastBackup = now);
      _message(
        kIsWeb ? 'JSONのダウンロードを開始しました。保存先でファイルを確認してください。' : 'JSONファイルを保存しました',
      );
    } catch (error) {
      _message('JSONファイルを保存できませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _working = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json', 'zip'],
      );
      if (picked == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('プロジェクトを読み込みますか？'),
          content: const Text(
            '検証に成功した場合、現在の登録内容を置き換えます。フォルダ保存モードでは、現在の自動保存先もこの内容に更新します。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('検証して読み込む'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await BackupCoordinator(
        widget.persistence!,
        files: widget.photoFiles,
      ).restore(await picked.readAsBytes());
      if (!mounted) return;
      _message(result.isValid ? '読み込みました' : result.errors.join('\n'));
      if (result.isValid) widget.onProjectLoaded?.call();
      setState(() {});
    } catch (error) {
      _message('プロジェクトを読み込めませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
