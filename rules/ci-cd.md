---
paths:
  - ".github/**"
  - ".gitlab-ci*"
  - "Jenkinsfile*"
  - ".circleci/**"
---
# Правила CI/CD

## GitHub Actions
- Фиксировать версии actions по SHA, не по тегу
- Использовать reusable workflows для повторяющихся паттернов
- `actionlint` — обязательный линтинг workflows
- Кэширование зависимостей через `actions/cache`
- Matrix builds для мульти-версионного тестирования

## Общие принципы
- Секреты — только через GitHub/GitLab secrets, не хардкод
- Fail fast: не продолжать pipeline после критических ошибок
- Environments с approval для production deployments
- Стадии: lint → test → build → scan → deploy
- Артефакты сборки — с версией и хешем коммита
- Уведомления о сбоях pipeline — обязательны
