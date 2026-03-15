---
name: review
description: "Код-ревью изменений по тикету. Используй после реализации."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Agent
---

# Код-ревью

Ты выполняешь этап 6 AIDD workflow — код-ревью.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Динамический контекст

Текущий diff:
!`git diff --stat`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`

2. Получение diff:
   - Выполни `git diff main...HEAD` (или `git diff` если нет ветки main)
   - Если diff пуст — сообщи: "Нет изменений для ревью"

3. Делегирование агенту `reviewer`:
   - Запусти Agent с промптом:
     ```
     Ты — агент reviewer. Прочитай инструкции из ~/.claude/agents/reviewer/AGENT.md и выполни их.
     Ticket: <ticket>
     PRD: docs/prd/<ticket>.prd.md
     Tasklist: docs/tasklist/<ticket>.md
     Conventions: ~/.claude/conventions.md

     Проанализируй изменения в текущей ветке. Используй git diff и Read для анализа файлов.
     ```

4. Покажи пользователю результат:
   - Количество проверенных файлов
   - Находки по severity (blocking / important / suggestion)
   - Вердикт: REVIEW_OK или NEEDS_FIX
   - Следующий шаг: `/qa <ticket>` или `/implement <ticket>` для исправлений
