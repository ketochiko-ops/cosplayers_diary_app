# ドメインモデルと不変条件

## 関連図

```text
Genre 1 ── * CosplayCharacter 1 ── * Costume (専用)
                                  └── * Costume (汎用はcharacterIdなし)

CosplayCharacter * ── * LensProduct
        （モデル上にlensProductIds/defaultLensProductIdがあるがUI未接続）

LensProduct 1 ── * LensPurchase 1 ── * LensInventory 1 ── * LensUsage
                                                          │
DiaryEntry 1 ─────────────────────────────────────────────┘

DiaryEntry ── Genre / CosplayCharacter / Costume / PhotoRecord / LensInventory
              （すべてID参照。未接続の参照を含む）
```

モデルは原則イミュータブルですが、各ストアと `LensLedger` が持つList自体は変更可能です。

## マスターデータ

ファイル: `features/master_data/domain/`

- `Genre`: `id`, `name`, `memo`, `archived`
- `CosplayCharacter`: 必須 `genreId`、任意のカラコン候補と既定値、`archived`
- `Costume`: `genreIds`（空なら全ジャンル）、`tags`、汎用か固有か、固有なら対象 `characterIds` を1件以上保持。旧 `genreId` と `characterId` は読み込み互換用

不変条件:

- 関連には名前ではなく安定IDを使う。
- 通常の削除操作は `archived = true` の論理削除。アーカイブ済み項目だけを確認後に完全削除できる。参照元IDは維持し、欠損をUIで「取得できませんでした」と表示する。
- 新規選択肢にはアーカイブ済みデータを出さない。
- 衣装候補は `genreIds` が空か選択キャラクターのジャンルを含み、かつ汎用衣装またはそのキャラクターIDを持つ固有衣装に限る。固有衣装の対象キャラクターは、ジャンルを指定した場合はそのいずれかに所属する。

管理画面では各マスターの名前をIDを維持して編集できます。キャラクターの新規登録時はジャンルを選び、衣装の新規登録・編集時はジャンルを複数選択または未選択（全ジャンル）にし、タグと汎用/固有を指定します。固有衣装は対象キャラクターを複数選択します。旧JSONの単一 `genreId` は `genreIds` に、単一 `characterId` は `characterIds` に移行し、所属ジャンルが欠ける固有衣装はキャラクターから補います。既存の日記は参照IDを維持し、衣装の対象を後から変更しても履歴の参照を残します。

## 日記

ファイル: `features/diary/domain/`

`ActivityType` は `cosplay`、`photographer`、`other` の3種です。`DiaryEntry` は活動日、種別、任意参照、メモ、任意の予定名 `calendarTitle`、作成/更新日時を持ちます。`calendarTitle` はJSONに保存し、古いJSONでは空文字です。空なら連携時に種別・作品・キャラクター・衣装から予定名を生成します。既存CSV列は変更せず、予定名の移行にはJSONを使います。

不変条件:

- `cosplay` の保存には `genreId`、`characterId`、`costumeId` がすべて必要。
- その他の種別ではそれらは不要。フォームで種別を変更すると参照をクリアする。
- 同じ日付に複数件を保存できる。
- 一覧は活動日時の降順。特定日の抽出結果は昇順。
- 複製時はカラコン実物参照をクリアし、写真参照など他の値は引き継ぐ。

注意: `DiaryStore.delete()` 単体は日記だけを削除します。画面からの日記削除はAppShellのコールバックと `deleteDiary()` を経由し、カラコン使用を解除してから日記を削除します。削除前に確認ダイアログを表示します。

## カラコン

ファイル: `features/contact_lenses/domain/`

- `LensProduct`: 製品情報、装用種別、開封後日数、アーカイブ状態
- `LensPurchase`: 購入単位、購入日、未開封期限、数量
- `LensInventory`: 1組単位の実物、開封日、廃棄状態
- `LensUsage`: 1つの日記と1つの実物を結ぶ使用履歴

`WearType` は `oneDay`、`twoWeeks`、`monthly`、`other` です。

不変条件:

- 購入数量は0以上。
- 未使用在庫 = `purchase.quantity - その購入から生成したLensInventory数`。0未満にはしない。
- ワンデーは開封操作ではなく使用時に実物を生成し、即時 `disposed = true` とする。
- ワンデー実物は別の日記で再使用できない。
- 同じ日記に使用履歴は最大1件。付け替え時は旧履歴を除く。
- ワンデー使用を日記から解除すると、履歴と自動生成した実物を削除し在庫を戻す。
- 再利用型の解除は使用履歴だけを削除し、実物は残す。
- 開封後期限日は開封日を0日目として `openPeriodDays` 日を加えた日。期限日当日は有効で、翌日から期限切れ。
- メーカー表示を優先し、期限計算は管理上の目安としてUIに表示する。

## 写真

ファイル: `features/photos/domain/photo_service.dart`

`PhotoRecord` はID、相対パス、元ファイル名を持ち、JSONの `photos` に永続化します。日記フォームの画像ピッカー・プレビューと接続しています。保存モードは `original` と `spaceSaving` です。

不変条件:

- 保存先は `images/<生成ID>.<安全な拡張子>`。
- 許可拡張子は `jpg`, `jpeg`, `png`, `webp`, `heic`。それ以外または拡張子なしは `jpg`。
- 容量節約は長辺2,048px。小さい画像は元bytesを返す。
- 差し替えは新規保存を先に行う。
- 旧ファイルが他から参照されている場合は削除しない。
- 旧ファイル削除失敗より新しい参照の安全を優先する。

`PhotoRecord` にはCSV定義上の `width`, `height`, `created_at` がまだありません。

## 統計

ファイル: `features/dashboard/domain/statistics_service.dart`

- 年がnullなら全期間、指定時はその年だけの日記を対象にする。
- 回数とユニーク活動日数を別々に数える。
- 同日活動は、コスプレとカメラマンの両方が存在する日数。
- 月別は1〜12月を常に返す。
- ジャンル/キャラクター/衣装ランキングは件数降順、同数ならID昇順、上位5件。
- カラコン利用製品ID、未使用在庫、期限間近件数は呼び出し側から渡す。

現行ダッシュボードはキャラクターランキングのIDをマスターデータの名前へ解決して表示します。参照先が存在しない場合は「取得できませんでした」と表示します。`expiringLensCount` はまだ算出していません。

## CSV

ファイル: `features/backup/domain/csv_service.dart`

- UTF-8 BOMを受理する。
- カンマ、引用符、CR/LFを含むセルはRFC 4180相当の引用を行う。
- 必須列、行内ID重複、ISO日付、整数、参照先IDを検証できる。
- `append` は既存IDをskip、`overwrite` は更新、`replaceAll` は入力にない既存IDを削除する差分件数を計算する。

`CsvService` は汎用部品です。ファイル別スキーマの組み立てと、プレビュー後にストアへ反映するインポート処理はまだありません。

## バックアップと設定

- フォルダの自動保存は状態JSON＋`images/`。手動の控えは画像もBase64で同梱した非圧縮JSON。旧ZIP形式version 1は移行読み込みのみ。
- 旧ZIPのmanifestは作成時刻、CSV別データ行数、画像件数を持つ。
- 展開後合計サイズ上限の既定値は1GiB。
- 最終バックアップがない、または30日以上経過するとリマインドする。
- 最終バックアップ日時が未来ならリマインドしない。

設定キー:

| key | 値 |
|---|---|
| `app_state_v1` | 3ストア全体のJSON |
| `last_backup_at` | 控えの保存操作のISO 8601日時（Webはダウンロード開始時点） |
| `photo_save_mode` | `original` または `spaceSaving` |
| `project_target_v1` | PWA保存モード `localFolder` または `browser`。未設定/旧Drive/旧 `localFile` は初回再指定。フォルダは権限・JSON一致・参照画像の存在を確認して自動再接続 |
| `google_calendar_sync_v1` | 自動同期設定、カレンダー別同期履歴、端末共通の日次試行回数・自動実行済み印、未同期表示、最終同期。トークンは含まず、プロジェクトJSONの対象外 |

## Googleカレンダー同期

- 任意のWeb/PWA機能。専用副カレンダーだけを読み書きする。
- 日記と参照マスターのID・名称・所属を同期する。マスターメモ、写真、カラコンは送らない。既存の同一IDマスターは上書きせず、不足分を追加する。
- 予定のタイトル・活動日・メモはGoogle側の編集も取り込む。専用カレンダーの外部作成予定は「その他」の日記。繰り返し予定は非対応として停止する。
- 履歴がある日記だけ削除を伝播する。両側更新や更新と削除の競合は手動選択し、ETag不一致時は停止する。
- Googleからの日記削除はカラコン使用を解除し、ワンデー在庫を復元する。使用履歴がある日記の日付変更は停止する。
- 同期試行は接続時・自動・手動・失敗を合算して端末/ブラウザごと10回/日。認証・カレンダー発見/作成・表示切替の通信は別で、APIリクエスト数の上限とは異なる。

プロジェクトJSONは `projectFormat: 2`。旧JSONは形式識別子と `photos` がなくても読めます。画像同梱の控えは追加の `embeddedImages`（相対パス→Base64）を持ち、自動保存時は含めません。画像の保存パスは `images/<英数字・ハイフン・アンダースコア>.<許可拡張子>` に限定し、重複ID/パスを拒否します。
