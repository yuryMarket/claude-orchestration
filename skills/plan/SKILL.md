---
name: plan
description: "Создать архитектурный план для тикета. Используй после PRD и опционального research."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Agent
---

# Создание архитектурного плана

Ты выполняешь этап 3 AIDD workflow — архитектура и план.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Проверка gate PRD_READY:
   - Прочитай `docs/prd/<ticket>.prd.md`
   - Если не существует — сообщи: "PRD не найден. Сначала выполни `/idea <ticket> <title>`"
   - Если Status: DRAFT — предупреди: "PRD в статусе DRAFT. Рекомендуется установить Status: PRD_READY перед планированием. Продолжить?"

3. Подготовка контекста:
   - Прочитай PRD
   - Прочитай research `docs/research/<ticket>.md` (если существует)

4. Делегирование агенту `planner`:
   - Запусти Agent с промптом:
     ```
     Ты — агент planner. Прочитай инструкции из ~/.claude/agents/planner/AGENT.md и выполни их.
     Ticket: <ticket>
     PRD: docs/prd/<ticket>.prd.md
     Research: docs/research/<ticket>.md (если существует)
     Шаблон плана: ~/.claude/skills/plan/plan-template.md
     Путь выхода: docs/plan/<ticket>.md
     ADR (если нужен): docs/adr/<ticket>-<decision>.md
     ```

5. Покажи пользователю результат:
   - Путь к плану
   - Ключевые архитектурные решения
   - Риски
   - Следующий шаг: установи `Status: PLAN_APPROVED` в плане, затем `/tasks <ticket>`
