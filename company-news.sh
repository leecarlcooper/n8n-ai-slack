#!/usr/bin/env bash
set -euo pipefail

SKILL_NEWS="company-news-12mo-analyst-memo"
SKILL_HTML="md-to-business-html"
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
OUT_HTML="company-news_${COMPANY_SLUG}_${TIMESTAMP}.html"
OUT_LOG="company-news_${COMPANY_SLUG}_${TIMESTAMP}.log"

START_EPOCH="$(date +%s)"
START_HUMAN="$(date +"%Y-%m-%d %H:%M:%S %Z")"

echo "========================================"
echo "Codex multi-step run (YOLO mode)"
echo "Model:   $MODEL"
echo "Company: $COMPANY_RAW"
echo "Markdown: $OUT_MD"
echo "HTML:     $OUT_HTML"
echo "Log:      $OUT_LOG"
echo "Started:  $START_HUMAN"
echo "========================================"

# Ensure log exists
: > "$OUT_LOG"

########################################
# STEP 1 — Generate 12-month news memo
########################################
echo
echo "---- STEP 1: Generating news memo ----"
echo "Skill: $SKILL_NEWS"

set +e
codex exec \
  --model "$MODEL" \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  "Use $SKILL_NEWS for $COMPANY_RAW. Output only the final memo in Markdown." \
  2> >(tee -a "$OUT_LOG" >&2) \
  | tee "$OUT_MD"
STEP1_EXIT="${PIPESTATUS[0]}"
set -e

if [[ "$STEP1_EXIT" -ne 0 || ! -s "$OUT_MD" ]]; then
  echo "ERROR: News memo step failed or produced empty output."
  exit 1
fi

########################################
# STEP 2 — Convert Markdown → HTML
########################################
echo
echo "---- STEP 2: Converting Markdown to HTML ----"
echo "Skill: $SKILL_HTML"

set +e
codex exec \
  --model "$MODEL" \
  --skip-git-repo-check \
  --dangerously-bypass-approvals-and-sandbox \
  "Use $SKILL_HTML on $OUT_MD. Output only confirmation and the output HTML filename." \
  2> >(tee -a "$OUT_LOG" >&2)
STEP2_EXIT="$?"
set -e

########################################
# Runtime + footer
########################################
END_EPOCH="$(date +%s)"
END_HUMAN="$(date +"%Y-%m-%d %H:%M:%S %Z")"
DURATION_SEC="$((END_EPOCH - START_EPOCH))"

if (( DURATION_SEC < 60 )); then
  DURATION_HUMAN="${DURATION_SEC}s"
else
  DURATION_HUMAN="$((DURATION_SEC / 60))m $((DURATION_SEC % 60))s"
fi

{
  echo
  echo "----------------------------------------"
  echo "SESSION METADATA"
  echo "----------------------------------------"
  echo "Company:        $COMPANY_RAW"
  echo "Model:          $MODEL"
  echo "Step 1 skill:   $SKILL_NEWS"
  echo "Step 2 skill:   $SKILL_HTML"
  echo "Markdown file:  $OUT_MD"
  echo "HTML file:      $OUT_HTML"
  echo "Started at:     $START_HUMAN"
  echo "Ended at:       $END_HUMAN"
  echo "Total runtime:  $DURATION_SEC seconds (${DURATION_HUMAN})"
  echo "Step 1 exit:    $STEP1_EXIT"
  echo "Step 2 exit:    $STEP2_EXIT"
} >> "$OUT_LOG"

echo
echo "========================================"
echo "DONE"
echo "Markdown: $OUT_MD"
echo "HTML:     $OUT_HTML"
echo "Log:      $OUT_LOG"
echo "Runtime:  $DURATION_HUMAN"
echo "========================================"

exit "$STEP2_EXIT"
