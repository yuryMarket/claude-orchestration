# Compact Recovery Context
<!-- Generated: 2026-06-01T08:12:21Z | trigger: manual -->

## Git состояние

```
---
```

## AIDD Workflow

**Тикет**: MLOPS-001

**Незавершённые задачи**:
```
(нет данных)
```

**Архитектурный план** (начало):
```
(нет данных)
```

## Ключевые решения из разговора

### Решения и ключевые фразы:
- ## Полная цепочка первопричин stuck upgrade — записана

[.claude/docs/investigations/COR1-332-root-cause-chain.md](.claude/docs/investigations/COR1-332-root-cause-chain.md)

**Ключевая находка**: stuck upgrade на np-usce1 — это **stacked failure** (L0 → L5):

| Layer | Что |
|---|---|
| **L0** (land...
- Пока ждём результат — отвечаю на главный вопрос:

## Первопричина — Gatekeeper. PDBs — усугубляющий фактор.

### Разделим две вещи

**Что произошло на 5-20**: на ВСЕХ 4 кластерах был GKE control-plane upgrade в одно окно (Google AUTO). На всех 4 apiserver pod рестартанул и попытался sync `default/ku...
- Результат audit log: поиск нашёл только `np-te-core-ai-usea4` (другой кластер, не наши 4) от 2025-09-16. Для наших 4 кластеров **UpdateNodePool client-инициированный не зафиксирован** в 400-day окне.

Это значит:
- Все наши node upgrades были **Google AUTO** (через internal API), не вручную
- Либо U...
- ## PDB (Pod Disruption Budget)

**Что это**: kubernetes-ресурс, который защищает приложение от **voluntary disruptions** — плановых evict операций (node drain при upgrade, scale-down, maintenance). От crash/OOM/eviction по resource pressure он НЕ защищает (это involuntary).

### Как работает

```yam...
- Ваше понимание **в основном корректное**, но с важными нюансами. Проверил сейчас prod Central-1.

## pr-te-core-ai-usce1 — фактическое состояние

| Параметр | Значение |
|---|---|
| Master version | 1.35.3-gke.1389000 ✅ |
| Master upgrades в мае | **8 раз** (5-03, 5-04, 5-05, 5-10, 5-11×2, 5-13, 5-1...

### Последние действия Claude (tool_use):
- Bash: echo "=== Apiserver pod restart events (creation of new apiserver instances) np-usce1 vs pr-usce1 in May ===" && for clu
- Read: /private/tmp/claude-501/-Users-yury-shubianok-core-ai/6d8e982b-501b-499a-a2ba-1dc35a4ab989/tasks/bd7fo8jr2.output
- Bash: echo "=== Full 'Resetting endpoints' messages on np-usce1 — what master IPs ===" && gcloud logging read 'resource.type="
- Bash: echo "=== Sample 'Resetting endpoints' across whole May np-usce1 — last few messages with IPs ===" && gcloud logging rea
- Read: /private/tmp/claude-501/-Users-yury-shubianok-core-ai/6d8e982b-501b-499a-a2ba-1dc35a4ab989/tasks/b9e90hyr9.output

### Последние сообщения пользователя:
- === Pattern of apiserver 'Resetting endpoints' events PER cluster, May === np-te-core-ai-usce1:     1000 'Resetting endpoints' events in May np-te-core-ai-usea1:        0 'Resetting endpoints' events ...
- === Cluster creation dates ALL 4 === np-te-core-ai-usce1: 2025-02-25T16:53:05+00:00	1.35.3-gke.1389000	1.31.5-gke.1068000 np-te-core-ai-usea1: 2025-02-25T14:34:26+00:00	1.35.3-gke.1389000	1.31.5-gke.1...
- Command running in background with ID: bd7fo8jr2. Output is being written to: /private/tmp/claude-501/-Users-yury-shubianok-core-ai/6d8e982b-501b-499a-a2ba-1dc35a4ab989/tasks/bd7fo8jr2.output. You wil...
- === Look for 'Resetting endpoints' anywhere in last 60 days for each cluster (any time, not just May) === np-te-core-ai-usea1:        0 events in last 60d pr-te-core-ai-usce1:        0 events in last ...
- === Try kind-specific Constraint listing on np-usce1 ===   np-usce1 disallowdefaultnamespace:        1 constraint instances   np-usce1 requiredprobes:        1 constraint instances   np-usce1 disallow...
- === Apiserver pod restart events (creation of new apiserver instances) np-usce1 vs pr-usce1 in May === --- np-te-core-ai-usce1 ---       10   ^^ apiserver 'Serving securely' events (= pod starts) in M...
- 1	=== Endpoint reconciler hints from apiserver logs each cluster === 2	--- np-te-core-ai-usce1 --- 3	2026-05-06T07:46:14.755893Z	FLAG: --endpoint-reconciler-type="lease" 4	2026-05-06T07:46:17.677154Z	...
- === Full 'Resetting endpoints' messages on np-usce1 — what master IPs === 2026-05-20T07:17:34.909955Z	Resetting endpoints for master service "kubernetes" to [10.43.132.130] 2026-05-20T07:17:47.1281539...
- === Sample 'Resetting endpoints' across whole May np-usce1 — last few messages with IPs ===  === Was there 'Resetting endpoints' on np-usce1 BEFORE 5-20 (anytime in 2026) ? ===
- 1	=== Cloud audit ops UPGRADE_NODES last 200 days — all 4 clusters === 2	--- project: np-te-core-ai --- 3	--- project: pr-te-core-ai --- 4	ERROR: (gcloud.logging.read) There was a problem refreshing y...
