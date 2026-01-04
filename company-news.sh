#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="company-news-12mo-analyst-memo"
MODEL="gpt-5.2"
COMPANY_RAW="${1:-}"

if [[ -z "$COMPANY_RAW" ]]; then
  echo "Usage: $0 \"Company Name\""
  exit 1
fi

# Filesystem-safe slug
COMPANY_SLUG="$(echo "$COMPANY_RAW" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g' \
  | sed -E 's/^-+|-+$//g')"

TIMESTAMP="$(date +"%Y-%m-%d_%H%M%S")"

OUT_MD="company-news_${COMPANY_SLUG}_${TIMESTAMP}.md"
OUT_LOG="company-news_${COMPANY_SLUG}_${TIMESTAMP}.log"

START_EPOCH="$(date +%s)"
START_HUMAN="$(date +"%Y-%m-%d %H:%M:%S %Z")"

echo "========================================"
echo "Running Codex skill in YOLO mode"
echo "Model:   $MODEL"
echo "Skill:   $SKILL_NAME"
echo "Company: $COMPANY_RAW"
echo "Memo:    $OUT_MD"
echo "Log:     $OUT_LOG"
echo "Started: $START_HUMAN"
echo "========================================"

# Ensure log file exists
: > "$OUT_LOG"

# Run Codex:
# - stdout -> memo (tee to terminal + file)
# - stderr -> verbose (tee to terminal + file)
set +e
codex exec \
  --model "$MODEL" \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  "Use $SKILL_NAME for $COMPANY_RAW. Output only the final memo in Markdown." \
  2> >(tee -a "$OUT_LOG" >&2) \
  | tee "$OUT_MD"
CODEX_EXIT="${PIPESTATUS[0]}"
set -e

END_EPOCH="$(date +%s)"
END_HUMAN="$(date +"%Y-%m-%d %H:%M:%S %Z")"
DURATION_SEC="$((END_EPOCH - START_EPOCH))"

# Human-friendly duration
if (( DURATION_SEC < 60 )); then
  DURATION_HUMAN="${DURATION_SEC}s"
else
  DURATION_HUMAN="$((DURATION_SEC / 60))m $((DURATION_SEC % 60))s"
fi

# Append footer to verbose log
{
  echo
  echo "----------------------------------------"
  echo "SESSION METADATA"
  echo "----------------------------------------"
  echo "Company:        $COMPANY_RAW"
  echo "Skill:          $SKILL_NAME"
  echo "Model:          $MODEL"
  echo "Started at:     $START_HUMAN"
  echo "Ended at:       $END_HUMAN"
  echo "Total runtime:  $DURATION_SEC seconds (${DURATION_HUMAN})"
  echo "Codex exit:     $CODEX_EXIT"
} >> "$OUT_LOG"

echo
echo "Saved memo to: $OUT_MD"
echo "Saved verbose log to: $OUT_LOG"
echo "Runtime: $DURATION_HUMAN"
echo "Codex exit code: $CODEX_EXIT"

exit "$CODEX_EXIT"
