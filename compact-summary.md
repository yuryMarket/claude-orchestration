# Compact Recovery Context
<!-- Generated: 2026-05-29T08:03:43Z | trigger: manual -->

## Git состояние

```
---
```

## AIDD Workflow

**Тикет**: COR1-332

**Незавершённые задачи**:
```
- [ ] Local synth passes
- [ ] Generated YAML manifests reviewed
- [ ] After merge → Spinnaker auto-apply в np кластеры
- [ ] Verify в np-te-core-ai-usce1: new constraint present, old constraint gone, EndpointSlice populated, no new `unable to sync` errors
- [ ] Verify в np-te-core-ai-usea1: same
- [ ] Live kubectl patch revert'нут через Spinnaker reconcile webhook config
- [ ] Prod deploy через ServiceNow CR (отдельный шаг)
```

**Архитектурный план** (начало):
```
# Plan v3: COR1-332 — Custom ConstraintTemplate (Option C) для exempt `system:apiserver`

Status: PLAN_APPROVED (v3, 2026-05-28 — user explicitly chose Option C — Rego exempt by `userInfo.username == "system:apiserver"` после deep investigation H9)
Date: 2026-05-28
PRD: docs/prd/COR1-332.prd.md (см. §13 Amendment 1 + §14 Amendment 2 для final RCA H9)
Type: CDK8s code change — replace `DisallowDefaultNamespace` с custom ConstraintTemplate + Constraint

**Supersedes:**

- Plan v1 (per-node drain) — ABORTED 2026-05-28: RCA H3 (Cilium BPF stale) была неверна
- Plan v2 (node pool upgrade) — ABORTED 2026-05-28 late: upgrade не помог (pod на 1.35.3 ноде тоже CrashLoop), RCA H7 (version skew) опровергнута

**Research артефакты (v3-relevant):**

- `docs/research/COR1-332-infra-snapshot.md` — initial live snapshot (RCA H3, ошибочная)
- `docs/research/COR1-332-deeper-diagnostics.md` — Q1/Q2/Q3 (RCA H7, ошибочная)
- `docs/research/COR1-332-cluster-diff-upgrade.md` — TF identical, runtime разница
- `.claude/docs/research/COR1-332-audit-upgrade-initiator.md` — Google AUTO upgrade
- `.claude/docs/research/COR1-332-cause-and-fix.md` — fix paths matrix
- `docs/research/COR1-332-access-audit.md` — права user подтверждены
```

## Ключевые решения из разговора

### Решения и ключевые фразы:
- ## Этап 1: PRD — готов

**Артефакт:** `docs/prd/COR1-332.prd.md` (158 строк) · `research_needed: true`

**Goal:** восстановить Argo Rollouts controller в `np-te-core-ai-usce1` — **только после** подтверждения root cause, не по непроверенной гипотезе.

**Структура (по твоему feedback):**
- §2 Known f...
- ## Что вообще такое Argo Rollouts и почему его поломка — это проблема

**Argo Rollouts** — это контроллер внутри кластера Kubernetes, который умеет постепенно выкатывать новые версии приложений (canary, blue-green). Вместо «убил старые pod'ы → создал новые», он шаг за шагом продвигает деплой: «давай...
- Отличный вопрос — да, есть **намного более простой паттерн**. Я думал не в ту сторону.

В `gatekeeper.ts` уже используется `excludedNamespaces` **на уровне самой constraint** (а не на уровне webhook). Это **первоклассная фича Gatekeeper**, и она уже применяется в 3 constraints этого же файла:

```ty...
- ## GKE upgrade stuck — нашёл причину

**На ноде `89a3` только 1 non-DaemonSet pod:** `doc-synopsis-74db764dc4-l5lxg` в CrashLoopBackOff (3606 restarts, 13 дней). Остальные — DaemonSet'ы (drain их пропускает).

**Драма с PDB:**
```
core-ai-dev/doc-synopsis  PDB  maxUnavailable=3  allowedDisruptions=0...

### Последние действия Claude (tool_use):
- ToolSearch
- Agent
- Read: /Users/yury_shubianok/docs/quick-lookup/2026-05-28-cor1-332-jira.md
- mcp__atlassian__jira_update_issue
- TodoWrite

### Последние сообщения пользователя:
- === usea1 violations + apiserver status === totalViolations= auditTimestamp= --- Cluster-wide CrashLoop count (usea1) 1
- 2026-05-28T18:36:06.594954Z	"HTTP" verb="GET" URI="/apis/constraints.gatekeeper.sh/v1beta1/disallowdefaultnamespaceexceptsystem/disallow-default-namespace-except-system" latency="9.224852ms" userAgent...
- Exit code 1 (eval):3: unmatched '
- Service/kubernetes: rv=196 managers= EndpointSlice/kubernetes: rv=1779978596006383006 managers= ConfigMap/kube-root-ca.crt: rv=259 managers= ServiceAccount/default: rv=248 managers=
- === BEFORE delete === name=kubernetes rv=1779978596006383006 endpoints=[{"addresses":["10.43.132.130"],"conditions":{"ready":true}}]  === DELETE EndpointSlice kubernetes === endpointslice.discovery.k8...
- Todos have been modified successfully. Ensure that you continue to use the todo list to track your progress. Please proceed with the current tasks if applicable
- теперь надо добавить всю информацию в тикет и исправить, переписать ту, которая уже указана. Нужно конкретно указать проблему, с которой мы столкнулись. Она указана с аргораллаутами.  Потом нужно расп...
- 1	# COR1-332 — Argo Rollouts not reconciling in np-te-core-ai-usce1 2	 3	**Дата получения**: 2026-05-28 4	 5	## Основные поля 6	 7	| Поле | Значение | 8	|------|----------| 9	| **Key** | COR1-332 | 10...
- {"result":"{\n  \"message\": \"Issue updated successfully\",\n  \"issue\": {\n    \"id\": \"5481097\",\n    \"key\": \"COR1-332\",\n    \"summary\": \"Cluster-wide outage in np-te-core-ai-usce1: Gatek...
- Todos have been modified successfully. Ensure that you continue to use the todo list to track your progress. Please proceed with the current tasks if applicable
