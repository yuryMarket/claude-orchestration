# Compact Recovery Context
<!-- Generated: 2026-06-09T14:45:20Z | trigger: manual -->

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
- Agent
- Write: /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/cdk8s-pdb-alwaysallow-gotcha.md
- Edit: /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/MEMORY.md
- Read: /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/MEMORY.md
- Edit: /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/MEMORY.md

### Последние сообщения пользователя:
- 1	import * as k8s from 'cdk8s-lib/imports/k8s/1.24'; 2	 3	interface Options { 4	    name: string; 5	    minAvailable?: number; 6	    maxUnavailable?: number; 7	} 8	 9	export function KubePodDisruption...
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-349.md has been updated successfully. (file state is current in your context — no need to Read it back)
- The user doesn't want to proceed with this tool use. The tool use was rejected (eg. if it was a file edit, the new_string was NOT written to the file). STOP what you are doing and wait for the user to...
- [Request interrupted by user for tool use]
- продолжаю.
- похоже, сейчас верно. Проверяй.  https://github.com/one-thd/core-ai-cdk8s/pull/5681/changes
- уже зеленый, сверяй.
- сделал мердж, ждем результата. Мусор уберем в будущем.
- File created successfully at: /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/cdk8s-pdb-alwaysallow-gotcha.md (file state is current in your context — no need to Read it ba...
- The file /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/MEMORY.md has been updated successfully. (file state is current in your context — no need to Read it back)
