#!/usr/bin/env bash
# session-start.sh — SessionStart hook для отображения статуса AIDD
# Событие: SessionStart
# Показывает текущий тикет, статус gates, прогресс задач

set -euo pipefail

# Если нет docs/.active_ticket — ничего не показываем
if [ ! -f "docs/.active_ticket" ]; then
  exit 0
fi

TICKET=$(cat "docs/.active_ticket" 2>/dev/null | tr -d '[:space:]')

if [ -z "$TICKET" ]; then
  exit 0
fi

echo "=== AIDD Workflow ==="
echo "Active ticket: $TICKET"

# PRD
PRD_FILE="docs/prd/${TICKET}.prd.md"
if [ -f "$PRD_FILE" ]; then
  PRD_STATUS=$(grep -i "^Status:" "$PRD_FILE" | head -1 | sed 's/^Status:[[:space:]]*//' || echo "unknown")
  echo "PRD: $PRD_STATUS"
else
  echo "PRD: missing"
fi

# Plan
PLAN_FILE="docs/plan/${TICKET}.md"
if [ -f "$PLAN_FILE" ]; then
  PLAN_STATUS=$(grep -i "^Status:" "$PLAN_FILE" | head -1 | sed 's/^Status:[[:space:]]*//' || echo "unknown")
  echo "Plan: $PLAN_STATUS"
else
  echo "Plan: missing"
fi

# Tasklist
TASKLIST_FILE="docs/tasklist/${TICKET}.md"
if [ -f "$TASKLIST_FILE" ]; then
  DONE=$(grep -c '\- \[x\]' "$TASKLIST_FILE" 2>/dev/null || echo "0")
  TODO=$(grep -c '\- \[ \]' "$TASKLIST_FILE" 2>/dev/null || echo "0")
  TOTAL=$((DONE + TODO))
  echo "Tasks: $DONE/$TOTAL completed"
else
  echo "Tasks: missing"
fi

# QA
QA_FILE="reports/qa/${TICKET}.md"
if [ -f "$QA_FILE" ]; then
  echo "QA: done"
else
  echo "QA: pending"
fi

# Рекомендация
if [ ! -f "$PRD_FILE" ]; then
  echo "Next: /idea $TICKET <title>"
elif [ ! -f "$PLAN_FILE" ]; then
  echo "Next: /plan $TICKET"
elif [ ! -f "$TASKLIST_FILE" ]; then
  echo "Next: /tasks $TICKET"
elif [ "$TODO" -gt 0 ] 2>/dev/null; then
  echo "Next: /implement $TICKET"
elif [ ! -f "$QA_FILE" ]; then
  echo "Next: /review $TICKET"
else
  echo "Next: /docs-update $TICKET"
fi

echo "===================="
exit 0
