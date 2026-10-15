# GitHub Pagesでの検証とVercel本番公開

## ブランチと配信先

| ブランチ | push後の処理 | URL |
|---|---|---|
| `pre-develop` | 解析・テスト・PWAビルド後、GitHub Pagesに検証版を公開 | https://ketochiko-ops.github.io/cosplayers_diary_app/ |
| `develop` | 解析・テスト・PWAビルド・ステージ検証後、Vercel本番に公開 | https://cosplayers-diary-app.vercel.app |

日常の修正は `pre-develop` にpushしてPagesで確認し、確認できた変更を `develop` にマージして本番公開します。Pagesは同じURLの検証版を更新します。PRごとの別URLではありません。検証版も公開サイトです。

`deploy-pages.yml` は `pre-develop`、`deploy-pwa.yml` は `develop` だけで実行します。手動実行でも異なるブランチではjobをskipします。VercelのGit自動デプロイは `vercel.json` で無効にしているため、`pre-develop` のpushでVercelのデプロイは作りません。

## GitHubの初回設定

1. リポジトリのSettings → Pages → Build and deployment → Sourceを **GitHub Actions** にします。ブランチからDartソースをそのまま配信する設定は使用しません。
2. Settings → Environments → `github-pages` のDeployment branches and tagsを **Selected branches and tags** にし、`pre-develop` ブランチを許可します。本番の `production` 環境と区別します。
3. `pre-develop` へpushします。Actionsの **Deploy pre-develop PWA to GitHub Pages** が成功すると、上記検証URLを開けます。

手動再実行は同ワークフローの既存runから **Re-run jobs** を使えます。Actionsの **Run workflow** を使う場合は、ワークフロー定義がデフォルトブランチにも存在する必要があります。追加直後に `pre-develop` のみに定義がある場合でもpushによる実行は動作します。

CLIで作業する場合の流れ:

```sh
git switch pre-develop
# 編集、検証、コミット
git push -u origin pre-develop
# Pagesで確認した後、通常のPRで pre-develop → develop をマージ
```

## PWA・保存データ

`actions/configure-pages` の `base_path` から `--base-href /cosplayers_diary_app/` 相当を指定してビルドします。独自Service Worker、CanvasKit、manifest、アイコンを同じ公開パスから取得します。`tool/verify_pwa.mjs` は公開パスと31件のプリキャッシュを確認します。

本番とPagesはオリジンが異なり、ブラウザ保存のデータとファイル権限は引き継ぎません。Pagesは初回に保存方法の選択が必要です。同じGitHubアカウントの他のPagesサイトとも、公開パス単位でlocalStorageキー、IndexedDBのファイルhandle、Service Workerキャッシュを分離します。ルート配信の本番は従来の保存キーとDB名を維持します。

検証にはプロジェクトJSONのコピーとGoogleのテスト用アカウントを使用してください。利用者が同じ外部JSONファイルや同じGoogleカレンダーを明示的に選べば、その外部データは本番と共有されます。Pagesへプロジェクトの内容や認証トークンはアップロードしません。

## Googleカレンダーの検証

Google Cloud側で、承認済みJavaScript生成元へ `https://ketochiko-ops.github.io` を追加します。生成元に `/cosplayers_diary_app/` は付けません。テスト公開中のOAuthはテストユーザーも登録します。

検証専用の公開クライアントIDを使う場合はRepository variable `GOOGLE_CALENDAR_PREVIEW_CLIENT_ID` を登録します。未設定時は既存の `GOOGLE_CALENDAR_CLIENT_ID` を使います。両方とも未設定なら連携ボタンは無効で、通常のオフライン利用と保存方法を確認できます。秘密鍵やクライアントシークレットは不要です。詳しくは [`google-calendar.md`](google-calendar.md) を参照してください。

## リソースと利用枠

2026-10-15確認。このリポジトリは公開設定で、使用する `ubuntu-latest` は標準のGitHubホストランナーです。

- **実行時間:** 公開リポジトリの標準ランナーは無料です。非公開リポジトリの月間無料時間は所有アカウント単位です。公開設定を変えた場合は利用条件も再確認します。
- **Pages配信:** 公開サイト1GB以下、転送量は月100GBのソフト上限です。公式説明はPagesサイトの上限で、他の全リポジトリと共有するActionsの月間無料時間とは別です。超過時は配信制限などの可能性があります。
- **ビルド頻度:** 通常のPagesの10ビルド/時というソフト上限は、今回使うカスタムActionsワークフローには適用されません。APIや同時実行など他の上限は残ります。
- **成果物保存:** ActionsのartifactとGitHub Packagesは所有アカウントの保存枠を共有します（GitHub Freeは500MB）。今回の配信用artifactは公開成功後に削除し、失敗・キャンセル・削除失敗時も1日で期限切れにします。公開済みサイトはartifact削除後も配信されます。
- **キャッシュ:** 無料のキャッシュ保存枠は1リポジトリ10GBで、artifactの共有枠とは別です。Flutter SDKキャッシュを再利用します。枠の増額は設定しません。
- **連続push:** 新しいrunが始まったら古いPagesワークフローをキャンセルし、未完了の検証版を何度も公開しません。ビルド20分・公開10分のtimeoutも設けます。
- **Vercel:** 検証中のアクセスとデプロイはPagesへ移ります。Vercel本番のアクセスや、`develop` へのマージ後のデプロイによる利用量は残ります。

現在の利用量はGitHubのSettings → Billing and licensing → Usage、キャッシュはリポジトリのActions → Cachesで確認します。今回の変更は課金枠の増額や有料ランナーの追加を行いません。

公式資料:

- [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Using custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
