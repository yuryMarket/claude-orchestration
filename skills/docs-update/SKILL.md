---
name: docs-update
description: "Обновить документацию после завершения фичи. Используй после прохождения QA."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Agent
---

# Обновление документации

Ты выполняешь этап 8 AIDD workflow — обновление документации.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Проверка gate RELEASE_READY:
   - Проверь `reports/qa/<ticket>.md` — если Verdict: NEEDS_FIX, предупреди

3. Делегирование агенту `tech-writer`:
   - Запусти Agent с промптом:
     ```
     Ты — агент tech-writer. Прочитай инструкции из ~/.claude/agents/tech-writer/AGENT.md и выполни их.
     Ticket: <ticket>
     PRD: docs/prd/<ticket>.prd.md
     Tasklist: docs/tasklist/<ticket>.md
     Plan: docs/plan/<ticket>.md

     Обнови: CHANGELOG.md, README (если нужно), runbooks (если нужно).
     ```

4. Покажи пользователю результат:
   - Список обновлённых файлов
   - Следующий шаг: `/validate <ticket>` для финальной проверки
