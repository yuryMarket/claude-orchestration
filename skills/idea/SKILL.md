---
name: idea
description: "Создать или обновить PRD для тикета. Используй при начале новой фичи или задачи."
argument-hint: "[ticket] [title]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Agent
---

# Создание / обновление PRD

Ты выполняешь этап 1 AIDD workflow — создание PRD (Product Requirements Document).

## Входные данные

- `$ARGUMENTS` — первый аргумент = ticket ID, остальное = title
- Если аргументы не переданы — спроси у пользователя ticket и title

## Алгоритм

1. Парсинг аргументов:
   - Ticket: `$0` (первое слово из $ARGUMENTS)
   - Title: остальные слова из $ARGUMENTS

2. Подготовка директорий:
   - Создай `docs/prd/` если не существует
   - Создай `docs/` если не существует

3. Установка активного тикета (per-session + legacy):
   3.1. Определи session_id:
        - из контекста — строка `AIDD session_id: <S>` (инжектит хук session-start.sh), ЛИБО
        - `Bash(printf '%s' "$CLAUDE_CODE_SESSION_ID")`
   3.2. Если session_id известен — запиши per-session файл
        `~/.claude/sessions/aidd/<session_id>.json` с полями
        `{ticket, cwd, source:"idea", updated}` атомарно (write tmp + mv;
        через helper из `~/.claude/hooks/_lib/` или inline `python3 -c`):
        ```
        Bash: mkdir -p ~/.claude/sessions/aidd && python3 -c '
        import json, os, sys, tempfile, datetime
        sid, cwd, ticket = sys.argv[1], sys.argv[2], sys.argv[3]
        path = os.path.expanduser("~/.claude/sessions/aidd/%s.json" % sid)
        now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        data = {"ticket": ticket, "cwd": cwd, "source": "idea", "updated": now}
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
        with os.fdopen(fd, "w") as f: json.dump(data, f)
        os.replace(tmp, path)
        ' "<session_id>" "<cwd>" "<ticket>"
        ```
   3.3. Запиши ticket ID в `docs/.active_ticket` (legacy fallback) через helper
        условной записи — вызывай его всегда (независимо от того, известен ли
        session_id); helper сам решает, писать ли:
        ```
        Bash: bash ~/.claude/hooks/_lib/aidd-write-legacy.sh "<cwd>" "<ticket>"
        ```
        Helper пишет только если файл пуст или уже содержит тот же тикет, и
        НЕ перетирает указатель параллельной сессии (чужой тикет).

4. Делегирование агенту `analyst`:
   - Запусти Agent с subagent_type не указан (general-purpose), передав промпт:
     ```
     Ты — агент analyst. Прочитай инструкции из ~/.claude/agents/analyst/AGENT.md и выполни их.
     Ticket: <ticket>
     Title: <title>
     Шаблон PRD: ~/.claude/skills/idea/prd-template.md
     Путь выхода: docs/prd/<ticket>.prd.md
     Active ticket: docs/.active_ticket (legacy fallback; per-session пишет скилл /idea, не агент)
     ```

5. Покажи пользователю результат:
   - Путь к PRD
   - Статус: DRAFT
   - Открытые вопросы (если есть)
   - Следующий шаг: `/research $TICKET` или `/plan $TICKET`
