#!/usr/bin/env bash
# aidd-write-legacy.sh — Исполняемый helper (НЕ event-хук, НЕ регистрируется в settings.json)
# Назначение: УСЛОВНАЯ запись legacy-указателя <cwd>/docs/.active_ticket — не перетирает
#             указатель параллельной сессии (чужой тикет).
# Вызов: bash "$HOME/.claude/hooks/_lib/aidd-write-legacy.sh" <cwd> <ticket>
#        (из workflow.md шаг 2c, skills/idea шаг 3.3, agents/analyst шаг 9)
#
# ВАЖНО: здесь НЕТ `set -euo pipefail` на уровне файла — единый стиль с другими _lib/.
#        Все операции fail-open: при любом сбое (нет каталога, нет python3, нет aidd-ticket.sh)
#        деградация и exit 0. ВСЕГДА завершаемся успешно — это write-path, не gate.
#
# Аргументы:
#   <cwd>    — рабочая директория сессии (нормализуется strip trailing slash; пустой → pwd)
#   <ticket> — id тикета для записи (если пуст → exit 0, файл не создаётся)
#
# Логика записи (УСЛОВНАЯ):
#   target := <cwd>/docs/.active_ticket
#   current := текущее значение target (trim пробелов; пусто, если файла нет)
#   - current пуст ИЛИ current == ticket → записать ticket атомарно (tmp + mv)
#   - current содержит ДРУГОЙ тикет     → НЕ трогать; предупреждение в stderr; exit 0
#
# Идемпотентность: повторный вызов с тем же тикетом перезаписывает то же значение (no-op по сути).

cwd="${1:-}"
ticket="${2:-}"

# Нечего писать — тикет не задан. Файл не создаём.
if [ -z "$ticket" ]; then
  exit 0
fi

# Валидация ticket: значение подставляется в путь target и пишется в файл. Multiline/мусор
# (перевод строки, пробелы, слэши, спецсимволы) → тихая порча при последующем чтении (склейка
# строк через trim). Whitelist [a-zA-Z0-9._-] отсекает всё перечисленное. По образцу валидации
# session_id в aidd-session-id.sh. Невалидный ticket НЕ пишем, fail-open: exit 0.
case "$ticket" in *[!a-zA-Z0-9._-]*) exit 0 ;; esac

# Нормализация cwd: удаляем единственный trailing slash; пустой cwd → текущая pwd.
cwd="${cwd%/}"
if [ -z "$cwd" ]; then
  cwd="$(pwd 2>/dev/null || echo "")"
fi
# Если cwd так и не определился — писать некуда, тихо выходим (fail-open).
if [ -z "$cwd" ]; then
  exit 0
fi

target="$cwd/docs/.active_ticket"

# Читаем текущее значение. Переиспользуем _aidd_read_legacy из aidd-ticket.sh ради единой
# функции trim (DRY). Если библиотека недоступна — деградация к inline-чтению через cat | tr.
current=""
if [ -f "$HOME/.claude/hooks/_lib/aidd-ticket.sh" ]; then
  # ИНВАРИАНТ (см. шапку aidd-ticket.sh): файл не содержит кода верхнего уровня (только функции
  # и комментарии) — source безопасен, побочных эффектов в текущем процессе нет.
  . "$HOME/.claude/hooks/_lib/aidd-ticket.sh"
  current="$(_aidd_read_legacy "$target")"
elif [ -f "$target" ]; then
  current="$(cat "$target" 2>/dev/null | tr -d '[:space:]' 2>/dev/null || echo "")"
fi

# Защита от перетирания: файл содержит ДРУГОЙ тикет (реально только при параллельной сессии).
if [ -n "$current" ] && [ "$current" != "$ticket" ]; then
  echo "AIDD: legacy docs/.active_ticket=$current принадлежит другой сессии — пропускаю запись $ticket" >&2
  exit 0
fi

# Запись разрешена (current пуст ИЛИ current == ticket). Создаём каталог при необходимости.
mkdir -p "$cwd/docs" 2>/dev/null || exit 0

# Атомарная запись: пишем во временный файл и переименовываем (mv атомарен в пределах ФС).
tmp="$target.tmp.$$"
printf '%s\n' "$ticket" > "$tmp" 2>/dev/null && mv -f "$tmp" "$target" 2>/dev/null || rm -f "$tmp" 2>/dev/null

exit 0  # fail-open: всегда успех (write-path, не блокирующий gate)
