# WattsApp

macOSのメニューバーに現在の消費電力や充電時の電力（W）をリアルタイム表示するユーティリティアプリです。

## 機能

- **電力消費の可視化**: Mac 本体の消費電力をメニューバーに表示。メニューでは、アダプタからの入力とバッテリーへの充電電力の内訳も確認可能
  - Apple Silicon Mac では、充電中・AC 接続中も本体の消費電力を表示します
  - 本体の消費電力を取得できない機種（主に Intel Mac）では、AC 接続中は `---W` と表示します
- **詳細情報の確認**: メニューからバッテリー残量、健康度、サイクル数、温度などを確認可能
- **表示のカスタマイズ**: アイコン＋テキスト、テキストのみ等、プレファレンスに合わせた表示設定
- **更新頻度の調整**: リアルタイム監視（1.5秒）から省電力モード（5秒）まで選択可能

## インストール（手動）

本アプリは、バッテリーの詳細情報を取得するため、`IOKit` から公式にはドキュメント化されていない `AppleSmartBattery` の値を読み取っています。そのため、Mac App Store ではなく GitHub Releases 経由での配布となります。

1. [Releases](https://github.com/P4Nburger/WattsApp/releases) ページから最新の `WattsApp.app.zip` をダウンロード・展開
2. `WattsApp.app` を「アプリケーション」フォルダに配置

## 動作環境

- macOS 13.0+
- Apple Silicon / Intel Mac

## アーキテクチャ

SwiftUI + MVVM アーキテクチャを採用しています。

- `PowerViewModel`: 電力・バッテリー状態の監視ロジック
- `BatteryInfoProvider`: IOKitを利用したハードウェア情報の取得
- `PowerPresentation`: アイコン・更新間隔・表示文字列を決める純粋関数（ユニットテスト対象）
- `AppSettings`: `@AppStorage` を用いた設定の永続化
- `LaunchAtLogin`: ログイン時自動起動の制御

## ライセンス

MIT License
