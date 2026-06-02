#!/usr/bin/env bash
# test-resolve-ticket.sh — bash-тесты функции resolve_ticket() (тикет AIDD-001, T.2 + T.3)
# Тестируемый компонент: ~/.claude/hooks/_lib/aidd-ticket.sh → resolve_ticket <cwd> <sid>
#   заполняет глобальные TICKET и TICKET_SRC (session|legacy|none).
#
# Также — негативные тесты безопасности для resolve_session_id() из _lib/aidd-session-id.sh:
#   path-traversal и glob в session_id должны давать SID="" (path-traversal guard).
#
# Изоляция: каждый тест работает в TEST_HOME/TEST_CWD (см. test-helpers.sh). HOME переопределяется
#   на TEST_HOME, поэтому resolve_ticket читает per-session файлы из TEST_HOME, а НЕ из реального ~.
#
# Контракт для раннера: функции test_* возвращают 0 (PASS) либо печатают причину в stderr и
#   возвращают 1 (FAIL). Никаких побочных эффектов вне TEST_HOME/TEST_CWD.

# --- Вспомогательное: записать per-session JSON в изолированный TEST_HOME ------
# _write_session_file <sid> <ticket> <cwd>
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

# T.2.a — корректный per-session файл с совпадающим cwd → TICKET_SRC=session, TICKET из файла.
test_resolve_ticket_per_session_primary() {
  setup_test_env
  local sid="sid-primary-001"
  _write_session_file "$sid" "FEAT-PRIMARY" "$TEST_CWD"

  # Изолируем HOME и вызываем resolve_ticket.
  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "$sid"

  local rc=0
  if [ "$TICKET_SRC" != "session" ]; then
    echo "  ожидался TICKET_SRC=session, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-PRIMARY" ]; then
    echo "  ожидался TICKET=FEAT-PRIMARY, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.2.b — per-session файл с ДРУГИМ cwd → cwd-guard срабатывает, резолюция падает в legacy.
test_resolve_ticket_cwd_guard() {
  setup_test_env
  local sid="sid-guard-001"
  # В файле — чужой cwd; тикет per-session НЕ должен примениться.
  _write_session_file "$sid" "FEAT-OTHER-PROJECT" "/some/other/project/path"
  # При этом в текущем cwd есть legacy-указатель — именно он должен победить.
  echo "FEAT-LEGACY" >"$TEST_CWD/docs/.active_ticket"

  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "$sid"

  local rc=0
  if [ "$TICKET_SRC" != "legacy" ]; then
    echo "  cwd-guard: ожидался TICKET_SRC=legacy, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-LEGACY" ]; then
    echo "  cwd-guard: ожидался TICKET=FEAT-LEGACY, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.3.a — нет per-session файла, есть docs/.active_ticket → TICKET_SRC=legacy.
test_resolve_ticket_legacy_fallback() {
  setup_test_env
  echo "FEAT-LEGACY-ONLY" >"$TEST_CWD/docs/.active_ticket"

  # session_id передаём, но файла для него нет → должен уйти в legacy.
  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "sid-no-file-001"

  local rc=0
  if [ "$TICKET_SRC" != "legacy" ]; then
    echo "  ожидался TICKET_SRC=legacy, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-LEGACY-ONLY" ]; then
    echo "  ожидался TICKET=FEAT-LEGACY-ONLY, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.3.b — per-session файл содержит битый JSON → stderr-варнинг, fallback к legacy, exit 0 (не 2).
test_resolve_ticket_fail_open_corrupt_json() {
  setup_test_env
  local sid="sid-corrupt-001"
  local dir="$TEST_HOME/.claude/sessions/aidd"
  mkdir -p "$dir"
  # Битый JSON: нет извлекаемых полей ticket/cwd ни через python3, ни через grep-fallback.
  printf '%s' '{{{ this is not valid json @@@ no fields here' >"$dir/${sid}.json"
  # Legacy-указатель присутствует — на него и должен прийтись fallback.
  echo "FEAT-AFTER-CORRUPT" >"$TEST_CWD/docs/.active_ticket"

  # Перехватываем stderr во временный файл, проверяем код возврата (fail-open => 0).
  local errf
  errf="$(mktemp "${TMPDIR:-/tmp}/aidd-corrupt-err.XXXXXX")"
  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "$sid" 2>"$errf"
  local resolve_rc=$?

  local rc=0
  if [ "$resolve_rc" -ne 0 ]; then
    echo "  fail-open нарушен: resolve_ticket вернул код $resolve_rc (ожидался 0)" >&2
    rc=1
  fi
  if ! grep -q "corrupt session file" "$errf"; then
    echo "  ожидался stderr-варнинг 'corrupt session file', не найден" >&2
    rc=1
  fi
  if [ "$TICKET_SRC" != "legacy" ]; then
    echo "  после битого JSON ожидался TICKET_SRC=legacy, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-AFTER-CORRUPT" ]; then
    echo "  после битого JSON ожидался TICKET=FEAT-AFTER-CORRUPT, получено '$TICKET'" >&2
    rc=1
  fi

  rm -f "$errf" 2>/dev/null || true
  teardown_test_env
  return "$rc"
}

# T.3.c — python3 недоступен (PATH очищен) → grep-fallback резолвит legacy.
test_resolve_ticket_no_python3() {
  setup_test_env
  echo "FEAT-NO-PY3" >"$TEST_CWD/docs/.active_ticket"

  # Очищаем PATH так, чтобы python3 не нашёлся; coreutils для grep/sed/cat остаются доступны
  # через абсолютные вызовы внутри библиотеки (она использует чистый bash + grep/sed по имени).
  # Чтобы grep/sed всё же работали, оставляем минимальный системный PATH БЕЗ python3.
  # /usr/bin содержит python3 на macOS, поэтому используем заведомо пустой каталог + симлинки
  # на нужные утилиты, исключая python3.
  local fakebin
  fakebin="$(mktemp -d "${TMPDIR:-/tmp}/aidd-nopy3.XXXXXX")"
  local u
  for u in bash sh grep sed cat head basename find date touch mktemp wc tr; do
    local src
    src="$(command -v "$u" 2>/dev/null || true)"
    [ -n "$src" ] && ln -sf "$src" "$fakebin/$u" 2>/dev/null || true
  done

  # Санити: в изолированном PATH python3 не должен находиться.
  local has_py3
  has_py3="$(PATH="$fakebin" command -v python3 2>/dev/null || echo "")"

  HOME="$TEST_HOME" PATH="$fakebin" resolve_ticket "$TEST_CWD" "sid-nopy3-001"

  local rc=0
  if [ -n "$has_py3" ]; then
    echo "  не удалось убрать python3 из PATH (найден: $has_py3) — тест недостоверен" >&2
    rc=1
  fi
  if [ "$TICKET_SRC" != "legacy" ]; then
    echo "  без python3 ожидался TICKET_SRC=legacy (grep-fallback), получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-NO-PY3" ]; then
    echo "  без python3 ожидался TICKET=FEAT-NO-PY3, получено '$TICKET'" >&2
    rc=1
  fi

  rm -rf "$fakebin" 2>/dev/null || true
  teardown_test_env
  return "$rc"
}

# T.3.d — нет ни per-session, ни legacy → TICKET_SRC=none, TICKET="", без exit 2.
test_resolve_ticket_none() {
  setup_test_env
  # Ничего не создаём: ни per-session файла, ни docs/.active_ticket.

  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "sid-none-001"
  local resolve_rc=$?

  local rc=0
  if [ "$resolve_rc" -ne 0 ]; then
    echo "  ожидался код возврата 0 (без exit 2), получено $resolve_rc" >&2
    rc=1
  fi
  if [ "$TICKET_SRC" != "none" ]; then
    echo "  ожидался TICKET_SRC=none, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ -n "$TICKET" ]; then
    echo "  ожидался пустой TICKET, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# --- Негативные тесты безопасности (BLOCKING-фикс AIDD-001: path-traversal guard) ---
# resolve_session_id() из _lib/aidd-session-id.sh обязан САНИТИЗИРОВАТЬ session_id из
# недоверенного stdin, ИНАЧЕ значение попадает в пути файлов (sessions/aidd/<SID>.json,
# tmp+mv, find TTL). whitelist [a-zA-Z0-9._-] + отсев `.`/`..` → невалидный SID="".

# Негативный: session_id="../../tmp/evil" (слэши — попытка записи вне каталога хранилища).
# Ожидание: resolve_session_id даёт SID=""; resolve_ticket с пустым SID НЕ читает/пишет вне
# хранилища (падает в legacy, а без legacy — в none). Доп. проверяем, что вредоносный путь
# вне каталога хранилища НЕ был создан.
test_resolve_session_id_rejects_path_traversal() {
  setup_test_env
  local evil="../../tmp/evil"
  # CLAUDE_CODE_SESSION_ID должен быть пуст, чтобы источником SID стал именно stdin .session_id.
  local payload
  payload="$(printf '{"session_id":"%s","cwd":"%s"}' "$evil" "$TEST_CWD")"

  # Канареечный путь, который traversal попытался бы затронуть, если бы SID не санитизировался:
  # <storage>/<SID>.json = <TEST_HOME>/.claude/sessions/aidd/../../tmp/evil.json
  #   → нормализуется в <TEST_HOME>/.claude/tmp/evil.json (вне каталога хранилища aidd/).
  local canary_dir="$TEST_HOME/.claude/tmp"
  local canary="$canary_dir/evil.json"
  rm -f "$canary" 2>/dev/null || true

  # Вызов резолюции id (env-var очищаем, чтобы он не перекрыл stdin-источник).
  HOME="$TEST_HOME" CLAUDE_CODE_SESSION_ID="" resolve_session_id "$payload"

  local rc=0
  if [ -n "$SID" ]; then
    echo "  path-traversal: ожидался SID='', получено '$SID'" >&2
    rc=1
  fi

  # С пустым SID resolve_ticket не должен трогать per-session хранилище: при отсутствии legacy
  # → TICKET_SRC=none, TICKET="" (падение в legacy/none, без чтения/записи вне каталога).
  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "$SID"
  if [ "$TICKET_SRC" != "none" ]; then
    echo "  path-traversal: с пустым SID и без legacy ожидался TICKET_SRC=none, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ -n "$TICKET" ]; then
    echo "  path-traversal: ожидался пустой TICKET, получено '$TICKET'" >&2
    rc=1
  fi

  # Канареечный файл вне каталога хранилища не должен появиться ни на одном шаге.
  if [ -e "$canary" ]; then
    echo "  path-traversal: обнаружена запись вне каталога хранилища: $canary" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# Негативный: session_id с glob-символами (* и [) — ломает name-исключение в find TTL.
# Ожидание: resolve_session_id даёт SID="" для каждого варианта.
test_resolve_session_id_rejects_glob() {
  setup_test_env

  local rc=0
  local bad
  for bad in 'sess*' 'sess[abc]' '*' '['; do
    local payload
    payload="$(printf '{"session_id":"%s","cwd":"%s"}' "$bad" "$TEST_CWD")"
    HOME="$TEST_HOME" CLAUDE_CODE_SESSION_ID="" resolve_session_id "$payload"
    if [ -n "$SID" ]; then
      echo "  glob: session_id='$bad' → ожидался SID='', получено '$SID'" >&2
      rc=1
    fi
  done

  teardown_test_env
  return "$rc"
}

# --- AIDD-002: удалённый уровень 3 + нормализация cwd (T.1) --------------------
# resolve_ticket теперь двухуровневая (per-session → docs/.active_ticket → none).
# Бывший уровень 3 (<cwd>/.claude/docs/.active_ticket) удалён — эти тесты фиксируют,
# что он больше не читается, и что trailing slash в cwd нормализуется (cwd-guard и legacy-путь).

# T.A — <cwd>/.claude/docs/.active_ticket больше НЕ читается (удалённый уровень 3).
# Создаём ТОЛЬКО осиротевший указатель уровня 3; ни per-session, ни legacy docs/.active_ticket нет.
# Ожидание: TICKET_SRC=none, TICKET="" (уровень 3 игнорируется).
test_resolve_ticket_level3_ignored() {
  setup_test_env
  # Осиротевший указатель бывшего уровня 3 — он не должен попасть в резолюцию.
  mkdir -p "$TEST_CWD/.claude/docs"
  echo "FEAT-ORPHAN" >"$TEST_CWD/.claude/docs/.active_ticket"
  # Намеренно НЕ создаём ни per-session файла, ни $TEST_CWD/docs/.active_ticket (legacy уровня 2).

  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD" "sid-level3-001"
  local resolve_rc=$?

  local rc=0
  if [ "$resolve_rc" -ne 0 ]; then
    echo "  уровень 3: ожидался код возврата 0, получено $resolve_rc" >&2
    rc=1
  fi
  if [ "$TICKET_SRC" != "none" ]; then
    echo "  уровень 3 не должен читаться: ожидался TICKET_SRC=none, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ -n "$TICKET" ]; then
    echo "  уровень 3 не должен читаться: ожидался пустой TICKET, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.B — нормализация cwd для cwd-guard уровня 1 (per-session).
# В per-session файле cwd=$TEST_CWD (без слеша); вызываем resolve_ticket с trailing slash.
# Ожидание: cwd-guard проходит за счёт нормализации ${cwd%/} → TICKET_SRC=session.
test_resolve_ticket_trailing_slash_session() {
  setup_test_env
  local sid="sid-tslash-session-001"
  # cwd в файле — без trailing slash (как его пишет session-start.sh).
  _write_session_file "$sid" "FEAT-TSLASH-SESSION" "$TEST_CWD"

  # Вызов с trailing slash — без нормализации cwd-guard сравнил бы "$TEST_CWD" != "$TEST_CWD/".
  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD/" "$sid"

  local rc=0
  if [ "$TICKET_SRC" != "session" ]; then
    echo "  trailing slash (session): ожидался TICKET_SRC=session, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-TSLASH-SESSION" ]; then
    echo "  trailing slash (session): ожидался TICKET=FEAT-TSLASH-SESSION, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}

# T.B2 — нормализация cwd для построения legacy-пути уровня 2.
# Есть $TEST_CWD/docs/.active_ticket, нет per-session; вызываем с trailing slash.
# Ожидание: legacy-путь строится из нормализованного cwd → TICKET_SRC=legacy.
test_resolve_ticket_trailing_slash_legacy() {
  setup_test_env
  echo "FEAT-TSLASH-LEGACY" >"$TEST_CWD/docs/.active_ticket"
  # per-session файла для этого sid нет → резолюция должна уйти в legacy.

  HOME="$TEST_HOME" resolve_ticket "$TEST_CWD/" "sid-tslash-legacy-no-file"

  local rc=0
  if [ "$TICKET_SRC" != "legacy" ]; then
    echo "  trailing slash (legacy): ожидался TICKET_SRC=legacy, получено '$TICKET_SRC'" >&2
    rc=1
  fi
  if [ "$TICKET" != "FEAT-TSLASH-LEGACY" ]; then
    echo "  trailing slash (legacy): ожидался TICKET=FEAT-TSLASH-LEGACY, получено '$TICKET'" >&2
    rc=1
  fi

  teardown_test_env
  return "$rc"
}
