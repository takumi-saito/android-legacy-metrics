# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Android 技術負債計測ツール - grep ベースで Android プロジェクトの技術負債を迅速に検出し、JSON 形式でレポート出力するツール。GitHub Actions の再利用ワークフローとして提供され、対象リポジトリに依存を追加せずに計測を実行できる。

## アーキテクチャ

### コンポーネント構成

1. **計測スクリプト** (`scripts/grep_scan.sh`)
   - Bash と coreutils のみで実装された軽量な grep ベース計測エンジン
   - Git 管理下のソースファイルを対象に Android 特有の技術負債パターンを検出
   - Python3 を使用した JSON 出力生成

2. **再利用ワークフロー** (`.github/workflows/run-metrics.yml`)
   - `workflow_call` イベントで他リポジトリから呼び出し可能
   - 計測結果を集約リポジトリ（`legacy-graph`）へ自動プッシュ

### 計測フロー

1. 対象リポジトリが再利用ワークフローを呼び出し
2. `grep_scan.sh` が技術負債を検出・集計
3. `build/metrics/tech-debt-metrics.json` を生成
4. 集約リポジトリへ `latest.json` と履歴ファイルを保存

## 開発コマンド

```bash
# スクリプトのテスト実行（Android プロジェクトのルートで実行）
bash scripts/grep_scan.sh

# 出力 JSON の確認
cat build/metrics/tech-debt-metrics.json | jq .

# スクリプトの実行権限付与
chmod +x scripts/grep_scan.sh
```

## コード構造

### grep_scan.sh の処理フロー

1. **ファイル収集**: `git ls-files` で管理下のソースファイルを取得
   - 除外パス: `build/`, `.gradle/`, `gradle/wrapper/`, `generated/`, `third_party/`
   - 対象拡張子: `.kt`, `.java`, `.xml`, `.gradle`, `.gradle.kts`

2. **計測カテゴリ**:
   - **UI 計測**: Composable 関数、Android View、XML レイアウト、DataBinding
   - **言語計測**: Java/Kotlin ファイル比率
   - **ビルド計測**: kapt/ksp プラグイン、DataBinding 設定
   - **イベント計測**: RxJava、EventBus、Coroutines Flow、LiveData
   - **レガシー計測**: AsyncTask、Loader、古い Fragment、Support Library

3. **JSON 生成**: Python3 で構造化された JSON を出力

### 計測ロジックのカスタマイズポイント

- **検出パターン追加**: `count_grep` 関数で新しい grep パターンを定義
- **除外パス変更**: `git ls-files` のフィルタ条件を調整
- **出力形式変更**: Python スクリプト部分で JSON 構造を修正

## 重要な技術的詳細

- **grep の高速化**: ファイルリストを配列化し、一括処理で実行
- **エラーハンドリング**: `|| true` や `|| echo 0` で grep の失敗を許容
- **Python 依存**: JSON 生成と浮動小数点計算に Python3 を使用
- **Git 依存**: ファイルリストの取得に `git ls-files` を使用（Git 管理下のみ対象）

## 拡張・改修時の注意点

1. **パフォーマンス**: 巨大リポジトリでは grep の実行時間が増大する
2. **誤検知**: grep ベースのため、コメントアウトされたコードも検出対象
3. **PAT トークン**: 集約リポジトリへのプッシュには Fine-grained PAT が必要
4. **互換性**: Bash 4.0 以上、GNU coreutils、Python3 が必要