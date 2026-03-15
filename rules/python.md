---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---
# Правила Python

## Форматирование и линтинг
- `ruff` для lint + format (заменяет black, isort, flake8)
- `mypy --strict` для проверки типов

## Типизация и документация
- Type hints обязательны для public API
- Docstrings: Google style, только для public API
- Избегать `Any` — использовать `object` или конкретные типы

## Структура и стиль
- Структура проекта: src layout (`src/package_name/`)
- Async: asyncio для I/O-bound задач, не threading
- Логирование: structlog / стандартный logging со structured output
- Обработка ошибок: конкретные exceptions, не bare except
- f-strings предпочтительнее `.format()` и `%`
- Контекстные менеджеры для управления ресурсами (файлы, соединения)
