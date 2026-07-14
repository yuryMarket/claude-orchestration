#!/usr/bin/env bash
# detect-correction.sh — Stop hook для обнаружения паттернов коррекции
# Событие: Stop
# Назначение: если пользователь ОТРИЦАЕТ оценку сделанного (в НАЧАЛЕ сообщения) И Claude делал
#             Edit/Write — ставит флаг для запуска config-watcher анализа.
# Exit 0 = продолжить нормально
# {"ok": false} = попросить Claude продолжить (запустит config-watcher)
#
# Ужесточение (AIDD-003, 5.2): сигнал коррекции — ТОЛЬКО слова-отрицания оценки сделанного
#   в НАЧАЛЕ сообщения (нет, / не так / неправильно / не то / wrong / not right / that's not /
#   incorrect). Императивы (переделай/измени/исправь/redo/fix it/rework) сами по себе НЕ триггерят —
#   учитываются лишь как УСИЛИТЕЛЬ после отрицания. Плюс rate-limit: не чаще 1 раза в 4 часа/сессию.

# Fail-open (AIDD-003, review-fix): Stop-хук НЕ блокирует ответ Claude и НИКОГДА не должен падать.
# `set -euo pipefail` оставлен СОЗНАТЕЛЬНО и безопасен ТОЛЬКО потому, что ВСЕ подстановки ниже
# защищены (`|| echo ...` / `|| true`). Без защиты битая строка транскрипта уронила бы `jq`,
# pipefail пробросил бы non-zero через `| tail`, и set -e аварийно завершил бы хук (нарушив
# fail-open). Тот же подход в session-start.sh: set -euo pipefail + все подстановки защищены.
set -euo pipefail

# Читаем stdin (пустой/битый stdin — норма: подстановка защищена, INPUT станет пустым).
INPUT="$(cat 2>/dev/null || true)"

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

# Находим последнее сообщение пользователя.
# Реальный формат транскрипта: {message: {role: "user", content: [...]}, type: "user"}.
# `|| echo ""` ОБЯЗАТЕЛЕН при set -euo pipefail: на битой строке транскрипта jq выходит с non-zero,
# pipefail пробрасывает этот код через `| tail`, и без защиты set -e аварийно завершил бы хук.
# С защитой подстановка отдаёт пустую строку → срабатывает обычный тихий exit 0 ниже (fail-open).
LAST_USER_MSG="$(jq -r 'select(.message.role == "user") | .message.content | if type == "array" then .[].text // "" else . end' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")"

# Фолбэк на плоский формат {role: "user", content: ...} (та же защита `|| echo ""`, тот же мотив).
if [ -z "$LAST_USER_MSG" ]; then
  LAST_USER_MSG="$(jq -r 'select(.role == "user") | .content // ""' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || echo "")"
fi

if [ -z "$LAST_USER_MSG" ]; then
  exit 0
fi

# --- Условие A: ОТРИЦАНИЕ оценки сделанного В НАЧАЛЕ сообщения (ОБЯЗАТЕЛЬНОЕ условие) -----------
# Берём только начало сообщения: первую строку и ~первые 40 символов. Это и реализует «в начале»:
# отрицание глубоко в длинном поручении («исправь баг ... там всё не так») НЕ считается коррекцией.
HEAD_LINE="${LAST_USER_MSG%%$'\n'*}"
HEAD="${HEAD_LINE:0:40}"

# Якорь ^ с допуском ведущих пробелов/пунктуации (маркеры списков, кавычки, тире).
# Кириллица: явный [Нн] на случай, если grep -i не сворачивает регистр в текущей локали.
NEGATION_START='^[[:space:][:punct:]]*([Нн]ет,|[Нн]е так|[Нн]еправильно|[Нн]е то|wrong|not right|that.?s not|incorrect)'
NEGATION_AT_START=false
if printf '%s' "$HEAD" | grep -qiE "$NEGATION_START"; then
  NEGATION_AT_START=true
fi

# Нет отрицания в начале → это обычное поручение (в т.ч. «исправь баг в модуле X»), выходим.
if [ "$NEGATION_AT_START" = "false" ]; then
  exit 0
fi

# Императив — только УСИЛИТЕЛЬ после отрицания (сам по себе не триггерит). Нужен лишь для reason.
IMPERATIVE_PATTERN='(переделай|измени|исправь|сделай по.другому|redo|fix it|rework)'
AMPLIFIER=""
if printf '%s' "$LAST_USER_MSG" | grep -qiE "$IMPERATIVE_PATTERN"; then
  AMPLIFIER=" + императив"
fi

# --- Условие B: Claude вызывал Edit или Write -------------------------------------------------
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

# --- Rate-limit: не чаще 1 раза в 4 часа на сессию --------------------------------------------
# Marker-файл в /tmp; если моложе 4ч (14400 c) — тихий exit 0 (не шумим config-watcher-ом).
RATELIMIT_MARKER="/tmp/claude-correction-ratelimit-${SESSION_ID}"
if [ -f "$RATELIMIT_MARKER" ]; then
  now="$(date +%s 2>/dev/null || echo 0)"
  mtime="$(stat -f %m "$RATELIMIT_MARKER" 2>/dev/null || stat -c %Y "$RATELIMIT_MARKER" 2>/dev/null || echo 0)"
  age=$(( now - mtime ))
  if [ "$age" -lt 14400 ]; then
    exit 0
  fi
fi
# Обновляем метку времени последнего срабатывания (идемпотентно).
touch "$RATELIMIT_MARKER" 2>/dev/null || true

# Оба условия выполнены и rate-limit пройден — ставим флаг коррекции.
echo "$TRANSCRIPT_PATH" > "/tmp/claude-correction-flag-${SESSION_ID}"

# Инициализируем курсор если ещё не существует
CURSOR_FILE="/tmp/claude-cursor-${SESSION_ID}"
if [ ! -f "$CURSOR_FILE" ]; then
  TOTAL_MSGS="$(jq -s 'length' "$TRANSCRIPT_PATH" 2>/dev/null || echo '0')"
  echo "$TOTAL_MSGS" > "$CURSOR_FILE"
fi

# Возвращаем ok: false чтобы Claude запустил config-watcher
echo "{\"ok\": false, \"reason\": \"Обнаружена коррекция пользователя (отрицание в начале${AMPLIFIER}). Запускаю config-watcher для анализа.\"}"
exit 0
