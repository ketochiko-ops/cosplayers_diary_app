import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_state_persistence.dart';
import '../../../core/database/project_storage.dart';
import '../../../core/database/project_sync_controller.dart';
import '../../../core/database/settings_store.dart';
import '../../backup/application/backup_coordinator.dart';
import '../domain/backup_reminder.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.settingsStore,
    required this.persistence,
    this.projectSync,
    this.onProjectLoaded,
    super.key,
  });
  final SettingsStore? settingsStore;
  final AppStatePersistence? persistence;
  final ProjectSyncController? projectSync;
  final VoidCallback? onProjectLoaded;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _policy = BackupReminderPolicy();
  static const _googleClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
  );
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
                'データはこのブラウザ内に保存されます。外部保存は下で任意に設定できます。端末変更やブラウザデータ削除に備えて、定期的にZIPバックアップを作成してください。',
              ),
            ),
          ),
        if (kIsWeb && widget.projectSync != null) ...[
          Text('プロジェクト保存', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'データ更新時に選択した保存先へ自動保存します。別の端末で更新された場合は停止し、再接続時に使用する内容を選べます。',
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: widget.projectSync!,
            builder: (context, _) {
              final sync = widget.projectSync!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sync.target == null
                        ? (sync.preferredTarget?.isNotEmpty ?? false)
                              ? '前回の保存先は未接続です。再接続してください。'
                              : 'プロジェクト保存は未設定です。'
                        : '${sync.name} に自動保存中',
                  ),
                  if (sync.message != null)
                    Text(
                      sync.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (sync.target != null)
                    OutlinedButton(
                      onPressed: sync.busy ? null : _disconnectProject,
                      child: const Text('プロジェクト保存を切断'),
                    ),
                  if (sync.target == null &&
                      sync.storage.supportsLocalFile) ...[
                    FilledButton.tonal(
                      onPressed: sync.busy ? null : _createLocalProject,
                      child: const Text('ローカルに新しいプロジェクトを保存'),
                    ),
                    OutlinedButton(
                      onPressed: sync.busy ? null : _openLocalProject,
                      child: const Text('既存のプロジェクトファイルを開く'),
                    ),
                    if (sync.preferredTarget == ProjectTarget.localFile.name)
                      TextButton(
                        onPressed: sync.busy ? null : _reconnectLocalProject,
                        child: const Text('前回のローカルファイルに再接続'),
                      ),
                  ],
                  if (!sync.storage.supportsLocalFile)
                    const Text(
                      'このブラウザではファイルへの自動上書きに対応していません。Google Drive連携またはZIPバックアップを利用できます。',
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        sync.busy ||
                            sync.target != null ||
                            _googleClientId.isEmpty
                        ? null
                        : _connectDrive,
                    icon: const Icon(Icons.cloud_outlined),
                    label: const Text('Google Driveに接続'),
                  ),
                  Text(
                    _googleClientId.isEmpty
                        ? 'Google Drive連携はサイト運営者による設定待ちです。'
                        : '自分のGoogleアカウントで接続します。Drive上の「CosplayDiary/CosplayDiary.project.json」を使用します。',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
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

  Future<void> _createLocalProject() => _chooseProject(
    ProjectTarget.localFile,
    widget.projectSync!.createLocalFile,
  );

  Future<void> _openLocalProject() => _chooseProject(
    ProjectTarget.localFile,
    widget.projectSync!.openLocalFile,
  );

  Future<void> _reconnectLocalProject() => _chooseProject(
    ProjectTarget.localFile,
    widget.projectSync!.reconnectLocalFile,
  );

  Future<void> _connectDrive() async {
    try {
      final snapshot = await widget.projectSync!.connectGoogleDrive(
        _googleClientId,
      );
      await _resolveProject(ProjectTarget.googleDrive, snapshot);
    } catch (error) {
      _showProjectMessage('Google Driveへの接続に失敗しました: $error');
    }
  }

  Future<void> _chooseProject(
    ProjectTarget target,
    Future<ProjectSnapshot?> Function() choose,
  ) async {
    try {
      final snapshot = await choose();
      if (snapshot == null) return;
      await _resolveProject(target, snapshot);
    } catch (error) {
      _showProjectMessage('プロジェクトを開けませんでした: $error');
    }
  }

  Future<void> _resolveProject(
    ProjectTarget target,
    ProjectSnapshot snapshot,
  ) async {
    if (!mounted) return;
    final sync = widget.projectSync!;
    final current = widget.persistence!.exportJson();
    if (snapshot.content == null || snapshot.content == current) {
      await sync.uploadCurrent(target, snapshot);
      _showProjectMessage('プロジェクトを接続しました');
      return;
    }
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用するデータを選択'),
        content: const Text(
          '保存先とこの端末の内容が異なります。どちらか一方の内容で置き換えます。必要なら先にZIPバックアップを作成してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存先を読み込む'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('この端末を保存先へ書き込む'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice) {
      await sync.useProject(target, snapshot);
      widget.onProjectLoaded?.call();
    } else {
      await sync.uploadCurrent(target, snapshot);
    }
    _showProjectMessage('プロジェクトを接続しました');
  }

  Future<void> _disconnectProject() async {
    try {
      await widget.projectSync!.disconnect();
    } catch (error) {
      _showProjectMessage('切断できませんでした: $error');
    }
  }

  void _showProjectMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
