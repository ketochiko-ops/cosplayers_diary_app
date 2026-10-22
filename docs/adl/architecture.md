# アーキテクチャ

## 全体像

機能単位のディレクトリと、軽量なレイヤー分離を採用しています。

```text
lib/
├── main.dart                         # プラットフォーム別SettingsStoreを開きアプリを起動
├── app/
│   ├── app.dart                      # ストア所有、状態復元、レスポンシブシェル
│   ├── router.dart                   # 5つのナビゲーション定義
│   └── theme.dart                    # Material 3、紺/金テーマ
├── core/
│   ├── database/                     # スキーマ、接続、JSON状態永続化
│   └── services/                     # Clock/FileStore境界
└── features/
    ├── diary/
    ├── master_data/
    ├── contact_lenses/
    ├── photos/
    ├── backup/
    ├── calendar_sync/
    ├── dashboard/
    └── settings/
```

各featureは必要に応じて次の層を持ちます。

- `domain`: モデル、検証、計算。Flutter WidgetやプラットフォームI/Oに依存させない。
- `application`: `ChangeNotifier` ストアや複数処理の調整役。
- `infrastructure`: ファイル、画像処理など外部パッケージを使う実装。
- `presentation`: Widget、ダイアログ、画面遷移。

厳密なDIコンテナやリポジトリ層はありません。依存はコンストラクタで直接渡します。

## 起動と画面構成

```text
main()
  └─ openDefaultSettingsStore()
      ├─ native → AppDatabase.openDefault()
      ├─ web → WebSettingsStore(localStorage)
      └─ CosplayDiaryApp
          └─ AppShell
              ├─ MasterDataStore
              ├─ DiaryStore
              ├─ LensStore
              └─ AppStatePersistence.load() → attach()
```

`AppShell` のインデックスと画面は固定です。

| index | 画面 | 主な依存 |
|---:|---|---|
| 0 | `CalendarPage` | DiaryStore, MasterDataStore |
| 1 | `DiaryListPage` | DiaryStore, MasterDataStore |
| 2 | `ManagementPage` | MasterDataStore, LensStore |
| 3 | `DashboardPage` | DiaryStore, LensStore |
| 4 | `SettingsPage` | SettingsStore, AppStatePersistence |

幅600px未満は `NavigationBar`、600px以上は `NavigationRail` です。ルーティングパッケージは使わず、編集画面は `MaterialPageRoute` でpushします。

`CosplayDiaryApp(settingsStore: null)` はテスト用の有効な構成です。この場合、初期ロード画面、永続化、設定のバックアップ操作は無効になります。

### カレンダー表示設定と日記内マスター追加

`CalendarWeekStart` は月曜・日曜の選択肢と初期値（月曜）を定義します。`AppShell` が起動時に `calendar_week_start` をSettingsStoreから読み、CalendarPageとSettingsPageへ渡します。設定画面は保存成功後にAppShellへ変更を通知します。表示設定は端末固有で、プロジェクトJSONには含めません。

CalendarPageは開始曜日から日付のオフセットを算出し、52px（文字サイズ設定に応じ拡大）の行を持つSliverGridで表示します。年・月の選択欄と前後月の矢印、日付選択・日記一覧を同じスクロール領域に置きます。日付セルは予定名とキャラクター名を省略表示し、選択日と日記画面の一覧には全組のキャラクター・タグ付き衣装名を表示します。参照マスターが欠損した日は警告色と「⚠」を付け、一覧・編集画面で「取得できませんでした」と示します。マスター変更時も一覧を再描画します。

DiaryFormは1件の日記へ複数の `CosplayLook` を追加・削除できます。各組のマスター欄の追加ボタンから `showQuickAddMasterDialog` を開きます。空白名は確定せず、確定時はMasterDataStoreの通常メソッドで通知・自動保存します。キャラはその組のジャンル、専用衣装はその組のキャラに関連付け、汎用衣装も選べます。親の変更時はその組の子の選択だけ解除します。フォームのkeyも選択IDで更新し、見た目と保存IDを一致させます。

MasterDataPageは参加イベントの登録・改名・アーカイブと全期間の参加回数も表示します。参加回数は同じイベントID・活動日を1回にまとめます。DiaryFormは参加イベントを任意で選択・その場で追加でき、従来の自由入力予定名も保持します。

MasterDataPageの編集ダイアログは名前、キャラクター追加時のジャンル、衣装の複数ジャンル（空なら全ジャンル）・タグ・汎用/固有・対象キャラクター複数選択を扱います。アーカイブタブから確認後にマスターを完全削除できます。MasterDataStoreはアーカイブ済み項目だけの削除を許し、参照IDは他のレコードに残します。日記の既存衣装IDが後の分類変更で現在の候補から外れても、DiaryFormではその日記の履歴として表示します。旧JSONの衣装は単一キャラID・ジャンルIDから複数IDへ復元します。日記削除は編集画面と一覧メニューから確認後に行い、AppShell経由の `deleteDiary()` がカラコン使用解除を先に実行します。

初回のProjectSetupに移行専用UIはありません。JSONの読み込みは設定画面の通常操作を使用します。

## 状態変更と自動保存

```text
Presentation
  → Storeのメソッド
    → Domain serviceで検証/計算
    → インメモリListを更新
    → notifyListeners()
      ├─ AnimatedBuilderが再描画
      └─ AppStatePersistenceが250msデバウンス
          → 全ストアをJSON化
          → SettingsStore(key='app_state_v1')へ保存
          → フォルダ保存モードで接続中のJSON・imagesへ保存
```

アプリ起動時は逆方向に、JSONを読み、3ストアが保持する公開Listを `clear` + `addAll` で復元します。`AppShell.dispose()` は保留中タイマーを止めた後、最終状態を保存します。

### 現行の正本

- ランタイム状態: 各ストアのインメモリList
- 再起動後の正本: ネイティブはSQLite `settings.app_state_v1`、WebはlocalStorage `cosplayers_diary.app_state_v1` のJSON
- `genres`、`diary` などの正規化テーブル: version 1 migrationで作成されるが未使用

正規化テーブルへの保存を追加する場合は、JSONとの二重書き込みを安易に増やさず、どちらを正本にするかと移行/ロールバックを先に決めます。

Webとネイティブは同じJSONプロジェクト形式を使用します。ただしブラウザのサンドボックスからiOSアプリのSQLiteへ直接アクセスできないため、両者間のデータ移行は設定画面のJSON保存・読み込みで行います。Webの保存領域は公開オリジンごとに分離され、ブラウザデータ削除の対象です。

### PWAプロジェクト保存

`ProjectSyncController` が保存モード、外部保存先、前回のrevisionを保持します。PWAの初回（モード未指定時）は `ProjectSetup` の必須ダイアログでフォルダ保存モードかブラウザ保存モードを選びます。フォルダ保存モードでは作成/読み込みが成功するまで編集不可です。Safariなど非対応ブラウザにはブラウザ保存モードを提供します。異なるファイル内容を読み込んだ場合は以前のプロジェクトの編集routeを閉じます。ネイティブのSQLite保存方式は変更しません。

`AppStatePersistence.onSaved` が指定フォルダへ画像を先に、同じJSONを後に書きます。保存失敗時はキャッシュを保持して `requiresSelection` に移行し、AppShellが編集中のrouteの上にも閉じられないダイアログを表示します。5秒周期とアプリ復帰時にフォルダ、JSON、参照画像の存在・権限・revisionを確認し、失敗を検出した場合も再指定を求めます。監視と書き込みは直列化します。

Web実装は `web/project_storage.js` と `project_storage_web.dart` のJS interopです。File System Access APIのdirectory handleをIndexedDBへ保存し、トランザクション完了まで待ちます。起動時に許可済みでキャッシュと同じ内容の場合のみ再接続します。許可要求は利用者のボタン操作で行います。保存先選択前に旧保存処理を排出し、JSONを一時ストアで検証後、端末側/ファイル側のどちらを使うか確認します。書き込み直前に内容一致を確認しますが、他アプリとの完全に原子的な競合防止ではありません。

ブラウザ保存モードでは外部フォルダを読み書きせず、JSONをlocalStorage、画像をIndexedDBへ自動保存します。設定画面から手動でJSONの控えをダウンロード・読み込みします。Google Drive連携は削除しています。キャッシュJSONが破損した場合は復旧画面を表示し、保存方法の明示的な再指定が完了するまで通常保存や終了処理で破損データを上書きしません。

### 任意のGoogleカレンダー同期

`AppShell` が `CalendarSyncController` を所有し、設定カードへ渡します。`AppStatePersistence` の追加保存リスナーは外部JSON保存の `onSaved` と共存します。日記と関連マスターの同期対象だけを比較し、接続中の日ごとの初回変更で自動実行、以降は手動です。`Clock` で端末の暦日を計算し、試行前に回数を永続化します。失敗・接続時の初回同期を含め端末・ブラウザごと10回/日で、アカウント切替ではリセットしません。

`CalendarCodec` は参加イベントIDと参照マスター名も予定の非表示メタデータ・説明へ含め、旧同期データにイベントマスターがない場合も読み込みます。参加イベント選択時に個別の予定名が空ならそのマスター名を予定名にします。

`CalendarCodec` は純粋Dartで予定・最小限のマスターを変換し、`CalendarPlanner` は前回同期・端末・Googleの3状態を比較します。競合は利用者が選び、Google更新にはETagを使います。履歴のない日記は不在を理由に削除しません。端末側の復元は全件検証してから実施し、通信中の編集を保護します。カラコン使用付き日記の日時変更は停止、削除は台帳経由です。プロジェクト変更時は接続と履歴を解除します。

Web境界は `web/calendar_sync.js` と条件付きJS interopです。GISのOAuthトークンはメモリのみ。`calendar.app.created` と `calendar.calendarlist.readonly` で専用副カレンダーを発見・作成し、その予定だけを読み書きします。新規カレンダーは `selected:false`、非公開・終日・通知なしの予定です。ポーリング・自動リトライはせず、1回100書き込み/一覧20ページまでで停止します。ネイティブは未対応stubです。

同期履歴、回数、設定は `google_calendar_sync_v1` に分離し、プロジェクトJSONに認証・同期履歴は含めません。CIの公開クライアントID変数は `GOOGLE_CALENDAR_CLIENT_ID`。運営者設定と実接続の検証手順は [`../google-calendar.md`](../google-calendar.md) を参照してください。

## PWA配信

`web/manifest.json` がホーム画面名、テーマ色、通常/マスカブルアイコンを定義します。Flutter自動生成Service Workerには依存せず、`web/app_service_worker.js` が同一オリジンのアプリシェルと実行時取得リソースをキャッシュします。`web/flutter_bootstrap.js` はService Workerを登録し、CanvasKitを同梱ファイルから読み込むため、初回オンライン起動後はオフラインでも起動できます。

Vercelではドメイン直下用に `--base-href /` でビルドし、`tool/prepare_vercel_output.mjs` が `build/web` をBuild Output API形式の `.vercel/output/static` へ変換します。Build Outputには実ファイルを優先するfilesystemルートと、Flutter Web向けの `index.html` フォールバックを含めます。`.github/workflows/deploy-pwa.yml` はProduction用のprebuilt成果物をステージし、Deployment Protectionを通過する認証付き `vercel curl` のHTTP検証に成功した場合だけ、同じprebuilt成果物を `cosplayers-diary-app` の本番ドメインへ公開します。`vercel.json` はVercelのGit自動デプロイを無効化し、公開経路をこのワークフローへ一本化します。公開URLは `https://cosplayers-diary-app.vercel.app` です。

GitHub Actionsのビルド・検証スクリプトは両ワークフローで `actions/setup-node` を使用し、`.node-version` のセキュリティ修正版Node.js 24.22.1で実行します。公開成果物はFlutter Webの静的ファイルのみで、Node.jsのサーバー処理・Functionsは含めません。Vercel CLIはCIでのみ使用し、公開アプリには含めません。

`pre-develop` のpushは `.github/workflows/deploy-pages.yml` でGitHub Pagesの検証版へ配信します。`configure-pages` の公開パスを `--base-href` に渡し、検証済み `build/web` だけをupload/deployします。成果物は公開成功後に削除、失敗時も1日保持です。連続pushは古いrunをキャンセルします。Pages側のdeploy jobにだけ `pages:write`・`id-token:write`・自身のartifactを削除する `actions:write` を付与し、Vercelの資格情報は使用しません。両ワークフローにブランチのjob条件を付け、手動実行も分離しています。

Pagesの同一オリジン上の別プロジェクトを保護するため、localStorageのキー、IndexedDBのhandle保存DB、Service Workerキャッシュを公開base path/scope単位に分けます。ルート配信の従来の保存キーとDB名は維持します。キャッシュ更新時も別scopeのキャッシュを削除しません。Pagesの初回設定・Google認証の生成元・利用枠は [`../pwa-preview.md`](../pwa-preview.md) を参照してください。

## SQLite

`AppDatabase.openDefault()` はプラットフォームのDBディレクトリに `cosplayers_diary.db` を開きます。接続時に外部キーを有効にし、`schema.dart` の順序付きmigrationをトランザクション内で適用します。

現在の `databaseVersion` は1です。新しいmigrationは既存versionのstatementを書き換えず、versionを上げて末尾へ追加します。インメモリDB結合テストは `sqflite_common_ffi` を使います。

## JSON保存と旧ZIP移行

`BackupCoordinator.create()` は非同期で `AppStatePersistence.exportJson()` に画像のBase64を `embeddedImages` として追加し、非圧縮JSONのUTF-8バイト列を返します。自動保存は参照のみ、手動の控えだけ画像同梱です。設定画面は `.project.json` を保存します。

読み込み時は通常JSONを検証します。既存データ移行のためZIPヘッダーを検出した場合のみ `BackupService.inspect()` でCRC/ZIP Slip/サイズ/形式/画像件数を検査し、`data/app_state.json` を取り出します。`BackupService` は旧ZIPの読取専用です。新規ZIPの作成コードはありません。

JSON構造と全レコードの型は一時ストアで検査し、検証が済むまで既存状態を変更しません。保留中の保存を排出後に復元し、キャッシュと指定フォルダへ保存します。画像の実体・保存パス・IDの検証後に読み込みます。既存画像IDのデータは上書きせず、失敗前に追加できた未参照画像が残る場合があります。

## ファイルと画像

`FileStore` がアプリ専用ファイル操作の境界です。`LocalFileStore` は絶対パスと `..` を拒否し、一時ファイルへ書いてからrenameします。

`PhotoService.replace()` は新ファイルの保存成功後に古い未参照ファイルを削除します。古いファイルの削除失敗は、新しい参照を壊さないため無視します。容量節約時は `PackageImageProcessor` が向きを補正し、長辺が2,048pxを超える場合のみJPEG quality 90へ変換します。

`AppShell` は `PhotoController` を生成し、日記の画像追加・プレビュー・取り外しへ渡します。Webは `ProjectStorage.assets` のIndexedDBキャッシュ、ネイティブはアプリ専用 `LocalFileStore` を使用します。画像メタデータは `AppStatePersistence.photos` からJSONへ保存します。`PhotoService` のClockは注入可能です。

新規作成は保存先の親フォルダ内に `cosplayers_diary_project/` を作成します。同名の空フォルダを直接指定することもできます。既存データがある同名フォルダは上書きしません。既存プロジェクトの読み込みは任意のフォルダ名に対応します。フォルダ内は `CosplayDiary.project.json` と `images/`。JS境界は画像を先に書き、JSONのrevisionと画像のサイズ/最終変更時刻を確認してからJSONをコミットします。既存の画像はID単位で不変とし、差し替えは新規IDです。旧 `localFile` 設定は初回再指定へ移行し、旧JSONは削除しません。詳細は [`../project-folders.md`](../project-folders.md)。

## 外部依存の役割

| パッケージ | 用途 |
|---|---|
| `sqflite`, `sqflite_common` | モバイルSQLiteと共通API |
| `sqflite_common_ffi` | テスト用インメモリSQLite |
| `web` | PWAでlocalStorageへアクセスするWeb API境界 |
| `image_picker` | 将来の画像選択用。現行UI未接続 |
| `image` | 向き補正、縮小、JPEG変換 |
| `path_provider`, `path` | アプリ領域/安全なパス操作 |
| `archive` | 旧ZIPのCRC付き検証・展開（読取専用） |
| `file_picker` | 日記画像の選択、画像同梱JSONの保存、JSON/旧ZIP読み込み |
| `csv` | 依存宣言はあるが、現行 `CsvService` は独自パーサー/エンコーダー |
| `share_plus` | 依存宣言はあるが、現行コードでは未使用 |

通常利用にネットワークや認証は不要です。Google Drive連携はありません。任意のWeb/PWAカレンダー連携だけがGoogle Identity ServicesとCalendar APIを使います。分析SDKはありません。
