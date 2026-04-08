#!/usr/bin/env bash
# session-start-pending.sh — SessionStart hook для показа незакрытых предложений
# Событие: SessionStart
# Назначение: показать содержимое pending-changes.md если он существует

set -euo pipefail

PENDING_FILE="${HOME}/.claude/pending-changes.md"

# Если файла нет — выходим тихо
if [ ! -f "$PENDING_FILE" ]; then
  exit 0
fi

# Если файл пустой — удаляем и выходим
if [ ! -s "$PENDING_FILE" ]; then
  rm -f "$PENDING_FILE"
  exit 0
fi

# Показываем содержимое
echo "=== config-watcher: незакрытые предложения ==="
echo "Есть предложения по изменению конфигов от предыдущей сессии:"
echo ""
cat "$PENDING_FILE"
echo ""
echo "Команды: 'применить pending changes' | 'отклонить pending changes' | продолжи работу (сохранятся до следующей сессии)"
echo "================================================"

exit 0
