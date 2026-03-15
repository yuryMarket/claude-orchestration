---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*"
  - "**/.dockerignore"
---
# Правила Docker

## Dockerfile
- Multi-stage builds для минимального размера образа
- Non-root user (директива USER) — обязательно
- `.dockerignore` — обязателен
- `hadolint` для линтинга Dockerfile
- COPY вместо ADD (кроме tar-архивов)
- Один процесс на контейнер
- HEALTHCHECK для production-образов
- Не хранить секреты в образе (build args → multi-stage)
- Фиксировать версии базовых образов — не использовать `:latest`

## Docker Compose
- Healthchecks для всех сервисов
- `depends_on` с condition: service_healthy
- Profiles для разделения dev/test/prod сервисов
- Именованные volumes для персистентных данных
