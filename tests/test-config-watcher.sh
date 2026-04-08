#!/usr/bin/env bash
# test-config-watcher.sh — Unit-тесты для bash-хуков config-watcher
# Запуск: bash ~/.claude/tests/test-config-watcher.sh
# Покрытие: detect-correction.sh, session-start-pending.sh

set -euo pipefail

# ─── Инфраструктура ────────────────────────────────────────────────────────────

PASS=0
FAIL=0
SKIP=0

HOOK_DIR="$(cd "$(dirname "$0")/.." && pwd)/hooks"
DETECT="$HOOK_DIR/detect-correction.sh"
SESSION_START="$HOOK_DIR/session-start-pending.sh"
PENDING_FILE="${HOME}/.claude/pending-changes.md"

# Цвета
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}  FAIL${NC} $1"; FAIL=$((FAIL+1)); }
section() { echo -e "\n${YELLOW}▶ $1${NC}"; }

# Создаёт mock-транскрипт и возвращает путь
make_transcript() {
  local path="/tmp/cw_test_transcript_$$.jsonl"
  cat > "$path"
  echo "$path"
}

# Запускает detect-correction.sh с заданным JSON-входом, возвращает вывод
run_detect() {
  local input="$1"
  bash "$DETECT" <<< "$input" 2>/dev/null || true
}

cleanup() {
  rm -f /tmp/cw_test_transcript_*.jsonl
  rm -f "/tmp/claude-watcher-ran-testXXX"
  rm -f "/tmp/claude-correction-flag-testXXX"
  rm -f "/tmp/claude-cursor-testXXX"
  # Восстанавливаем pending-changes.md если он был изменён тестами
  rm -f "${PENDING_FILE}.bak_cw_test" 2>/dev/null || true
}
trap cleanup EXIT

# ─── Группа 1: detect-correction.sh ──────────────────────────────────────────

section "detect-correction.sh"

# Вспомогательная функция: формат реального транскрипта
make_correction_transcript() {
  make_transcript <<'EOF'
{"type": "assistant", "sessionId": "testXXX", "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "Edit", "id": "t1", "input": {"file_path": "/tmp/f.txt", "old_string": "a", "new_string": "b"}}]}}
{"type": "user", "sessionId": "testXXX", "message": {"role": "user", "content": "нет, переделай это"}}
EOF
}

make_no_correction_transcript() {
  make_transcript <<'EOF'
{"type": "assistant", "sessionId": "testXXX", "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "Edit", "id": "t1", "input": {"file_path": "/tmp/f.txt", "old_string": "a", "new_string": "b"}}]}}
{"type": "user", "sessionId": "testXXX", "message": {"role": "user", "content": "спасибо, всё отлично"}}
EOF
}

make_correction_no_edit_transcript() {
  make_transcript <<'EOF'
{"type": "assistant", "sessionId": "testXXX", "message": {"role": "assistant", "content": [{"type": "text", "text": "Вот мой ответ без изменений файлов"}]}}
{"type": "user", "sessionId": "testXXX", "message": {"role": "user", "content": "нет, это неправильно"}}
EOF
}

make_write_tool_transcript() {
  make_transcript <<'EOF'
{"type": "assistant", "sessionId": "testXXX", "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "Write", "id": "t1", "input": {"file_path": "/tmp/f.txt", "content": "test"}}]}}
{"type": "user", "sessionId": "testXXX", "message": {"role": "user", "content": "wrong, redo this"}}
EOF
}

# ── Тест 1.1: stop_hook_active=true → тихий выход ─────────────────────────────
T="1.1 stop_hook_active=true — тихий выход"
transcript=$(make_correction_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":true}')
rm -f "$transcript"
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 1.2: Пустой session_id → тихий выход ─────────────────────────────────
T="1.2 пустой session_id — тихий выход"
transcript=$(make_correction_transcript)
result=$(run_detect '{"session_id":"","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 1.3: Несуществующий транскрипт → тихий выход ─────────────────────────
T="1.3 несуществующий транскрипт — тихий выход"
result=$(run_detect '{"session_id":"testXXX","transcript_path":"/tmp/not_exist_$$_.jsonl","stop_hook_active":false}')
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 1.4: Edit + слово коррекции → ok:false ───────────────────────────────
T="1.4 Edit + коррекция (ru) → ok:false"
rm -f "/tmp/claude-watcher-ran-testXXX"
rm -f "/tmp/claude-correction-flag-testXXX"
rm -f "/tmp/claude-cursor-testXXX"
transcript=$(make_correction_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if echo "$result" | grep -q '"ok": false' || echo "$result" | grep -q '"ok":false'; then
  pass "$T"
else
  fail "$T (output: $result)"
fi
rm -f "/tmp/claude-correction-flag-testXXX" "/tmp/claude-cursor-testXXX"

# ── Тест 1.5: Write + коррекция (en) → ok:false ───────────────────────────────
T="1.5 Write + коррекция (en: 'wrong, redo') → ok:false"
rm -f "/tmp/claude-watcher-ran-testXXX"
transcript=$(make_write_tool_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if echo "$result" | grep -q '"ok": false' || echo "$result" | grep -q '"ok":false'; then
  pass "$T"
else
  fail "$T (output: $result)"
fi
rm -f "/tmp/claude-correction-flag-testXXX" "/tmp/claude-cursor-testXXX"

# ── Тест 1.6: Edit есть, но нет слов коррекции → тихий выход ──────────────────
T="1.6 Edit + нет слов коррекции → тихий выход"
rm -f "/tmp/claude-watcher-ran-testXXX"
transcript=$(make_no_correction_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 1.7: Слова коррекции есть, но нет Edit/Write → тихий выход ───────────
T="1.7 коррекция + нет Edit/Write → тихий выход"
rm -f "/tmp/claude-watcher-ran-testXXX"
transcript=$(make_correction_no_edit_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 1.8: Флаг watcher-ran существует → тихий выход + флаг удалён ─────────
T="1.8 watcher-ran флаг существует → тихий выход + флаг сброшен"
touch "/tmp/claude-watcher-ran-testXXX"
transcript=$(make_correction_transcript)
result=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}')
rm -f "$transcript"
if [ -z "$result" ] && [ ! -f "/tmp/claude-watcher-ran-testXXX" ]; then
  pass "$T"
elif [ -n "$result" ]; then
  fail "$T (expected empty output, got: $result)"
else
  fail "$T (watcher-ran флаг не был удалён)"
fi

# ── Тест 1.9: После trigger — файлы создаются ─────────────────────────────────
T="1.9 после trigger — correction-flag и cursor созданы"
rm -f "/tmp/claude-watcher-ran-testXXX"
rm -f "/tmp/claude-correction-flag-testXXX"
rm -f "/tmp/claude-cursor-testXXX"
transcript=$(make_correction_transcript)
run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}' > /dev/null
rm -f "$transcript"
if [ -f "/tmp/claude-correction-flag-testXXX" ] && [ -f "/tmp/claude-cursor-testXXX" ]; then
  pass "$T"
elif [ ! -f "/tmp/claude-correction-flag-testXXX" ]; then
  fail "$T (correction-flag не создан)"
else
  fail "$T (cursor не создан)"
fi
rm -f "/tmp/claude-correction-flag-testXXX" "/tmp/claude-cursor-testXXX"

# ── Тест 1.10: cursor не перезаписывается если уже существует ──────────────────
T="1.10 cursor не перезаписывается если уже существует"
rm -f "/tmp/claude-watcher-ran-testXXX"
rm -f "/tmp/claude-correction-flag-testXXX"
echo "42" > "/tmp/claude-cursor-testXXX"
transcript=$(make_correction_transcript)
run_detect '{"session_id":"testXXX","transcript_path":"'"$transcript"'","stop_hook_active":false}' > /dev/null
rm -f "$transcript"
cursor_val=$(cat "/tmp/claude-cursor-testXXX" 2>/dev/null || echo "")
if [ "$cursor_val" = "42" ]; then
  pass "$T"
else
  fail "$T (cursor был перезаписан, теперь: $cursor_val)"
fi
rm -f "/tmp/claude-correction-flag-testXXX" "/tmp/claude-cursor-testXXX"

# ── Тест 1.11: Слова коррекции — полный список ────────────────────────────────
section "detect-correction.sh — проверка ключевых слов"

check_word() {
  local word="$1"
  local t
  rm -f "/tmp/claude-watcher-ran-testXXX"
  t=$(make_transcript <<EOF
{"type": "assistant", "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "Edit", "id": "t1", "input": {}}]}}
{"type": "user", "message": {"role": "user", "content": "$word"}}
EOF
)
  local r
  r=$(run_detect '{"session_id":"testXXX","transcript_path":"'"$t"'","stop_hook_active":false}')
  rm -f "$t" "/tmp/claude-correction-flag-testXXX" "/tmp/claude-cursor-testXXX"
  if echo "$r" | grep -q '"ok"'; then
    pass "  keyword: '$word'"
  else
    fail "  keyword: '$word' не сработал (output: $r)"
  fi
}

check_word "нет, переделай"
check_word "это неправильно"
check_word "исправь это"
check_word "сделай по-другому"
check_word "wrong answer"
check_word "redo it"
check_word "not right"
check_word "incorrect"
check_word "rework this"

# ─── Группа 2: session-start-pending.sh ──────────────────────────────────────

section "session-start-pending.sh"

# Сохраняем оригинальный pending-changes.md если он есть
if [ -f "$PENDING_FILE" ]; then
  cp "$PENDING_FILE" "${PENDING_FILE}.bak_cw_test"
fi

# ── Тест 2.1: Нет файла → тихий выход ─────────────────────────────────────────
T="2.1 нет pending-changes.md → тихий выход"
rm -f "$PENDING_FILE"
result=$(bash "$SESSION_START" 2>/dev/null || true)
if [ -z "$result" ]; then
  pass "$T"
else
  fail "$T (output: $result)"
fi

# ── Тест 2.2: Пустой файл → удалён, тихий выход ───────────────────────────────
T="2.2 пустой pending-changes.md → файл удалён, тихий выход"
touch "$PENDING_FILE"
result=$(bash "$SESSION_START" 2>/dev/null || true)
if [ -z "$result" ] && [ ! -f "$PENDING_FILE" ]; then
  pass "$T"
elif [ -n "$result" ]; then
  fail "$T (ожидался тихий выход, got: $result)"
else
  fail "$T (файл не удалён)"
fi

# ── Тест 2.3: Файл с содержимым → показывается содержимое ─────────────────────
T="2.3 pending-changes.md с содержимым → показывается"
cat > "$PENDING_FILE" <<'EOF'
## [2026-04-06] ~/.claude/rules/feedback.md
Тип: новое правило
Предложение: тест
Статус: ожидает подтверждения
EOF
result=$(bash "$SESSION_START" 2>/dev/null || true)
if echo "$result" | grep -q "config-watcher" && echo "$result" | grep -q "тест"; then
  pass "$T"
else
  fail "$T (output не содержит ожидаемого: $result)"
fi

# ── Тест 2.4: После показа файл остаётся (хук только читает, не трогает) ───────
T="2.4 после показа — файл остаётся нетронутым"
if [ -f "$PENDING_FILE" ]; then
  pass "$T"
else
  fail "$T (файл был удалён хуком, а не должен)"
fi
rm -f "$PENDING_FILE"

# Восстанавливаем оригинальный pending-changes.md
if [ -f "${PENDING_FILE}.bak_cw_test" ]; then
  mv "${PENDING_FILE}.bak_cw_test" "$PENDING_FILE"
fi

# ─── Итог ─────────────────────────────────────────────────────────────────────

section "Итог"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "Всего: $TOTAL | ${GREEN}PASS: $PASS${NC} | ${RED}FAIL: $FAIL${NC} | ${YELLOW}SKIP: $SKIP${NC}"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
