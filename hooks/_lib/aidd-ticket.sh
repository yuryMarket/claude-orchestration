#!/usr/bin/env bash
# aidd-ticket.sh — Sourced-библиотека (НЕ event-хук, НЕ регистрируется в settings.json)
# Назначение: двухуровневая (per-session → docs/.active_ticket → none) резолюция активного AIDD-тикета.
# Подключение: source "$HOME/.claude/hooks/_lib/aidd-ticket.sh"  (из session-start.sh, gate-workflow.sh)
#
# ВАЖНО: здесь НЕТ `set -euo pipefail` на уровне файла — он повлиял бы на вызывающий хук.
#        Все операции fail-open: при отсутствии файла, битом JSON или отсутствии python3 —
#        предупреждение в stderr и переход к следующему уровню. НИКОГДА не завершаемся ошибкой.
#
# ИНВАРИАНТ: файл НЕ содержит кода верхнего уровня (только функции и комментарии) — безопасно
#        source-ить из других хуков/helper (например, aidd-write-legacy.sh подключает его ради
#        функции _aidd_read_legacy). При добавлении кода верхнего уровня этот инвариант нарушится:
#        source начнёт выполнять побочные эффекты в процессе вызывающего. НЕ добавлять top-level код.
#
# Функция: resolve_ticket <cwd> <session_id>
#   <cwd>        — абсолютный путь рабочей директории сессии (для cwd-guard и legacy-путей)
#   <session_id> — id сессии (может быть пустым; извлечение id — ответственность aidd-session-id.sh)
#   Результат — в глобальные переменные:
#     TICKET      — id активного тикета (пустая строка, если не найден)
#     TICKET_SRC  — источник: session | legacy | none
#
# Цепочка резолюции (первый успех выигрывает):
#   1) ~/.claude/sessions/aidd/<session_id>.json  (.ticket), guard: .cwd == <cwd>   → session
#   2) <cwd>/docs/.active_ticket                  (legacy plain-text)                → legacy
#   3) иначе                                                                          → none
# cwd нормализуется (strip trailing slash) перед cwd-guard и построением legacy-пути.

# _aidd_json_field <json-file> <field>
# Извлекает строковое поле верхнего уровня из JSON-файла.
# python3 при наличии, иначе grep-fallback. Печатает значение в stdout (или пусто).
# Никогда не завершается с ошибкой (fail-open к "").
_aidd_json_field() {
  local file="${1:-}"
  local field="${2:-}"
  [ -n "$file" ] && [ -n "$field" ] && [ -f "$file" ] || { echo ""; return 0; }

  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys,json
try:
    with open(sys.argv[1], encoding='utf-8') as fh:
        print(json.load(fh).get(sys.argv[2], '') or '')
except Exception:
    print('')" "$file" "$field" 2>/dev/null || echo ""
  else
    # grep-fallback: вытащить значение строкового поля "<field>": "<value>"
    grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
      | head -1 \
      | sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"//; s/\"$//" \
      2>/dev/null || echo ""
  fi
}

# _aidd_read_legacy <path>
# Читает legacy plain-text указатель, обрезает все пробелы/переводы строк.
# Печатает результат в stdout (или пусто). Не зависит от внешних утилит (tr/sed) —
# чистый bash, чтобы оставаться надёжным на горячем пути и при нестандартном PATH.
_aidd_read_legacy() {
  local path="${1:-}"
  [ -n "$path" ] && [ -f "$path" ] || { echo ""; return 0; }
  local raw=""
  raw="$(cat "$path" 2>/dev/null || echo "")"
  # Удаляем все пробельные символы (пробел, таб, CR, LF) bash-расширением.
  raw="${raw//[$' \t\r\n']/}"
  echo "$raw"
}

# resolve_ticket <cwd> <session_id>
# Заполняет глобальные переменные TICKET и TICKET_SRC.
resolve_ticket() {
  local cwd="${1:-}"
  cwd="${cwd%/}"
  local session_id="${2:-}"
  TICKET=""
  TICKET_SRC="none"

  # --- Уровень 1: per-session JSON с cwd-guard --------------------------------
  if [ -n "$session_id" ]; then
    local session_file="$HOME/.claude/sessions/aidd/${session_id}.json"
    if [ -f "$session_file" ]; then
      # cwd-guard: тикет применяется только если .cwd в файле совпадает с переданным cwd.
      local file_cwd
      file_cwd="$(_aidd_json_field "$session_file" "cwd")"
      local file_ticket
      file_ticket="$(_aidd_json_field "$session_file" "ticket")"

      if [ -z "$file_cwd" ] && [ -z "$file_ticket" ]; then
        # Поля не извлеклись — вероятно битый JSON или непригодный fallback.
        echo "AIDD: corrupt session file $session_file, falling back" >&2
      elif [ -n "$cwd" ] && [ "$file_cwd" != "$cwd" ]; then
        # cwd не совпадает — этот тикет принадлежит другому проекту. Тихий переход к legacy.
        :
      elif [ -n "$file_ticket" ]; then
        TICKET="$file_ticket"
        TICKET_SRC="session"
        return 0
      fi
      # Иначе (ticket пуст, но JSON валиден) — fail-open к legacy ниже.
    fi
    # Файла нет — это норма (сессия без per-session записи). Тихо идём в legacy.
  fi

  # --- Уровень 2: <cwd>/docs/.active_ticket (legacy) --------------------------
  if [ -n "$cwd" ]; then
    local legacy1="$cwd/docs/.active_ticket"
    local t1
    t1="$(_aidd_read_legacy "$legacy1")"
    if [ -n "$t1" ]; then
      TICKET="$t1"
      TICKET_SRC="legacy"
      return 0
    fi
  fi

  # --- Уровень 3: ничего не найдено -------------------------------------------
  TICKET=""
  TICKET_SRC="none"
  return 0
}
