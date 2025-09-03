# android-legacy-metrics

Android 技術負債を**対象リポに依存追加なし**で計測し、集約リポへ JSON 出力します。

* 計測：**grep ベース**（Bash + coreutils）
* 実行：各リポの GitHub Actions から**再利用ワークフロー**を呼び出し
* 出力：`legacy-graph/data/<org>/<repo>/{latest.json, YYYYMMDDThhmmssZ.json}`

## 計測項目（初期セット）

* **UI**：`@Composable` 数／Android View使用ファイル数／XML数／DataBindingレイアウト数
* **言語**：Javaファイル比率
* **ビルド**：kaptプラグイン・依存／kspプラグイン／DataBinding有効モジュール
* **イベント**：RxJava・EventBus／Flow・LiveData の import 件数
* **古い技術**：AsyncTask／Loader／旧Fragment（`android.app.Fragment`/`android.support.v4.app.Fragment`）／`<fragment>`タグ
* **Support Library 残存**：`android.support.*` / `com.android.support:` 参照

> 近似検出のため誤検知あり。精度が必要な箇所は後で Konsist/Lint に置換可能。

## 仕組み

1. 対象リポが再利用WFを呼ぶ → リポを `checkout`
2. 本リポの `scripts/grep_scan.sh` を実行 → `tech-debt-metrics.json` 生成
3. 集約リポ（例：`legacy-graph`）へ `latest.json` と履歴を push

## 導入手順（最短）

1. **集約リポ**を作成（例：`takumi-saito/legacy-graph`）
2. **Fine-grained PAT** を発行（`legacy-graph` の Contents: Read/Write）
3. **対象リポ**の Secrets に `LEGACY_GRAPH_TOKEN` を追加
4. **対象リポ**に下記ワークフローを追加

```yaml
# .github/workflows/metrics.yml （対象リポ）
name: TechDebt Metrics
on:
  workflow_dispatch:
  pull_request:
  schedule: [cron: "0 2 * * 1"]  # 週次
permissions: { contents: read }
jobs:
  call:
    uses: takumi-saito/android-legacy-metrics/.github/workflows/run-metrics.yml@main
    with: { repo_slug: ${{ github.repository }} }
    secrets:
      LEGACY_GRAPH_TOKEN: ${{ secrets.LEGACY_GRAPH_TOKEN }}
```

## このリポに含まれるもの

```
scripts/grep_scan.sh              # 計測本体（grepのみ）
.github/workflows/run-metrics.yml # 再利用ワークフロー（workflow_call）
```

## 出力例（抜粋）

```json
{
  "files": {"kotlin": 123, "java": 45},
  "ui": {"xml_layout_files": 60, "databinding_layout_files": 8, "composable_functions": 210, "kotlin_view_like_files": 52},
  "language": {"java_file_ratio": 0.268},
  "events": {"rx_imports": 14, "eventbus_imports": 0, "flow_imports": 120, "livedata_imports": 18},
  "buildsys": {"kapt_plugins_count": 2, "kapt_deps_count": 5, "ksp_plugins_count": 1, "dataBinding_enabled_modules": 1},
  "legacy": {"asyncTask_usages": 0, "loader_usages": 3, "frameworkFragment_usages": 0, "supportFragment_usages": 2, "fragmentXml_tags": 6},
  "supportlib": {"support_code_refs": 12, "support_dep_refs": 0}
}
```

## カスタマイズ

* 除外パスや正規表現は `scripts/grep_scan.sh` で集中管理（対象リポは無改変）
* Lint/Konsist 追加は `.github/workflows/run-metrics.yml` にステップを足すだけ

## 既知の注意

* grep 近似のため誤検知あり／巨大リポは実行時間が増えます
* 別リポへの push には `LEGACY_GRAPH_TOKEN`（PAT もしくは GitHub App トークン）が必要
