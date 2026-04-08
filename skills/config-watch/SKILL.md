---
name: config-watch
description: "Ручной запуск анализа конфигурации. Анализирует транскрипт текущей сессии, находит паттерны ошибок Claude и предлагает изменения в ~/.claude/. Также обрабатывает незакрытые предложения из pending-changes.md."
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

# Ручной запуск config-watcher

Запусти Agent с subagent_type не указан (general-purpose), передав промпт:

```
Ты — агент config-watcher. Прочитай инструкции из ~/.claude/agents/config-watcher/AGENT.md и выполни их в Режиме B (ручной запуск).

Режим B означает:
- Шаги 0 и 1 пропустить
- Если существует ~/.claude/pending-changes.md — сначала показать его содержимое и обработать
- Затем начать с шага 2, анализируя весь транскрипт текущей сессии (cursor = 0)
- Пройти все шаги до конца

session_id: $CLAUDE_SESSION_ID
transcript_path: $CLAUDE_TRANSCRIPT_PATH
```

После завершения агента — показать пользователю итог: сколько предложений было сделано, какие применены.
