---
name: qa
description: "Запустить QA-проверки и сгенерировать отчёт. Используй после прохождения ревью."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Agent
---

# QA и тестирование

Ты выполняешь этап 7 AIDD workflow — QA и тестирование.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Проверка gate REVIEW_OK:
   - Если есть blocking-находки из ревью — предупреди: "Есть blocking-замечания. Рекомендуется сначала исправить."

3. Подготовка:
   - Создай `reports/qa/` если не существует

4. Делегирование агенту `qa-engineer`:
   - Запусти Agent с промптом:
     ```
     Ты — агент qa-engineer. Прочитай инструкции из ~/.claude/agents/qa-engineer/AGENT.md и выполни их.
     Ticket: <ticket>
     Tasklist: docs/tasklist/<ticket>.md
     Путь выхода: reports/qa/<ticket>.md

     Запусти все доступные проверки: lint, type-check, tests, security scan.
     ```

5. Покажи пользователю результат:
   - Путь к QA-отчёту
   - Summary: passed/failed/skipped
   - Критические проблемы
   - Вердикт: RELEASE_READY или NEEDS_FIX
   - Следующий шаг: `/docs-update <ticket>` или `/implement <ticket>`
