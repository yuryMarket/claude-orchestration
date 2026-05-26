#!/usr/bin/env bash
# pre-compact.sh — PreCompact hook
# Назначение: перед компакцией сохранить ключевой контекст (AIDD-тикет, git, транскрипт) в файл
#              для последующего восстановления хуком session-start-compact.sh.
# Событие: PreCompact
# Matcher: нет
# Exit 0 = всегда (не блокирует компакцию)
set -euo pipefail

# Защита от рекурсии: если хук был запущен из дочернего процесса Claude — выйти
if [ -n "${CLAUDE_HOOK_SPAWNED:-}" ]; then
  exit 0
fi
export CLAUDE_HOOK_SPAWNED=1

# Читаем stdin (может быть пустым при ошибках Claude Code)
PAYLOAD="$(cat 2>/dev/null || true)"

# Извлекаем поля из JSON через python3 (надёжнее, чем grep/sed для произвольного JSON)
CWD=""
TRANSCRIPT=""
TRIGGER=""
if command -v python3 >/dev/null 2>&1 && [ -n "$PAYLOAD" ]; then
  CWD=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")
  TRANSCRIPT=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")
  TRIGGER=$(echo "$PAYLOAD" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('trigger',''))" 2>/dev/null || echo "")
fi

# Определяем путь к summary-файлу: проектный, если есть маркеры; иначе глобальный
SUMMARY_PATH=""
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  for marker in .git package.json pyproject.toml Makefile go.mod cdk8s.yaml; do
    if [ -e "$CWD/$marker" ]; then
      SUMMARY_PATH="$CWD/.claude/compact-summary.md"
      break
    fi
  done
fi
if [ -z "$SUMMARY_PATH" ]; then
  SUMMARY_PATH="$HOME/.claude/compact-summary.md"
fi

# Создаём родительский каталог
mkdir -p "$(dirname "$SUMMARY_PATH")" 2>/dev/null || true

# Временный файл для сборки summary
TMP_FILE="$(mktemp 2>/dev/null || echo "/tmp/compact-summary-$$.md")"
TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo 'unknown')"

# Шапка
{
  echo "# Compact Recovery Context"
  echo "<!-- Generated: ${TIMESTAMP} | trigger: ${TRIGGER} -->"
  echo ""
} > "$TMP_FILE"

# Git-блок: статус и последние коммиты
{
  echo "## Git состояние"
  echo ""
  echo '```'
  if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    (cd "$CWD" && git status --short 2>/dev/null | head -20) || true
    echo "---"
    (cd "$CWD" && git log --oneline -5 2>/dev/null) || true
  else
    echo "(CWD недоступен)"
  fi
  echo '```'
  echo ""
} >> "$TMP_FILE" 2>/dev/null || true

# AIDD-блок: только если есть активный тикет в проекте
if [ -n "$CWD" ] && [ -f "$CWD/docs/.active_ticket" ]; then
  TICKET="$(cat "$CWD/docs/.active_ticket" 2>/dev/null | tr -d '[:space:]' || echo "")"
  if [ -n "$TICKET" ]; then
    {
      echo "## AIDD Workflow"
      echo ""
      echo "**Тикет**: ${TICKET}"
      echo ""
      echo "**Незавершённые задачи**:"
      echo '```'
      grep "^- \[ \]" "$CWD/docs/tasklist/${TICKET}.md" 2>/dev/null | head -10 || echo "(нет данных)"
      echo '```'
      echo ""
      echo "**Архитектурный план** (начало):"
      echo '```'
      head -20 "$CWD/docs/plan/${TICKET}.md" 2>/dev/null || echo "(нет данных)"
      echo '```'
      echo ""
    } >> "$TMP_FILE" 2>/dev/null || true
  fi
fi

# Transcript-блок: извлечение последних user-сообщений и ключевых решений из assistant
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && command -v python3 >/dev/null 2>&1; then
  {
    echo "## Ключевые решения из разговора"
    echo ""
    python3 - "$TRANSCRIPT" <<'PYEOF' 2>/dev/null || true
import json
import sys
import re

path = sys.argv[1]
KEYWORDS = ["решено", "используем", "BLOCKING", "следующий шаг", "выбрали"]
user_msgs = []
assistant_decisions = []
assistant_tool_uses = []

try:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            rec_type = rec.get("type")
            msg = rec.get("message") or {}
            role = msg.get("role")
            content = msg.get("content")

            if rec_type == "user" or role == "user":
                # content может быть строкой или списком блоков
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    parts = []
                    for block in content:
                        if isinstance(block, dict):
                            if block.get("type") == "text":
                                parts.append(block.get("text", ""))
                            elif "content" in block and isinstance(block.get("content"), str):
                                parts.append(block["content"])
                    text = "\n".join(parts)
                else:
                    text = ""
                text = text.strip()
                # Пропускаем чисто служебные tool_result сообщения
                if text and not text.startswith("<") and len(text) > 5:
                    user_msgs.append(text)

            elif rec_type == "assistant" or role == "assistant":
                if isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get("type") == "text":
                            t = block.get("text", "")
                            for kw in KEYWORDS:
                                if kw.lower() in t.lower():
                                    snippet = t.strip()
                                    if len(snippet) > 300:
                                        snippet = snippet[:300] + "..."
                                    assistant_decisions.append(snippet)
                                    break
                        elif block.get("type") == "tool_use":
                            name = block.get("name", "")
                            inp = block.get("input") or {}
                            # Краткое описание tool_use
                            descr = name
                            if isinstance(inp, dict):
                                if "file_path" in inp:
                                    descr = f"{name}: {inp['file_path']}"
                                elif "command" in inp:
                                    cmd = str(inp["command"])[:120]
                                    descr = f"{name}: {cmd}"
                                elif "pattern" in inp:
                                    descr = f"{name}: {inp['pattern']}"
                            assistant_tool_uses.append(descr)
except Exception:
    pass

# Последние 5 решений assistant
print("### Решения и ключевые фразы:")
for d in assistant_decisions[-5:]:
    print(f"- {d}")
print()

# Последние 5 tool_use
print("### Последние действия Claude (tool_use):")
for t in assistant_tool_uses[-5:]:
    print(f"- {t}")
print()

# Последние 10 user-сообщений
print("### Последние сообщения пользователя:")
for m in user_msgs[-10:]:
    snippet = m.replace("\n", " ").strip()
    if len(snippet) > 200:
        snippet = snippet[:200] + "..."
    print(f"- {snippet}")
PYEOF
    echo ""
  } >> "$TMP_FILE" 2>/dev/null || true
else
  # Fallback без python3: только пометка, что транскрипт не проанализирован
  {
    echo "## Ключевые решения из разговора"
    echo ""
    echo "_(python3 недоступен или transcript_path не задан — анализ транскрипта пропущен)_"
    echo ""
  } >> "$TMP_FILE" 2>/dev/null || true
fi

# Обрезка до 6000 символов
FINAL_CONTENT="$(cat "$TMP_FILE" 2>/dev/null || echo "")"
MAX_LEN=6000
CUR_LEN=${#FINAL_CONTENT}
if [ "$CUR_LEN" -gt "$MAX_LEN" ]; then
  FINAL_CONTENT="${FINAL_CONTENT:0:$MAX_LEN}"
  FINAL_CONTENT="${FINAL_CONTENT}
...[truncated]"
fi

# Запись итогового файла
printf '%s\n' "$FINAL_CONTENT" > "$SUMMARY_PATH" 2>/dev/null || true

# Удаляем временный файл
rm -f "$TMP_FILE" 2>/dev/null || true

# Никогда не блокируем компакцию
exit 0
