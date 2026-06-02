#!/usr/bin/env bash
# test-helpers.sh — Утилиты изоляции для bash-тестов per-session логики AIDD (тикет AIDD-001, T.1)
# НЕ event-хук, НЕ регистрируется в settings.json. Подключается через `source` из тестов.
#
# КРИТИЧНО: тесты ПОЛНОСТЬЮ изолированы. setup_test_env создаёт временный HOME (TEST_HOME)
#   и временный cwd (TEST_CWD). Тесты переопределяют HOME=$TEST_HOME, чтобы хуки и библиотеки
#   писали per-session файлы в $TEST_HOME/.claude/sessions/aidd, НИКОГДА не трогая реальный
#   ~/.claude/sessions/aidd и реальные хуки-артефакты.
#
# Экспортируемые переменные:
#   TEST_HOME — корень временного HOME (содержит .claude/sessions/aidd/ и зеркало .claude/hooks/)
#   TEST_CWD  — временная рабочая директория проекта (содержит docs/)
#
# Функции:
#   setup_test_env()    — создаёт изолированное окружение; идемпотентна; безопасна без аргументов
#   teardown_test_env() — удаляет временные каталоги; идемпотентна; безопасна без аргументов
#   backdate_file <file> <days> — выставляет mtime файла на N дней назад (GNU/BSD-портабельно)
#
# Здесь НЕТ `set -euo pipefail` — файл подключается в раннер, который сам управляет режимом.

# Абсолютный путь к каталогу _lib (где лежат тестируемые библиотеки и сам этот файл).
# Захватывается в момент source (до любого переопределения HOME) — используется тестами
# для source aidd-ticket.sh / aidd-session-id.sh независимо от cwd.
# shellcheck disable=SC2034
TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Корень РЕАЛЬНЫХ хуков (на уровень выше _lib) — настоящие session-start.sh / gate-workflow.sh.
# Захватывается до переопределения HOME, поэтому всегда указывает на ~/.claude/hooks.
# shellcheck disable=SC2034
TEST_HOOKS_DIR="$(cd "$TEST_LIB_DIR/.." && pwd)"

# setup_test_env — создать tmp HOME (со структурой .claude/sessions/aidd/ + зеркалом .claude/hooks/)
# и tmp cwd (с docs/). Безопасна при вызове без аргументов. Экспортирует TEST_HOME и TEST_CWD.
setup_test_env() {
  # Если уже инициализировано в этом процессе — сначала очищаем (идемпотентность).
  if [ -n "${TEST_HOME:-}" ] && [ -d "${TEST_HOME:-/nonexistent}" ]; then
    teardown_test_env
  fi

  TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/aidd-test-home.XXXXXX")"
  TEST_CWD="$(mktemp -d "${TMPDIR:-/tmp}/aidd-test-cwd.XXXXXX")"
  export TEST_HOME TEST_CWD

  # Структура per-session хранилища внутри изолированного HOME.
  # Это ЕДИНСТВЕННОЕ место, куда хуки пишут per-session файлы при HOME=$TEST_HOME —
  # реальный ~/.claude/sessions/aidd НИКОГДА не затрагивается.
  mkdir -p "$TEST_HOME/.claude/sessions/aidd"

  # КРИТИЧНО: тестируемые хуки (session-start.sh, gate-workflow.sh) подключают свои
  # sourced-библиотеки по пути $HOME/.claude/hooks/_lib/... При запуске с HOME=$TEST_HOME
  # этот путь вёл бы в пустой временный HOME, библиотеки (resolve_ticket/resolve_session_id)
  # не подключились бы, и хуки молча деградировали бы в legacy-режим (ломая T.6).
  # Поэтому зеркалим РЕАЛЬНЫЕ хуки и _lib в TEST_HOME симлинками: исполняется настоящий код,
  # а per-session ХРАНИЛИЩЕ остаётся изолированным (реальные хуки только читаются по симлинку).
  mkdir -p "$TEST_HOME/.claude/hooks"
  local real_hooks="${TEST_HOOKS_DIR:-$HOME/.claude/hooks}"
  local entry name
  for entry in "$real_hooks"/* "$real_hooks"/.[!.]*; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    ln -sf "$entry" "$TEST_HOME/.claude/hooks/$name" 2>/dev/null || true
  done

  # Рабочая директория проекта с docs/ (legacy-указатель и артефакты живут здесь).
  mkdir -p "$TEST_CWD/docs"

  return 0
}

# teardown_test_env — удалить временные каталоги. Идемпотентна; безопасна без аргументов.
teardown_test_env() {
  # Защита: удаляем только то, что похоже на наши mktemp-каталоги, и только если переменная задана.
  if [ -n "${TEST_HOME:-}" ] && [ -d "${TEST_HOME:-/nonexistent}" ]; then
    case "$TEST_HOME" in
      */aidd-test-home.*) rm -rf "$TEST_HOME" 2>/dev/null || true ;;
    esac
  fi
  if [ -n "${TEST_CWD:-}" ] && [ -d "${TEST_CWD:-/nonexistent}" ]; then
    case "$TEST_CWD" in
      */aidd-test-cwd.*) rm -rf "$TEST_CWD" 2>/dev/null || true ;;
    esac
  fi
  unset TEST_HOME TEST_CWD
  return 0
}

# backdate_file <file> <days> — выставить mtime файла на <days> дней в прошлое.
# Портабельно: сперва GNU `touch -d "<N> days ago"`, при неудаче — BSD `touch -t` + `date -v`.
# Нужно для TTL-теста (mtime +14): на macOS BSD touch не понимает относительные даты в -d.
backdate_file() {
  local file="${1:-}"
  local days="${2:-15}"
  [ -n "$file" ] || return 0

  if touch -d "${days} days ago" "$file" 2>/dev/null; then
    return 0
  fi
  # BSD-ветка (macOS): вычисляем timestamp формата [[CC]YY]MMDDhhmm через date -v.
  local ts
  ts="$(date -v-"${days}"d +%Y%m%d%H%M 2>/dev/null || echo "")"
  if [ -n "$ts" ]; then
    touch -t "$ts" "$file" 2>/dev/null || true
  fi
  return 0
}
