# 実装・調査ガイド

## 開発環境

`pubspec.yaml` は Dart `^3.13.3` を要求します。README記載の想定は Flutter 3.47 / Dart 3.13です。まず次を確認します。

```sh
flutter --version
flutter pub get
flutter doctor
```

基本検証:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

実機/エミュレーター:

```sh
flutter devices
flutter run -d <device-id>
```

Android releaseは `flutter build appbundle --release`、iOS releaseはmacOS/Xcodeで `flutter build ipa --release` です。

Web/PWAはローカル確認に `flutter run -d chrome`、Vercel用リリース生成に `flutter build web --release --pwa-strategy=none --base-href /` を使います。独自の `app_service_worker.js` を使うため、Flutter生成Service Workerは無効化します。HTTPS配信先はVercelの `cosplayers-diary-app` プロジェクトです。VercelのGit自動デプロイは無効で、公開はGitHub Actionsが生成する検証済みprebuilt成果物だけを使用します。

PWAは初回に指定フォルダ（対応ブラウザ）かブラウザ保存（Safari対応）を選びます。設定から切替可能です。Google Drive連携と `GOOGLE_OAUTH_CLIENT_ID` ビルド設定は削除しました。JS境界のテストは `node tool/project_storage_test.mjs`、起動/再指定/モード切替は `test/widget/project_setup_test.dart`、障害・競合は `project_sync_controller_test.dart` で確認します。

任意のGoogleカレンダー連携は別の公開クライアントID `GOOGLE_CALENDAR_CLIENT_ID` を使用します。OAuthの運営者設定と利用手順は [`../google-calendar.md`](../google-calendar.md)。`flutter test test/unit/calendar_sync test/widget/calendar_sync_card_test.dart` と `node tool/calendar_sync_test.mjs` で同期規則・回数制限・UI・GIS/API境界を検証します。実Googleアカウント、Safariでの認証、Gemini検索はOAuth設定後に別途確認が必要です。

ビルド後に `node tool/verify_pwa.mjs build/web` を実行すると、manifestのJSON、独自Service Worker登録、ローカルCanvasKit設定、プリキャッシュ対象ファイルの存在を検証できます。続けて `node tool/prepare_vercel_output.mjs build/web` を実行すると、Vercel CLIの `vercel deploy --prebuilt --prod --skip-domain` でステージできる成果物になります。`.github/workflows/deploy-pwa.yml` も同じ検証・変換を行い、Deployment Protectionが有効なステージURLを認証付き `vercel curl` で検証してから、同じprebuilt成果物を本番へ公開します。

`pre-develop` は `deploy-pages.yml` からPages検証版へ配信します。手動の再現は `flutter build web --release --pwa-strategy=none --base-href /cosplayers_diary_app/` と `node tool/verify_pwa.mjs build/web /cosplayers_diary_app/`。ルート配信とは別のビルドです。`node tool/service_worker_test.mjs` はサブパスの取得・別サイトのキャッシュ保持・オフラインフォールバックを検証します。`project_storage_test.mjs` は公開パス別handle DBも検証します。初回のPages Source/Environment設定と利用枠は [`../pwa-preview.md`](../pwa-preview.md) を参照してください。

## 変更箇所マップ

| 変更したいこと | 主な開始地点 | 同時に確認するもの |
|---|---|---|
| ナビ/レスポンシブ | `lib/app/app.dart`, `router.dart` | `test/widget/app_shell_test.dart`、600px境界 |
| 参加イベントと回数 | `master_data_store.dart`, `statistics_service.dart` | 日記のeventId、同日重複、マスター一覧/ダッシュボード、JSON、Googleカレンダー |
| マスター項目/候補 | `master_models.dart`, `master_service.dart` | store、フォーム、JSON、CSV、過去参照 |
| 日記の項目/検証 | `diary_models.dart`, `diary_service.dart` | DiaryStore、フォーム/一覧、JSON、CSV、統計 |
| 日記の複数キャラ・衣装 | `CosplayLook`, `diary_form.dart` | カレンダー表示、旧単一IDの読み込み、ランキング、Googleカレンダー、CSV定義 |
| カラコン在庫/使用 | `lens_service.dart` | 日記との整合性、LensStore、JSON、CSV、統計 |
| 写真保存 | `photo_service.dart`, `local_file_store.dart` | UI composition、メタデータ永続化、JSONの画像参照 |
| SQLite | `schema.dart`, `app_database.dart` | version追加、DB結合テスト、JSON正本との関係 |
| 自動保存/復元 | `app_state_persistence.dart`, `settings_store.dart` | SQLite/localStorage、全モデルの往復、古いJSON、dispose時保存 |
| PWAプロジェクト保存 | `project_sync_controller.dart`, `project_storage*.dart`, `web/project_storage.js` | 外部更新競合、ファイル権限再許可、オフライン、ローカルキャッシュ |
| Googleカレンダー連携 | `features/calendar_sync/`, `web/calendar_sync.js` | 3状態比較、ETag、削除と在庫、日次10回、認証/表示切替、OAuth設定文書 |
| PWA/配信 | `web/`, `.github/workflows/deploy-pwa.yml`, `deploy-pages.yml` | 本番/検証ブランチ、manifest、base href、保存領域とキャッシュのscope、オフライン再起動 |
| CSV | `csv_service.dart`, `backup_coordinator.dart` | README列定義、samples、参照検証、BOM |
| Node.jsのセキュリティ更新 | `.node-version`, `.github/workflows/` | Node公式の修正版、PagesとVercelの両ワークフロー、Vercel CLI、静的成果物 |
| JSON/旧ZIP読取 | `backup_service.dart`, `backup_coordinator.dart` | 検証前非破壊、サイズ/パス/形式、設定UI |
| 統計 | `statistics_service.dart`, `dashboard_page.dart` | 回数対日数、年filter、空状態、ID→名称表示 |
| バックアップ通知 | `backup_reminder.dart`, `settings_page.dart` | 時計境界、未来日時、保存キャンセル |

## テスト構成

```text
test/
├── unit/
│   ├── backup/          # JSON往復・非破壊検証・旧ZIP読取
│   ├── calendar_sync/   # 変換・競合・削除・日次上限・端末間同期
│   ├── contact_lenses/  # 期限、在庫、ワンデー、編集/削除整合性
│   ├── core/            # Clock、migration定義
│   ├── csv/             # BOM、引用、検証、差分preview
│   ├── dashboard/       # 回数/日数、月別、同率、全期間
│   ├── diary/           # 必須項目、同日複数、複製
│   ├── master_data/     # ID絞り込み、汎用衣装、archive履歴
│   ├── photos/          # 保存順序、共有旧ファイル
│   └── settings/        # 30日リマインド
├── widget/
│   └── app_shell_test.dart
└── integration/
    ├── database_test.dart
    └── user_flows_test.dart
```

`user_flows_test.dart` のシナリオ:

- A: マスター連鎖からコスプレ日記保存
- B/C: ワンデー使用と解除による在庫復元
- D: JSON経由で空DB側のストアへ状態復元
- E: 同日のコスプレ/撮影を独立集計

新しい業務規則は最小のunit testへ追加し、複数featureの接続はintegration test、画面の表示/操作はwidget testで補います。

## 実装パターン

### モデル項目を追加する

1. domain modelと必要な `copyWith` を変更する。
2. serviceの検証/計算とunit testを変更する。
3. storeとpresentationの入力/表示を変更する。
4. `AppStatePersistence.exportJson()` と `restoreJson()` を往復で変更する。
5. 関連するCSV列・行変換、バックアップ、サンプルを確認する。
6. 正規化テーブルへ将来保存する項目なら、新migrationの要否を判断する。
7. ADLの関連章を更新する。

古いJSONに存在しない可能性がある項目は、可能なら既定値を使って後方互換に読みます。必須化するなら移行処理を用意します。

### 新しいストア操作を追加する

- 値のtrimや業務検証をstore/service境界で行う。
- 成功した変更の後に `notifyListeners()` を1回呼ぶ。
- 失敗時に部分更新が残らない順序にする。
- 複数ストア更新は専用coordinatorで失敗/ロールバック方針を定める。

### migrationを追加する

- `databaseVersion` を増やす。
- `migrations` の末尾へ新versionを追加し、version 1を書き換えない。
- 新規DBと旧versionからのupgradeの両方をテストする。
- 外部キーONの状態とmigration全体のトランザクション性を維持する。

## 既知の未接続・改善候補

優先度はユーザー要求で決めます。以下は調査で判明した事実であり、この文書作成時には修正していません。

### 機能接続

- 日記画面からのジャンル・キャラ・衣装追加、週開始曜日の切替は `diary_form_test.dart`・`calendar_page_test.dart`・`calendar_preferences_test.dart` で確認します。

- 日記画像の追加・プレビュー・差し替え・取り外しは接続済み。画像の物理削除と拡大専用ビューは未実装。
- 日記フォームにカラコン購入/実物の選択、開封、使用解除がない。
- 日記内の追加では選択中ジャンル・キャラへの関連付けと固有/汎用衣装に対応。管理画面では参加イベントの登録・参加回数、名前の編集、キャラ追加時のジャンル選択、衣装の複数ジャンル・全ジャンル・タグ・汎用/固有・対象キャラ複数選択に対応。日記とカレンダーの日記一覧には予定名・キャラ・タグ付き衣装を表示。メモ・カラコン候補の編集UIは未実装。
- 単独CSVを選択して検証/preview/反映するUIとapplication処理がない。
- ダッシュボードは一部統計だけを表示し、ジャンル/衣装ランキングや期限間近件数は未接続。

### データ整合性・堅牢性

- `DiaryStore.delete()` 単体はカラコン使用解除をしない。画面上の日記削除はAppShellのコールバックから `deleteDiary()` を呼び、使用解除してから実行するため、今後の削除経路追加時も同じ関数を使う。
- `restoreJson()` は全体検証後に復元する。JSON/旧ZIPの読み込み失敗は設定画面へ通知する。
- 旧ZIP移行の検査はmanifestのCSV行数と実内容を照合しない。
- 手動JSONバックアップは画像をBase64で同梱するため、画像数が多いとメモリと容量を使う。フォルダ保存ではフォルダ全体のコピーも利用できる。
- ID生成は各クラス内の `DateTime.now().microsecondsSinceEpoch + sequence` で、共通ID生成器や注入可能なClockを使っていない。
- `Clock` 抽象は存在するが、多くのUI/store/domain modelが `DateTime.now()` を直接使用する。
- SQLite/localStorage自体の自動保存例外をユーザーへ通知・再試行する仕組みがない。PWA指定フォルダの例外は必須の再指定画面を表示し、外部保存と編集を停止する。

### 保守性

- `csv`、`image_picker`、`path_provider`、`share_plus` は、少なくとも現行 `lib/` から一部または全部が未使用。
- Vercelの自動公開にはGitHub ActionsのRepository secret `VERCEL_TOKEN` が必要。`VERCEL_ORG_ID` と `VERCEL_PROJECT_ID` はワークフローの固定環境変数で管理する。
- app stateの保存キーは既存の `app_state_v1` を維持し、payloadに `projectFormat: 2` と画像一覧を追加している。旧JSONは後方互換で読む。
- ストアのListが外部から直接変更可能で、変更時に通知や保存を迂回できる。

## 作業完了チェック

- 要求されたユーザーフローが画面から完結するか。
- domainの不変条件を壊していないか。
- store更新後に再描画と自動保存が起きるか。
- 再起動、JSON保存/読み込み、旧ZIP移行、古いJSONへの影響を確認したか。
- スマホ幅とタブレット幅でレイアウトを確認したか。
- 対象test、全 `flutter test`、`flutter analyze` を実行したか。
- 実行できない検証は、環境理由とともに明示したか。
- 実装とADLが一致しているか。

## プロジェクトフォルダと画像

仕様・移行は [`../project-folders.md`](../project-folders.md)。`ProjectStorage.assets` が画像キャッシュのFileStore境界、`loadAssets()` が選択したフォルダからの検証済み取り込みです。フォルダJSONは画像の参照のみ、手動BackupCoordinatorは非同期で画像を同梱します。日記写真を変更する場合はPhotoController、JSONメタデータ、フォルダの先行画像保存、画像付きバックアップの往復を一緒に確認してください。`tool/project_storage_test.mjs` は空フォルダ・画像の欠損/外部更新・権限・非破壊・パス検証を含みます。
