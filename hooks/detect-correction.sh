#!/usr/bin/env bash
# detect-correction.sh — Stop hook для обнаружения паттернов коррекции
# Событие: Stop
# Назначение: если пользователь скорректировал Claude И Claude делал Edit/Write —
#             ставит флаг для запуска config-watcher анализа
# Exit 0 = продолжить нормально
# {"ok": false} = попросить Claude продолжить (запустит config-watcher)

set -euo pipefail

# Читаем stdin
INPUT="$(cat)"

# Защита от бесконечного цикла
STOP_HOOK_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo 'false')"
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Получаем session_id и transcript_path
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo '')"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo '')"

# Если нет данных — выходим
if [ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Проверяем флаг повторного запуска watcher-а
WATCHER_FLAG="/tmp/claude-watcher-ran-${SESSION_ID}"
if [ -f "$WATCHER_FLAG" ]; then
  # Сбрасываем флаг для следующего обмена
  rm -f "$WATCHER_FLAG"
  exit 0
fi

# Проверка: есть ли jq
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Находим последнее сообщение пользователя
# Реальный формат транскрипта: {message: {role: "user", content: [...]}, type: "user"}
LAST_USER_MSG="$(jq -r 'select(.message.role == "user") | .message.content | if type == "array" then .[].text // "" else . end' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)"

# Фолбэк на плоский формат {role: "user", content: ...}
if [ -z "$LAST_USER_MSG" ]; then
  LAST_USER_MSG="$(jq -r 'select(.role == "user") | .content // ""' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1)"
fi

if [ -z "$LAST_USER_MSG" ]; then
  exit 0
fi

# Условие A: слова-коррекции в последнем сообщении пользователя
CORRECTION_PATTERN='(нет[,\s]|не так|неправильно|переделай|измени|исправь|сделай по.другому|не то|wrong|redo|fix it|not right|that.s not|incorrect|rework)'
CONDITION_A=false
if echo "$LAST_USER_MSG" | grep -qiE "$CORRECTION_PATTERN"; then
  CONDITION_A=true
fi

if [ "$CONDITION_A" = "false" ]; then
  exit 0
fi

# Условие B: Claude вызывал Edit или Write
# Реальный формат: message.content[].type == "tool_use" и message.content[].name == "Edit"|"Write"
CONDITION_B=false
if jq -r 'select(.message.role == "assistant") | .message.content[]? | select(.type == "tool_use") | .name // ""' "$TRANSCRIPT_PATH" 2>/dev/null | grep -qE '^(Edit|Write)$'; then
  CONDITION_B=true
fi

# Фолбэк на плоский формат
if [ "$CONDITION_B" = "false" ]; then
  if jq -r 'select(.role == "assistant") | .content[]? | select(type == "object") | select(.type == "tool_use") | .name // ""' "$TRANSCRIPT_PATH" 2>/dev/null | grep -qE '^(Edit|Write)$'; then
    CONDITION_B=true
  fi
fi

if [ "$CONDITION_B" = "false" ]; then
  exit 0
fi

# Оба условия выполнены — ставим флаг коррекции
echo "$TRANSCRIPT_PATH" > "/tmp/claude-correction-flag-${SESSION_ID}"

# Инициализируем курсор если ещё не существует
CURSOR_FILE="/tmp/claude-cursor-${SESSION_ID}"
if [ ! -f "$CURSOR_FILE" ]; then
  TOTAL_MSGS="$(jq -s 'length' "$TRANSCRIPT_PATH" 2>/dev/null || echo '0')"
  echo "$TOTAL_MSGS" > "$CURSOR_FILE"
fi

# Возвращаем ok: false чтобы Claude запустил config-watcher
echo '{"ok": false, "reason": "Обнаружена коррекция пользователя. Запускаю config-watcher для анализа."}'
exit 0
