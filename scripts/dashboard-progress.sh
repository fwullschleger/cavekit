#!/bin/bash

# SDD Dashboard — Progress Pane (top-right)
# Shows frontier progress, task status, iteration count.
# Renders each frame into a buffer and flushes in one write — no flicker.

set -uo pipefail

R=$'\033[0m'
B=$'\033[1m'
D=$'\033[2m'
GR=$'\033[32m'
YL=$'\033[33m'
RD=$'\033[31m'
BL=$'\033[34m'
BGB=$'\033[44m'
BGY=$'\033[43m'
BGD=$'\033[100m'
EL=$'\033[K'
TASK_ID_PATTERN='T-([A-Za-z0-9]+-)*[A-Za-z0-9]+'

extract_task_id() {
  printf '%s\n' "$1" | grep -oE "$TASK_ID_PATTERN" | head -1
}

is_frontier_task_line() {
  local line="$1"
  printf '%s\n' "$line" | grep -Eq "^[[:space:]]*\\|[[:space:]]*${TASK_ID_PATTERN}[[:space:]]*\\||^[[:space:]]*-[[:space:]]+${TASK_ID_PATTERN}([[:space:]]|$)"
}

record_task_status() {
  TASK_STATUS_LINES+="$1"$'\t'"$2"$'\n'
}

lookup_task_status() {
  local task_id="$1"
  local line=""
  local task_status=""
  local result=""

  while IFS=$'\t' read -r line task_status; do
    [[ "$line" == "$task_id" ]] && result="$task_status"
  done <<< "${TASK_STATUS_LINES:-}"

  printf '%s' "$result"
}

tput civis 2>/dev/null
trap 'tput cnorm 2>/dev/null' EXIT
printf '\033[2J'

render() {
  local cols=$(tput cols 2>/dev/null || echo 40)
  local rows=$(tput lines 2>/dev/null || echo 24)
  local hr=$(printf '%.0s─' $(seq 1 "$cols"))
  local line=0
  local max=$((rows - 1))
  local buf=$'\033[H'

  emit() { ((line < max)) && buf+="${1}${EL}"$'\n' && line=$((line + 1)); }

  emit "${B}${BL} BLUEPRINT${R}"
  emit "${BL}${D}${hr}${R}"

  # ── Ralph Loop state ──
  local state_file=".claude/ralph-loop.local.md"
  local iteration="-" max_iter="-" started_at="" active=false

  if [[ -f "$state_file" ]]; then
    active=true
    iteration=$(grep -m1 '^iteration:' "$state_file" 2>/dev/null | awk '{print $2}' || echo "-")
    max_iter=$(grep -m1 '^max_iterations:' "$state_file" 2>/dev/null | awk '{print $2}' || echo "-")
    started_at=$(grep -m1 '^started_at:' "$state_file" 2>/dev/null | sed 's/started_at: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' || echo "")
  fi

  local elapsed="--:--"
  if [[ -n "$started_at" ]]; then
    local start_epoch
    start_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || date -d "$started_at" +%s 2>/dev/null || echo "")
    if [[ -n "$start_epoch" ]]; then
      local now_epoch=$(date +%s)
      local diff=$((now_epoch - start_epoch))
      elapsed="$((diff / 60))m $((diff % 60))s"
    fi
  fi

  if [[ "$active" == "true" ]]; then
    emit "  ${GR}ACTIVE${R}  iter ${B}${iteration}${R}/${max_iter}  ${D}${elapsed}${R}"
  else
    emit "  ${D}IDLE — no active loop${R}"
  fi
  emit ""

  # ── Find frontier ──
  local frontier=""
  if [[ -d "context/sites" ]]; then
    frontier=$(find "context/sites" -maxdepth 1 \( -name "*site*.md" -o -name "*site*.md" \) -type f 2>/dev/null | grep -v '/archive/' | sort | head -1)
  fi

  if [[ -z "$frontier" ]]; then
    emit "  ${D}No frontier found${R}"
    while ((line < max - 1)); do emit ""; done
    emit "${D}$(date +%H:%M:%S)${R}"
    printf '%b' "$buf"
    return
  fi

  # ── Parse tasks ──
  local total=0 done_count=0 in_progress=0 blocked=0
  local task_ids=()
  local TASK_STATUS_LINES=""

  while IFS= read -r tline; do
    local tid=""
    is_frontier_task_line "$tline" || continue
    tid=$(extract_task_id "$tline")
    [[ -n "$tid" ]] && task_ids+=("$tid") && total=$((total + 1))
  done < "$frontier"

  for impl_file in context/impl/impl-*.md; do
    [[ -f "$impl_file" ]] || continue
    while IFS= read -r tline; do
      local tid=""
      tid=$(extract_task_id "$tline")
      [[ -z "$tid" ]] && continue
      if echo "$tline" | grep -qi 'DONE'; then
        record_task_status "$tid" "DONE"
      elif echo "$tline" | grep -qi 'IN.PROGRESS\|PARTIAL'; then
        record_task_status "$tid" "WIP"
      elif echo "$tline" | grep -qi 'BLOCKED\|DEAD.END'; then
        record_task_status "$tid" "BLOCKED"
      fi
    done < <(grep -E "$TASK_ID_PATTERN" "$impl_file" 2>/dev/null || true)
  done

  for tid in "${task_ids[@]+"${task_ids[@]}"}"; do
    case "$(lookup_task_status "$tid")" in
      DONE)    done_count=$((done_count + 1)) ;;
      WIP)     in_progress=$((in_progress + 1)) ;;
      BLOCKED) blocked=$((blocked + 1)) ;;
    esac
  done
  local remaining=$((total - done_count - in_progress - blocked))

  # ── Progress bar ──
  emit "${B} Tasks${R}"
  emit "${BL}${D}${hr}${R}"

  if [[ $total -gt 0 ]]; then
    local bar_w=$((cols - 8))
    [[ $bar_w -gt 36 ]] && bar_w=36
    local filled=$((done_count * bar_w / total))
    local wip_w=0
    [[ $in_progress -gt 0 ]] && wip_w=$((in_progress * bar_w / total))
    [[ $wip_w -lt 1 && $in_progress -gt 0 ]] && wip_w=1
    local empty=$((bar_w - filled - wip_w))
    [[ $empty -lt 0 ]] && empty=0

    local bar=""
    [[ $filled -gt 0 ]] && bar+=$(printf "${BGB}%*s${R}" "$filled" "")
    [[ $wip_w -gt 0 ]] && bar+=$(printf "${BGY}%*s${R}" "$wip_w" "")
    [[ $empty -gt 0 ]] && bar+=$(printf "${BGD}%*s${R}" "$empty" "")

    emit "  ${bar} $((done_count * 100 / total))%"
  fi

  emit ""
  emit "  ${GR}Done${R}        ${B}${done_count}${R}/${total}"
  [[ $in_progress -gt 0 ]] && emit "  ${YL}In Progress${R} ${B}${in_progress}${R}"
  [[ $blocked -gt 0 ]] && emit "  ${RD}Blocked${R}     ${B}${blocked}${R}"
  emit "  ${D}Remaining${R}   ${remaining}"
  emit ""

  # ── Tiers ──
  emit "${B} Tiers${R}"
  emit "${BL}${D}${hr}${R}"

  local cur_tier="" tier_total=0 tier_done=0
  while IFS= read -r tline; do
    if [[ "$tline" =~ ^##.*[Tt]ier ]]; then
      if [[ -n "$cur_tier" ]]; then
        local mk="${D}-${R}"
        [[ $tier_done -eq $tier_total && $tier_total -gt 0 ]] && mk="${GR}*${R}"
        [[ $tier_done -gt 0 && $tier_done -lt $tier_total ]] && mk="${YL}>${R}"
        emit "  ${mk} ${cur_tier}: ${tier_done}/${tier_total}"
      fi
      cur_tier=$(echo "$tline" | sed 's/^##[[:space:]]*//' | head -c $((cols - 14)))
      tier_total=0; tier_done=0
    elif is_frontier_task_line "$tline"; then
      local tid=""
      tid=$(extract_task_id "$tline")
      tier_total=$((tier_total + 1))
      [[ "$(lookup_task_status "$tid")" == "DONE" ]] && tier_done=$((tier_done + 1))
    fi
  done < "$frontier"

  if [[ -n "$cur_tier" ]]; then
    local mk="${D}-${R}"
    [[ $tier_done -eq $tier_total && $tier_total -gt 0 ]] && mk="${GR}*${R}"
    [[ $tier_done -gt 0 && $tier_done -lt $tier_total ]] && mk="${YL}>${R}"
    emit "  ${mk} ${cur_tier}: ${tier_done}/${tier_total}"
  fi
  emit ""

  # ── Dead ends ──
  local dead_ends=0
  for impl_file in context/impl/impl-*.md; do
    [[ -f "$impl_file" ]] || continue
    dead_ends=$((dead_ends + $(grep -ciE 'dead.end' "$impl_file" 2>/dev/null || true)))
  done
  [[ $dead_ends -gt 0 ]] && emit "  ${RD}Dead ends: ${dead_ends}${R}" && emit ""

  # ── Peer Review ──
  local findings_file="context/impl/peer-review-findings.md"
  if [[ -f "$findings_file" ]]; then
    local critical=$(grep -ciE 'CRITICAL' "$findings_file" 2>/dev/null || true)
    local high=$(grep -ciE '\bHIGH\b' "$findings_file" 2>/dev/null || true)
    emit "${B} Peer Review${R}"
    emit "${BL}${D}${hr}${R}"
    [[ $critical -gt 0 ]] && emit "  ${RD}CRITICAL${R} ${critical}"
    [[ $high -gt 0 ]] && emit "  ${YL}HIGH${R}     ${high}"
    [[ $critical -eq 0 && $high -eq 0 ]] && emit "  ${GR}Clean${R}"
    emit ""
  fi

  # Blank remaining lines + footer
  while ((line < max - 1)); do emit ""; done
  emit "${D}$(date +%H:%M:%S)${R}"

  # Single atomic write
  printf '%b' "$buf"
}

while true; do
  render
  sleep 5
done
