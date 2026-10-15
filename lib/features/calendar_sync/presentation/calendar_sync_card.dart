import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/calendar_sync_controller.dart';
import '../domain/calendar_plan.dart';

class CalendarSyncCard extends StatelessWidget {
  const CalendarSyncCard({
    required this.sync,
    this.clientId = const String.fromEnvironment('GOOGLE_CALENDAR_CLIENT_ID'),
    super.key,
  });
  final CalendarSyncController sync;
  final String clientId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: sync,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Googleカレンダー連携（任意）',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '専用の「コスプレ日記」カレンダーで日記・予定を同期します。写真とカラコン在庫は送りません。Googleの通常カレンダーには書き込みません。',
            ),
            if (!sync.transport.supported)
              const Text('連携はWeb/PWA版で利用できます。')
            else ...[
              if (clientId.isEmpty) const Text('サイト運営者によるGoogleカレンダーの設定待ちです。'),
              FilledButton.icon(
                onPressed: sync.busy || clientId.isEmpty
                    ? null
                    : () => _connect(context),
                icon: const Icon(Icons.event),
                label: Text(
                  sync.connected ? 'Googleアカウントを再接続' : 'Googleカレンダーに接続',
                ),
              ),
              Text(
                sync.connected
                    ? '接続先: ${sync.calendarName}'
                    : '未接続です。起動し直した場合も再接続してください。',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('その日の最初の編集を自動同期'),
                subtitle: const Text('以後の編集は「今すぐ同期」で送れます。'),
                value: sync.automatic,
                onChanged: sync.busy
                    ? null
                    : (value) async {
                        try {
                          await sync.setAutomatic(value);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('設定を保存できませんでした')),
                            );
                          }
                        }
                      },
              ),
              if (sync.connected) ...[
                Text(
                  'この端末・ブラウザで本日 ${sync.usedToday} / 10回（残り${sync.remainingToday}回）',
                ),
                const Text(
                  '自動・手動・接続時の同期を合わせて1日10回。通信に失敗した試行も数えます。表示の切り替えは別です。',
                ),
                if (sync.pending) const Text('未同期の変更、または確認が必要な日記があります。'),
                if (sync.lastSync != null) Text('前回の同期: ${sync.lastSync}'),
                OutlinedButton.icon(
                  onPressed: sync.busy || sync.remainingToday <= 0
                      ? null
                      : () => sync.sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('今すぐ同期'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Googleカレンダーに表示'),
                  subtitle: const Text(
                    'OFFでも予定は残り、同期できます。Google側でもカレンダー名横のチェックで切り替えられます。',
                  ),
                  value: sync.visible,
                  onChanged: sync.busy
                      ? null
                      : (value) => sync.setVisible(value),
                ),
                TextButton(
                  onPressed: sync.busy ? null : () => sync.disconnect(),
                  child: const Text('カレンダー連携を解除（予定は残す）'),
                ),
              ],
              if (sync.message != null)
                Text(
                  sync.message!,
                  style: TextStyle(
                    color: sync.paused
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              for (final change in sync.conflicts) ...[
                const Divider(),
                Text('内容の競合: ${change.label}'),
                const Text('片方で削除された場合も、選んだ側の内容を採用します。'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: sync.busy || sync.remainingToday <= 0
                          ? null
                          : () => sync.sync(
                              resolutions: {
                                change.diaryId: CalendarResolution.local,
                              },
                            ),
                      child: const Text('この端末の内容を使う'),
                    ),
                    TextButton(
                      onPressed: sync.busy || sync.remainingToday <= 0
                          ? null
                          : () => sync.sync(
                              resolutions: {
                                change.diaryId: CalendarResolution.google,
                              },
                            ),
                      child: const Text('Googleの内容を使う'),
                    ),
                  ],
                ),
              ],
              if (sync.busy) const LinearProgressIndicator(),
            ],
            const Divider(),
            const Text(
              'Geminiで予定を探す',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Geminiの「連携アプリ」でGoogle Workspaceを接続し、同じGoogleアカウントを使用してください。作品名・キャラクター・衣装・メモを予定の説明にも記載します。Geminiの回答は元の予定で確認してください。',
            ),
            const SizedBox(height: 8),
            const SelectableText(
              '@Google Calendar 「コスプレ日記」カレンダーから、今月のコスプレ活動を作品・キャラクター別に教えて',
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(
                    text: '@Google Calendar 「コスプレ日記」カレンダーから、今月のコスプレ活動を作品・キャラクター別に教えて',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gemini用の質問をコピーしました')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Gemini用の質問をコピー'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _connect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日記・予定をGoogleと同期しますか？'),
        content: const Text(
          '日付、活動種別、作品・キャラクター・衣装、予定名、メモを自分の専用カレンダーへ送信します。Google側の変更もこの端末へ取り込みます。新しい専用カレンダーは最初は非表示です。接続時の同期も本日の10回に含みます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('接続して同期'),
          ),
        ],
      ),
    );
    if (confirmed == true) await sync.connect(clientId);
  }
}
