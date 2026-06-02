#!/usr/bin/env bash
# test-write-legacy.sh — bash-тесты helper aidd-write-legacy.sh (тикет AIDD-002, T.2)
# Тестируемый компонент: ~/.claude/hooks/_lib/aidd-write-legacy.sh
#   Вызов: bash aidd-write-legacy.sh <cwd> <ticket>  → УСЛОВНАЯ запись <cwd>/docs/.active_ticket.
#   Контракт helper: fail-open, всегда exit 0; не перетирает указатель другой сессии (чужой тикет);
#   при пустом ticket файл не создаётся; запись разрешена, если файл пуст или содержит тот же тикет.
#
# Изоляция: каждый тест работает в TEST_HOME/TEST_CWD (см. test-helpers.sh). Helper запускается
#   как ОТДЕЛЬНЫЙ процесс с HOME=$TEST_HOME и cwd-аргументом=$TEST_CWD — поэтому он пишет в
#   <TEST_CWD>/docs/.active_ticket, а source aidd-ticket.sh берётся из зеркала хуков в $TEST_HOME.
#   Реальный проект и реальный ~/.claude НИКОГДА не затрагиваются.
#   Запуск через subprocess (не source) обязателен: helper делает `exit 0`, что в source-контексте
#   завершило бы сам раннер.
#
# Контракт для раннера: функции test_* возвращают 0 (PASS) либо печатают причину в stderr и
#   возвращают 1 (FAIL). Никаких побочных эффектов вне TEST_HOME/TEST_CWD.

# --- Вспомогательное: абсолютный путь к тестируемому helper --------------------
# TEST_LIB_DIR экспортируется test-helpers.sh и указывает на реальный каталог _lib
# (захвачен до переопределения HOME). Helper лежит рядом с aidd-ticket.sh.
_write_legacy_helper() {
  echo "${TEST_LIB_DIR:-$HOME/.claude/hooks/_lib}/aidd-write-legacy.sh"
}

# T.C1 — docs/.active_ticket отсутствует → helper создаёт файл с тикетом, exit 0.
test_write_legacy_empty_file_writes() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  # setup создаёт docs/, но файла указателя быть не должно — это сценарий «пусто».
  rm -f "$target" 2>/dev/null || true

  HOME="$TEST_HOME" bash "$helper" "$TEST_CWD" "FEAT-NEW-001"
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  empty: ожидался exit 0, получено $helper_rc" >&2
    rc=1
  fi
  if [ ! -f "$target" ]; then
    echo "  empty: файл $target не создан" >&2
    rc=1
  else
    local got
    got="$(cat "$target" 2>/dev/null | tr -d '[:space:]')"
    if [ "$got" != "FEAT-NEW-001" ]; then
      echo "  empty: ожидался тикет FEAT-NEW-001 в файле, получено '$got'" >&2
      rc=1
    fi
  fi

  teardown_test_env
  return "$rc"
}

# T.C2 — файл уже содержит ТОТ ЖЕ тикет → повторный вызов идемпотентен (тот же тикет), exit 0.
test_write_legacy_same_ticket_idempotent() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  # Предсостояние: файл уже содержит тот же тикет, который мы попросим записать.
  echo "FEAT-SAME-002" >"$target"

  HOME="$TEST_HOME" bash "$helper" "$TEST_CWD" "FEAT-SAME-002"
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  same: ожидался exit 0, получено $helper_rc" >&2
    rc=1
  fi
  local got
  got="$(cat "$target" 2>/dev/null | tr -d '[:space:]')"
  if [ "$got" != "FEAT-SAME-002" ]; then
    echo "  same: ожидался неизменный тикет FEAT-SAME-002, получено '$got'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.C3 — файл содержит ДРУГОЙ тикет → значение НЕ перетёрто, stderr содержит предупреждение, exit 0.
test_write_legacy_other_ticket_not_overwritten() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  # Предсостояние: указатель уже занят ЧУЖИМ тикетом (параллельная сессия).
  echo "FEAT-EXISTING-003" >"$target"

  # Перехватываем stderr — helper должен предупредить, что пропускает запись.
  local errf
  errf="$(mktemp "${TMPDIR:-/tmp}/aidd-write-legacy-err.XXXXXX")"
  HOME="$TEST_HOME" bash "$helper" "$TEST_CWD" "FEAT-INTRUDER-999" 2>"$errf"
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  other: ожидался exit 0 (fail-open), получено $helper_rc" >&2
    rc=1
  fi
  # Значение не должно измениться — чужой тикет остаётся на месте.
  local got
  got="$(cat "$target" 2>/dev/null | tr -d '[:space:]')"
  if [ "$got" != "FEAT-EXISTING-003" ]; then
    echo "  other: чужой тикет перетёрт — ожидался FEAT-EXISTING-003, получено '$got'" >&2
    rc=1
  fi
  if ! grep -q "принадлежит другой сессии" "$errf"; then
    echo "  other: ожидалось предупреждение 'принадлежит другой сессии' в stderr, не найдено" >&2
    rc=1
  fi

  rm -f "$errf" 2>/dev/null || true
  teardown_test_env
  return "$rc"
}

# T.C4 — пустой аргумент ticket → exit 0, файл не создаётся.
test_write_legacy_empty_ticket_arg() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  # Файла быть не должно ни до, ни после вызова.
  rm -f "$target" 2>/dev/null || true

  HOME="$TEST_HOME" bash "$helper" "$TEST_CWD" ""
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  empty-arg: ожидался exit 0, получено $helper_rc" >&2
    rc=1
  fi
  if [ -e "$target" ]; then
    echo "  empty-arg: файл $target не должен был создаваться при пустом тикете" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.C5 (AIDD-002, MAJOR-1) — ticket с символом вне whitelist (перевод строки) → файл НЕ создан, exit 0.
# Защита от тихой порчи: multiline ticket при последующем trim-чтении склеился бы в мусор.
test_write_legacy_rejects_multiline_ticket() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  # Файла указателя быть не должно — проверяем, что невалидный ticket его НЕ создаёт.
  rm -f "$target" 2>/dev/null || true

  # ticket с реальным переводом строки внутри ($'...\n...' — символ LF попадает в аргумент).
  local bad_ticket
  bad_ticket=$'FEAT-001\nrm -rf evil'
  HOME="$TEST_HOME" bash "$helper" "$TEST_CWD" "$bad_ticket"
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  multiline: ожидался exit 0 (fail-open), получено $helper_rc" >&2
    rc=1
  fi
  if [ -e "$target" ]; then
    echo "  multiline: файл $target создан — невалидный (multiline) ticket НЕ должен писаться" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.C6 (AIDD-002) — пустой первый аргумент cwd → helper подставляет pwd и пишет в <pwd>/docs/.active_ticket.
# Helper запускается из $TEST_CWD (подоболочка `cd`), значит его pwd == $TEST_CWD — туда и должна
# попасть запись. cwd самого раннера не трогаем (он зависит от своего cwd для путей).
test_write_legacy_empty_cwd_uses_pwd() {
  setup_test_env
  local helper
  helper="$(_write_legacy_helper)"
  local target="$TEST_CWD/docs/.active_ticket"
  rm -f "$target" 2>/dev/null || true

  # cwd="" → helper делает pwd; запускаем его из $TEST_CWD в изолированной подоболочке.
  ( cd "$TEST_CWD" && HOME="$TEST_HOME" bash "$helper" "" "FEAT-PWD-006" )
  local helper_rc=$?

  local rc=0
  if [ "$helper_rc" -ne 0 ]; then
    echo "  empty-cwd: ожидался exit 0, получено $helper_rc" >&2
    rc=1
  fi
  if [ ! -f "$target" ]; then
    echo "  empty-cwd: файл $target не создан — ожидалась запись в <pwd>/docs/.active_ticket" >&2
    rc=1
  else
    local got
    got="$(cat "$target" 2>/dev/null | tr -d '[:space:]')"
    if [ "$got" != "FEAT-PWD-006" ]; then
      echo "  empty-cwd: ожидался тикет FEAT-PWD-006 в файле, получено '$got'" >&2
      rc=1
    fi
  fi

  teardown_test_env
  return "$rc"
}
