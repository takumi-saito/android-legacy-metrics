#!/usr/bin/env bash
set -euo pipefail

SRC=()
while IFS= read -r line; do
  SRC+=("$line")
done < <(git ls-files \
  | grep -Ev '(^|/)(build|\.gradle|gradle/wrapper|generated|third_party)/' \
  | grep -E '\.(kt|java|xml|gradle|gradle\.kts)$' || true)

count_grep() { 
  if [ ${#SRC[@]} -eq 0 ]; then
    echo 0
  else
    grep -Hn -E "$1" "${SRC[@]}" 2>/dev/null | wc -l | tr -d ' ' || echo 0
  fi
}
count_files() { 
  if [ ${#SRC[@]} -eq 0 ]; then
    echo 0
  else
    printf "%s\n" "${SRC[@]}" | grep -E "$1" | wc -l | tr -d ' ' || echo 0
  fi
}

KT_COUNT=$(count_files '\.kt$')
JAVA_COUNT=$(count_files '\.java$')
XML_LAYOUT_COUNT=$(if [ ${#SRC[@]} -eq 0 ]; then echo 0; else printf "%s\n" "${SRC[@]}" | grep -E 'src/.*/res/layout/.*\.xml$' | wc -l | tr -d ' ' || echo 0; fi)
DB_LAYOUT_COUNT=$(if [ ${#SRC[@]} -eq 0 ]; then 
  echo 0
else 
  layout_files=$(printf "%s\n" "${SRC[@]}" | grep -E 'src/.*/res/layout/.*\.xml$' || true)
  if [ -z "$layout_files" ]; then 
    echo 0
  else 
    echo "$layout_files" | xargs -r grep -l "<layout" 2>/dev/null | wc -l | tr -d ' ' || echo 0
  fi
fi)

COMPOSABLE_FUNCS=$(count_grep '@Composable')
VIEW_FILE_LIKE=$(if [ ${#SRC[@]} -eq 0 ]; then echo 0; else
  source_files=$(printf "%s\n" "${SRC[@]}" | grep -E '\.kt$|\.java$' || true)
  if [ -z "$source_files" ]; then echo 0; else echo "$source_files" | xargs -r grep -l -E '^(package|import).*(android\.view\.|android\.widget\.|androidx\.appcompat\.widget\.|androidx\.recyclerview\.widget\.|androidx\.viewpager2\.widget\.)' 2>/dev/null | wc -l | tr -d ' ' || echo 0; fi
fi)

JAVA_RATIO=$(python3 - <<PY
kt=${KT_COUNT}; jv=${JAVA_COUNT}
print(round(jv/(kt+jv), 4) if (kt+jv)>0 else 0.0)
PY
)

RX_IMPORTS=$(count_grep 'import +io\.reactivex|import +io\.reactivestreams')
EVENTBUS_IMPORTS=$(count_grep 'import +org\.greenrobot\.eventbus')
FLOW_IMPORTS=$(count_grep 'import +kotlinx\.coroutines\.flow')
LIVEDATA_IMPORTS=$(count_grep 'import +androidx\.lifecycle\.(Mutable)?LiveData')

KAPT_PLUGINS=$(count_grep 'id\("kotlin-kapt"\)|apply +plugin *: *"kotlin-kapt"')
KAPT_DEPS=$(count_grep 'kapt\(')
KSP_PLUGINS=$(count_grep 'id\("com.google.devtools.ksp"\)|apply +plugin *: *"com.google.devtools.ksp"')
DATABINDING_ON=$(count_grep 'buildFeatures\s*\{[^}]*dataBinding\s*=\s*true')

ASYNC_USAGES=$(count_grep 'import +android\.os\.AsyncTask|extends +AsyncTask(\<.*\>)?')
LOADER_USAGES=$(count_grep 'import +(androidx\.loader\.|android\.support\.v4\.content\.Loader|androidx\.loader\.app\.LoaderManager)')
FW_FRAGMENT_USAGES=$(count_grep 'import +android\.app\.Fragment|extends +Fragment(\s|<|$)')
SUPPORT_FRAGMENT_USAGES=$(count_grep 'import +android\.support\.v4\.app\.Fragment')
FRAGMENT_XML_TAGS=$(if [ ${#SRC[@]} -eq 0 ]; then echo 0; else
  layout_files=$(printf "%s\n" "${SRC[@]}" | grep -E 'src/.*/res/layout/.*\.xml$' || true)
  if [ -z "$layout_files" ]; then echo 0; else echo "$layout_files" | xargs -r grep -Hn -E '^\s*<fragment(\s|>)' 2>/dev/null | wc -l | tr -d ' ' || echo 0; fi
fi)
SUPPORT_CODE_REFS=$(count_grep 'android\.support\.')
SUPPORT_DEP_REFS=$(count_grep 'com\.android\.support:')

mkdir -p build/metrics

# 変数をクリーンアップして数値のみにする
KT_COUNT="${KT_COUNT:-0}"
JAVA_COUNT="${JAVA_COUNT:-0}"
XML_LAYOUT_COUNT="${XML_LAYOUT_COUNT:-0}"
DB_LAYOUT_COUNT="${DB_LAYOUT_COUNT:-0}"
COMPOSABLE_FUNCS="${COMPOSABLE_FUNCS:-0}"
VIEW_FILE_LIKE="${VIEW_FILE_LIKE:-0}"
JAVA_RATIO="${JAVA_RATIO:-0.0}"
RX_IMPORTS="${RX_IMPORTS:-0}"
EVENTBUS_IMPORTS="${EVENTBUS_IMPORTS:-0}"
FLOW_IMPORTS="${FLOW_IMPORTS:-0}"
LIVEDATA_IMPORTS="${LIVEDATA_IMPORTS:-0}"
KAPT_PLUGINS="${KAPT_PLUGINS:-0}"
KAPT_DEPS="${KAPT_DEPS:-0}"
KSP_PLUGINS="${KSP_PLUGINS:-0}"
DATABINDING_ON="${DATABINDING_ON:-0}"
ASYNC_USAGES="${ASYNC_USAGES:-0}"
LOADER_USAGES="${LOADER_USAGES:-0}"
FW_FRAGMENT_USAGES="${FW_FRAGMENT_USAGES:-0}"
SUPPORT_FRAGMENT_USAGES="${SUPPORT_FRAGMENT_USAGES:-0}"
FRAGMENT_XML_TAGS="${FRAGMENT_XML_TAGS:-0}"
SUPPORT_CODE_REFS="${SUPPORT_CODE_REFS:-0}"
SUPPORT_DEP_REFS="${SUPPORT_DEP_REFS:-0}"

python3 - <<PY > build/metrics/tech-debt-metrics.json
import json,datetime

# 文字列として渡して、Python側で数値に変換
def to_int(s):
    try:
        return int(s.strip())
    except:
        return 0

def to_float(s):
    try:
        return float(s.strip())
    except:
        return 0.0

print(json.dumps({
  "generated_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "files": {"kotlin": to_int("${KT_COUNT}"), "java": to_int("${JAVA_COUNT}")},
  "ui": {
    "xml_layout_files": to_int("${XML_LAYOUT_COUNT}"),
    "databinding_layout_files": to_int("${DB_LAYOUT_COUNT}"),
    "composable_functions": to_int("${COMPOSABLE_FUNCS}"),
    "kotlin_view_like_files": to_int("${VIEW_FILE_LIKE}")
  },
  "language": {"java_file_ratio": to_float("${JAVA_RATIO}")},
  "events": {
    "rx_imports": to_int("${RX_IMPORTS}"),
    "eventbus_imports": to_int("${EVENTBUS_IMPORTS}"),
    "flow_imports": to_int("${FLOW_IMPORTS}"),
    "livedata_imports": to_int("${LIVEDATA_IMPORTS}")
  },
  "buildsys": {
    "kapt_plugins_count": to_int("${KAPT_PLUGINS}"),
    "kapt_deps_count": to_int("${KAPT_DEPS}"),
    "ksp_plugins_count": to_int("${KSP_PLUGINS}"),
    "dataBinding_enabled_modules": to_int("${DATABINDING_ON}")
  },
  "legacy": {
    "asyncTask_usages": to_int("${ASYNC_USAGES}"),
    "loader_usages": to_int("${LOADER_USAGES}"),
    "frameworkFragment_usages": to_int("${FW_FRAGMENT_USAGES}"),
    "supportFragment_usages": to_int("${SUPPORT_FRAGMENT_USAGES}"),
    "fragmentXml_tags": to_int("${FRAGMENT_XML_TAGS}")
  },
  "supportlib": {
    "support_code_refs": to_int("${SUPPORT_CODE_REFS}"),
    "support_dep_refs": to_int("${SUPPORT_DEP_REFS}")
  }
}, ensure_ascii=False))
PY
echo "✅ build/metrics/tech-debt-metrics.json"
