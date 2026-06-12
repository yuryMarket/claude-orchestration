# Compact Recovery Context
<!-- Generated: 2026-06-11T13:20:13Z | trigger: manual -->

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
- Идея хорошая — она DRY и закрывает дыру «новые приложения забудут про фикс». И её **можно сделать без CR**, но с одним жёстким условием.

**Ключевое условие (иначе прилетит prod + CR):** это должен быть **новый отдельный констракт**, а **не** правка общего `kubePodDisruptionBudget.ts`. Общий оставля...
- Не гоняюсь за косметическим markdown-lint в плане (это пред-существующие предупреждения от генерации — на суть не влияют). Артефакты готовы.

# 🚩 Сигнал: все артефакты COR1-349 обновлены и готовы

## Твои решения учтены
- **#1** — Трек 1 → **3 PR** (PR-1 core-ai-dev 42 · PR-2 merch+hr-systems+stores...
- Идея хорошая — она DRY и закрывает дыру «новые приложения забудут про фикс». И её **можно сделать без CR**, но с одним жёстким условием.

**Ключевое условие (иначе прилетит prod + CR):** это должен быть **новый отдельный констракт**, а **не** правка общего `kubePodDisruptionBudget.ts`. Общий оставля...
- Не гоняюсь за косметическим markdown-lint в плане (это пред-существующие предупреждения от генерации — на суть не влияют). Артефакты готовы.

# 🚩 Сигнал: все артефакты COR1-349 обновлены и готовы

## Твои решения учтены
- **#1** — Трек 1 → **3 PR** (PR-1 core-ai-dev 42 · PR-2 merch+hr-systems+stores...
- Идея хорошая — она DRY и закрывает дыру «новые приложения забудут про фикс». И её **можно сделать без CR**, но с одним жёстким условием.

**Ключевое условие (иначе прилетит prod + CR):** это должен быть **новый отдельный констракт**, а **не** правка общего `kubePodDisruptionBudget.ts`. Общий оставля...

### Последние действия Claude (tool_use):
- mcp__atlassian__jira_add_comment
- mcp__atlassian__jira_add_comment
- mcp__atlassian__jira_add_comment
- ToolSearch
- mcp__atlassian__jira_edit_comment

### Последние сообщения пользователя:
- The file /Users/yury_shubianok/.claude/projects/-Users-yury-shubianok-core-ai/memory/cdk8s-pdb-alwaysallow-gotcha.md has been updated successfully. (file state is current in your context — no need to ...
- нужно, чтобы ты добавил комментарии в текущую задачу COR1-349 1. В первом комментарии опиши всю цепочку событий и проблем, которые у нас возникают, начиная от блокирующих PDB, которые затем приводят к...
- === np namespaces для 8 prod-coupled приложений === --- core-ai-dev/ir-mcp-server np-te-core-ai/np-te-core-ai-usce1/core-ai-dev/app.ts --- merch/doc-ingestion-chunk-processor np-te-core-ai/np-te-core-...
- {"result":"{\n  \"id\": \"3994798\",\n  \"body\": \"Incident chain — why non-prod node-pool upgrades deadlocked\\nThe upgrade deadlock was the end of a chain of independent problems that compounded. I...
- {"result":"{\n  \"id\": \"3994805\",\n  \"body\": \"PDB fix — centralizing AlwaysAllow  fleet convergence\\nRoot cause.\\ncdk8s-lib\\n's\\nKubePodDisruptionBudget.toJson()\\nre-runs the typed k8s 1.24...
- {"result":"{\n  \"id\": \"3994824\",\n  \"body\": \"Apps not converged — prod-coupling (action needed)\\nThese 8 apps could\\nnot\\nbe included in the non-prod PDB convergence. In the repo layout thei...
- {"result":"{\n  \"id\": \"3994836\",\n  \"body\": \"Gatekeeper (non-prod) — durable fix\\nPR #5742 (merged) — https://github.com/one-thd/core-ai-cdk8s/pull/5742 — hardens the non-prod gatekeeper valid...
- {"result":"{\n  \"id\": \"3994845\",\n  \"body\": \"Verification — config, behavioral, and chaos tests\\nAll tests run on \\nnp-te-core-ai\\n after PR #5742 deployed.\\nTest A — live configuration (bo...
- {"result":"{\n  \"id\": \"3994848\",\n  \"body\": \"Summary\\nProblem.\\n Non-prod node-pool upgrades could deadlock. Two independent eviction blockers compounded during an upgrade: (1) PodDisruptionB...
- {"result":"{\n  \"id\": \"3994824\",\n  \"body\": \"Apps not converged — prod-coupling (action needed)\\nThese 8 apps could \\nnot\\n be included in the non-prod PDB convergence. In the repo layout th...
