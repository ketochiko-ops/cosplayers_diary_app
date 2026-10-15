import 'package:flutter/material.dart';

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
          const Text('保存方法を選んでください。指定ファイル方式は、ファイルの作成または読み込みが完了するまで編集を開始できません。'),
          if (_error ?? sync.message case final String message) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            '指定ファイルへ自動保存（Chrome／Edge）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            '任意の場所のJSONファイルを使用します。読み込み・保存の失敗を検出すると、すぐにこの画面で保存先の再指定を求めます。',
          ),
          if (sync.storage.supportsLocalFile) ...[
            FilledButton(
              onPressed: enabled ? () => _choose(sync.createLocalFile) : null,
              child: const Text('保存場所を指定してプロジェクトを作成'),
            ),
            OutlinedButton(
              onPressed: enabled ? () => _choose(sync.openLocalFile) : null,
              child: const Text('既存のプロジェクトファイルを指定'),
            ),
            if (sync.preferredTarget == ProjectTarget.localFile.name)
              TextButton(
                onPressed: enabled
                    ? () => _choose(sync.reconnectLocalFile)
                    : null,
                child: const Text('前回のファイルへのアクセスを許可'),
              ),
          ] else
            const Text('このブラウザは指定ファイルへの自動上書きに対応していません。'),
          const SizedBox(height: 16),
          const Text(
            'ブラウザ内へ自動保存（Safari対応）',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'データはこのブラウザ内に保存します。任意の場所のファイルへ自動上書きはできません。設定からJSONの控えを保存・読み込みできます。ブラウザデータ削除に備えて控えを保存してください。',
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
        await sync.uploadCurrent(ProjectTarget.localFile, snapshot);
      } else {
        // Validate before offering any destructive replacement.
        sync.validate(snapshot.content ?? '');
        setState(() => _working = false);
        final useFile = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('使用する内容を選択'),
            content: const Text(
              'ファイルと端末内の内容が異なります。端末内の変更を残す場合は「端末の内容をファイルへ保存」を選んでください。選ばなかった側の内容は置き換わります。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ファイルの内容を読み込む'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('端末の内容をファイルへ保存'),
              ),
            ],
          ),
        );
        if (useFile == null || !mounted) return;
        setState(() => _working = true);
        if (useFile) {
          await sync.useProject(ProjectTarget.localFile, snapshot);
        } else {
          await sync.uploadCurrent(ProjectTarget.localFile, snapshot);
        }
      }
      if (mounted) widget.onReady?.call();
    } catch (error) {
      if (mounted) setState(() => _error = 'プロジェクトを使用できませんでした: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
