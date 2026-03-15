---
paths:
  - "k8s/**"
  - "helm/**"
  - "**/kustomize/**"
  - "**/charts/**"
  - "**/manifests/**"
---
# Правила Kubernetes

## Манифесты
- Всегда указывать resource requests и limits
- Всегда указывать liveness и readiness probes
- Использовать namespaces для изоляции
- Не использовать тег `latest` для образов — только конкретные версии/SHA
- PodDisruptionBudget для production workloads
- Лейблы: стандарт `app.kubernetes.io/*`

## Безопасность
- SecurityContext: runAsNonRoot, readOnlyRootFilesystem
- NetworkPolicies: deny all по умолчанию, разрешать явно
- RBAC: принцип минимальных привилегий
- ServiceAccount: отдельный для каждого workload

## Helm
- values.yaml с документацией параметров
- Chart.yaml с корректным appVersion и семантическим версионированием
- `helm lint` + `helm template` + `kubeconform` для валидации

## Kustomize
- Структура: base + overlays (dev, staging, prod)
- Не дублировать ресурсы между overlays — использовать patches
