---
name: NUDGE project overview
description: NUDGE — SRE incident automation project with AI agent (thd-holmes) and K8s deployments (pro-project-deployments)
type: project
---

NUDGE is an SRE incident automation project at The Home Depot consisting of two subprojects:
1. **thd-holmes** — Python AI agent that investigates alerts using LLM + observability tools (Prometheus, Loki, Tempo, K8s) and delivers findings via Slack
2. **pro-project-deployments** — CDK8s/TypeScript monorepo for K8s deployment configs (Nx, Spinnaker, Argus)

**Why:** Reduce MTTR by automating the first steps of incident triage.

**How to apply:** Root directory is `nudge/`. When working with the AI agent code, focus on `thd-holmes/`. For infrastructure/deployment, focus on `pro-project-deployments/`.
