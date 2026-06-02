#!/usr/bin/env bash
# run-tests.sh — единый раннер bash-тестов per-session логики AIDD (тикет AIDD-001, T.1–T.8)
# Обнаруживает все функции test_* в test-*.sh, выполняет каждую изолированно, печатает PASS/FAIL
# и итог. Код выхода: 0 — все зелёные, 1 — есть упавшие.
#
# Запуск:  bash ~/.claude/hooks/_lib/tests/run-tests.sh
#
# Изоляция (КРИТИЧНО): тесты используют временный HOME (TEST_HOME) и временный cwd (TEST_CWD)
#   из test-helpers.sh. НИ ОДИН тест не пишет в реальный ~/.claude/sessions/aidd и не трогает
#   реальные хуки-артефакты. Тестируемые хуки запускаются с HOME=$TEST_HOME и cwd=$TEST_CWD.
set -uo pipefail

# Абсолютные пути (раннер не зависит от cwd вызывающего).
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# --- Подключение тестируемых библиотек ----------------------------------------
# resolve_ticket / resolve_session_id должны быть доступны для тестов прямого вызова (T.2/T.3).
# В библиотеках нет `set -euo pipefail` — они fail-open; раннер сам управляет режимом.
# shellcheck source=/dev/null
source "$LIB_DIR/aidd-ticket.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/aidd-session-id.sh"

# --- Подключение тест-хелпера и наборов тестов --------------------------------
# shellcheck source=/dev/null
source "$LIB_DIR/test-helpers.sh"

# Подключаем все наборы test-*.sh (кроме самого test-helpers.sh).
for f in "$TESTS_DIR"/test-*.sh; do
  [ -f "$f" ] || continue
  # shellcheck source=/dev/null
  source "$f"
done

# --- Обнаружение и запуск test_* функций --------------------------------------
# Собираем имена объявленных функций test_*, сортируем для детерминированного порядка.
mapfile -t TEST_FUNCS < <(declare -F | awk '{print $3}' | grep -E '^test_' | sort)

PASS_COUNT=0
FAIL_COUNT=0
FAILED_NAMES=()

echo "=============================================="
echo " AIDD per-session tests — раннер (AIDD-001)"
echo " Обнаружено тестов: ${#TEST_FUNCS[@]}"
echo "=============================================="

for tf in "${TEST_FUNCS[@]}"; do
  # Гарантируем чистое окружение между тестами (на случай, если тест упал до teardown).
  teardown_test_env 2>/dev/null || true

  # Запускаем тест. Тест сам делает setup_test_env/teardown_test_env.
  # Причину падения тест печатает в stderr; перехватываем для аккуратного вывода.
  errf="$(mktemp "${TMPDIR:-/tmp}/aidd-test-run.XXXXXX")"
  if "$tf" 2>"$errf"; then
    echo "PASS  $tf"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL  $tf"
    # Печатаем диагностику теста с отступом.
    while IFS= read -r line; do
      [ -n "$line" ] && echo "      $line"
    done <"$errf"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_NAMES+=("$tf")
  fi
  rm -f "$errf" 2>/dev/null || true

  # Подстраховка: убираем за тестом, если он не успел.
  teardown_test_env 2>/dev/null || true
done

echo "=============================================="
echo " Итог: PASS=${PASS_COUNT}  FAIL=${FAIL_COUNT}  ВСЕГО=${#TEST_FUNCS[@]}"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo " Упавшие: ${FAILED_NAMES[*]}"
fi
echo "=============================================="

[ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
