---
name: implement
description: "Реализовать задачи из tasklist батчами (этап 5 AIDD). Используй после создания tasklist."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent
---

# Реализация задач (батч-режим)

Ты выполняешь этап 5 AIDD workflow — реализация. Задачи выполняются батчами независимых задач с авто-переходом между батчами. Паузы AIDD остаются на уровне этапа, а не внутри него: diff и подтверждение по каждой задаче не требуются.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — резолюция активного тикета:
  1. Primary: session_id из строки контекста `AIDD session_id: <S>` → файл `~/.claude/sessions/aidd/<S>.json`, поле `ticket`
  2. Fallback (legacy): содержимое `docs/.active_ticket`

## Тип задачи

infra (GCP/K8s ресурсы без изменений кода: gcloud/kubectl delete/describe/list/verify) → агент `infra-operator`; всё остальное → агент `implementer`.

## Алгоритм

1. Определение тикета:
   - Ticket: `$0`; если не передан — резолюция активного тикета (см. «Входные данные»): primary `~/.claude/sessions/aidd/<S>.json` → fallback `docs/.active_ticket`

2. Проверка gate TASKLIST_READY:
   - Прочитай `docs/tasklist/<ticket>.md`
   - Если не существует — сообщи: "Tasklist не найден. Сначала выполни `/tasks <ticket>`"
   - Если Status не содержит TASKLIST_READY — предупреди

3. Выбор батча:
   - Из текущей категории (порядок: Infrastructure → Code → Tests → Monitoring → Docs) выбери независимые задачи `- [ ]`
   - Если все задачи `- [x]` — сообщи: "Все задачи выполнены! Следующий шаг: `/review <ticket>`"

4. Запуск батча:
   - infra-задачи → агент `infra-operator`; code-задачи → агент `implementer` параллельно (макс 3)
   - Промпт infra:
     ```
     Ты — агент infra-operator. Прочитай инструкции из ~/.claude/agents/infra-operator/AGENT.md и выполни их.
     Ticket: <ticket>
     Выполни ТОЛЬКО: <задача>
     Логи: <путь>
     ```
   - Промпт code:
     ```
     Ты — агент implementer. Прочитай инструкции из ~/.claude/agents/implementer/AGENT.md и выполни их.
     Ticket: <ticket>
     Tasklist: docs/tasklist/<ticket>.md
     PRD: docs/prd/<ticket>.prd.md
     Plan: docs/plan/<ticket>.md
     Conventions: ~/.claude/conventions.md
     Реализуй ТОЛЬКО: <задача>. НЕ трогай чужие файлы.
     ```

5. После батча:
   - Прочитай tasklist, залогируй прогресс без СТОП, авто-переход к следующему батчу
   - Один и тот же файл → задачи только последовательно
   - После code-батча → запусти тесты

6. Итог (когда все задачи `- [x]`):
   - Выполненные задачи, изменённые файлы, результат тестов, прогресс N/M
   - Следующий шаг: `/review <ticket>`

## ВАЖНО

- Задачи выполняются батчами независимых задач; между батчами — авто-переход без СТОП
- Один и тот же файл — только последовательно, не параллельно
- После code-батча — запусти тесты
- **СТОП** только когда ВСЕ задачи `- [x]`
