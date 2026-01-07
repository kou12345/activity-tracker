# Activity Tracker

macOS メニューバー常駐型のアクティビティ追跡アプリ。

## 機能

- アプリ使用時間の記録
- キーストローク・クリック数の追跡
- 集中セッションの分析
- 日別・週別・月別レポート

## 必要環境

- macOS 13.0 以上
- Swift 5.9 以上

## ビルド・インストール

```bash
# ビルドしてインストール
make install

# ビルド、インストール、起動を一括実行
make run
```

## Makefile コマンド

| コマンド | 説明 |
|----------|------|
| `make build` | .app バンドルをビルド |
| `make install` | ビルドして /Applications にインストール |
| `make run` | インストールして起動 |
| `make clean` | ビルド成果物を削除 |

## 開発

```bash
# デバッグビルド＆実行
swift run

# テスト
swift test
```

## ファイル構成

```
ActivityTracker/
├── Sources/ActivityTracker/
│   ├── ActivityTrackerApp.swift  # エントリーポイント
│   ├── Managers/                 # サービス層
│   ├── Models/                   # データモデル
│   └── Views/                    # SwiftUI ビュー
├── Resources/
│   └── Info.plist               # アプリ設定
├── build-app.sh                 # ビルドスクリプト
├── Makefile
└── Package.swift
```

## 権限

初回起動時、以下の権限が必要です：

- **アクセシビリティ** - キーストローク・クリック監視用
  - システム設定 → プライバシーとセキュリティ → アクセシビリティ
