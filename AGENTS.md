# Codex 作業ガイド

このファイルは、このリポジトリで作業するエージェントの入口です。詳細な調査結果は [`docs/adl/README.md`](docs/adl/README.md) から必要な章だけ参照してください。

## 最初に読むもの

1. [`docs/adl/README.md`](docs/adl/README.md): 現状、実装済み範囲、文書索引
2. [`docs/adl/architecture.md`](docs/adl/architecture.md): 構成、起動、状態保存、バックアップ
3. 変更対象に応じて [`docs/adl/domain-model.md`](docs/adl/domain-model.md) または [`docs/adl/work-guide.md`](docs/adl/work-guide.md)

`README.md` は利用者向け機能説明、`DEVELOPMENT_REPORT.md` はフェーズ別の開発履歴です。実装と文書が食い違う場合は、テストを含む現在のコードを優先し、ADLも同じ変更で更新してください。

## リポジトリの要点

- Flutter/Dart製の完全オフライン型モバイルアプリです。対象はiOS、iPadOS、Androidです。
- 状態管理は外部パッケージではなく、`ChangeNotifier` ベースの3ストアを `AppShell` が所有します。
- 現行の永続化の正本は、SQLite `settings` テーブルの `app_state_v1` JSONです。正規化テーブルは作成されますが、通常の読み書きにはまだ使われません。
- `domain` はFlutter UIやI/Oから独立させます。副作用は `application`、`infrastructure`、`presentation` の適切な境界に置きます。
- エンティティ間の関連は表示名ではなくIDで維持します。履歴を壊す物理削除よりアーカイブを優先します。
- カラコンの在庫数は保存値ではなく、購入数量と生成済み実物の差から導出します。
- バックアップ復元は検証完了前に既存状態を変更してはいけません。

## 変更時の基本ルール

- 新しい業務規則は、可能なら `features/<feature>/domain` の純粋なDartコードに置き、先にユニットテストを追加します。
- ストアを変更したら `notifyListeners()` と `AppStatePersistence` のシリアライズ/復元の両方を確認します。
- 永続化モデルを変更したら、JSONの後方互換性、CSV列、ZIPバックアップ、SQLiteスキーマの影響を確認します。
- 日記とカラコン使用のような複数ストアをまたぐ操作は、片側だけ更新しないでください。必要ならapplication層にコーディネーターを置きます。
- `DateTime.now()` やファイルI/Oを業務規則へ直接増やさず、既存の `Clock` / `FileStore` 境界を利用または拡張します。
- UI文言は既存どおり日本語を基本とします。画面幅600px未満/以上の両方を考慮します。
- 依頼に無関係な既存変更は上書きしません。

## 検証

推奨順序:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

変更範囲が小さい場合は対象テストを先に実行し、最後に全体を実行します。SDK要件は `pubspec.yaml` の `environment` を正としてください。調査時点では Dart `^3.13.3`（Flutter 3.47系が目安）が必要です。

## 文書同期

次の変更ではADLも更新します。

- ディレクトリ/責務/依存方向: `architecture.md`
- モデル、関連、業務不変条件: `domain-model.md`
- コマンド、変更マップ、既知の未接続箇所: `work-guide.md`
- 実装状況または調査基準コミット: `docs/adl/README.md`
