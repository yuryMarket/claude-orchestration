#!/usr/bin/env bash
# test-gate-workflow.sh — bash-тесты PreToolUse-хука gate-workflow.sh (тикет AIDD-001, T.4/T.5/T.6)
# Тестируемый компонент: ~/.claude/hooks/gate-workflow.sh
#   exit 0 = разрешить Edit/Write; exit 2 = блокировать (gate не пройден с резолвнутым тикетом).
#
# Изоляция и важные инварианты:
#   - HOME=$TEST_HOME → per-session хранилище читается из TEST_HOME, не из реального ~.
#   - CLAUDE_CODE_SESSION_ID очищается → session_id берётся ТОЛЬКО из stdin JSON (детерминизм).
#   - Хук читает PRD/plan/tasklist ОТНОСИТЕЛЬНО своей рабочей директории (process cwd),
#     а ticket резолвит по cwd из stdin JSON. Поэтому хук запускается С cwd=$TEST_CWD И
#     с тем же cwd в stdin — иначе gates искали бы артефакты не там.
#
# Контракт для раннера: test_* → 0 (PASS) / 1 (FAIL, причина в stderr).

GATE_HOOK="$TEST_HOOKS_DIR/gate-workflow.sh"

# _run_gate <session_id> <file_path> — запустить gate-workflow.sh изолированно.
# Печатает stderr хука в текущий stderr (для диагностики), возвращает код выхода хука.
# Рабочая директория хука = $TEST_CWD (через bash -c 'cd ...'), HOME=$TEST_HOME,
# CLAUDE_CODE_SESSION_ID очищен. stdin — JSON с tool_name/file_path/session_id/cwd.
_run_gate() {
  local sid="$1" file_path="$2"
  local payload
  payload="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"session_id":"%s","cwd":"%s"}' \
    "$file_path" "$sid" "$TEST_CWD")"

  # Запускаем в субшелле: переопределяем HOME, гасим CLAUDE_CODE_SESSION_ID, ставим cwd=$TEST_CWD.
  HOME="$TEST_HOME" CLAUDE_CODE_SESSION_ID="" TEST_HOME="$TEST_HOME" GATE_HOOK="$GATE_HOOK" TEST_CWD="$TEST_CWD" \
    bash -c 'cd "$TEST_CWD" || exit 99; printf "%s" "$0" | HOME="$HOME" CLAUDE_CODE_SESSION_ID="" exec "$GATE_HOOK"' "$payload"
}

# _make_ready_artifacts <ticket> — создать готовый AIDD-цикл для тикета в $TEST_CWD/docs.
#   PRD: Status: PRD_READY | plan: Status: PLAN_APPROVED | tasklist: Status: TASKLIST_READY
_make_ready_artifacts() {
  local ticket="$1"
  mkdir -p "$TEST_CWD/docs/prd" "$TEST_CWD/docs/plan" "$TEST_CWD/docs/tasklist"
  printf 'Status: PRD_READY\n\n# %s PRD\n' "$ticket"      >"$TEST_CWD/docs/prd/${ticket}.prd.md"
  printf 'Status: PLAN_APPROVED\n\n# %s Plan\n' "$ticket" >"$TEST_CWD/docs/plan/${ticket}.md"
  printf 'Status: TASKLIST_READY\n\n# %s Tasks\n' "$ticket" >"$TEST_CWD/docs/tasklist/${ticket}.md"
}

# _write_session_file <sid> <ticket> <cwd> — per-session JSON в изолированный TEST_HOME.
_write_session_file() {
  local sid="$1" ticket="$2" cwd="$3"
  local dir="$TEST_HOME/.claude/sessions/aidd"
  mkdir -p "$dir"
  cat >"$dir/${sid}.json" <<EOF
{
  "ticket": "${ticket}",
  "cwd": "${cwd}",
  "source": "test",
  "created": "2026-06-01T00:00:00Z",
  "updated": "2026-06-01T00:00:00Z"
}
EOF
}

# T.4 — одиночная сессия, полный AIDD-цикл готов (legacy ticket) → exit 0 на обычном файле.
test_gate_single_session_full_cycle_allows() {
  setup_test_env
  local ticket="FEAT-FULL"
  echo "$ticket" >"$TEST_CWD/docs/.active_ticket"
  _make_ready_artifacts "$ticket"

  # Обычный исходный файл (НЕ в docs/, не .claude/) — gates применяются полностью.
  local target="$TEST_CWD/src/module.py"
  mkdir -p "$TEST_CWD/src"
  : >"$target"

  _run_gate "sid-full-001" "$target"
  local gate_rc=$?

  local rc=0
  if [ "$gate_rc" -ne 0 ]; then
    echo "  полный цикл: ожидался exit 0, получено $gate_rc" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.5 — нет ни per-session, ни docs/.active_ticket → любой file_path → exit 0 (тикет неактивен).
test_gate_no_ticket_allows() {
  setup_test_env
  # Намеренно НЕ создаём ни per-session файла, ни docs/.active_ticket, ни артефактов.
  local target="$TEST_CWD/src/anything.py"
  mkdir -p "$TEST_CWD/src"
  : >"$target"

  _run_gate "sid-noticket-001" "$target"
  local gate_rc=$?

  local rc=0
  if [ "$gate_rc" -ne 0 ]; then
    echo "  без тикета: ожидался exit 0, получено $gate_rc" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.6 — две параллельные сессии, разные тикеты; один cwd.
#   sid-A → FEAT-A (артефакты готовы)  → exit 0
#   sid-B → FEAT-B (план НЕ готов)     → exit 2
test_gate_parallel_sessions_isolated() {
  setup_test_env
  local target="$TEST_CWD/src/shared.py"
  mkdir -p "$TEST_CWD/src"
  : >"$target"

  # Два per-session файла с ОДНИМ cwd, но разными тикетами.
  _write_session_file "sid-A" "FEAT-A" "$TEST_CWD"
  _write_session_file "sid-B" "FEAT-B" "$TEST_CWD"

  # Для FEAT-A — полный готовый цикл.
  _make_ready_artifacts "FEAT-A"

  # Для FEAT-B — намеренно НЕ готов: PRD есть (PRD_READY), а план отсутствует → gate PLAN блокирует.
  mkdir -p "$TEST_CWD/docs/prd"
  printf 'Status: PRD_READY\n\n# FEAT-B PRD\n' >"$TEST_CWD/docs/prd/FEAT-B.prd.md"
  # docs/plan/FEAT-B.md и tasklist намеренно отсутствуют.

  local rc=0

  # Сессия A: тикет FEAT-A, всё готово → exit 0.
  _run_gate "sid-A" "$target"
  local rc_a=$?
  if [ "$rc_a" -ne 0 ]; then
    echo "  сессия A (FEAT-A готов): ожидался exit 0, получено $rc_a" >&2
    rc=1
  fi

  # Сессия B: тикет FEAT-B, план не готов → exit 2.
  _run_gate "sid-B" "$target"
  local rc_b=$?
  if [ "$rc_b" -ne 2 ]; then
    echo "  сессия B (FEAT-B план не готов): ожидался exit 2, получено $rc_b" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}
