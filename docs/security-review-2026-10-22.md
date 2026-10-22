# 2026-10-22 Node.jsと依存関係の点検

## 結論と対応

Node.js公式の[2026-10-21セキュリティリリース](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases)は22/24/26系に影響し、Brotliデコーダの範囲外書き込みなど高リスクの問題を修正しています。24系の修正版は[24.22.1](https://github.com/nodejs/node/releases/tag/v24.22.1)です。

公開中のPWAはFlutter Webの静的ファイルです。Vercelの本番デプロイは `.vercel/output/static` と静的ルーティング設定で構成され、Node.jsのFunctionsは含みません。Node.jsはGitHub Actionsの検証・ビルド・Vercel CLIに使用します。両ワークフローで `actions/setup-node` をコミットSHAで固定し、`.node-version` の24.22.1を使用します。Vercel CLIはCI限定で65.0.0へ更新しました。GitHub提供のアクション自体が使うNode.jsはGitHubランナー側で管理され、`setup-node` では変更できません。

## 追加点検

- `pubspec.lock` のPub公開パッケージ101件をOSV APIのパッケージ名・固定バージョンで照合し、該当アドバイザリは0件でした。これは未公開の脆弱性がないことを保証しません。
- リポジトリに `package.json` / npm lockfileはなく、公開アプリにnpm依存パッケージを同梱しません。`web/` のJavaScriptには `eval`、`innerHTML`、`document.write` の使用がありません。
- `vercel@60.1.3` の一時インストールを `npm audit` で調べると35件、`vercel@65.0.0` では33件（critical 1、高24、中8）の推移的依存警告がありました。最新版でも全件は解消していません。CLIは信頼済みのビルド成果物をCIでデプロイする際だけ実行し、公開成果物には含めません。上流が修正版を公開したら再監査して更新します。
- GitHubのDependabot alerts APIはリポジトリで無効化されており403でした。必要ならリポジトリ設定で有効化します。

## 検証

公式配布のNode.js 24.22.1をSHA256照合して取得し、Calendar・プロジェクト保存・Service Worker・Vercel静的成果物のJavaScriptテスト31件を実行しました。Flutterの静的解析とテスト145件、両ワークフローのactionlint検査も通過しました。Vercel CLI 65.0.0で `deploy --prebuilt`、`--prod`、`--skip-domain` のオプションと `curl` コマンドの存在を確認しました。実際の本番デプロイは `develop` のワークフローでのみ行います。
