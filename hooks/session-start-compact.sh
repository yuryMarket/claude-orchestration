#!/usr/bin/env bash
# session-start-compact.sh — SessionStart hook (matcher: compact)
# Назначение: после компакции вывести сохранённый summary в stdout — он будет
#              инжектирован в контекст новой сессии Claude Code.
# Событие: SessionStart
# Matcher: compact
# Exit 0 = всегда (вывод в stdout — это и есть полезная нагрузка)
set -euo pipefail

# --- Инвариант per-session тикета при compact (AIDD-001) ----------------------
# session_id СТАБИЛЕН при compact: compaction не порождает новую сессию, id
# сохраняется (research §2, §6). Поэтому per-session файл
# ~/.claude/sessions/aidd/<session_id>.json уже существует и валиден после compact.
#
# Актуализацию per-session файла (обновление source=compact и updated) выполняет
# session-start.sh — он тоже срабатывает на событие SessionStart с source=compact
# (он зарегистрирован БЕЗ matcher, т.е. ловит все ветки, включая compact).
#
# Поэтому здесь МЕНЯТЬ логику записи per-session файла НЕ нужно — дублирование
# upsert на критическом пути восстановления контекста (timeout 10с) только
# увеличило бы blast radius. Этот хук остаётся узкоспециализированным: вывести
# сохранённый compact-summary в контекст.

# Читаем payload (может быть пустым)
PAYLOAD="$(cat 2>/dev/null || true)"

# Извлекаем CWD через python3 (с fallback на пустую строку)
CWD=""
if command -v python3 >/dev/null 2>&1 && [ -n "$PAYLOAD" ]; then
  CWD=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
fi

# Ищем summary-файл: сначала проектный, затем глобальный
SUMMARY_PATH=""
if [ -n "$CWD" ] && [ -f "$CWD/.claude/compact-summary.md" ]; then
  SUMMARY_PATH="$CWD/.claude/compact-summary.md"
elif [ -f "$HOME/.claude/compact-summary.md" ]; then
  SUMMARY_PATH="$HOME/.claude/compact-summary.md"
fi

# Выводим только если файл найден и не старше 2 часов (120 минут)
if [ -n "$SUMMARY_PATH" ]; then
  if find "$SUMMARY_PATH" -mmin -120 -print -quit 2>/dev/null | grep -q . ; then
    echo "=== КОНТЕКСТ ВОССТАНОВЛЕН ПОСЛЕ COMPACT ==="
    cat "$SUMMARY_PATH" 2>/dev/null || true
    echo ""
    echo "=== КОНЕЦ ВОССТАНОВЛЕННОГО КОНТЕКСТА ==="
  fi
fi

exit 0
