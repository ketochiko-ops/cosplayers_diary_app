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
- `Costume`: 汎用かキャラクター専用。専用なら `characterId` 必須

不変条件:

- 関連には名前ではなく安定IDを使う。
- 削除は `archived = true` の論理削除。過去の日記から参照できるようデータを残す。
- 新規選択肢にはアーカイブ済みデータを出さない。
- 衣装候補は「汎用」または「選択キャラクター専用」に限る。

現行UIの追加ダイアログは名前しか受け取らず、キャラクターは最初の有効ジャンルに、衣装は汎用として登録します。ドメインが表現できる全項目を編集するUIではありません。

## 日記

ファイル: `features/diary/domain/`

`ActivityType` は `cosplay`、`photographer`、`other` の3種です。`DiaryEntry` は活動日、種別、任意参照、メモ、作成/更新日時を持ちます。

不変条件:

- `cosplay` の保存には `genreId`、`characterId`、`costumeId` がすべて必要。
- その他の種別ではそれらは不要。フォームで種別を変更すると参照をクリアする。
- 同じ日付に複数件を保存できる。
- 一覧は活動日時の降順。特定日の抽出結果は昇順。
- 複製時はカラコン実物参照をクリアし、写真参照など他の値は引き継ぐ。

注意: `DiaryStore.delete()` は日記だけを削除し、`LensLedger.removeDiaryUsage()` を呼びません。現行UIではカラコン使用が未接続なので表面化しませんが、接続時はapplication層で一貫して処理します。

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

`PhotoRecord` はID、相対パス、元ファイル名を持ちます。保存モードは `original` と `spaceSaving` です。

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

現行ダッシュボードはキャラクターランキングのIDをマスターデータの名前へ解決して表示します。参照先が存在しない破損データでは「不明なキャラクター」と表示します。`expiringLensCount` はまだ算出していません。

## CSV

ファイル: `features/backup/domain/csv_service.dart`

- UTF-8 BOMを受理する。
- カンマ、引用符、CR/LFを含むセルはRFC 4180相当の引用を行う。
- 必須列、行内ID重複、ISO日付、整数、参照先IDを検証できる。
- `append` は既存IDをskip、`overwrite` は更新、`replaceAll` は入力にない既存IDを削除する差分件数を計算する。

`CsvService` は汎用部品です。ファイル別スキーマの組み立てと、プレビュー後にストアへ反映するインポート処理はまだありません。

## バックアップと設定

- ZIP形式versionは1。
- manifestは作成時刻、CSV別データ行数、画像件数を持つ。
- 展開後合計サイズ上限の既定値は1GiB。
- 最終バックアップがない、または30日以上経過するとリマインドする。
- 最終バックアップ日時が未来ならリマインドしない。

設定キー:

| key | 値 |
|---|---|
| `app_state_v1` | 3ストア全体のJSON |
| `last_backup_at` | ISO 8601日時 |
| `photo_save_mode` | `original` または `spaceSaving` |
| `project_target_v1` | PWAで最後に選んだ `localFile` または `googleDrive`。起動後は再接続が必要 |
