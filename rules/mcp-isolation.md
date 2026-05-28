# Изоляция MCP-серверов

Оркестратор НЕ вызывает `mcp__*` напрямую. Делегируй субагенту.

## Таблица: MCP-сервер → субагент

| MCP-сервер | Субагент | Сценарий |
|---|---|---|
| `context7` | `quick-lookup` | Точечная проверка: синтаксис API, параметр, конфиг |
| `context7` | `deep-researcher` | Глубокое исследование: сравнение, миграция |
| `atlassian` (Confluence) | `quick-lookup` | Конкретная страница/процесс/runbook |
| `atlassian` (Confluence) | `deep-researcher` | Анализ нескольких страниц |
| `mcp__gcp__run_gcloud_command` | `infra-operator` | Все GCP CLI: delete, describe, list, IAM |

## Выбор субагента

- **quick-lookup** — один факт/snippet (haiku, быстро)
- **deep-researcher** — сравнение/анализ нескольких источников (sonnet)
- **infra-operator** — любые GCP CLI операции (никогда не вызывать `mcp__gcp__*` из оркестратора)

## Шаблоны вызова

**quick-lookup (документация)**: `"Найди в документации <lib> синтаксис для <что>. Контекст: <зачем>."`

**quick-lookup (Confluence)**: `"Найди в Confluence страницу про <тема>. Контекст: <зачем>."`

**deep-researcher**: `"Исследуй <тема>. Вопросы: <список>. Сохрани отчёт в: docs/research/<name>.md"`

**infra-operator**: `"Выполни GCP операции в проекте <id>: <список>. Логи: <путь>"`

## Почему

MCP-вызовы дорогие по токенам. Изоляция не засоряет контекст сырыми данными. Результаты кэшируются в файл (`~/docs/quick-lookup/`, `docs/research/`) — повторный запрос не нужен.
