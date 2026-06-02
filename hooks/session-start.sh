#!/usr/bin/env bash
# session-start.sh — SessionStart hook для AIDD-workflow (per-session резолюция тикета)
# Событие: SessionStart  (без matcher — срабатывает для startup/resume/clear/compact)
# Matcher: нет
# Exit 0 = всегда. Хук НИКОГДА не блокирует и не падает (fail-open developer tooling).
#
# Назначение:
#   1. Прочитать stdin (session_id, source, cwd) и резолвить активный тикет per-session.
#   2. TTL-очистка orphaned per-session файлов (только при source=startup).
#   3. Upsert per-session файла ~/.claude/sessions/aidd/<session_id>.json (атомарно).
#   4. Вывести в stdout строку `AIDD session_id: <S>` (→ контекст LLM) + status-panel.
#
# Хранилище per-session: ~/.claude/sessions/aidd/<session_id>.json
#   {"ticket","cwd","source","created","updated"}  (см. plan AIDD-001 §Схема хранения)
set -euo pipefail

# --- [2.1] Чтение stdin (один раз) и подключение sourced-библиотек -------------
# PAYLOAD может быть пустым (CI/тест-среда, старые версии CLI) — это норма.
PAYLOAD="$(cat 2>/dev/null || true)"

# Подключаем библиотеки резолюции. В них НЕТ `set -euo pipefail` (намеренно),
# все ошибки гасятся внутри функций (fail-open). Подключение защищено `|| true`,
# чтобы отсутствие файла библиотеки не уронило хук.
# shellcheck source=/dev/null
source "$HOME/.claude/hooks/_lib/aidd-session-id.sh" 2>/dev/null || true
# shellcheck source=/dev/null
source "$HOME/.claude/hooks/_lib/aidd-ticket.sh" 2>/dev/null || true

# resolve_session_id заполняет глобальную SID (env-var → .session_id → transcript → "").
SID=""
if command -v resolve_session_id >/dev/null 2>&1; then
  resolve_session_id "$PAYLOAD"
fi

# Извлекаем source (→SRC) и cwd (→CWD) из PAYLOAD через python3.
# Если python3 недоступен — деградируем gracefully: панель/резолюция тикета
# зависят от python3 (как и существующие хуки), поэтому просто выходим без ошибок.
SRC=""
CWD=""
if command -v python3 >/dev/null 2>&1 && [ -n "$PAYLOAD" ]; then
  SRC="$(printf '%s' "$PAYLOAD" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('source','') or '')" \
    2>/dev/null || echo "")"
  CWD="$(printf '%s' "$PAYLOAD" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('cwd','') or '')" \
    2>/dev/null || echo "")"
fi
# Fallback cwd на текущую директорию (CI/пустой stdin/нет поля).
[ -z "$CWD" ] && CWD="$(pwd 2>/dev/null || echo "")"

# Если python3 недоступен — резолюция тикета и panel не работают как задумано.
# Деградируем: выведем строку session_id (если он есть) и тихо выйдем.
if ! command -v python3 >/dev/null 2>&1; then
  echo "AIDD session_id: ${SID:-unknown}"
  exit 0
fi

# Резолюция тикета: per-session (cwd-guard) → legacy docs/.active_ticket → none.
TICKET=""
TICKET_SRC="none"
if command -v resolve_ticket >/dev/null 2>&1; then
  resolve_ticket "$CWD" "$SID"
fi

# --- [2.2] TTL-очистка orphaned per-session файлов (только при source=startup) -
# Удаляем файлы старше 14 дней по mtime, КРОМЕ файла текущей сессии.
# Пропускаем, если SRC != startup или директории нет. Текущий файл не трогаем.
AIDD_DIR="$HOME/.claude/sessions/aidd"
if [ "$SRC" = "startup" ] && [ -d "$AIDD_DIR" ]; then
  # Сначала считаем, сколько кандидатов на удаление (для stderr-сообщения),
  # затем удаляем. Обе команды fail-open. Имя текущей сессии исключаем.
  ORPHAN_COUNT=0
  if [ -n "$SID" ]; then
    ORPHAN_COUNT="$(find "$AIDD_DIR" -type f -name '*.json' -mtime +14 \
      ! -name "${SID}.json" 2>/dev/null | wc -l | tr -d '[:space:]' || echo 0)"
    find "$AIDD_DIR" -type f -name '*.json' -mtime +14 \
      ! -name "${SID}.json" -delete 2>/dev/null || true
  else
    # SID неизвестен — исключать нечего по имени, но удаляем только старые файлы.
    ORPHAN_COUNT="$(find "$AIDD_DIR" -type f -name '*.json' -mtime +14 \
      2>/dev/null | wc -l | tr -d '[:space:]' || echo 0)"
    find "$AIDD_DIR" -type f -name '*.json' -mtime +14 -delete 2>/dev/null || true
  fi
  # Защита от нечислового значения (на случай странного wc-вывода).
  case "$ORPHAN_COUNT" in
    ''|*[!0-9]*) ORPHAN_COUNT=0 ;;
  esac
  if [ "$ORPHAN_COUNT" -ge 1 ] 2>/dev/null; then
    echo "AIDD: cleaned ${ORPHAN_COUNT} orphaned session files" >&2
  fi
fi

# --- [2.3] Upsert per-session файла ~/.claude/sessions/aidd/<SID>.json --------
# SID пуст → пропускаем (legacy-режим). Иначе:
#   нет файла  → создать атомарно (tmp + mv) с {ticket,cwd,source,created,updated};
#                ticket=$TICKET (унаследован из legacy через resolve_ticket;
#                при source=clear это и есть наследование тикета по cwd), source=$SRC;
#   есть файл  → обновить ТОЛЬКО source и updated; ticket НЕ перетирать если непустой.
#
# ИНВАРИАНТ (наследование тикета при source=clear): при /clear создаётся НОВАЯ сессия с
#   новым session_id, поэтому per-session файла для неё ещё нет — ticket берётся из TICKET,
#   который resolve_ticket добыл из legacy-указателя по текущему cwd. Это наследование
#   КОРРЕКТНО ровно потому, что legacy docs/.active_ticket пишется ВСЕГДА при активации
#   тикета (workflow.md шаг 2c; idea/SKILL.md шаг 3.3). Если этот инвариант нарушить
#   (перестать писать legacy-указатель) — наследование тикета через /clear молча сломается.
if [ -n "$SID" ]; then
  mkdir -p "$AIDD_DIR" 2>/dev/null || true
  SESSION_FILE="$AIDD_DIR/${SID}.json"
  TMP_FILE="${SESSION_FILE}.tmp.$$"

  if [ ! -f "$SESSION_FILE" ]; then
    # Создание нового файла. ticket наследуется из TICKET (legacy/per-session),
    # для source=clear TICKET уже содержит унаследованный из legacy по cwd тикет
    # (см. ИНВАРИАНТ выше: legacy-указатель пишется всегда → наследование надёжно).
    if AIDD_TICKET="$TICKET" AIDD_CWD="$CWD" AIDD_SRC="$SRC" python3 -c '
import json, os, sys, datetime
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
data = {
    "ticket": os.environ.get("AIDD_TICKET", "") or "",
    "cwd": os.environ.get("AIDD_CWD", "") or "",
    "source": os.environ.get("AIDD_SRC", "") or "",
    "created": now,
    "updated": now,
}
sys.stdout.write(json.dumps(data, ensure_ascii=False, indent=2))
sys.stdout.write("\n")
' >"$TMP_FILE" 2>/dev/null; then
      mv -f "$TMP_FILE" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP_FILE" 2>/dev/null || true
    else
      rm -f "$TMP_FILE" 2>/dev/null || true
    fi
  else
    # Обновление существующего: только source + updated. ticket сохраняем,
    # если он непустой; cwd/created не трогаем. Битый JSON → fail-open (оставляем как есть).
    if AIDD_SRC="$SRC" python3 -c '
import json, os, sys, datetime
path = sys.argv[1]
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("not an object")
except Exception:
    sys.exit(1)
# Обновляем ТОЛЬКО source и updated; ticket не перетираем, если он уже непустой.
data["source"] = os.environ.get("AIDD_SRC", "") or ""
data["updated"] = now
data.setdefault("ticket", "")
sys.stdout.write(json.dumps(data, ensure_ascii=False, indent=2))
sys.stdout.write("\n")
' "$SESSION_FILE" >"$TMP_FILE" 2>/dev/null; then
      mv -f "$TMP_FILE" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP_FILE" 2>/dev/null || true
    else
      rm -f "$TMP_FILE" 2>/dev/null || true
    fi
  fi
fi

# --- [2.4] stdout: строка session_id + status-panel ---------------------------
# Plain-text (Вариант A плана): для SessionStart stdout инжектится в контекст LLM.
echo "AIDD session_id: ${SID:-unknown}"

# Если тикет не резолвится — панель не выводим (но строка session_id уже выведена).
if [ -z "$TICKET" ]; then
  exit 0
fi

# Хелпер: ищет артефакт сначала в <CWD>/docs/<rel>, затем в <CWD>/.claude/docs/<rel>.
# Печатает найденный путь в stdout (или пусто).
_aidd_find_doc() {
  local rel="${1:-}"
  [ -n "$rel" ] || { echo ""; return 0; }
  if [ -f "$CWD/docs/$rel" ]; then
    echo "$CWD/docs/$rel"
  elif [ -f "$CWD/.claude/docs/$rel" ]; then
    echo "$CWD/.claude/docs/$rel"
  else
    echo ""
  fi
}

# Короткий session_id для шапки панели (первые 8 символов), source с fallback на legacy.
SID_SHORT="${SID:0:8}"
[ -z "$SID_SHORT" ] && SID_SHORT="unknown"
PANEL_SRC="${SRC:-legacy}"
[ -z "$PANEL_SRC" ] && PANEL_SRC="legacy"

echo "=== AIDD Workflow ==="
echo "Session: ${SID_SHORT} source=${PANEL_SRC}"
echo "Active ticket: ${TICKET} (source=${TICKET_SRC})"

# PRD
PRD_FILE="$(_aidd_find_doc "prd/${TICKET}.prd.md")"
if [ -n "$PRD_FILE" ]; then
  PRD_STATUS="$(grep -i "^Status:" "$PRD_FILE" 2>/dev/null | head -1 | sed 's/^Status:[[:space:]]*//' || echo "unknown")"
  echo "PRD: ${PRD_STATUS:-unknown}"
else
  echo "PRD: missing"
fi

# Plan
PLAN_FILE="$(_aidd_find_doc "plan/${TICKET}.md")"
if [ -n "$PLAN_FILE" ]; then
  PLAN_STATUS="$(grep -i "^Status:" "$PLAN_FILE" 2>/dev/null | head -1 | sed 's/^Status:[[:space:]]*//' || echo "unknown")"
  echo "Plan: ${PLAN_STATUS:-unknown}"
else
  echo "Plan: missing"
fi

# Tasklist
TASKLIST_FILE="$(_aidd_find_doc "tasklist/${TICKET}.md")"
TODO=0
if [ -n "$TASKLIST_FILE" ]; then
  DONE="$(grep -c '\- \[x\]' "$TASKLIST_FILE" 2>/dev/null || echo 0)"
  TODO="$(grep -c '\- \[ \]' "$TASKLIST_FILE" 2>/dev/null || echo 0)"
  case "$DONE" in ''|*[!0-9]*) DONE=0 ;; esac
  case "$TODO" in ''|*[!0-9]*) TODO=0 ;; esac
  TOTAL=$((DONE + TODO))
  echo "Tasks: ${DONE}/${TOTAL} completed"
else
  echo "Tasks: missing"
fi

# QA (reports/qa/<ticket>.md в docs/ или .claude/docs/; также reports/ относительно cwd)
QA_FILE="$(_aidd_find_doc "reports/qa/${TICKET}.md")"
if [ -z "$QA_FILE" ] && [ -f "$CWD/reports/qa/${TICKET}.md" ]; then
  QA_FILE="$CWD/reports/qa/${TICKET}.md"
fi
if [ -n "$QA_FILE" ]; then
  echo "QA: done"
else
  echo "QA: pending"
fi

# Рекомендация Next (та же логика, что и раньше)
if [ -z "$PRD_FILE" ]; then
  echo "Next: /idea ${TICKET} <title>"
elif [ -z "$PLAN_FILE" ]; then
  echo "Next: /plan ${TICKET}"
elif [ -z "$TASKLIST_FILE" ]; then
  echo "Next: /tasks ${TICKET}"
elif [ "$TODO" -gt 0 ] 2>/dev/null; then
  echo "Next: /implement ${TICKET}"
elif [ -z "$QA_FILE" ]; then
  echo "Next: /review ${TICKET}"
else
  echo "Next: /docs-update ${TICKET}"
fi

echo "===================="
exit 0
