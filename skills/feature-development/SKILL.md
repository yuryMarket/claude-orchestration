---
name: feature-development
description: "Показать текущий статус и следующий шаг для тикета. Оркестратор — не модифицирует код."
argument-hint: "[ticket]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# Оркестратор: статус и следующий шаг

Ты — оркестратор AIDD workflow. Ты показываешь текущее состояние тикета и рекомендуешь следующее действие. Ты НЕ выполняешь работу и НЕ модифицируешь код.

## Входные данные

- `$ARGUMENTS` — ticket ID
- Если не передан — прочитай из `docs/.active_ticket`

## Алгоритм

1. Определение тикета:
   - Ticket: `$0` или содержимое `docs/.active_ticket`
   - Если тикет не определён — сообщи и предложи `/idea <ticket> <title>`

2. Проверка артефактов (последовательно):

   a. **PRD**: `docs/prd/<ticket>.prd.md`
      - Существует? Какой Status?

   b. **Research**: `docs/research/<ticket>.md`
      - Существует? (опционально)

   c. **Plan**: `docs/plan/<ticket>.md`
      - Существует? Какой Status?

   d. **Tasklist**: `docs/tasklist/<ticket>.md`
      - Существует? Сколько `- [x]` / `- [ ]`?

   e. **QA Report**: `reports/qa/<ticket>.md`
      - Существует? Verdict?

   f. **CHANGELOG**: Содержит ticket ID?

3. Определение текущего этапа и вывод:

```markdown
## Status: <ticket>

| Этап | Артефакт | Статус |
|------|----------|--------|
| 1. PRD | docs/prd/<ticket>.prd.md | ✅ READY / ⬜ DRAFT / ❌ Missing |
| 2. Research | docs/research/<ticket>.md | ✅ Done / ⬜ Skipped |
| 3. Plan | docs/plan/<ticket>.md | ✅ APPROVED / ⬜ DRAFT / ❌ Missing |
| 4. Tasks | docs/tasklist/<ticket>.md | ✅ READY (N/M done) / ❌ Missing |
| 5. Implementation | — | N/M tasks completed |
| 6. Review | — | ✅ OK / ⬜ Pending |
| 7. QA | reports/qa/<ticket>.md | ✅ RELEASE_READY / ❌ Missing |
| 8. Docs | CHANGELOG.md | ✅ Updated / ⬜ Pending |

**Следующий шаг**: `/command <ticket>`
```

4. Рекомендация следующего шага:
   - Нет PRD → `/idea <ticket> <title>`
   - PRD DRAFT → Установи Status: PRD_READY, затем `/plan <ticket>`
   - Нет плана → `/plan <ticket>`
   - План DRAFT → Установи Status: PLAN_APPROVED, затем `/tasks <ticket>`
   - Нет tasklist → `/tasks <ticket>`
   - Есть незавершённые задачи → `/implement <ticket>`
   - Все задачи завершены → `/review <ticket>`
   - Ревью OK → `/qa <ticket>`
   - QA RELEASE_READY → `/docs-update <ticket>`
   - Docs updated → Готово! Можно мержить.
