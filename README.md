# WattsApp

macOSのメニューバーに現在の電力消費（W）をリアルタイム表示するユーティリティアプリです。

## 機能

- **電力消費の可視化**: 充電・AC接続・バッテリー駆動の状態に応じたワット数を表示
- **詳細情報の確認**: メニューからバッテリー残量、健康度、サイクル数、温度などを確認可能
- **表示のカスタマイズ**: アイコン＋テキスト、テキストのみ等、プレファレンスに合わせた表示設定
- **更新頻度の調整**: リアルタイム監視（1.5秒）から省電力モード（5秒）まで選択可能

## インストール（手動）

本アプリは、バッテリーの詳細情報を取得するため `IOKit` のプライベートAPIを使用しています。そのため、Mac App Store ではなく GitHub Releases 経由での配布となります。

1. [Releases](https://github.com/P4Nburger/wattsapp/releases) ページから最新の `WattsApp.app.zip` をダウンロード・展開
2. `WattsApp.app` を「アプリケーション」フォルダに配置
3. **初回起動時のみ**: アプリアイコンを右クリック（Control+クリック）し、「開く」を選択（macOSのセキュリティ警告をバイパスするため）

## 動作環境

- macOS 13.0+
- Apple Silicon / Intel Mac

## アーキテクチャ

SwiftUI + MVVM アーキテクチャを採用しています。

- `PowerViewModel`: 電力・バッテリー状態の監視ロジック
- `BatteryInfoProvider`: IOKitを利用したハードウェア情報の取得
- `AppSettings`: `@AppStorage` を用いた設定の永続化
- `LaunchAtLogin`: ログイン時自動起動の制御

## ライセンス

MIT License
