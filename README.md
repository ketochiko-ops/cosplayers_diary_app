# コスプレ日記

iOS・iPadOS・Android・PWA向けの、完全オフライン型コスプレ活動管理アプリです。カレンダー、日記、ジャンル・キャラクター・衣装、カラコン購入/実物/使用履歴、写真、統計、CSV、ZIPバックアップを一つのFlutterプロジェクトで扱います。通常利用にネット接続やアカウントは不要です。

## 主な機能

- 月カレンダー、同日複数活動、コスプレ/カメラマン/その他の日記
- ジャンル→キャラクター→専用/汎用衣装の連動候補、論理削除
- カラコン製品、購入別在庫、1組単位の開封/使用履歴、ワンデー再使用防止
- 年/全期間の活動回数・活動日数・同日重複・月別・上位ランキング
- オリジナルまたは長辺2,048pxの写真保存サービス
- UTF-8/BOM対応CSVと、検証付きZIPバックアップ/復元
- 最終バックアップから30日経過した場合の端末内リマインド
- 600px未満は下部ナビゲーション、600px以上はNavigationRail
- iPhone/iPadのホーム画面追加と、インストール後のオフライン起動に対応するPWA

## 技術と構成

- Flutter 3.47 / Dart 3.13
- ネイティブ版はSQLite (`sqflite`)、PWA版はブラウザのlocalStorageへ同じJSON状態を永続化
- `image_picker` / `image` / `path_provider`
- `archive` によるZIP、独立したCSVパーサー/検証器
- UI (`presentation`)、状態/ユースケース (`application`)、業務規則 (`domain`)、I/O (`infrastructure`) を分離
- 現在日時は `Clock`、ファイルは `FileStore` で抽象化

主要ディレクトリ:

```text
lib/
├── app/                 # テーマ、レスポンシブシェル
├── core/                # プラットフォーム別状態保存、SQLite、時計、ファイル境界
└── features/
    ├── diary/           # 日記・カレンダー
    ├── master_data/     # ジャンル・キャラクター・衣装
    ├── contact_lenses/  # 製品・購入・実物・使用台帳
    ├── photos/          # 安全な画像保存・縮小
    ├── backup/          # CSV・ZIP
    ├── dashboard/       # 統計
    └── settings/        # 設定・バックアップ案内
test/
├── unit/
├── widget/
└── integration/
```

名称変更で過去データが壊れないよう、関連は名称でなくIDで保持します。マスター削除はアーカイブです。ネイティブ版はSQLiteの `settings`、PWA版はブラウザのlocalStorageに、互換性のあるJSONスナップショットを保持して起動時に復元します。ネイティブ版の正規化テーブルは将来の段階的移行とSQL検索のため同時に作成されます。

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

```sh
flutter run -d chrome
flutter build web --release --pwa-strategy=none
```

生成物は `build/web` です。PWA機能とブラウザ保存を正しく動かすため、公開時はHTTPSで配信してください（`localhost` での開発は例外です）。サブディレクトリへ公開する場合は、次のように末尾の `/` を含むベースパスを指定します。

```sh
flutter build web --release --pwa-strategy=none --base-href /cosplayers_diary_app/
```

Web版のアプリ状態は同じ `app_state_v1` JSONをブラウザのローカルストレージへ保存します。ネイティブ版のSQLiteをWebから直接開くことはできないため、端末間の移行には設定画面のZIPバックアップ作成・復元を使用してください。Safariの「履歴とWebサイトデータを消去」などでブラウザ保存が削除されるため、定期バックアップを推奨します。

GitHub Pagesへの公開ワークフローは [`.github/workflows/deploy-pwa.yml`](.github/workflows/deploy-pwa.yml) にあります。GitHubのリポジトリ設定で Pages のSourceを「GitHub Actions」に変更すると、`develop` へのpushまたは手動実行で、リポジトリ名を含むベースパスへ自動ビルド・公開します。

iPhoneではSafariで公開URLを開き、共有メニューから「ホーム画面に追加」を選択します。初回表示と更新取得にはネット接続が必要ですが、その後はキャッシュ済みのアプリをオフラインで起動できます。

## CSV

文字コードはUTF-8（BOMあり入力も可）、日付は `YYYY-MM-DD`、真偽値は `true` / `false`、関連はUUID/安定IDです。カンマ、引用符、改行を含む値はRFC 4180形式で引用します。空欄可能な参照列は空文字にします。

| ファイル | 列（順番） |
|---|---|
| `genres.csv` | `id,name,memo,archived` |
| `characters.csv` | `id,genre_id,name,memo,default_lens_product_id,archived` |
| `costumes.csv` | `id,name,is_general,character_id,memo,archived` |
| `character_lenses.csv` | `character_id,lens_product_id,is_default` |
| `contact_lenses.csv` | `id,name,manufacturer,color,wear_type,open_period_days,memo,archived` |
| `lens_purchases.csv` | `id,lens_product_id,purchased_on,unopened_expires_on,quantity` |
| `lens_inventory.csv` | `id,purchase_id,opened_on,disposed` |
| `lens_usage.csv` | `id,diary_id,inventory_id,used_on` |
| `diary.csv` | `id,activity_date,activity_type,genre_id,character_id,costume_id,memo,photo_id,lens_inventory_id` |
| `photos.csv` | `id,relative_path,original_name,width,height,created_at` |

`wear_type` は `oneDay` / `twoWeeks` / `monthly` / `other`、`activity_type` は `cosplay` / `photographer` / `other` です。サンプルは [`samples/csv`](samples/csv) にあります。取り込み前に必須値、重複ID、参照ID、日付、整数を検証し、追加・上書き・全置換の差分件数を計算できます。

## ZIPバックアップ

設定画面の「ZIPバックアップを作成」から保存先を選びます。復元は「ZIPから復元」でファイルと置換確認を行います。

```text
CosplayDiary_Backup_YYYYMMDD.zip
├── manifest.json
└── data/
    ├── app_state.json
    ├── genres.csv
    ├── characters.csv
    ├── costumes.csv
    ├── character_lenses.csv
    ├── contact_lenses.csv
    ├── lens_purchases.csv
    ├── lens_inventory.csv
    ├── lens_usage.csv
    ├── diary.csv
    └── photos.csv
```

写真登録済みの場合は `images/<photo-uuid>.<ext>` を追加する設計です。復元前にCRC、形式バージョン、相対パス（ZIP Slip）、展開後サイズ、画像件数を検査します。検証失敗時は現在の保存状態を変更しません。

## テスト

```sh
flutter test
flutter analyze
```

ビジネスロジックUT、SQLiteインメモリ結合テスト、スマホ/タブレットWidgetテスト、主要シナリオA〜Eの統合テストを含みます。各フェーズはテストを先に失敗させてから実装しています。

## 現在の既知制約

- Windowsのこの検証環境にはAndroid SDK/エミュレーターとXcodeがないため、実機E2Eは未実行です。統合シナリオはFlutterテスト上で実行しています。
- 写真保存・縮小・差し替えのサービス層は完成していますが、日記フォームの写真ピッカー/拡大ビューへの最終配線は未完です。
- CSVの解析・検証・差分計画とZIP内CSV出力は完成していますが、単独CSVを選ぶ一括インポート画面は未完です。ZIP復元は利用できます。
- 日記フォームからカラコン実物を選ぶUIの最終配線は未完です。製品/購入管理と使用台帳の整合性ロジックは実装・テスト済みです。
- ネイティブ版では正規化SQLiteテーブルとマイグレーションを作成しますが、現バージョンの通常保存はトランザクション更新しやすいJSONスナップショットを `settings` に保持します。
- PWAのデータはブラウザと公開オリジン（スキーム・ホスト・ポート）の組み合わせごとに分離されます。公開URLを変更した場合は自動移行されないため、変更前にZIPバックアップを作成してください。
