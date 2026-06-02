# CHANGELOG — ~/.claude AIDD Workflow

Формат: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [Unreleased]

### Added

- **AIDD-002**: Новый helper `~/.claude/hooks/_lib/aidd-write-legacy.sh` — условная запись
  legacy-указателя `docs/.active_ticket`. Принимает аргументы `<cwd> <ticket>`. Пишет файл
  только если он пуст или уже содержит тот же тикет; если файл содержит тикет другой сессии —
  пропускает запись и сообщает в stderr. Атомарная запись через tmp+mv. Всегда завершается
  с exit 0 (fail-open). Используется вместо безусловной записи в `workflow.md`, `idea/SKILL.md`,
  `analyst/AGENT.md`.

- **AIDD-002**: Новые bash-тесты:
  - `test-resolve-ticket.sh`: тесты `T.A` (уровень 3 не читается — регресс), `T.B`
    (нормализация cwd + guard по per-session), `T.B2` (нормализация cwd + legacy).
  - `test-write-legacy.sh`: тесты `T.C1–T.C4` покрывают все ветви helper
    (`aidd-write-legacy.sh`): запись в пустой файл, идемпотентность, защита чужого тикета,
    пустой аргумент.

- **AIDD-001**: Per-session изоляция активного тикета AIDD. Каждая сессия Claude Code
  хранит свой указатель тикета в `~/.claude/sessions/aidd/<session_id>.json` — отдельный файл
  на сессию с полями `{ticket, cwd, source, created, updated}`. Это позволяет вести несколько
  тикетов параллельно в одной рабочей директории без гонки за единственным
  `docs/.active_ticket`.

- **AIDD-001**: Новая директория `~/.claude/sessions/aidd/` — хранилище per-session файлов.
  Создаётся автоматически хуком `session-start.sh` через `mkdir -p`.

- **AIDD-001**: Библиотека `~/.claude/hooks/_lib/aidd-ticket.sh` — общая функция
  `resolve_ticket(cwd, session_id)` с трёхуровневой логикой резолюции:
  1. primary: `~/.claude/sessions/aidd/<session_id>.json` (c cwd-guard)
  2. fallback: `<cwd>/docs/.active_ticket` (legacy plain-text)
  3. fallback: `<cwd>/.claude/docs/.active_ticket`

- **AIDD-001**: Библиотека `~/.claude/hooks/_lib/aidd-session-id.sh` — извлечение
  `session_id` из `$CLAUDE_CODE_SESSION_ID` (v2.1.132+) или из stdin JSON (все версии).

- **AIDD-001**: Хук `session-start.sh` инжектит `session_id` и активный тикет в
  `additionalContext` (plain-text stdout) — LLM-оркестратор получает свой id пассивно,
  без Bash-вызова. Строка формата: `AIDD session_id: <S>`.

- **AIDD-001**: TTL-очистка orphaned per-session файлов (TTL = 14 дней) в `session-start.sh`
  при `source=startup`. Файл текущей сессии защищён исключением `! -name "${SID}.json"`.

- **AIDD-001**: Observability в хуках: `gate-workflow.sh` и `session-start.sh` пишут в
  stderr источник тикета: `AIDD: ticket=<T> source=session:<S>` или `source=legacy`.

### Changed

- **AIDD-002**: `~/.claude/hooks/_lib/aidd-ticket.sh` — удалён уровень 3 из `resolve_ticket`
  (`<cwd>/.claude/docs/.active_ticket`). Цепочка стала двухуровневой: per-session →
  `<cwd>/docs/.active_ticket` → none. Добавлена нормализация cwd (`cwd="${cwd%/}"`) перед
  cwd-guard и построением legacy-пути. Шапка-комментарий обновлена: «трёхуровневая» →
  «двухуровневая (per-session → legacy → none)».

- **AIDD-002**: `~/.claude/hooks/gate-workflow.sh` — удалён второй `if` в блоке ВАРИАНТ A,
  читавший `$CWD/.claude/docs/.active_ticket` (уровень 3). Шапка-комментарий обновлена:
  строка уровня 3 удалена, уровни перенумерованы.

- **AIDD-002**: `~/.claude/workflow.md` — шаг 2(c) переведён на вызов
  `aidd-write-legacy.sh`: «Запиши legacy `docs/.active_ticket` УСЛОВНО через helper:
  `Bash: bash ~/.claude/hooks/_lib/aidd-write-legacy.sh "<cwd>" "<ticket>"`». Указано, что
  helper не перетирает указатель параллельной сессии; если session_id неизвестен — helper
  остаётся единственным способом зафиксировать тикет.

- **AIDD-002**: `~/.claude/skills/idea/SKILL.md` — шаг 3.3 переведён на вызов
  `aidd-write-legacy.sh`. Убрана формулировка «ВСЕГДА, независимо от session_id» —
  заменена пояснением, что helper безопасен в обоих случаях.

- **AIDD-002**: `~/.claude/agents/analyst/AGENT.md` — шаг 9 переведён на вызов
  `aidd-write-legacy.sh`. Добавлено: helper создаёт `docs/` при необходимости и не перетирает
  указатель другой сессии; при неизвестном cwd передавать пустой аргумент (helper возьмёт pwd).

- **AIDD-001**: `~/.claude/hooks/session-start.sh` — расширен: читает `session_id` из stdin
  JSON, регистрирует/обновляет per-session файл при старте/resume/compact/clear, добавляет
  строку `AIDD session_id: <S>` в stdout (контекст LLM), показывает source в status-panel.

- **AIDD-001**: `~/.claude/hooks/gate-workflow.sh` — расширен: определяет `session_id` через
  `$CLAUDE_CODE_SESSION_ID` → stdin JSON; резолюция тикета через `resolve_ticket()` (per-session
  primary → legacy fallback). Все существующие gate-исключения и логика PRD/PLAN/TASKLIST
  проверок сохранены без изменений.

- **AIDD-001**: `~/.claude/workflow.md` — обновлён протокол записи активного тикета (Точка
  входа, шаг 2): оркестратор пишет оба указателя — per-session файл (если session_id известен)
  и `docs/.active_ticket` (legacy, всегда). В раздел «Принципы» добавлен инвариант per-session
  изоляции.

- **AIDD-001**: `~/.claude/skills/idea/SKILL.md` — шаг 3 расширен: скилл `/idea` устанавливает
  per-session файл (source: `"idea"`) плюс пишет legacy `docs/.active_ticket`. Per-session
  файл устанавливает именно скилл, а не субагент `analyst` (скилл исполняется в контексте
  родительской сессии и знает её session_id).

- **AIDD-001**: `~/.claude/agents/analyst/AGENT.md` — добавлен комментарий к шагу 9: агент
  пишет только legacy `docs/.active_ticket`; per-session указатель устанавливает скилл `/idea`.

### Removed

- **AIDD-002**: Удалён осиротевший файл `core-ai/.claude/docs/.active_ticket` (содержал
  устаревший указатель `COR1-335`; уровень 3 больше не читается ни одним из хуков).

### Notes (migration — AIDD-002)

- `<cwd>/.claude/docs/.active_ticket` (бывший уровень 3) более **не читается** как fallback
  ни `aidd-ticket.sh`, ни `gate-workflow.sh`. Единственный legacy-указатель теперь —
  `<cwd>/docs/.active_ticket`.
- Если кто-то вручную создавал указатель по пути `<проект>/.claude/docs/.active_ticket` —
  перенести в `<проект>/docs/.active_ticket`.
- Одиночные сессии не пострадали: helper записывает тикет при пустом файле (первый запуск)
  или идемпотентно при совпадении значения. Параллельные сессии больше не перетирают чужой
  указатель.

### Notes (обратная совместимость — AIDD-001)

- `docs/.active_ticket` (legacy) не удалён и не изменён — продолжает работать как fallback
  для одиночных сессий и при деградации (нет `session_id`, нет `python3`, битый JSON).
- Проекты без AIDD (`docs/.active_ticket` отсутствует, per-session файл не создан) —
  не затронуты: `gate-workflow.sh` тихо делает `exit 0`.
- `/clear` создаёт новый `session_id`; `session-start.sh` при `source=clear` наследует тикет
  из legacy `docs/.active_ticket` по cwd — непрерывность работы сохраняется.
- Старые CLI (< v2.1.132 без `$CLAUDE_CODE_SESSION_ID`) деградируют к legacy-режиму без
  поломки функциональности.
