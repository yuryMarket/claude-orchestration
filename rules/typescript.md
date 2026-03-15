---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/tsconfig*.json"
---
# Правила TypeScript

## Конфигурация
- `strict: true` в tsconfig.json — обязательно
- ESM modules предпочтительнее CommonJS
- `prettier` + `eslint` для форматирования

## Типизация
- Использовать `type` вместо `interface` (если не нужен declaration merging)
- Избегать `any` — использовать `unknown` + type guards
- Предпочитать `readonly` для неизменяемых данных
- Zod / valibot для runtime-валидации на границах системы

## Стиль
- Barrel exports (`index.ts`) — только для public API модуля
- Обработка ошибок: Result pattern или типизированные ошибки
- Предпочитать именованные экспорты перед default
- Async/await вместо raw Promise chains
