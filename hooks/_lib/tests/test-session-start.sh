#!/usr/bin/env bash
# test-session-start.sh — bash-тесты SessionStart-хука session-start.sh (тикет AIDD-001, T.7/T.8)
# Тестируемый компонент: ~/.claude/hooks/session-start.sh
#   - TTL-очистка orphaned per-session файлов при source=startup (mtime > 14 дней, кроме текущего).
#   - Пустой stdin → exit 0 без ошибок.
#
# Изоляция: HOME=$TEST_HOME (per-session хранилище в TEST_HOME), CLAUDE_CODE_SESSION_ID очищен,
#   cwd хука = $TEST_CWD. session_id/source/cwd подаются через stdin JSON.
#
# Контракт для раннера: test_* → 0 (PASS) / 1 (FAIL, причина в stderr).

SESSION_START_HOOK="$TEST_HOOKS_DIR/session-start.sh"

# _run_session_start <payload> — запустить session-start.sh изолированно.
# payload подаётся как stdin (может быть пустым). Печатает: stdout → $RUN_OUT, stderr → $RUN_ERR,
# код выхода → $RUN_RC. Рабочая директория = $TEST_CWD, HOME=$TEST_HOME, env-SID очищен.
RUN_OUT=""
RUN_ERR=""
RUN_RC=0
_run_session_start() {
  local payload="$1"
  local outf errf
  outf="$(mktemp "${TMPDIR:-/tmp}/aidd-ss-out.XXXXXX")"
  errf="$(mktemp "${TMPDIR:-/tmp}/aidd-ss-err.XXXXXX")"

  HOME="$TEST_HOME" CLAUDE_CODE_SESSION_ID="" TEST_HOME="$TEST_HOME" TEST_CWD="$TEST_CWD" \
    SESSION_START_HOOK="$SESSION_START_HOOK" \
    bash -c 'cd "$TEST_CWD" || exit 99; printf "%s" "$0" | HOME="$HOME" CLAUDE_CODE_SESSION_ID="" exec "$SESSION_START_HOOK"' \
    "$payload" >"$outf" 2>"$errf"
  RUN_RC=$?
  RUN_OUT="$(cat "$outf" 2>/dev/null || echo "")"
  RUN_ERR="$(cat "$errf" 2>/dev/null || echo "")"
  rm -f "$outf" "$errf" 2>/dev/null || true
}

# T.7 — TTL-очистка: sid-old.json (15 дней назад) удаляется; sid-cur.json цел; stderr "cleaned 1".
test_session_start_ttl_cleanup() {
  setup_test_env
  local dir="$TEST_HOME/.claude/sessions/aidd"
  mkdir -p "$dir"

  # Orphaned-файл: создаём и backdate'им на 15 дней (mtime +14 → попадает под удаление).
  printf '{"ticket":"OLD-1","cwd":"%s","source":"startup","created":"x","updated":"x"}\n' "$TEST_CWD" \
    >"$dir/sid-old.json"
  backdate_file "$dir/sid-old.json" 15

  # Текущий файл сессии: свежий mtime, не должен быть удалён.
  printf '{"ticket":"CUR-1","cwd":"%s","source":"startup","created":"x","updated":"x"}\n' "$TEST_CWD" \
    >"$dir/sid-cur.json"

  # Запуск с source=startup, session_id=sid-cur.
  local payload
  payload="$(printf '{"source":"startup","session_id":"sid-cur","cwd":"%s"}' "$TEST_CWD")"
  _run_session_start "$payload"

  local rc=0
  if [ "$RUN_RC" -ne 0 ]; then
    echo "  TTL: ожидался exit 0, получено $RUN_RC; stderr: $RUN_ERR" >&2
    rc=1
  fi
  if [ -f "$dir/sid-old.json" ]; then
    echo "  TTL: orphaned-файл sid-old.json должен быть удалён, но существует" >&2
    rc=1
  fi
  if [ ! -f "$dir/sid-cur.json" ]; then
    echo "  TTL: текущий sid-cur.json должен сохраниться, но удалён" >&2
    rc=1
  fi
  if ! printf '%s' "$RUN_ERR" | grep -q "AIDD: cleaned 1 orphaned session files"; then
    echo "  TTL: ожидался stderr 'AIDD: cleaned 1 orphaned session files', получено: $RUN_ERR" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.8 — пустой stdin → exit 0, без ошибок в stderr (допустимы лишь опц. предупреждения о деградации).
test_session_start_empty_stdin() {
  setup_test_env

  # Пустой stdin: `echo "" | session-start.sh`-эквивалент.
  _run_session_start ""

  local rc=0
  if [ "$RUN_RC" -ne 0 ]; then
    echo "  пустой stdin: ожидался exit 0, получено $RUN_RC" >&2
    rc=1
  fi
  # stderr должен быть пустым: TTL-очистка не запускается (source!=startup), upsert пропускается
  # (SID пуст), python3 доступен. Любой вывод в stderr здесь — регрессия.
  if [ -n "$RUN_ERR" ]; then
    echo "  пустой stdin: ожидался пустой stderr, получено: $RUN_ERR" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}
