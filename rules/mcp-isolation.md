# Изоляция MCP-серверов: делегирование вместо прямых вызовов

Оркестратор НЕ вызывает `mcp__*` инструменты напрямую. Для получения данных из внешних источников — делегируй вызов субагенту с соответствующими MCP-инструментами в `tools:`.

## Правило

- Когда нужна информация из внешнего источника (документация библиотеки, внутренняя wiki) — вызови субагента, а не `mcp__*` напрямую
- Субагенты с MCP-инструментами в своём `tools:` (quick-lookup, deep-researcher) вызывают MCP свободно — это их штатное поведение

## Покрытые MCP-серверы и субагенты

| MCP-сервер | Субагент | Сценарий |
|---|---|---|
| `context7` | `quick-lookup` | Точечная проверка: синтаксис API, параметры, конфигурация |
| `context7` | `deep-researcher` | Глубокое исследование: сравнение подходов, миграция версий |
| `atlassian` (Confluence) | `quick-lookup` | Точечный поиск: конкретная страница, процесс, runbook |
| `atlassian` (Confluence) | `deep-researcher` | Глубокий анализ: сбор информации с нескольких страниц |
| `mcp__gcp__run_gcloud_command` | `infra-operator` | Любые GCP CLI операции: удаление ресурсов, describe, list, IAM |

Другие MCP-серверы при появлении — по аналогии: назначить или создать субагента с нужными `tools:`.

## Выбор субагента

- **Точечный вопрос** (один факт, один snippet) — `quick-lookup` (модель haiku, быстро и дёшево)
- **Исследование** (сравнение, анализ нескольких источников) — `deep-researcher` (модель sonnet, глубже и дороже)
- **GCP операции** (удаление, describe, list, IAM) — `infra-operator` (никогда не вызывать `mcp__gcp__run_gcloud_command` из оркестратора напрямую)

## Шаблоны вызова оркестратором

### quick-lookup: проверка документации библиотеки

```
Agent(subagent_type="quick-lookup"):

Найди в документации <библиотека> правильный синтаксис для <что именно>.
Контекст: <зачем нужно, какая версия>.
```

Пример:

```
Agent(subagent_type="quick-lookup"):

Найди в документации pytest правильный синтаксис для parametrize с indirect fixtures.
Контекст: нужно параметризовать фикстуру базы данных для тестов с разными движками.
```

### quick-lookup: поиск внутренней документации

```
Agent(subagent_type="quick-lookup"):

Найди в Confluence страницу про <тема>.
Контекст: <что именно ищем, зачем нужна информация>.
```

Пример:

```
Agent(subagent_type="quick-lookup"):

Найди в Confluence страницу про процесс деплоя в production.
Контекст: нужно узнать требуемые approvals и порядок канареечного релиза.
```

### deep-researcher: исследование с несколькими источниками

```
Agent(subagent_type="deep-researcher"):

Исследуй <тема>. Проверь документацию <библиотека/сервис> и внутренние страницы Confluence.
Вопросы: <конкретные вопросы, на которые нужен ответ>.
Сохрани отчёт в: docs/research/<название>.md
```

Пример:

```
Agent(subagent_type="deep-researcher"):

Исследуй подходы к structured logging в FastAPI. Проверь документацию structlog и loguru, найди в Confluence наш стандарт логирования.
Вопросы: какой формат JSON-логов принят, нужен ли correlation ID middleware.
Сохрани отчёт в: docs/research/fastapi-logging.md
```

### infra-operator: GCP операции

```
Agent(subagent_type="infra-operator"):

Выполни следующие GCP операции в проекте <project>:
<список операций или описание задачи>

Логи сохрани в: <путь>
```

Пример:

```
Agent(subagent_type="infra-operator"):

Удали следующие ресурсы в проекте np-te-core-ai (порядок важен):
1. gcloud compute network-attachments delete test-attachment --region=us-central1 --quiet
2. gcloud compute networks subnets delete test-subnet --region=us-central1 --quiet

Логи сохрани в: ~/cor1-297-round3/logs/deletion-log.csv
```

## Почему

- MCP-вызовы дорогие по токенам — quick-lookup на модели haiku минимизирует стоимость
- Изоляция предотвращает засорение контекста оркестратора сырыми данными из внешних источников
- Результаты кэшируются в файл (quick-lookup в `~/docs/quick-lookup/`, deep-researcher в `docs/research/`) — повторный запрос не нужен
- Прямой вызов `mcp__gcp__run_gcloud_command` из оркестратора затягивает в главный контекст полные JSON-ответы (листинги десятков ресурсов, большие describe-выводы); `infra-operator` сохраняет детали в файл и возвращает только структурированное резюме
