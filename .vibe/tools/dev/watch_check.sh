#!/usr/bin/env bash
# 等 HEAD 那次 push 的「iOS check」（分支 work/** 的檢查線）跑完，印各關結果；
# 紅燈就印錯誤行；把 UI 測試的截圖抓回來給 AI 看。要先 gh auth login。
# 用法：bash .vibe/tools/dev/watch_check.sh   （會等到跑完，十幾分鐘，建議丟背景）
cd "$(dirname "$0")/../../.." || exit 1
SCRATCH="${RENCAN_SCRATCH:-${TMPDIR:-/tmp}/rencan-ci}"
SHA=$(git rev-parse HEAD)
RUN=""
for i in $(seq 1 30); do
  RUN=$(gh run list --workflow=ios-check.yml --limit 8 --json databaseId,headSha --jq ".[] | select(.headSha==\"$SHA\") | .databaseId" | head -1)
  [ -n "$RUN" ] && break
  sleep 6
done
[ -z "$RUN" ] && { echo "找不到這次 push 的執行"; exit 1; }
echo "run $RUN  sha ${SHA:0:7}"
for i in $(seq 1 150); do
  ST=$(gh run view "$RUN" --json status --jq .status)
  [ "$ST" = "completed" ] && break
  sleep 12
done
gh run view "$RUN" --json jobs --jq '.jobs[] | .name + " = " + (.conclusion // .status)'
gh run view "$RUN" --json jobs --jq '.jobs[] | select(.name|startswith("編譯")) | .steps[] | select(.conclusion=="failure") | "  失敗的步驟：" + .name'
OUT="$SCRATCH/ci/${SHA:0:7}"
rm -rf "$OUT"; mkdir -p "$OUT"
gh run download "$RUN" --dir "$OUT" >/dev/null 2>&1
LOG="$OUT/rencan-ui-log/build-uitest.log"
if [ -f "$LOG" ]; then
  echo "--- 編譯與測試紀錄（錯誤與結果行）"
  grep -E "error:|Test Case .*(failed)|XCTAssert|Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|BUILD (SUCCEEDED|FAILED)|Testing failed|\*\* " "$LOG" | sed 's#/Users/runner/work/Ginseng-Cultivation/Ginseng-Cultivation/##' | sort -u | cut -c1-420 | head -70
fi
# lint 的錯誤在 job log 裡
CORE=$(gh run view "$RUN" --json jobs --jq '.jobs[] | select(.name|startswith("規則引擎")) | .conclusion')
if [ "$CORE" != "success" ]; then
  echo "--- Linux 測試失敗"
  gh run view "$RUN" --log-failed 2>/dev/null | sed 's/^.*Z //' | grep -E "error|failed|XCTAssert" | cut -c1-400 | head -40
fi
J=$(gh run view "$RUN" --json jobs --jq '.jobs[] | select(.name|startswith("編譯")) | .databaseId')
LINTBAD=$(gh run view "$RUN" --json jobs --jq '.jobs[] | select(.name|startswith("編譯")) | .steps[] | select(.name|test("swift-format|SwiftLint")) | select(.conclusion!="success") | .name' | head -1)
if [ -n "$LINTBAD" ]; then
  echo "--- 排版或 lint 沒過"
  gh run view --job "$J" --log 2>/dev/null | sed 's/^.*Z //' | grep -E "\.swift:[0-9]+:[0-9]+: (error|warning)" | sed 's#/Users/runner/work/Ginseng-Cultivation/Ginseng-Cultivation/##' | sort -u | cut -c1-300 | head -60
fi
echo "--- 截圖"
ls "$OUT/rencan-ui-screenshots" 2>/dev/null | head -80
echo "截圖資料夾：$OUT/rencan-ui-screenshots"
