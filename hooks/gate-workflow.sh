#!/usr/bin/env bash
# gate-workflow.sh — PreToolUse hook для блокировки Edit/Write без quality gates
# Событие: PreToolUse, matcher: Edit|Write
# Exit 0 = разрешить, Exit 2 = блокировать

# Если нет docs/.active_ticket — проект не использует AIDD, разрешаем
if [ ! -f "docs/.active_ticket" ]; then
  exit 0
fi

TICKET="$(cat "docs/.active_ticket" 2>/dev/null | tr -d '[:space:]')"

# Если ticket пуст — AIDD не активен
if [ -z "$TICKET" ]; then
  exit 0
fi

# Читаем tool input из stdin (JSON)
INPUT="$(cat)"

# Извлекаем путь к редактируемому файлу (если есть)
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' 2>/dev/null || echo "")"

# Исключения: AIDD-артефакты всегда разрешены
if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in
    docs/prd/*|docs/plan/*|docs/tasklist/*|docs/research/*|docs/adr/*|docs/.active_ticket)
      exit 0
      ;;
    reports/*)
      exit 0
      ;;
  esac
fi

# Проверка gates для редактирования исходного кода

# Gate: PRD_READY
PRD_FILE="docs/prd/${TICKET}.prd.md"
if [ ! -f "$PRD_FILE" ]; then
  echo "AIDD Gate BLOCKED: PRD не найден ($PRD_FILE). Выполни /idea $TICKET" >&2
  exit 2
fi

PRD_STATUS="$(grep -i '^Status:' "$PRD_FILE" | head -1 || echo "")"
if echo "$PRD_STATUS" | grep -qi "DRAFT"; then
  echo "AIDD Gate BLOCKED: PRD в статусе DRAFT. Установи Status: PRD_READY в $PRD_FILE" >&2
  exit 2
fi

# Gate: PLAN_APPROVED
PLAN_FILE="docs/plan/${TICKET}.md"
if [ ! -f "$PLAN_FILE" ]; then
  echo "AIDD Gate BLOCKED: План не найден ($PLAN_FILE). Выполни /plan $TICKET" >&2
  exit 2
fi

PLAN_STATUS="$(grep -i '^Status:' "$PLAN_FILE" | head -1 || echo "")"
if ! echo "$PLAN_STATUS" | grep -qi "PLAN_APPROVED"; then
  echo "AIDD Gate BLOCKED: План не утверждён. Установи Status: PLAN_APPROVED в $PLAN_FILE" >&2
  exit 2
fi

# Gate: TASKLIST_READY
TASKLIST_FILE="docs/tasklist/${TICKET}.md"
if [ ! -f "$TASKLIST_FILE" ]; then
  echo "AIDD Gate BLOCKED: Tasklist не найден ($TASKLIST_FILE). Выполни /tasks $TICKET" >&2
  exit 2
fi

TASKLIST_STATUS="$(grep -i '^Status:' "$TASKLIST_FILE" | head -1 || echo "")"
if ! echo "$TASKLIST_STATUS" | grep -qi "TASKLIST_READY"; then
  echo "AIDD Gate BLOCKED: Tasklist не готов. Установи Status: TASKLIST_READY в $TASKLIST_FILE" >&2
  exit 2
fi

# Все gates пройдены
exit 0
