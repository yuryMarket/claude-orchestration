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

3. Установка активного тикета:
   - Запиши ticket ID в `docs/.active_ticket`

4. Делегирование агенту `analyst`:
   - Запусти Agent с subagent_type не указан (general-purpose), передав промпт:
     ```
     Ты — агент analyst. Прочитай инструкции из ~/.claude/agents/analyst/AGENT.md и выполни их.
     Ticket: <ticket>
     Title: <title>
     Шаблон PRD: ~/.claude/skills/idea/prd-template.md
     Путь выхода: docs/prd/<ticket>.prd.md
     Active ticket: docs/.active_ticket
     ```

5. Покажи пользователю результат:
   - Путь к PRD
   - Статус: DRAFT
   - Открытые вопросы (если есть)
   - Следующий шаг: `/research $TICKET` или `/plan $TICKET`
