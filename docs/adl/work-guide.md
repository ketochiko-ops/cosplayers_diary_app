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

Google Drive連携を公開する場合、サイト運営者がGoogle CloudのWeb OAuthクライアントを作成し、GitHub ActionsのRepository variable `GOOGLE_OAUTH_CLIENT_ID` を設定します。ワークフローは `--dart-define` で公開クライアントIDをビルドへ渡します。未設定時はGoogle Drive接続ボタンが無効です。利用者個別のOAuthクライアントIDを公開サイトで入力させる方式はGoogleのドメイン所有要件に合いません。

ビルド後に `node tool/verify_pwa.mjs build/web` を実行すると、manifestのJSON、独自Service Worker登録、ローカルCanvasKit設定、プリキャッシュ対象ファイルの存在を検証できます。続けて `node tool/prepare_vercel_output.mjs build/web` を実行すると、Vercel CLIの `vercel deploy --prebuilt --prod --skip-domain` でステージできる成果物になります。`.github/workflows/deploy-pwa.yml` も同じ検証・変換を行い、Deployment Protectionが有効なステージURLを認証付き `vercel curl` で検証してから本番へ昇格します。

## 変更箇所マップ

| 変更したいこと | 主な開始地点 | 同時に確認するもの |
|---|---|---|
| ナビ/レスポンシブ | `lib/app/app.dart`, `router.dart` | `test/widget/app_shell_test.dart`、600px境界 |
| マスター項目/候補 | `master_models.dart`, `master_service.dart` | store、フォーム、JSON、CSV、過去参照 |
| 日記の項目/検証 | `diary_models.dart`, `diary_service.dart` | DiaryStore、フォーム/一覧、JSON、CSV、統計 |
| カラコン在庫/使用 | `lens_service.dart` | 日記との整合性、LensStore、JSON、CSV、統計 |
| 写真保存 | `photo_service.dart`, `local_file_store.dart` | UI composition、メタデータ永続化、ZIP画像 |
| SQLite | `schema.dart`, `app_database.dart` | version追加、DB結合テスト、JSON正本との関係 |
| 自動保存/復元 | `app_state_persistence.dart`, `settings_store.dart` | SQLite/localStorage、全モデルの往復、古いJSON、dispose時保存 |
| PWAプロジェクト保存 | `project_sync_controller.dart`, `project_storage*.dart`, `web/project_storage.js` | 外部更新競合、OAuth再接続、オフライン、ローカルキャッシュ |
| PWA/配信 | `web/`, `.github/workflows/deploy-pwa.yml` | manifest、アイコン、base href、HTTPS、オフライン再起動 |
| CSV | `csv_service.dart`, `backup_coordinator.dart` | README列定義、samples、参照検証、BOM |
| ZIP | `backup_service.dart`, `backup_coordinator.dart` | 検証前非破壊、サイズ/パス/形式、設定UI |
| 統計 | `statistics_service.dart`, `dashboard_page.dart` | 回数対日数、年filter、空状態、ID→名称表示 |
| バックアップ通知 | `backup_reminder.dart`, `settings_page.dart` | 時計境界、未来日時、保存キャンセル |

## テスト構成

```text
test/
├── unit/
│   ├── backup/          # manifest、version、ZIP Slip、サイズ上限
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
- D: ZIP経由で空DB側のストアへ状態復元
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

- 日記フォームに写真選択、プレビュー、差し替え、削除がない。
- 日記フォームにカラコン購入/実物の選択、開封、使用解除がない。
- マスター追加UIで所属ジャンル、専用衣装、メモ、カラコン候補を指定できない。
- 単独CSVを選択して検証/preview/反映するUIとapplication処理がない。
- ダッシュボードは一部統計だけを表示し、ジャンル/衣装ランキングや期限間近件数は未接続。

### データ整合性・堅牢性

- `DiaryStore.delete()` とカラコン使用解除が連動していない。
- `restoreJson()` は構造不正や未知enumを回復可能な検証エラーにしない。
- バックアップ検査はmanifestのCSV行数と実内容を照合しない。
- バックアップ作成は画像ファイルを収集せず、写真メタデータも状態に含まない。
- ID生成は各クラス内の `DateTime.now().microsecondsSinceEpoch + sequence` で、共通ID生成器や注入可能なClockを使っていない。
- `Clock` 抽象は存在するが、多くのUI/store/domain modelが `DateTime.now()` を直接使用する。
- SQLite/localStorage自体の自動保存例外をユーザーへ通知・再試行する仕組みがない。PWA外部保存の例外は設定画面に表示し、外部保存を停止する。

### 保守性

- `csv`、`image_picker`、`path_provider`、`share_plus` は、少なくとも現行 `lib/` から一部または全部が未使用。
- Vercelの自動公開にはGitHub ActionsのRepository secrets（`VERCEL_TOKEN`、`VERCEL_ORG_ID`、`VERCEL_PROJECT_ID`）が必要。
- app state JSONのschema versionがpayload内にない。キー名だけが `app_state_v1`。
- ストアのListが外部から直接変更可能で、変更時に通知や保存を迂回できる。

## 作業完了チェック

- 要求されたユーザーフローが画面から完結するか。
- domainの不変条件を壊していないか。
- store更新後に再描画と自動保存が起きるか。
- 再起動、ZIP作成/復元、古いJSONへの影響を確認したか。
- スマホ幅とタブレット幅でレイアウトを確認したか。
- 対象test、全 `flutter test`、`flutter analyze` を実行したか。
- 実行できない検証は、環境理由とともに明示したか。
- 実装とADLが一致しているか。
