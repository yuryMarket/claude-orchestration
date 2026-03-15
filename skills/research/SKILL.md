---
name: research
description: "Исследовать кодовую базу и внешние источники для тикета. Используй после создания PRD."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, WebSearch, WebFetch, Agent
---

# Исследование для тикета

Ты выполняешь этап 2 AIDD workflow — исследование.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`
   - Если тикет не определён — попроси пользователя указать

2. Проверка gate:
   - Проверь существование `docs/prd/<ticket>.prd.md`
   - Если PRD не существует — сообщи: "PRD не найден. Сначала выполни `/idea <ticket> <title>`"

3. Подготовка контекста:
   - Прочитай PRD: `docs/prd/<ticket>.prd.md`
   - Извлеки ключевой вопрос исследования из секций "Контекст" и "Цели"

4. Делегирование агенту `deep-researcher`:
   - Запусти Agent с subagent_type="deep-researcher", передав промпт:
     ```
     Исследуй вопрос для тикета <ticket>.

     PRD (контекст):
     <содержимое PRD>

     Шаблон отчёта: ~/.claude/skills/research/research-template.md
     Сохрани результат в: docs/research/<ticket>.md

     Фокус исследования: ответь на вопросы из PRD, исследуй текущую кодовую базу, найди лучшие практики и возможные решения.
     ```

5. Покажи пользователю результат:
   - Путь к отчёту
   - Краткое резюме находок
   - Следующий шаг: `/plan <ticket>`
