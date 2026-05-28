---
name: update-config
description: "Редактирует ~/.claude/settings.json напрямую без загрузки полной JSON-схемы. Используй для изменения permissions (allow/deny), env vars, hooks. Для hooks предпочитай hooks-manager."
allowed-tools: Read, Edit, Bash
---

# Update Config

Вноси изменения в `~/.claude/settings.json` напрямую.

## Workflow

1. `Read ~/.claude/settings.json` — обязательно до редактирования
2. Точечные изменения через `Edit` (merge, не replace полного файла)
3. Валидация: `jq -e '.permissions.allow | length' ~/.claude/settings.json`

## Синтаксис permissions

```json
"permissions": {
  "allow": ["Bash(git *)", "WebFetch", "mcp__github__get_issue"],
  "deny":  ["Bash(rm -rf *)", "Bash(git push --force*)"]
}
```

- Prefix wildcard: `"Bash(git *)"` — матчит `git` и все подкоманды
- Tool only: `"WebFetch"` — разрешает все URL без ограничений
- Domain: `"WebFetch(domain:example.com)"` — только этот домен
- MCP: `"mcp__github__get_issue"` — точный матч по имени инструмента

## Файлы настроек

| Файл | Область |
|------|---------|
| `~/.claude/settings.json` | Глобально (все проекты) |
| `.claude/settings.json` | Проект (коммитится) |
| `.claude/settings.local.json` | Проект (gitignore, личные) |

## Границы применения

- **Хуки** (PreToolUse, PostToolUse, Stop, SessionStart...) → используй `hooks-manager`
- **~/.claude/rules/*.md** → используй `rules-manager`
- **~/.claude/agents/*/AGENT.md** → используй `subagent-creator`

## JSON Schema (только по запросу)

Полная схема: https://json.schemastore.org/claude-code-settings.json
Не загружай в контекст без явной необходимости.
