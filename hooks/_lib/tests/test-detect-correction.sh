#!/usr/bin/env bash
# test-detect-correction.sh — регрессионные тесты Stop-хука detect-correction.sh (тикет AIDD-003, 5.3)
# Тестируемый компонент: ~/.claude/hooks/detect-correction.sh
#   Сигнал коррекции = ОТРИЦАНИЕ оценки сделанного В НАЧАЛЕ сообщения + Edit/Write в транскрипте,
#   с rate-limit 1 раз / 4 часа на сессию.
#
# Изоляция (КРИТИЧНО): НИ ОДИН тест не зависит от реальной сессии. session_id — уникальный,
#   транскрипт — временный JSONL (mktemp), marker-файлы /tmp/claude-*-${SID} чистятся ДО и ПОСЛЕ.
#   Хук пишет только в /tmp по уникальному SID и читает временный транскрипт — реальные
#   ~/.claude/sessions и настоящие marker-файлы НИКОГДА не затрагиваются.
#
# Контракт для раннера: test_* → 0 (PASS) / 1 (FAIL, причина в stderr).

DETECT_HOOK="$TEST_HOOKS_DIR/detect-correction.sh"

# _dc_markers <sid> — удалить все /tmp marker-файлы, которыми оперирует хук для данной сессии.
_dc_markers() {
  local sid="$1"
  rm -f "/tmp/claude-correction-ratelimit-${sid}" \
        "/tmp/claude-watcher-ran-${sid}" \
        "/tmp/claude-correction-flag-${sid}" \
        "/tmp/claude-cursor-${sid}" 2>/dev/null || true
}

# _dc_new_sid <suffix> — уникальный session_id, не пересекающийся с реальными сессиями.
_dc_new_sid() {
  echo "test-detcorr-$$-${RANDOM}-${1:-x}"
}

# _dc_write_transcript <file> <user_text> — записать минимальный JSONL:
#   последнее сообщение пользователя = <user_text> (безопасно экранировано через jq),
#   плюс assistant с tool_use Edit (чтобы Условие B выполнялось).
_dc_write_transcript() {
  local file="$1" text="$2"
  jq -cn --arg t "$text" '{type:"user",message:{role:"user",content:[{type:"text",text:$t}]}}' >"$file"
  printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{}}]}}' >>"$file"
}

# _run_detect <sid> <transcript> — запустить хук изолированно.
#   stdout хука → $DC_OUT, код выхода → $DC_RC.
DC_OUT=""
DC_RC=0
_run_detect() {
  local sid="$1" tpath="$2"
  local outf
  outf="$(mktemp "${TMPDIR:-/tmp}/dc-out.XXXXXX")"
  printf '{"session_id":"%s","transcript_path":"%s","stop_hook_active":false}' "$sid" "$tpath" \
    | "$DETECT_HOOK" >"$outf" 2>/dev/null
  DC_RC=$?
  DC_OUT="$(cat "$outf" 2>/dev/null || echo "")"
  rm -f "$outf" 2>/dev/null || true
}

# Кейс 1 — истинная коррекция (отрицание в начале) + Edit → {"ok": false}.
test_detect_correction_true_negation_triggers() {
  local sid tr rc=0
  sid="$(_dc_new_sid c1)"
  tr="$(mktemp "${TMPDIR:-/tmp}/dc-tr.XXXXXX")"
  _dc_markers "$sid"
  _dc_write_transcript "$tr" "нет, не так, переделай"

  _run_detect "$sid" "$tr"

  if [ "$DC_RC" -ne 0 ]; then
    echo "  коррекция: ожидался exit 0, получено $DC_RC" >&2; rc=1
  fi
  if ! printf '%s' "$DC_OUT" | grep -q '"ok": false'; then
    echo "  коррекция: ожидался {\"ok\": false}, получено: '$DC_OUT'" >&2; rc=1
  fi

  _dc_markers "$sid"; rm -f "$tr" 2>/dev/null || true
  return "$rc"
}

# Кейс 2 — обычное поручение-императив (без отрицания) → exit 0, без ok:false.
test_detect_correction_imperative_task_no_trigger() {
  local sid tr rc=0
  sid="$(_dc_new_sid c2)"
  tr="$(mktemp "${TMPDIR:-/tmp}/dc-tr.XXXXXX")"
  _dc_markers "$sid"
  _dc_write_transcript "$tr" "исправь баг в модуле X"

  _run_detect "$sid" "$tr"

  if [ "$DC_RC" -ne 0 ]; then
    echo "  поручение: ожидался exit 0, получено $DC_RC" >&2; rc=1
  fi
  if printf '%s' "$DC_OUT" | grep -q '"ok"'; then
    echo "  поручение: ok:false НЕ ожидался, получено: '$DC_OUT'" >&2; rc=1
  fi

  _dc_markers "$sid"; rm -f "$tr" 2>/dev/null || true
  return "$rc"
}

# Кейс 3 — отрицание НЕ в начале (в середине длинного сообщения) → exit 0, без ok:false.
test_detect_correction_negation_not_at_start_no_trigger() {
  local sid tr rc=0
  sid="$(_dc_new_sid c3)"
  tr="$(mktemp "${TMPDIR:-/tmp}/dc-tr.XXXXXX")"
  _dc_markers "$sid"
  _dc_write_transcript "$tr" "Обнови конфиг в модуле, потому что там всё неправильно настроено"

  _run_detect "$sid" "$tr"

  if [ "$DC_RC" -ne 0 ]; then
    echo "  отрицание-в-середине: ожидался exit 0, получено $DC_RC" >&2; rc=1
  fi
  if printf '%s' "$DC_OUT" | grep -q '"ok"'; then
    echo "  отрицание-в-середине: ok:false НЕ ожидался, получено: '$DC_OUT'" >&2; rc=1
  fi

  _dc_markers "$sid"; rm -f "$tr" 2>/dev/null || true
  return "$rc"
}

# Кейс 4 — rate-limit: 1-й прогон коррекции → ok:false, немедленный повтор → exit 0 без ok:false.
test_detect_correction_ratelimit_suppresses_repeat() {
  local sid tr rc=0
  sid="$(_dc_new_sid c4)"
  tr="$(mktemp "${TMPDIR:-/tmp}/dc-tr.XXXXXX")"
  _dc_markers "$sid"
  _dc_write_transcript "$tr" "нет, неправильно, переделай"

  # Первый прогон — коррекция должна сработать.
  _run_detect "$sid" "$tr"
  if ! printf '%s' "$DC_OUT" | grep -q '"ok": false'; then
    echo "  rate-limit: 1-й прогон должен дать ok:false, получено: '$DC_OUT'" >&2; rc=1
  fi

  # Повтор сразу — rate-limit (<4ч) должен подавить.
  _run_detect "$sid" "$tr"
  if [ "$DC_RC" -ne 0 ]; then
    echo "  rate-limit: 2-й прогон ожидался exit 0, получено $DC_RC" >&2; rc=1
  fi
  if printf '%s' "$DC_OUT" | grep -q '"ok"'; then
    echo "  rate-limit: 2-й прогон не должен давать ok:false, получено: '$DC_OUT'" >&2; rc=1
  fi

  _dc_markers "$sid"; rm -f "$tr" 2>/dev/null || true
  return "$rc"
}
