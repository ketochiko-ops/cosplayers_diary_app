import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../backup/application/backup_coordinator.dart';

import '../../../core/database/project_storage.dart';
import '../../../core/database/project_sync_controller.dart';

/// Shared by the mandatory startup/recovery dialog and the settings page.
class ProjectSetup extends StatefulWidget {
  const ProjectSetup({required this.sync, this.onReady, super.key});
  final ProjectSyncController sync;
  final VoidCallback? onReady;

  @override
  State<ProjectSetup> createState() => _ProjectSetupState();
}

class _ProjectSetupState extends State<ProjectSetup> {
  bool _working = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.sync,
    builder: (context, _) {
      final sync = widget.sync;
      final enabled = !_working && !sync.busy;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('保存方法を選んでください。フォルダ方式は、フォルダの作成または読み込みが完了するまで編集を開始できません。'),
          if (_error ?? sync.message case final String message) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '指定フォルダへ自動保存（Chrome／Edge）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            '保存場所を選ぶと、その中にcosplayers_diary_projectフォルダを作成します。同名の空フォルダを直接選ぶこともできます。既存データが入っている場合は「開く」を使ってください。JSONとマスターを含む登録情報、images内の画像を一緒に管理します。読み込み・保存の失敗時は保存先の再指定を求めます。',
          ),
          if (sync.storage.supportsLocalFolder) ...[
            FilledButton(
              onPressed: enabled ? () => _choose(sync.createLocalFolder) : null,
              child: const Text('保存場所を指定してプロジェクトを作成'),
            ),
            OutlinedButton(
              onPressed: enabled ? () => _choose(sync.openLocalFolder) : null,
              child: const Text('既存のプロジェクトフォルダを開く'),
            ),
            if (sync.preferredTarget == ProjectTarget.localFolder.name)
              TextButton(
                onPressed: enabled
                    ? () => _choose(sync.reconnectLocalFolder)
                    : null,
                child: const Text('前回のフォルダへのアクセスを許可'),
              ),
          ] else
            const Text('このブラウザは外部フォルダへの自動保存に対応していません。'),
          OutlinedButton(
            onPressed: enabled ? _importJson : null,
            child: const Text('旧JSON・画像同梱JSONから移行'),
          ),
          const SizedBox(height: 16),
          const Text(
            'ブラウザ内へ自動保存（Safari対応）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'データはこのブラウザ内に保存します。外部フォルダへの継続した自動保存はできません。設定からJSONの控えを保存・読み込みできます。ブラウザデータ削除に備えて控えを保存してください。',
          ),
          FilledButton.tonal(
            onPressed: enabled ? _browserMode : null,
            child: const Text('ブラウザ保存モードで開始'),
          ),
          if (_working || sync.busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    },
  );

  Future<void> _browserMode() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.sync.useBrowserMode();
      if (mounted) widget.onReady?.call();
    } catch (error) {
      if (mounted) setState(() => _error = '保存方法を変更できませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _choose(Future<ProjectSnapshot?> Function() choose) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final snapshot = await choose();
      if (snapshot == null || !mounted) return;
      final sync = widget.sync;
      if (snapshot.content == sync.persistence.exportJson()) {
        await sync.uploadCurrent(ProjectTarget.localFolder, snapshot);
      } else {
        // Validate before offering any destructive replacement.
        sync.validate(snapshot.content ?? '');
        setState(() => _working = false);
        final useFile = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('使用する内容を選択'),
            content: const Text(
              'フォルダと端末内の内容が異なります。端末内の変更を残す場合は「端末の内容をフォルダへ保存」を選んでください。選ばなかった側の内容は置き換わります。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('フォルダの内容を読み込む'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('端末の内容をフォルダへ保存'),
              ),
            ],
          ),
        );
        if (useFile == null || !mounted) return;
        setState(() => _working = true);
        if (useFile) {
          await sync.useProject(ProjectTarget.localFolder, snapshot);
        } else {
          await sync.uploadCurrent(ProjectTarget.localFolder, snapshot);
        }
      }
      if (mounted) widget.onReady?.call();
    } catch (error) {
      if (mounted) setState(() => _error = 'プロジェクトを使用できませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importJson() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json', 'zip'],
      );
      if (picked == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('移行するJSONを読み込みますか？'),
          content: const Text(
            '検証後に端末内の内容を置き換えます。旧JSONには画像本体は含まれません。読み込み後にプロジェクトフォルダを作成するか、ブラウザ保存を選んでください。',
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
        widget.sync.persistence,
        files: widget.sync.storage.assets,
      ).restore(await picked.readAsBytes());
      if (!result.isValid) throw FormatException(result.errors.join('\n'));
      widget.sync.projectImported();
      if (mounted) {
        setState(() => _error = '読み込みました。空のフォルダへ作成するか、ブラウザ保存モードで開始してください。');
      }
    } catch (error) {
      if (mounted) setState(() => _error = '移行できませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
