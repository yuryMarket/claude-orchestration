# Compact Recovery Context
<!-- Generated: 2026-05-29T13:42:51Z | trigger: manual -->

## Git состояние

```
---
```

## AIDD Workflow

**Тикет**: COR1-338

**Незавершённые задачи**:
```
(нет данных)
```

**Архитектурный план** (начало):
```
# Plan: COR1-338 — Идентификация владельцев IP-адресов Cloud Armor (Pyroscope / Otel OIDC)

Status: PLAN_APPROVED
Date: 2026-05-29
PRD: docs/prd/COR1-338.prd.md
Research: docs/research/COR1-338.md
GCP raw: .claude/docs/investigations/COR1-338-gcp-raw.md

---

## 0. Контекст

SRE Enablement (Kacper Prusak) настраивает Cloud Armor policies для защиты Pyroscope NP и Otel OIDC NP/PR endpoints в рамках epic COR1-295. В логах Cloud Armor зафиксировано 11 IP, источник которых не определён. Исследование (Этап 2) показало: **4 IP** — Cloud NAT egress самого core-ai (np/pr × us-central1/us-east1), полностью верифицировано через gcloud; **7 IP** с высокой степенью уверенности принадлежат `np-store-sre` / `pr-store-sre` (Store Systems SRE, S3 team), но требуют финального подтверждения через gcloud в их проектах. Все 11 IP в `httpRequest.remoteIp` Cloud Armor логов — это **источники входящего трафика** (клиенты), не destinations. Изменения Cloud Armor — вне scope core-ai TFE workspace (это SRE Enablement, COR1-295). Задача core-ai: подтвердить владение 4 NAT IP, эскалировать 7 IP, выдать SRE Enablement готовый список + runbook.

## 1. Решения

### Решение A — Размещение runbook

**Выбор**: оба варианта одновременно.
- **Источник истины**: `docs/runbooks/cloud-armor-unknown-ip.md` — markdown в core-ai монорепо. Версионируется, code review, история изменений. Подпадает под `docs-storage.md` Режим 1 (мы в проектном репо), но `runbooks/` — не AIDD-категория, это новая категория эксплуатационных артефактов и она ортогональна правилу AIDD-storage.
```

## Ключевые решения из разговора

### Решения и ключевые фразы:
- Отличный вопрос — да, есть **намного более простой паттерн**. Я думал не в ту сторону.

В `gatekeeper.ts` уже используется `excludedNamespaces` **на уровне самой constraint** (а не на уровне webhook). Это **первоклассная фича Gatekeeper**, и она уже применяется в 3 constraints этого же файла:

```ty...
- ## GKE upgrade stuck — нашёл причину

**На ноде `89a3` только 1 non-DaemonSet pod:** `doc-synopsis-74db764dc4-l5lxg` в CrashLoopBackOff (3606 restarts, 13 дней). Остальные — DaemonSet'ы (drain их пропускает).

**Драма с PDB:**
```
core-ai-dev/doc-synopsis  PDB  maxUnavailable=3  allowedDisruptions=0...
- ## Этап 1: PRD — готов

**Артефакт:** [docs/prd/COR1-337.prd.md](docs/prd/COR1-337.prd.md) (184 строки) · `research_needed: true`

**Проблема:** PR #5566 (image tag bump) падает на `Run gator test` для всех 7 apps с ошибкой `missing ConstraintTemplate: template "disallowdefaultnamespaceexceptsystem"...
- Понял. Корректирую направление:

**Webhook `failurePolicy: Ignore` — это temporary bypass, не permanent fix.** Policy должна работать (blocking the unwhitelisted) и не должна disable'иться. Цель не "ничего не менять", а **понять почему np-usce1 уникален** → дизайнить proper fix, который:
- Сохраняет...
- `=~"UpdateCluster"` regex slow. Kill + используем точную filter on log name.

### Последние действия Claude (tool_use):
- Bash: echo "=== 'Resetting endpoints' on np-usce1 in WHOLE May ===" && time gcloud logging read 'resource.type="k8s_control_pl
- Bash: echo "=== apiserver Starting/Initialized/Listening msgs np-usce1 around 5-20T07:17 ===" && time gcloud logging read 'res
- Bash: echo "=== np-usea1: 'unable to sync' in May ===" && time gcloud logging read 'resource.type="k8s_control_plane_component
- Bash: echo "=== count 'unable to sync' events per cluster in May ===" && for cluster in np-te-core-ai-usce1 np-te-core-ai-usea
- TodoWrite

### Последние сообщения пользователя:
- === UpdateCluster (exact match) on np-usce1 5-10..5-21 === gcloud logging read  --project np-te-core-ai --order=asc --limit 10  2>&1  0.32s user 0.13s system 2% cpu 18.809 total head -15  0.00s user 0...
- === UpdateClusterInternal (Google AUTO) on np-usce1 5-10..5-21 === 2026-05-14T08:55:45.108128679Z	1.35.3-gke.1389000		 2026-05-14T09:05:00.103022641Z			 gcloud logging read  --project np-te-core-ai --...
- === ALL apiserver logs np-usce1 in 30 min window before first deny (07:00-07:18) === 2026-05-20T07:00:00.006952Z	"HTTP" verb="PUT" URI="/apis/coordination.k8s.io/v1/namespaces/kube-system/leases/l4-lb...
- === first 'Resetting endpoints for master service' on np-usce1 === 2026-05-20T07:17:34.909955Z	Resetting endpoints for master service "kubernetes" to [10.43.132.130] 2026-05-20T07:17:47.128153999Z	Res...
- === last 'Resetting endpoints' BEFORE 2026-05-20T07:17:34 (gap from previous attempt?) === gcloud logging read  --project np-te-core-ai --limit 3  2>&1  0.33s user 0.14s system 4% cpu 10.927 total hea...
- === 'Resetting endpoints' on np-usce1 in WHOLE May === 2026-05-20T07:17:34.909955Z 2026-05-20T07:17:47.128153999Z 2026-05-20T07:17:48.628540Z 2026-05-20T07:17:57.135394Z 2026-05-20T07:17:58.630625Z gc...
- === apiserver Starting/Initialized/Listening msgs np-usce1 around 5-20T07:17 === 2026-05-20T07:10:00.104333Z	"Starting watch" path="/api/v1/namespaces/kube-system/configmaps" resourceVersion="17792609...
- === np-usea1: 'unable to sync' in May === 2026-05-20T07:06:42.911999Z gcloud logging read  --project np-te-core-ai --order=asc --limit 3  2>&1  0.37s user 0.15s system 1% cpu 33.697 total head -10  0....
- === count 'unable to sync' events per cluster in May === np-te-core-ai-usce1: 1000 events np-te-core-ai-usea1: 1 events pr-te-core-ai-usce1: 3 events pr-te-core-ai-usea1: 0 events
- Todos have been modified successfully. Ensure that you continue to use the todo list to track your progress. Please proceed with the current tasks if applicable
