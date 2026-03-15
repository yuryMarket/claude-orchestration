---
name: implement
description: "Реализовать следующую задачу из tasklist. Используй после создания tasklist."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
---

# Реализация задачи

Ты выполняешь этап 5 AIDD workflow — реализация. Одна задача за вызов.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Проверка gate TASKLIST_READY:
   - Прочитай `docs/tasklist/<ticket>.md`
   - Если не существует — сообщи: "Tasklist не найден. Сначала выполни `/tasks <ticket>`"
   - Если Status не содержит TASKLIST_READY — предупреди

3. Поиск следующей задачи:
   - Найди первую строку `- [ ]` в tasklist
   - Если все задачи `- [x]` — сообщи: "Все задачи выполнены! Следующий шаг: `/review <ticket>`"

4. Делегирование агенту `implementer`:
   - Запусти Agent с промптом:
     ```
     Ты — агент implementer. Прочитай инструкции из ~/.claude/agents/implementer/AGENT.md и выполни их.
     Ticket: <ticket>
     Tasklist: docs/tasklist/<ticket>.md
     PRD: docs/prd/<ticket>.prd.md
     Plan: docs/plan/<ticket>.md
     Conventions: ~/.claude/conventions.md

     Выполни ОДНУ следующую незавершённую задачу. После выполнения ОСТАНОВИСЬ.
     ```

5. Покажи пользователю результат:
   - Какая задача выполнена
   - Изменённые файлы
   - Результат тестов
   - Прогресс: N/M задач
   - Следующий шаг: `/implement <ticket>` или `/review <ticket>`

## ВАЖНО

- Одна задача за вызов — СТРОГО
- Показать diff перед применением изменений
- Дождаться подтверждения пользователя
- После одной задачи — СТОП
