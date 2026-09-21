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
- Если не передан — резолюция активного тикета:
  1. Primary: session_id из строки контекста `AIDD session_id: <S>` → файл `~/.claude/sessions/aidd/<S>.json`, поле `ticket`
  2. Fallback (legacy): содержимое `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0`; если не передан — резолюция активного тикета (см. «Входные данные»): primary `~/.claude/sessions/aidd/<S>.json` → fallback `docs/.active_ticket`
   - Если тикет не определён — сообщи: "Тикет не указан. Используй `/validate <ticket>` или создай `docs/.active_ticket`"

2. Делегирование агенту `validator`:
   - Запусти Agent с промптом:
     ```
     Ты — агент validator. Прочитай инструкции из ~/.claude/agents/validator/AGENT.md и выполни их.
     Ticket: <ticket>
     Проверь все 8 quality gates и выведи таблицу статусов.
     ```

3. Информационный gate «Worklog» (проверяется скиллом, не блокирует):
   - Существует ли `docs/reports/<ticket>-worklog.md` (вне проекта — `~/docs/reports/<ticket>-worklog.md`)
   - Есть → `✅ Present`; нет → `⬜ Pending — выполни /worklog <ticket>`
   - Добавь строку в итоговую таблицу: `| Worklog | <статус> | docs/reports/<ticket>-worklog.md |`

4. Покажи пользователю:
   - Таблицу gates: gate | status | details (включая строку Worklog)
   - Первый непройденный gate
   - Рекомендуемую команду для следующего шага
