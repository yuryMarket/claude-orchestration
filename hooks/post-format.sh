#!/usr/bin/env bash
# post-format.sh — PostToolUse hook авто-форматирования отредактированных файлов
# Событие: PostToolUse | Matcher: Edit|Write
# Назначение: после Edit/Write прогнать подходящий форматтер по расширению файла.
# Fail-open (строгий): нет форматтера в PATH / неизвестное расширение / любая ошибка → тихий exit 0.
# Побочные эффекты изолированы: форматируется ТОЛЬКО существующий отредактированный файл
#   (исключение — .tf/.tfvars: terraform fmt работает по КАТАЛОГУ, см. ветку ниже).
set -euo pipefail

# Читаем stdin PostToolUse JSON (может быть пустым — тогда просто выходим).
INPUT="$(cat 2>/dev/null || true)"

# jq обязателен для извлечения пути. Нет jq → тихий выход (fail-open).
command -v jq >/dev/null 2>&1 || exit 0

# Извлекаем путь отредактированного файла из tool_input.file_path.
FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"

# Нет пути — форматировать нечего.
[ -n "$FILE_PATH" ] || exit 0

# Форматируем только существующие файлы: не трогаем несуществующие/удалённые пути.
[ -f "$FILE_PATH" ] || exit 0

# Не трогаем отчёты и артефакты в ~/docs — это документация, форматтеры её не касаются.
case "$FILE_PATH" in
  "$HOME/docs/"*) exit 0 ;;
esac

# Выбор форматтера по расширению. Форматтер отсутствует в PATH → тихий exit 0.
# Любая ошибка самого форматтера гасится `|| true` → строгий fail-open.
ext="${FILE_PATH##*.}"
case "$ext" in
  py)
    command -v ruff >/dev/null 2>&1 || exit 0
    ruff format "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
  ts|tsx|js|jsx|json|md)
    command -v prettier >/dev/null 2>&1 || exit 0
    prettier --write "$FILE_PATH" >/dev/null 2>&1 || true
    ;;
  tf|tfvars)
    command -v terraform >/dev/null 2>&1 || exit 0
    # ВНИМАНИЕ: `terraform fmt` принимает КАТАЛОГ, а не одиночный файл — на путь-файл он
    # ничего не форматирует. Поэтому форматируем каталог отредактированного файла:
    # `dirname "$FILE_PATH"`. ОСОЗНАННЫЙ побочный эффект: заодно форматируются и СОСЕДНИЕ
    # .tf/.tfvars того же каталога — это приемлемо (единый стиль каталога Terraform).
    # Любая ошибка форматтера гасится `|| true` → строгий fail-open сохранён.
    terraform fmt "$(dirname "$FILE_PATH")" >/dev/null 2>&1 || true
    ;;
  *)
    # Неизвестное расширение — форматтер не выбран, ничего не делаем.
    exit 0
    ;;
esac

# Успех либо погашенная ошибка форматтера — в любом случае не блокируем (PostToolUse не блокирует).
exit 0
