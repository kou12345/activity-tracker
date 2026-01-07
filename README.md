# Activity Tracker

macOS用のアクティビティ追跡アプリケーション。アプリの使用時間、入力アクティビティ、集中度を記録・分析します。

## 機能

### 追跡データ
- **アプリ使用ログ**: アプリ名、開始/終了時刻、アクティブ時間
- **入力アクティビティ**: キーストローク数、マウスクリック数、スクロール量
- **集中度メトリクス**: アプリ切り替え回数、連続作業時間、アイドル時間

### UI
- **メニューバー**: 今日の作業時間、上位アプリをリアルタイム表示
- **詳細ウィンドウ**:
  - ダッシュボード: 今日のサマリー、時間帯別グラフ
  - アプリ別: アプリごとの使用時間一覧・推移
  - 集中度: 集中セッション、切り替え頻度
  - レポート: 日次/週次/月次レポート
  - 履歴: カレンダーから過去のデータ閲覧

### 設定
- ログイン時に自動起動
- アイドル判定時間の調整
- 除外アプリの設定
- データのエクスポート（CSV/JSON）

## 必要条件

- macOS 13.0以上
- Xcode 15.0以上
- Swift 5.9以上

## ビルド方法

```bash
cd ActivityTracker
swift build
```

## 実行方法

```bash
swift run ActivityTracker
```

または、Xcodeでプロジェクトを開いて実行:

```bash
open Package.swift
```

## 権限

このアプリは以下の権限が必要です:

- **アクセシビリティ**: キーボードとマウスの入力を監視するため
- **オートメーション**: アプリの使用状況を追跡するため

初回起動時に、システム環境設定でアクセシビリティの許可を求めるダイアログが表示されます。

## プロジェクト構造

```
ActivityTracker/
├── Package.swift
├── Sources/
│   └── ActivityTracker/
│       ├── ActivityTrackerApp.swift  # メインアプリ
│       ├── AppDelegate.swift          # アプリデリゲート
│       ├── AppState.swift             # 状態管理
│       ├── Models/                    # データモデル
│       │   ├── AppUsageLog.swift
│       │   ├── InputActivity.swift
│       │   ├── FocusSession.swift
│       │   └── Settings.swift
│       ├── Views/                     # UI
│       │   ├── MenuBarView.swift
│       │   ├── DetailWindow.swift
│       │   ├── DashboardView.swift
│       │   ├── AppsView.swift
│       │   ├── FocusView.swift
│       │   ├── ReportsView.swift
│       │   ├── HistoryView.swift
│       │   └── SettingsView.swift
│       ├── Services/                  # サービス
│       │   ├── TrackingService.swift
│       │   └── InputMonitor.swift
│       └── Managers/                  # マネージャー
│           └── DatabaseManager.swift
└── Resources/
    ├── Info.plist
    └── ActivityTracker.entitlements
```

## データ保存

SQLiteを使用してローカルにデータを保存します。データベースファイルは以下の場所に保存されます:

```
~/Library/Application Support/ActivityTracker/activity_tracker.db
```

## ライセンス

MIT License
