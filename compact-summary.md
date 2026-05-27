# Compact Recovery Context
<!-- Generated: 2026-05-26T12:25:44Z | trigger: manual -->

## Git состояние

```
---
```

## AIDD Workflow

**Тикет**: COR1-297

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
- ## Stage 3 завершён: Архитектурный план COR1-297

**Артефакт**: `.claude/docs/plan/COR1-297.md`

### Ключевые решения

- **Канал**: `gcloud` CLI (не Terraform) — ресурсы orphaned, не управляются IaC
- **Порядок**: Phase A (Vertex AI undeploy → delete) → Phase B (Subscriptions → Topics) → Phase C (Wo...

### Последние действия Claude (tool_use):
- Bash: PROJECT=np-te-core-ai
echo "=== Block 5: e2e-live-test ==="
gcloud network-security gateway-security-policies list --pro
- Bash: PROJECT=np-te-core-ai

echo "=== Block 1 Gateway (network-services) ==="
gcloud network-services gateways list --project
- Read: /Users/yury_shubianok/core-ai/.claude/docs/plan/COR1-297.md
- Write: /Users/yury_shubianok/core-ai/.claude/docs/plan/COR1-297.md
- Write: /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-297.md

### Последние сообщения пользователя:
- === Vertex AI Endpoints === DELETED: 1268391116244254720 DELETED: 6437456412430827520 DELETED: 6504165981911252992 DELETED: 930556822761242624  === Vertex AI IndexEndpoints === DELETED: 70080694121419...
- === Block 9 missing topics (deadletter) === EXISTS:  core-ai-dev-doc-loader-GAUTAM-deadletter EXISTS:  core-ai-dev-ocr-chunk-GAUTAM-deadletter  === ir-mcp-search (approved by Gautam) === DELETED/NOT F...
- === Vertex AI Indexes (approved by Gautam) === DELETED: 8491899936244236288 DELETED: 8862153879828037632  === Brandon's approved networking blocks === -- e2e-live-test-dev -- e2e-live-test-dev-vpc-int...
- Считать ли Jira-SOT (comments 9&10) достаточным основанием для уже удалённых ресурсов, или нужна дополнительная эскалация? Мы не будем считать эти ресурсы достаточными для удаления, но возвращать уже ...
- === Block 1: e2e-live-test-dev-internal === WARNING: --filter : operator evaluation is changing for consistency across Google APIs.  name=e2e-live-test-dev-gateway currently does not match but will ma...
- === Block 5: e2e-live-test === WARNING: --filter : operator evaluation is changing for consistency across Google APIs.  name=e2e-live-test-dev-policy currently does not match but will match in the nea...
- Exit code 1 === Block 1 Gateway (network-services) === e2e-live-test-dev-gateway  === Block 5 GatewaySecurityPolicy === e2e-live-test-dev-policy  === ALL subnets per VPC === -- e2e-live-test-dev subne...
- 1	--- 2	Status: PLAN_APPROVED 3	Ticket: COR1-297 4	--- 5	 6	# Plan: COR1-297 — Round 3 cleanup: удаление 25 GCP-ресурсов в np-te-core-ai 7	 8	Status: PLAN_DRAFT 9	Date: 2026-05-26 10	PRD: .claude/docs...
- The file /Users/yury_shubianok/core-ai/.claude/docs/plan/COR1-297.md has been updated successfully. (file state is current in your context — no need to Read it back)
- The file /Users/yury_shubianok/core-ai/.claude/docs/tasklist/COR1-297.md has been updated successfully. (file state is current in your context — no need to Read it back)
