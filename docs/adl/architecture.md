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
          → 接続中のPWAプロジェクトファイルまたはGoogle Driveへ保存
```

アプリ起動時は逆方向に、JSONを読み、3ストアが保持する公開Listを `clear` + `addAll` で復元します。`AppShell.dispose()` は保留中タイマーを止めた後、最終状態を保存します。

### 現行の正本

- ランタイム状態: 各ストアのインメモリList
- 再起動後の正本: ネイティブはSQLite `settings.app_state_v1`、WebはlocalStorage `cosplayers_diary.app_state_v1` のJSON
- `genres`、`diary` などの正規化テーブル: version 1 migrationで作成されるが未使用

正規化テーブルへの保存を追加する場合は、JSONとの二重書き込みを安易に増やさず、どちらを正本にするかと移行/ロールバックを先に決めます。

Webとネイティブは同じJSON表現とZIPバックアップ形式を使用します。ただしブラウザのサンドボックスからiOSアプリのSQLiteへ直接アクセスできないため、両者間のデータ移行は設定画面のZIP作成・復元で行います。Webの保存領域は公開オリジンごとに分離され、ブラウザデータ削除の対象です。

### PWAプロジェクト保存

`ProjectSyncController` が外部保存先と前回のrevisionを保持します。設定画面で利用者が明示的にローカルファイルまたはGoogle Driveを接続すると、`AppStatePersistence.onSaved` から同じJSONを外部へ書きます。外部保存に失敗してもブラウザ内の `app_state_v1` は保持し、外部自動保存を停止します。再接続時に端末側か保存先側かを選びます。保存先JSONは一時ストアで形式を検査してから既存ストアへ復元します。

Web実装は `web/project_storage.js` と `project_storage_web.dart` のJS interopです。ローカルファイルはFile System Access APIの選択済みhandleをIndexedDBに保存します。Google DriveはGoogle Identity Servicesのtoken modelと `drive.file` scopeを使い、アプリが作る `CosplayDiary/CosplayDiary.project.json` をREST APIで読み書きします。アクセストークンはメモリ内だけに置きます。両保存先とも書き込み直前に外部の内容またはversionを確認します。Driveの取得と更新は別リクエストなので、同時更新の完全な原子性はありません。ネイティブではプロジェクト保存機能を公開せず、既存のSQLite/ZIPを利用します。

## PWA配信

`web/manifest.json` がホーム画面名、テーマ色、通常/マスカブルアイコンを定義します。Flutter自動生成Service Workerには依存せず、`web/app_service_worker.js` が同一オリジンのアプリシェルと実行時取得リソースをキャッシュします。`web/flutter_bootstrap.js` はService Workerを登録し、CanvasKitを同梱ファイルから読み込むため、初回オンライン起動後はオフラインでも起動できます。

Vercelではドメイン直下用に `--base-href /` でビルドし、`tool/prepare_vercel_output.mjs` が `build/web` をBuild Output API形式の `.vercel/output/static` へ変換します。Build Outputには実ファイルを優先するfilesystemルートと、Flutter Web向けの `index.html` フォールバックを含めます。`.github/workflows/deploy-pwa.yml` はProduction用のprebuilt成果物をステージし、Deployment Protectionを通過する認証付き `vercel curl` のHTTP検証に成功したデプロイだけを `cosplayers-diary-app` の本番ドメインへ昇格します。`vercel.json` はVercelのGit自動デプロイを無効化し、公開経路をこのワークフローへ一本化します。公開URLは `https://cosplayers-diary-app.vercel.app` です。

## SQLite

`AppDatabase.openDefault()` はプラットフォームのDBディレクトリに `cosplayers_diary.db` を開きます。接続時に外部キーを有効にし、`schema.dart` の順序付きmigrationをトランザクション内で適用します。

現在の `databaseVersion` は1です。新しいmigrationは既存versionのstatementを書き換えず、versionを上げて末尾へ追加します。インメモリDB結合テストは `sqflite_common_ffi` を使います。

## ZIPバックアップ

作成フロー:

```text
AppStatePersistence.exportJson()
  ├─ data/app_state.json
  └─ BackupCoordinatorが各CSV行へ写像
      → CsvService.encode(BOM付き)
          → BackupService.create()
              ├─ manifest.json
              └─ ZIP bytes
```

復元フロー:

```text
ZIP bytes
  → BackupService.inspect()
      ├─ CRC検証
      ├─ ZIP Slip対策
      ├─ 展開後合計1GiB上限
      ├─ formatVersion検証
      └─ imageCount検証
  → data/app_state.json をrestoreJson()
  → SettingsStoreへsave()
```

注意点:

- CSVは人間が確認・将来利用する副産物であり、現行復元処理はCSVを読みません。
- `character_lenses.csv` と `photos.csv` は定義されますが、現在は常にデータ行が空です。
- 画像ファイルを列挙してZIPへ渡す構成が未接続なため、現在のバックアップに画像は入りません。
- `inspect()` はmanifestの `dataCounts` と実ファイルの行数を照合しません。
- `restoreJson()` のJSON形式エラーは `BackupInspection.errors` へ変換されず例外になるため、復元堅牢化時の確認対象です。

## ファイルと画像

`FileStore` がアプリ専用ファイル操作の境界です。`LocalFileStore` は絶対パスと `..` を拒否し、一時ファイルへ書いてからrenameします。

`PhotoService.replace()` は新ファイルの保存成功後に古い未参照ファイルを削除します。古いファイルの削除失敗は、新しい参照を壊さないため無視します。容量節約時は `PackageImageProcessor` が向きを補正し、長辺が2,048pxを超える場合のみJPEG quality 90へ変換します。

現状、これらのクラスは `AppShell` で生成されず、画面・永続化・バックアップへ接続されていません。

## 外部依存の役割

| パッケージ | 用途 |
|---|---|
| `sqflite`, `sqflite_common` | モバイルSQLiteと共通API |
| `sqflite_common_ffi` | テスト用インメモリSQLite |
| `web` | PWAでlocalStorageへアクセスするWeb API境界 |
| `image_picker` | 将来の画像選択用。現行UI未接続 |
| `image` | 向き補正、縮小、JPEG変換 |
| `path_provider`, `path` | アプリ領域/安全なパス操作 |
| `archive` | ZIP作成、CRC付き検証・展開 |
| `file_picker` | ZIP保存先選択、復元元選択 |
| `csv` | 依存宣言はあるが、現行 `CsvService` は独自パーサー/エンコーダー |
| `share_plus` | 依存宣言はあるが、現行コードでは未使用 |

通常利用にネットワークや認証は不要です。任意のPWA Google Drive連携時のみGoogle Identity ServicesとDrive REST APIを使用します。分析SDKはありません。
