#!/bin/bash

# sdd-analytics — Show trends across SDD execution cycles.
# Parses loop-log.md files (current + archived) to extract:
#   - Iterations to convergence per cycle
#   - Common failure patterns (dead ends, blocked tasks)
#   - Time per task tier
#   - Task completion velocity
#
# Compatible with macOS bash 3.x (no associative arrays).

set -uo pipefail

R=$'\033[0m'
B=$'\033[1m'
D=$'\033[2m'
GR=$'\033[32m'
YL=$'\033[33m'
RD=$'\033[31m'
CY=$'\033[36m'

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ─── Collect all loop logs ────────────────────────────────────────────────────

LOGS=()

# Current log
[[ -f "$PROJECT_ROOT/context/impl/loop-log.md" ]] && LOGS+=("$PROJECT_ROOT/context/impl/loop-log.md")

# Archived logs
for archive_log in "$PROJECT_ROOT"/context/impl/archive/*/loop-log.md; do
  [[ -f "$archive_log" ]] && LOGS+=("$archive_log")
done

# Also check worktrees
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
for wt in "${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-"*; do
  [[ -d "$wt" ]] || continue
  [[ -f "$wt/context/impl/loop-log.md" ]] && LOGS+=("$wt/context/impl/loop-log.md")
  for archive_log in "$wt"/context/impl/archive/*/loop-log.md; do
    [[ -f "$archive_log" ]] && LOGS+=("$archive_log")
  done
done

if [[ ${#LOGS[@]} -eq 0 ]]; then
  echo "No loop logs found. Run /sdd:execute first."
  exit 0
fi

echo "${B}${CY}SDD Analytics${R}"
echo "${D}$(printf '%.0s─' $(seq 1 60))${R}"
echo ""

# ─── Parse iterations ─────────────────────────────────────────────────────────

total_iterations=0
total_cycles=0
total_done=0
total_partial=0
total_blocked=0
total_dead_ends=0

# Use a temp file for tier counts (avoids bash 3 associative array limitation)
TIER_FILE=$(mktemp /tmp/sdd-tiers-XXXXXX)
trap 'rm -f "$TIER_FILE"' EXIT

for log in "${LOGS[@]}"; do
  cycle_iters=0

  while IFS= read -r line; do
    # Count iterations
    if [[ "$line" =~ ^###.*Iteration ]]; then
      cycle_iters=$((cycle_iters + 1))
      total_iterations=$((total_iterations + 1))
    fi

    # Count statuses
    if [[ "$line" =~ Status:.*DONE ]]; then
      total_done=$((total_done + 1))
    elif [[ "$line" =~ Status:.*PARTIAL ]]; then
      total_partial=$((total_partial + 1))
    elif [[ "$line" =~ Status:.*BLOCKED ]]; then
      total_blocked=$((total_blocked + 1))
    fi

    # Record tier numbers
    if [[ "$line" =~ Tier:\ *([0-9]+) ]]; then
      echo "${BASH_REMATCH[1]}" >> "$TIER_FILE"
    fi
  done < "$log"

  if [[ $cycle_iters -gt 0 ]]; then
    total_cycles=$((total_cycles + 1))
  fi
done

# Count dead ends from impl files
for impl_dir in "$PROJECT_ROOT/context/impl" "${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-"*/context/impl; do
  [[ -d "$impl_dir" ]] || continue
  for impl in "$impl_dir"/impl-*.md "$impl_dir"/archive/*/impl-*.md; do
    [[ -f "$impl" ]] || continue
    dead=$(grep -ciE 'dead.end' "$impl" 2>/dev/null || true)
    [[ -n "$dead" ]] && total_dead_ends=$((total_dead_ends + dead))
  done
done

# ─── Overview ─────────────────────────────────────────────────────────────────

echo "${B}Overview${R}"
echo "  Cycles analyzed:     ${B}${total_cycles}${R}"
echo "  Total iterations:    ${B}${total_iterations}${R}"
if [[ $total_cycles -gt 0 ]]; then
  avg=$((total_iterations / total_cycles))
  echo "  Avg iterations/cycle:${B} ${avg}${R}"
fi
echo ""

# ─── Task Outcomes ────────────────────────────────────────────────────────────

total_tasks=$((total_done + total_partial + total_blocked))

echo "${B}Task Outcomes${R}"
if [[ $total_tasks -gt 0 ]]; then
  done_pct=$((total_done * 100 / total_tasks))
  partial_pct=$((total_partial * 100 / total_tasks))
  blocked_pct=$((total_blocked * 100 / total_tasks))

  printf "  ${GR}Done${R}      %4d  (%d%%)\n" "$total_done" "$done_pct"
  printf "  ${YL}Partial${R}   %4d  (%d%%)\n" "$total_partial" "$partial_pct"
  printf "  ${RD}Blocked${R}   %4d  (%d%%)\n" "$total_blocked" "$blocked_pct"
else
  echo "  No task outcomes recorded yet."
fi
echo ""

# ─── Dead Ends ────────────────────────────────────────────────────────────────

echo "${B}Failure Patterns${R}"
if [[ $total_dead_ends -gt 0 ]]; then
  echo "  ${RD}Dead ends:${R} ${B}${total_dead_ends}${R}"

  echo "  ${D}Recent dead ends:${R}"
  for impl_dir in "$PROJECT_ROOT/context/impl" "${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-"*/context/impl; do
    [[ -d "$impl_dir" ]] || continue
    for impl in "$impl_dir"/impl-*.md; do
      [[ -f "$impl" ]] || continue
      grep -iB1 'dead.end' "$impl" 2>/dev/null | grep -E 'T-[0-9]+' | head -5 | while read -r dline; do
        task_id=$(echo "$dline" | grep -oE 'T-[0-9]+' | head -1)
        desc=$(echo "$dline" | sed "s/.*$task_id[[:space:]]*//" | cut -c1-50)
        [[ -n "$task_id" ]] && echo "    ${RD}✕${R} ${task_id} ${D}${desc}${R}"
      done
    done
  done
else
  echo "  ${GR}No dead ends recorded.${R}"
fi
echo ""

# ─── Tier Distribution ───────────────────────────────────────────────────────

echo "${B}Iterations by Tier${R}"
if [[ -s "$TIER_FILE" ]]; then
  sort -n "$TIER_FILE" | uniq -c | sort -k2 -n | while read -r count tier; do
    if [[ $total_iterations -gt 0 ]]; then
      bar_len=$((count * 30 / total_iterations))
      [[ $bar_len -lt 1 ]] && bar_len=1
    else
      bar_len=1
    fi
    bar=$(printf '%*s' "$bar_len" '' | tr ' ' '█')
    printf "  Tier %s: %s %d\n" "$tier" "$bar" "$count"
  done
else
  echo "  No tier data recorded."
fi
echo ""

# ─── Velocity ─────────────────────────────────────────────────────────────────

echo "${B}Completion Velocity${R}"
if [[ $total_iterations -gt 0 && $total_done -gt 0 ]]; then
  tasks_per_iter=$(echo "scale=2; $total_done / $total_iterations" | bc 2>/dev/null || echo "?")
  echo "  Tasks/iteration: ${B}${tasks_per_iter}${R}"

  if [[ $total_tasks -gt 0 ]]; then
    success_rate=$((total_done * 100 / total_tasks))
    echo "  Success rate:    ${B}${success_rate}%${R}"
  fi
else
  echo "  Not enough data yet."
fi
echo ""

# ─── Active Agents ────────────────────────────────────────────────────────────

echo "${B}Active Agents${R}"
active_count=0
for wt in "${PROJECT_ROOT}/../${PROJECT_NAME}-sdd-"*; do
  [[ -d "$wt" ]] || continue
  name=$(basename "$wt" | sed "s/^${PROJECT_NAME}-sdd-//")
  if [[ -f "$wt/.claude/ralph-loop.local.md" ]]; then
    iter=$(grep -m1 '^iteration:' "$wt/.claude/ralph-loop.local.md" 2>/dev/null | awk '{print $2}' || echo "?")
    echo "  ${GR}⟳${R} ${name} — iteration ${iter}"
    active_count=$((active_count + 1))
  fi
done
if [[ $active_count -eq 0 ]]; then
  echo "  ${D}No active agents.${R}"
fi
echo ""
echo "${D}Data from ${#LOGS[@]} log files across ${total_cycles} cycles.${R}"
