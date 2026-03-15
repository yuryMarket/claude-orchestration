# Глобальные конвенции кода и инфраструктуры

## 1. Python

- Форматирование и линтинг: `ruff` (format + check)
- Проверка типов: `mypy --strict`
- Тесты: `pytest` + `pytest-cov`, фикстуры, parametrize, conftest.py
- Управление пакетами: `uv` (предпочтительно) или Poetry
- Структура: src layout (`src/<package>/`)
- Именование: snake_case для функций/переменных, PascalCase для классов
- Docstrings: Google style, только для публичного API

## 2. TypeScript / Node.js

- Форматирование: `prettier` + `eslint`
- Тесты: `vitest` (предпочтительно) или `jest`
- Управление пакетами: `pnpm` (предпочтительно) или `npm`
- Runtime: Node.js LTS
- Предпочитать именованные экспорты перед default
- Строгий TypeScript: `strict: true` в tsconfig

## 3. Infrastructure as Code

### Terraform
- Формат: `terraform fmt`, линтинг: `tflint`, безопасность: `checkov`
- Модули в `modules/`, окружения в `envs/`
- State: удалённый backend, блокировка состояния включена
- Всегда запускать `terraform plan` перед `apply`

### Pulumi
- Типизированная конфигурация стека, явное именование ресурсов
- Component resources для переиспользуемых абстракций

### Ansible
- Линтинг: `yamllint` + `ansible-lint`, тесты: `molecule`
- Структура ролей, идемпотентные задачи, handlers для рестартов

## 4. Контейнеры

- Dockerfile: multi-stage сборки, hadolint, non-root USER, trivy scan
- Фиксировать версии базовых образов (не использовать `:latest`)
- Docker Compose: profiles, healthchecks, именованные volumes

## 5. Kubernetes

- Манифесты: `kubeval`/`kubeconform`, resource limits обязательны, liveness/readiness probes
- Helm: `chart-testing`, валидация values, семантическое версионирование
- Kustomize: base + overlays структура
- Лейблы: стандарт `app.kubernetes.io/*`

## 6. CI/CD

- GitHub Actions: `actionlint`, переиспользуемые workflows в `.github/workflows/`
- GitLab CI: include templates, структура stages
- Стадии пайплайна: lint -> test -> build -> scan -> deploy
- Секреты: никогда не хардкодить, использовать vault/secrets manager

## 7. Наблюдаемость

- Логи: структурированный JSON logging, correlation IDs
- Метрики: Prometheus naming convention (`<namespace>_<name>_<unit>_total`)
- Алерты: уровни severity (critical/warning/info), обязательные ссылки на runbooks
- Дашборды: на основе SLI/SLO, golden signals (latency, traffic, errors, saturation)

## 8. Git

- Conventional commits: `type(scope): описание`
  - Типы: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Именование веток: `feature/<ticket>-описание`, `fix/<ticket>-описание`
- PR: squash merge в main, удалять ветку после merge
- Library-first подход: искать готовую библиотеку перед написанием >20 строк кода
