#!/usr/bin/env bash
# aidd-session-id.sh — Sourced-библиотека (НЕ event-хук, НЕ регистрируется в settings.json)
# Назначение: определить session_id текущей сессии Claude Code из доступных источников.
# Подключение: source "$HOME/.claude/hooks/_lib/aidd-session-id.sh"  (из session-start.sh, gate-workflow.sh)
#
# ВАЖНО: здесь НЕТ `set -euo pipefail` на уровне файла — он повлиял бы на вызывающий хук.
#        Ошибки гасятся локально внутри функции (|| echo "", 2>/dev/null, fail-open к "").
#
# Функция: resolve_session_id <payload>
#   <payload> — JSON-строка из stdin хука (может быть пустой)
#   Результат — в глобальную переменную SID (пустая строка, если id определить не удалось).
#
# Цепочка определения id (первый непустой выигрывает):
#   1) ${CLAUDE_CODE_SESSION_ID:-}                      # env-var (CLI v2.1.132+); быстрый путь
#   2) .session_id из payload JSON                       # присутствует во всех версиях CLI
#   3) basename .transcript_path .jsonl из payload JSON  # последний шанс (research §3 вариант C)
#   4) ""                                                # деградация: id неизвестен → legacy-режим

# resolve_session_id <payload>
# Заполняет глобальную переменную SID.
#
# БЕЗОПАСНОСТЬ (path traversal): session_id приходит из НЕДОВЕРЕННОГО stdin и далее
#   подставляется в пути файлов (~/.claude/sessions/aidd/<SID>.json, tmp+mv, find TTL).
#   Поэтому здесь — ЕДИНАЯ точка валидации: какой бы источник ни заполнил SID
#   (env-var, .session_id, basename transcript_path), значение нормализуется ОДИН РАЗ
#   в самом конце (см. финальный блок). Невалидный SID → SID="" → деградация к legacy.
#   Поток специально устроен так, что промежуточные шаги ТОЛЬКО присваивают SID, а
#   единственный возврат — после финальной валидации внизу функции.
resolve_session_id() {
  local payload="${1:-}"
  SID=""

  # Шаг 1: env-var (быстрый путь, не требует парсинга JSON)
  SID="${CLAUDE_CODE_SESSION_ID:-}"

  # Шаги 2–3 требуют payload и нужны лишь если шаг 1 не дал значения.
  if [ -z "$SID" ] && [ -n "$payload" ]; then
    if command -v python3 >/dev/null 2>&1; then
      # Шаг 2: .session_id из JSON
      SID="$(printf '%s' "$payload" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('session_id','') or '')" \
        2>/dev/null || echo "")"

      # Шаг 3: basename transcript_path .jsonl (только если шаг 2 пуст)
      if [ -z "$SID" ]; then
        local transcript
        transcript="$(printf '%s' "$payload" | python3 -c \
          "import sys,json; print(json.load(sys.stdin).get('transcript_path','') or '')" \
          2>/dev/null || echo "")"
        if [ -n "$transcript" ]; then
          SID="$(basename "$transcript" .jsonl 2>/dev/null || echo "")"
        fi
      fi
    else
      # python3 недоступен — grep-fallback для извлечения .session_id из JSON.
      # Паттерн как в gate-workflow.sh: вытащить значение строкового поля.
      SID="$(printf '%s' "$payload" \
        | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 \
        | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//; s/"$//' \
        2>/dev/null || echo "")"

      # grep-fallback для transcript_path → basename (только если шаг 2 пуст)
      if [ -z "$SID" ]; then
        local transcript
        transcript="$(printf '%s' "$payload" \
          | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
          | head -1 \
          | sed 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"//; s/"$//' \
          2>/dev/null || echo "")"
        if [ -n "$transcript" ]; then
          SID="$(basename "$transcript" .jsonl 2>/dev/null || echo "")"
        fi
      fi
    fi
  fi

  # --- ЕДИНАЯ валидация ПЕРЕД финальным возвратом SID (path-traversal guard) ----
  # Применяется ОДИН РАЗ, ко всем источникам id (env-var, .session_id, transcript basename).
  # whitelist [a-zA-Z0-9._-] отсекает слэши, glob (* [ ]), пробелы и прочие спецсимволы;
  # отдельно отсекаются `.` и `..` (иначе путь вида .json в корне хранилища). Невалидный → "".
  case "$SID" in ''|*[!a-zA-Z0-9._-]*) SID="" ;; esac
  case "$SID" in .|..) SID="" ;; esac

  return 0
}
