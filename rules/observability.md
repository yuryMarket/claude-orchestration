---
paths:
  - "monitoring/**"
  - "alerting/**"
  - "dashboards/**"
  - "**/prometheus/**"
  - "**/grafana/**"
  - "**/opentelemetry/**"
---
# Правила наблюдаемости

## Метрики
- Prometheus naming convention: `<namespace>_<subsystem>_<name>_<unit>`
- Обязательные метрики для сервисов: RED (Rate, Errors, Duration)
- Обязательные метрики для ресурсов: USE (Utilization, Saturation, Errors)
- SLO/SLI определить до настройки алертинга

## Алерты
- Уровни severity: critical, warning, info
- `runbook_url` — обязателен для каждого алерта
- Алерты на симптомы, не на причины
- Избегать alert fatigue — каждый алерт требует действия

## Логи
- Структурированный JSON-формат
- Обязательные поля: correlation ID, trace ID, timestamp, level
- Не логировать чувствительные данные (PII, секреты, токены)

## Трейсинг
- OpenTelemetry: traces, metrics, logs — единый SDK
- Инструментировать все входящие/исходящие HTTP-запросы и обращения к БД

## Дашборды
- Row-per-service layout, переменные для фильтрации
- Golden signals: latency, traffic, errors, saturation
