#!/usr/bin/env bash
# gate-workflow.sh — PreToolUse hook для блокировки Edit/Write без quality gates
# Событие: PreToolUse, matcher: Edit|Write
# Exit 0 = разрешить, Exit 2 = блокировать (stderr показывается пользователю как причина)
#
# Резолюция активного AIDD-тикета — per-session с деградацией:
#   1) session_id из stdin/env  → per-session JSON (~/.claude/sessions/aidd/<sid>.json) с cwd-guard
#   2) <cwd>/docs/.active_ticket            (legacy plain-text)
#   3) ничего не найдено → тикет неактивен → тихий exit 0
# Логику резолюции инкапсулируют sourced-библиотеки _lib/aidd-session-id.sh и _lib/aidd-ticket.sh.
#
# КРИТИЧНО — fail-open: здесь НЕТ `set -euo pipefail`. Он сломал бы fail-open
#   sourced-библиотек (см. предупреждения в их шапках) и вызывающую логику.
#   Любой сбой инфраструктуры (нет библиотеки, битый JSON, нет python3, нет файла) →
#   деградация и exit 0. НИКОГДА не выдаём ложный exit 2 из-за инфраструктурного сбоя.
#   exit 2 возможен ТОЛЬКО при реальном непрохождении одного из трёх gates с резолвнутым тикетом.

# Читаем stdin (JSON tool input) РОВНО ОДИН РАЗ — повторный cat невозможен (stdin исчерпан).
INPUT="$(cat 2>/dev/null || true)"

# Извлекаем путь к редактируемому файлу из $INPUT (НЕ повторный cat — парсим уже прочитанное).
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' 2>/dev/null || echo "")"

# --- Резолюция session_id -----------------------------------------------------
# Подключаем библиотеку под guard: её отсутствие не должно ронять хук (fail-open → SID="").
SID=""
if [ -f "$HOME/.claude/hooks/_lib/aidd-session-id.sh" ]; then
  . "$HOME/.claude/hooks/_lib/aidd-session-id.sh"
  resolve_session_id "$INPUT"
fi

# --- CWD ----------------------------------------------------------------------
# Рабочая директория: из $INPUT.cwd, иначе текущая pwd. Парсим $INPUT (НЕ повторный cat).
CWD="$(echo "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' 2>/dev/null || echo "")"
if [ -z "$CWD" ]; then
  CWD="$(pwd 2>/dev/null || echo "")"
fi

# --- Резолюция тикета ---------------------------------------------------------
# ЗАМЕНЯЕТ прежнее `TICKET="$(cat docs/.active_ticket)"`.
# Под guard подключаем библиотеку. Если библиотеки НЕТ на диске (ВАРИАНТ A) —
# деградируем к inline-чтению legacy-указателя, сохраняя целостность gates. Всё fail-open.
TICKET=""
TICKET_SRC="none"
if [ -f "$HOME/.claude/hooks/_lib/aidd-ticket.sh" ]; then
  . "$HOME/.claude/hooks/_lib/aidd-ticket.sh"
  resolve_ticket "$CWD" "$SID"
else
  # ВАРИАНТ A (УТВЕРЖДЁН): библиотеки нет — inline legacy fallback.
  # Читаем <CWD>/docs/.active_ticket; источник = legacy.
  if [ -n "$CWD" ] && [ -f "$CWD/docs/.active_ticket" ]; then
    TICKET="$(cat "$CWD/docs/.active_ticket" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$TICKET" ] && TICKET_SRC="legacy"
  fi
fi

# --- [3.2] Observability ------------------------------------------------------
# Печатает диагностику источника тикета в stderr РОВНО ОДИН РАЗ.
# Вызывается непосредственно перед фактическим завершением (и перед exit 2, и перед финальным exit 0),
# НО НЕ при ранних исключениях по FILE_PATH (там exit 0 идёт до observability — так задумано).
# Битый JSON уже логируется внутри resolve_ticket — здесь не дублируем.
aidd_log_source() {
  if [ -z "$SID" ]; then
    echo "AIDD: session_id unavailable, using legacy mode" >&2
  fi
  case "$TICKET_SRC" in
    session)
      echo "AIDD: ticket=$TICKET source=session:$SID" >&2
      ;;
    legacy)
      echo "AIDD: ticket=$TICKET source=legacy" >&2
      ;;
    # TICKET пуст / source=none → тихо (early exit 0 уже отработал до вызова этой функции).
  esac
}

# Если тикет не резолвнулся — проект/сессия без AIDD, тихо разрешаем.
if [ -z "$TICKET" ] || [ "$TICKET_SRC" = "none" ]; then
  exit 0
fi

# --- Исключения по FILE_PATH (ДО observability) -------------------------------
# AIDD-артефакты и системные файлы Claude Code всегда разрешены (абсолютные и относительные пути).
if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in
    *docs/prd/*|*docs/plan/*|*docs/tasklist/*|*docs/research/*|*docs/adr/*|*docs/.active_ticket|*docs/investigations/*|*docs/reports/*|*reports/*)
      exit 0
      ;;
    # Системные файлы Claude Code — никогда не блокировать
    */.claude/*|*/\.claude/*)
      exit 0
      ;;
  esac
  # Абсолютный путь содержит .claude/ — разрешаем
  if echo "$FILE_PATH" | grep -q '/\.claude/'; then
    exit 0
  fi
fi

# Проверка gates для редактирования исходного кода
#
# КРИТИЧНО — cwd-консистентность: тикет резолвится по $CWD (stdin.cwd), а НЕ по process cwd.
#   Поэтому пути gate-артефактов СТРОЯТСЯ ОТ $CWD, иначе при расхождении process-cwd и stdin.cwd
#   проверки читали бы файлы из «не той» директории → ложный exit 2 (нарушение fail-open).
#   Для каждого gate проверяем ОБА расположения: <cwd>/docs/... и <cwd>/.claude/docs/...
#   Логику самих проверок (DRAFT-блок, PLAN_APPROVED, TASKLIST_READY) не меняем.

# Gate: PRD_READY — проверяем оба возможных расположения (от $CWD)
PRD_FILE="$CWD/docs/prd/${TICKET}.prd.md"
if [ ! -f "$PRD_FILE" ]; then
  PRD_FILE="$CWD/.claude/docs/prd/${TICKET}.prd.md"
fi
if [ ! -f "$PRD_FILE" ]; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: PRD не найден. Выполни /idea $TICKET" >&2
  exit 2
fi

PRD_STATUS="$(grep -i '^Status:' "$PRD_FILE" | head -1 || echo "")"
if echo "$PRD_STATUS" | grep -qi "DRAFT"; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: PRD в статусе DRAFT. Установи Status: PRD_READY в $PRD_FILE" >&2
  exit 2
fi

# Gate: PLAN_APPROVED — проверяем оба расположения (от $CWD)
PLAN_FILE="$CWD/docs/plan/${TICKET}.md"
if [ ! -f "$PLAN_FILE" ]; then
  PLAN_FILE="$CWD/.claude/docs/plan/${TICKET}.md"
fi
if [ ! -f "$PLAN_FILE" ]; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: План не найден ($PLAN_FILE). Выполни /plan $TICKET" >&2
  exit 2
fi

PLAN_STATUS="$(grep -i '^Status:' "$PLAN_FILE" | head -1 || echo "")"
if ! echo "$PLAN_STATUS" | grep -qi "PLAN_APPROVED"; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: План не утверждён. Установи Status: PLAN_APPROVED в $PLAN_FILE" >&2
  exit 2
fi

# Gate: TASKLIST_READY — проверяем оба расположения (от $CWD)
TASKLIST_FILE="$CWD/docs/tasklist/${TICKET}.md"
if [ ! -f "$TASKLIST_FILE" ]; then
  TASKLIST_FILE="$CWD/.claude/docs/tasklist/${TICKET}.md"
fi
if [ ! -f "$TASKLIST_FILE" ]; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: Tasklist не найден ($TASKLIST_FILE). Выполни /tasks $TICKET" >&2
  exit 2
fi

TASKLIST_STATUS="$(grep -i '^Status:' "$TASKLIST_FILE" | head -1 || echo "")"
if ! echo "$TASKLIST_STATUS" | grep -qi "TASKLIST_READY"; then
  aidd_log_source
  echo "AIDD Gate BLOCKED: Tasklist не готов. Установи Status: TASKLIST_READY в $TASKLIST_FILE" >&2
  exit 2
fi

# Все gates пройдены — печатаем диагностику источника один раз и разрешаем.
aidd_log_source
exit 0
