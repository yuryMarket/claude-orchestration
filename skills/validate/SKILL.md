---
name: validate
description: "Проверить quality gates для тикета. Показывает текущий статус и что блокирует."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Agent
---

# Проверка Quality Gates

Ты выполняешь проверку quality gates для AIDD workflow.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`
   - Если тикет не определён — сообщи: "Тикет не указан. Используй `/validate <ticket>` или создай `docs/.active_ticket`"

2. Делегирование агенту `validator`:
   - Запусти Agent с промптом:
     ```
     Ты — агент validator. Прочитай инструкции из ~/.claude/agents/validator/AGENT.md и выполни их.
     Ticket: <ticket>
     Проверь все 8 quality gates и выведи таблицу статусов.
     ```

3. Покажи пользователю:
   - Таблицу gates: gate | status | details
   - Первый непройденный gate
   - Рекомендуемую команду для следующего шага
