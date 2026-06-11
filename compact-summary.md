# Compact Recovery Context
<!-- Generated: 2026-06-10T14:27:55Z | trigger: auto -->

## Git состояние

```
---
```

## AIDD Workflow

**Тикет**: COR1-330

**Незавершённые задачи**:
```
(нет данных)
```

**Архитектурный план** (начало):
```
---
Status: DRAFT
Ticket: COR1-330
---

# Plan: COR1-330 — OPA auto-approval для Agent Engine resource types (tfe-np-te-core-ai)

Status: DRAFT
Date: 2026-06-08
PRD: .claude/docs/prd/COR1-330.prd.md
Research:
- .claude/docs/research/COR1-330.md (инвентаризация типов, расчёт ресурсов)
- .claude/docs/research/COR1-330-module-scoped.md (механизм OPA, module-scoped подходы A/B/C)
- .claude/docs/research/COR1-330-security.md (security-классификация, DENY-список, вердикты)

> **Замечания к PRD**: (1) PRD предлагает `total_resource_changes_allowed = 60` — это ОШИБКА (расчёт для shared VPC без SWP). Корректное значение — см. раздел "Лимит" ниже. (2) BLOCKING-вопрос PRD про prod workspace (`tfe-pr-te-core-ai`) — **out of scope**, выделен в отдельный тикет. Этот план затрагивает только `tfe-np-te-core-ai`.

---

## 1. Архитектурное решение
```

## Ключевые решения из разговора

### Решения и ключевые фразы:
- Сверка с ground truth (я прогнал сам, не через интерпретацию агентов) — и она **опровергла** последний вердикт суб-агента. Важно.

## Противоречие разрешено: templates НЕ удалены

Все 7 instance-templates, на которые ссылаются MIG, **существуют** (проверил `instance-templates list` против ссылок каж...
- Короткий ответ: **да, ноды можно догнать до gke.2190000 ДО правки PDB-конструкта** — конструкт не предусловие апгрейда. Но есть *другое* предусловие: **те самые 22 блокирующих PDB надо расчистить перед апгрейдом**, иначе drain снова застрянет, как 28.05.

## Почему 22 PDB всё равно блокируют (даже с...
- # 🚩 Сигнал: все артефакты по COR1-349 готовы

## Прогресс: COR1-349
| # | Этап | Статус | Артефакт |
|---|------|--------|----------|
| 1 | PRD | ✅ | [COR1-349.prd.md](.claude/docs/prd/COR1-349.prd.md) — `PRD_READY` |
| 2 | Исследование | ✅ | `.claude/docs/{research,investigations}/COR1-341-*.md` (1...
- Не гоняюсь за косметическим markdown-lint в плане (это пред-существующие предупреждения от генерации — на суть не влияют). Артефакты готовы.

# 🚩 Сигнал: все артефакты COR1-349 обновлены и готовы

## Твои решения учтены
- **#1** — Трек 1 → **3 PR** (PR-1 core-ai-dev 42 · PR-2 merch+hr-systems+stores...
- Идея хорошая — она DRY и закрывает дыру «новые приложения забудут про фикс». И её **можно сделать без CR**, но с одним жёстким условием.

**Ключевое условие (иначе прилетит prod + CR):** это должен быть **новый отдельный констракт**, а **не** правка общего `kubePodDisruptionBudget.ts`. Общий оставля...

### Последние действия Claude (tool_use):
- Edit: /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md
- Edit: /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md
- Edit: /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md
- Edit: /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md
- Agent

### Последние сообщения пользователя:
- === now === 13:46:44 === op progress === RUNNING	Updating e2-standard-8, done with 20 out of 29 nodes (69.0%): 1 being processed, 4 succeeded === прогресс-таймлайн (poll, последние 6) === 13:37:44 | R...
- я хочу убедиться, что GKE полностью сам сможет провести апгрейд и ничего не зависит, если мы применим наши текущие конфигурации. Поэтому пусть все идет само, ничего не форси.
- давай пока продолжим работу по триггеру, передеплоя PDB во всех остальных приложениях. Напоминаю, что в рамках этого пиара мы триггернули и передеплоили те PDB, которые нас блокировали, но также нам н...
- === всего np app.ts с PDB-хелпером KubePodDisruptionBudget ===      104 === уже тронуты в PR-1 (маркер-комментарий) ===       19  === ОСТАВШИЕСЯ — по командам (team) ===    5 blinds    4 com   29 core...
- Your questions have been answered: "Как сгруппировать ~80 оставшихся касаний app.ts в PR для ленивой сходимости?"="4 PR по кластерам команд". You can now continue with these answers in mind.
- 1	# COR1-349: Durable konnectivity fix — np PDB AlwaysAllow + Gatekeeper к fail-closed 2	 3	Status: TASKLIST_READY 4	Progress: Трек 1 / PR-1 #5681 открыт (реализация идёт) 5	Date: 2026-06-09 6	PRD: .c...
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md has been updated successfully. (file state is current in your context — no need to Read it back)
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md has been updated successfully. (file state is current in your context — no need to Read it back)
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md has been updated successfully. (file state is current in your context — no need to Read it back)
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md has been updated successfully. (file state is current in your context — no need to Read it back)
