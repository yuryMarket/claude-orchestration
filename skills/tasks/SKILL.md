---
name: tasks
description: "Декомпозировать план в гранулярные задачи. Используй после утверждения плана."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Agent
---

# Декомпозиция задач

Ты выполняешь этап 4 AIDD workflow — декомпозиция плана в задачи.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Проверка gate PLAN_APPROVED:
   - Прочитай `docs/plan/<ticket>.md`
   - Если не существует — сообщи: "План не найден. Сначала выполни `/plan <ticket>`"
   - Если Status не содержит PLAN_APPROVED — предупреди: "План не утверждён. Установи `Status: PLAN_APPROVED` перед декомпозицией."

3. Делегирование агенту `task-planner`:
   - Запусти Agent с промптом:
     ```
     Ты — агент task-planner. Прочитай инструкции из ~/.claude/agents/task-planner/AGENT.md и выполни их.
     Ticket: <ticket>
     PRD: docs/prd/<ticket>.prd.md
     Plan: docs/plan/<ticket>.md
     Шаблон: ~/.claude/skills/tasks/tasklist-template.md
     Путь выхода: docs/tasklist/<ticket>.md
     ```

4. Покажи пользователю результат:
   - Путь к tasklist
   - Количество задач по категориям
   - Следующий шаг: `/implement <ticket>`
