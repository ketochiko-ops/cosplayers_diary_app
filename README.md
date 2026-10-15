# コスプレ日記

iOS・iPadOS・Android・PWA向けの、オフラインで使えるコスプレ活動管理アプリです。カレンダー、日記、参加イベント・ジャンル・キャラクター・衣装、カラコン購入/実物/使用履歴、写真、統計、CSV、JSONプロジェクト保存を一つのFlutterプロジェクトで扱います。通常利用にネット接続やアカウントは不要です。Web/PWA版では任意でGoogleカレンダーと日記を同期できます。

## 主な機能

- 月カレンダー、同日複数活動、日記1件への複数キャラ・衣装の登録、コスプレ/カメラマン/その他の日記
- ジャンル→キャラクター→固有/汎用衣装の連動候補、衣装の複数ジャンル・全ジャンル・対象キャラ複数選択、衣装タグ、マスター名の編集、アーカイブからの完全削除
- 参加イベントのマスター管理と日記への紐付け、同じ日の複数日記を1回とする参加回数集計
- カラコン製品、購入別在庫、1組単位の開封/使用履歴、ワンデー再使用防止
- 年/全期間の活動回数・活動日数・同日重複・月別・上位ランキング
- 日記への画像追加・プレビュー・差し替え（オリジナルまたは長辺2,048px）
- UTF-8/BOM対応CSVサービスと、検証付きJSON保存/読み込み（旧ZIPの移行読み込み対応）
- 最終バックアップから30日経過した場合の端末内リマインド
- 600px未満は下部ナビゲーション、600px以上はNavigationRail
- iPhone/iPadのホーム画面追加と、インストール後のオフライン起動に対応するPWA
- PWA初回に保存モードを選択：JSON・マスター・画像をまとめる指定フォルダへの自動保存（対応ブラウザ）またはブラウザ保存（Safari対応）
- 任意のGoogleカレンダー連携：専用カレンダー、日ごとの初回編集を自動同期、以降は手動、端末・ブラウザごとに合計10回/日

## 技術と構成

- Flutter 3.47 / Dart 3.13
- ネイティブ版はSQLite (`sqflite`)、PWA版はブラウザのlocalStorageへ同じJSON状態を永続化
- `image_picker` / `image` / `path_provider`
- `archive` による旧ZIPの読み込み、独立したCSVパーサー/検証器
- UI (`presentation`)、状態/ユースケース (`application`)、業務規則 (`domain`)、I/O (`infrastructure`) を分離
- 現在日時は `Clock`、ファイルは `FileStore` で抽象化

主要ディレクトリ:

```text
lib/
├── app/                 # テーマ、レスポンシブシェル
├── core/                # プラットフォーム別状態保存、SQLite、時計、ファイル境界
└── features/
    ├── diary/           # 日記・カレンダー
    ├── master_data/     # 参加イベント・ジャンル・キャラクター・衣装
    ├── contact_lenses/  # 製品・購入・実物・使用台帳
    ├── photos/          # 安全な画像保存・縮小
    ├── backup/          # CSV・JSON・旧ZIP読み込み
    ├── calendar_sync/   # 任意のGoogleカレンダー双方向同期
    ├── dashboard/       # 統計
    └── settings/        # 設定・バックアップ案内
test/
├── unit/
├── widget/
└── integration/
```

名称変更で過去データが壊れないよう、関連は名称でなくIDで保持します。マスターは先にアーカイブし、管理画面の「アーカイブ」から確認後に完全削除できます。参照が残る日記は削除せず、取得できない項目を表示します。ネイティブ版はSQLiteの `settings`、PWA版はブラウザのlocalStorageに、互換性のあるJSONスナップショットを保持して起動時に復元します。ネイティブ版の正規化テーブルは将来の段階的移行とSQL検索のため同時に作成されます。

## 開発環境

### Windows

1. Flutter stable、Git、Android Studioをインストールします。
2. Android StudioのSDK ManagerでAndroid SDK/Platform Toolsを導入します。
3. `flutter doctor` のAndroid licenseを完了します。
4. リポジトリで次を実行します。

```powershell
flutter pub get
flutter doctor
flutter run
```

プロジェクトパスに日本語が含まれ、Windows版Flutterのシェーダーコンパイラが失敗する場合は、英数字だけの場所へcloneするか、一時ドライブを割り当てます。

```powershell
subst X: "C:\path\to\cosplayers_diary_app"
Set-Location X:\
flutter test
```

### macOS

1. Flutter stable、Xcode、Android Studio、CocoaPodsをインストールします。
2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` を実行します。
3. `flutter pub get && flutter doctor` を実行します。

### Android

```sh
flutter run -d <android-device-id>
flutter build appbundle --release
```

生成物は `build/app/outputs/bundle/release/app-release.aab` です。

### iOS / iPadOS

macOSとXcodeが必要です。`ios/Runner.xcworkspace` でTeamとBundle Identifierを設定してから実機起動またはArchiveします。

```sh
flutter run -d <ios-device-id>
flutter build ipa --release
```

### Web / PWA

本番公開URL: <https://cosplayers-diary-app.vercel.app>

検証用URL（`pre-develop`）: <https://ketochiko-ops.github.io/cosplayers_diary_app/>

```sh
flutter run -d chrome
flutter build web --release --pwa-strategy=none --base-href /
```

生成物は `build/web` です。PWA機能とブラウザ保存を正しく動かすため、公開時はHTTPSで配信してください（`localhost` での開発は例外です）。Vercelではドメイン直下へ公開するため、`--base-href /` を指定します。

```sh
node tool/verify_pwa.mjs build/web
node tool/prepare_vercel_output.mjs build/web
npx --yes --package vercel@60.1.3 vercel deploy --prebuilt --prod --skip-domain
```

Web版は初回に保存モードを必ず選びます。フォルダ保存では同じJSON状態と画像をブラウザ内にも保持し、変更時に指定プロジェクトフォルダへ書き込みます。Safari対応モードでは日記と画像をブラウザ内へ自動保存します。ネイティブ版との移行は設定画面のJSON保存・読み込みで行います。ブラウザデータ削除に備え、定期的にJSONの控えを保存してください。

Vercelへの公開ワークフローは [`.github/workflows/deploy-pwa.yml`](.github/workflows/deploy-pwa.yml) にあります。GitHub ActionsのRepository secretへ `VERCEL_TOKEN` を登録すると、`develop` へのpushまたは手動実行で解析・テスト・PWA検証を行い、Production用のprebuiltデプロイを認証付き `vercel curl` でHTTP検証してから、同じprebuilt成果物を本番ドメインへ公開します。Team IDとProject IDは公開情報のためワークフローに固定しています。VercelのGit自動デプロイは [`vercel.json`](vercel.json) で無効化し、Flutterをビルドしていない空のデプロイが本番を上書きしないようにしています。Vercelプロジェクト名は `cosplayers-diary-app` です。

iPhoneではSafariで公開URLを開き、共有メニューから「ホーム画面に追加」を選択します。初回表示と更新取得にはネット接続が必要ですが、その後はキャッシュ済みのアプリをオフラインで起動できます。

### 本番公開前の確認（GitHub Pages）

`pre-develop` へのpushは [Pages用ワークフロー](.github/workflows/deploy-pages.yml) で検証版だけを公開します。確認後に `develop` へマージすると従来どおりVercelへ本番公開します。手動実行も各ブランチに限定し、検証ブランチからVercelへ公開されるのを防ぎます。

Pagesの初回設定はSourceを「GitHub Actions」、`github-pages` 環境の許可ブランチを `pre-develop` にします。公開リポジトリの標準ランナーの実行時間は無料です。転送量やartifact保存枠は別に制限があるため、配信用artifactは成功後に削除し、残った場合も1日で期限切れにします。設定手順・利用枠・検証データの扱いは [`docs/pwa-preview.md`](docs/pwa-preview.md) を参照してください。

### PWAのプロジェクト保存と端末間の利用

初回起動時（保存モード未指定時）は、保存方法の選択が完了するまで編集できません。設定画面の「保存モード・プロジェクトフォルダを変更」でいつでも切り替えられます。切り替えでも現在のデータは保持します。

| モード | 初回の操作 | 保存方法 |
|---|---|---|
| 指定フォルダ（Chrome/Edge等） | 保存場所を選び `cosplayers_diary_project` を作成するか、既存プロジェクトフォルダを指定 | JSON・マスター・`images/` の画像を自動保存。フォルダhandleをIndexedDBに保持 |
| ブラウザ保存（Safari対応） | 「ブラウザ保存モードで開始」を選択 | 日記・画像をブラウザ内へ自動保存。外部への控えは画像同梱の非圧縮JSONを保存 |

フォルダの作成・選択をキャンセルしても編集は開始しません。再起動時は、権限が残りJSONが端末キャッシュと一致し参照画像を読み込めるフォルダのみ自動再接続します。権限の再許可が必要な場合や内容が異なる場合は選択画面を表示します。端末とフォルダのどちらを使用するか、検証後に明示的に選びます。

保存失敗時は直ちに必須の再指定画面を表示し、外部保存と編集を止めます。変更内容は端末に保持します。フォルダ・JSON・参照画像の読み込み失敗、権限喪失、外部変更は、5秒間隔とアプリ復帰時の確認でも検出します。検出後は保存先の再作成・再選択、またはSafari対応モードへの変更が必要です。保存先の再作成には端末に保持している変更内容を使用します。

`cosplayers_diary_project/` は `CosplayDiary.project.json`（日記・マスター・カラコン・画像情報）と `images/`（画像本体）で構成します。画像を保存してからJSONを更新します。移動・保管はフォルダ全体で行ってください。旧JSONからの移行、画像操作、保存障害時の復旧は [`docs/project-folders.md`](docs/project-folders.md) を参照してください。

Safariでは任意の外部フォルダへ継続上書きできないため、ブラウザ内保存と画像同梱JSONの手動ダウンロードを使います。Google Drive連携は削除しました。ネイティブ版はSQLiteとアプリ専用画像フォルダへ保存し、画像同梱JSONでデータ交換します。

### 任意のGoogleカレンダー連携（Web/PWA）

設定から本人のGoogleアカウントへ接続すると、専用の「コスプレ日記」カレンダーで日記を双方向に同期します。新規作成時は非表示で、Googleカレンダーの一覧やアプリ設定で表示を切り替えられます。作品・キャラクター・衣装・メモを読みやすい予定として保存し、Geminiで参照するための質問例も用意しています。写真やカラコン在庫は同期しません。

接続中はその日最初の日記変更を自動同期し、以降は手動です（自動同期は無効化可能）。接続時の初回同期・失敗を含め、端末・ブラウザごとに合計10回/日です。再読み込みやアカウント切替でも回数を保持します。連携しない場合や上限到達時もローカル保存を続けられます。起動し直した場合は再接続が必要で、バックグラウンド同期はありません。

利用前に運営者のOAuth設定が必要です。GitHub ActionsのRepository **variable** `GOOGLE_CALENDAR_CLIENT_ID` またはビルド時の `--dart-define=GOOGLE_CALENDAR_CLIENT_ID=...` で公開クライアントIDを指定します。設定手順、同期対象、競合時の操作、Geminiの条件、料金・割当の注意は [`docs/google-calendar.md`](docs/google-calendar.md) を参照してください。実GoogleアカウントとGeminiでの接続確認は設定後に行います。

## CSV

文字コードはUTF-8（BOMあり入力も可）、日付は `YYYY-MM-DD`、真偽値は `true` / `false`、関連はUUID/安定IDです。カンマ、引用符、改行を含む値はRFC 4180形式で引用します。空欄可能な参照列は空文字にします。

| ファイル | 列（順番） |
|---|---|
| `genres.csv` | `id,name,memo,archived` |
| `events.csv` | `id,name,memo,archived` |
| `characters.csv` | `id,genre_id,name,memo,default_lens_product_id,archived` |
| `costumes.csv` | `id,name,is_general,character_id,memo,archived` |
| `character_lenses.csv` | `character_id,lens_product_id,is_default` |
| `contact_lenses.csv` | `id,name,manufacturer,color,wear_type,open_period_days,memo,archived` |
| `lens_purchases.csv` | `id,lens_product_id,purchased_on,unopened_expires_on,quantity` |
| `lens_inventory.csv` | `id,purchase_id,opened_on,disposed` |
| `lens_usage.csv` | `id,diary_id,inventory_id,used_on` |
| `diary.csv` | `id,activity_date,activity_type,genre_id,character_id,costume_id,event_id,memo,photo_id,lens_inventory_id` |
| `diary_looks.csv` | `diary_id,position,genre_id,character_id,costume_id` |
| `photos.csv` | `id,relative_path,original_name,width,height,created_at` |

`wear_type` は `oneDay` / `twoWeeks` / `monthly` / `other`、`activity_type` は `cosplay` / `photographer` / `other` です。サンプルは [`samples/csv`](samples/csv) にあります。取り込み前に必須値、重複ID、参照ID、日付、整数を検証し、追加・上書き・全置換の差分件数を計算できます。

## カレンダー表示と日記からのマスター追加

カレンダーは初期状態で月曜日始まりです。設定の「カレンダー表示 → 週の始まり」で月曜日始まり・日曜日始まりを切り替えられ、端末・ブラウザごとに保存します。日付セルは横幅に応じて縦に広がらないコンパクトな高さにし、画面が低い場合は全体をスクロールできます。土曜日は青、日曜日は赤で表示します。

カレンダー上部の年・月のプルダウンから目的の月へ直接移動できます。前後の月へ移動する矢印も引き続き利用できます。活動のある日付セルには予定名とキャラクター名を短く表示し、日付を選ぶと日記一覧にイベント名・全キャラクター・タグ付きの衣装名を表示します。日記画面でも同じ内容を確認できます。

参照していたマスターを完全削除した日記は、カレンダーの日付を警告色と「⚠」で示し、一覧や編集画面には該当項目を「取得できませんでした」と表示します。誤って作成した日記は一覧メニューまたは編集画面の「この日記を削除」から、確認後に削除できます。

日記の追加・編集画面では「キャラ・衣装を追加」から同じ日記に組を増やせます。各組でジャンル・キャラクター・衣装を選び、不要な組は削除できます。各欄の「＋」からその場で新規登録でき、キャラクターは選択中のジャンル、衣装は選択中のキャラクターに紐付きます。衣装は「汎用衣装」も選べます。ジャンル変更時はその組のキャラクター・衣装、キャラクター変更時はその組の衣装を解除し、他の組やメモは保持します。

管理画面では各マスターの名前を編集できます。キャラクターを追加するときはジャンルを選び、衣装を追加・編集するときは対象ジャンルを複数選択できます。ジャンル未選択なら全ジャンルで使えます。「汎用衣装」または「固有衣装」を指定し、固有衣装には対象キャラクターを複数選べます。例えばウマ娘の「勝負服」1件に該当するキャラクターを個別に選び、「制服」はそのジャンルの汎用衣装として登録できます。衣装ごとのタグで「メイド服（ロング丈）」など同名の衣装も区別できます。

「参加イベント」も管理画面または日記の追加・編集画面から登録できます。日記で「アコスタ池袋」などのマスターを選ぶと、開催日が違っても同じイベントとして集計します。同じイベント・同じ活動日の複数日記は1回として数え、管理画面では全期間、ダッシュボードでは選択した年または全期間の参加回数を表示します。個別の予定名は引き続き自由入力できます。既存の日記を集計に含めるには、その日記を編集して参加イベントを選択してください。

「追加して選択」で確定した項目は、日記を保存せず戻った場合もマスターに残ります。初回画面は保存方法の選択に絞り、JSONの控えの読み込みは設定画面から行います。

## JSONファイルの控え・読み込み

設定の「JSONファイルの控えを保存」で、圧縮しない `CosplayDiary_YYYYMMDD.project.json` を保存します。「プロジェクトJSONを読み込む」で形式を検証し、確認後に現在の内容を置き換えます。控えには画像もBase64で同梱します。フォルダ内の自動保存JSONは画像の相対パスだけを持つため、変更のたびに画像をJSONへ詰め直しません。ブラウザではダウンロード開始までを通知し、実際の保存結果は保存先で確認してください。フォルダ保存モードでは、読み込んだ内容と画像が現在の自動保存先にも反映されます。

新しいZIPは作成しません。以前のZIPは移行用に読み込みだけ対応し、CRC・形式バージョン・パス・サイズ・画像件数を検査後、`data/app_state.json` を使用します。JSONの構造と全レコードの型を一時ストアで検証するため、検証失敗時に既存状態を部分変更しません。新しい控えは画像本体も保存します。旧JSONだけから画像本体を復元することはできません。

## テスト

```sh
flutter test
flutter analyze
```

ビジネスロジックUT、SQLiteインメモリ結合テスト、スマホ/タブレットWidgetテスト、主要シナリオA〜Eの統合テストを含みます。各フェーズはテストを先に失敗させてから実装しています。

## 現在の既知制約

- Windowsのこの検証環境にはAndroid SDK/エミュレーターとXcodeがないため、実機E2Eは未実行です。統合シナリオはFlutterテスト上で実行しています。
- 日記の画像は1件につき1枚です。追加・プレビュー・差し替え・取り外しに対応していますが、拡大専用ビューは未実装です。
- CSVの解析・検証・差分計画は完成していますが、単独CSVの一括インポート画面は未完です。データ移行にはJSONを使います。
- 日記フォームからカラコン実物を選ぶUIの最終配線は未完です。製品/購入管理と使用台帳の整合性ロジックは実装・テスト済みです。
- ネイティブ版では正規化SQLiteテーブルとマイグレーションを作成しますが、現バージョンの通常保存はトランザクション更新しやすいJSONスナップショットを `settings` に保持します。
- PWAのデータはブラウザと公開オリジン（スキーム・ホスト・ポート）の組み合わせごとに分離されます。公開URLを変更した場合は自動移行されないため、変更前にJSONファイルの控えを保存してください。
