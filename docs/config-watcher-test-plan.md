# Тест-план: config-watcher

**Дата**: 2026-04-06  
**Статус**: готов к выполнению

---

## Часть 1: Unit-тесты (запускай один раз, не требуют Claude Code)

```bash
bash ~/.claude/tests/test-config-watcher.sh
```

Ожидаемый результат: `PASS: 23 | FAIL: 0`

---

## Часть 2: Интеграционные тесты

### Соглашения

- Каждый тест — в **новой сессии** Claude Code (если не указано иное)
- Сообщения для вставки выделены блоками `Сообщение N →`
- `[ожидаемый ответ Claude]` — что должно произойти после сообщения
- Проверочные команды запускаются в отдельном терминале (не в Claude Code)
- Финальная очистка — в конце каждого теста

### Как узнать session_id

После первого trigger в тесте:
```bash
ls /tmp/claude-correction-flag-* 2>/dev/null | sed 's|/tmp/claude-correction-flag-||'
```

---

## Тест A: Автоматический flow — базовая проверка цепочки

**Проверяет:** Stop hook → detect-correction.sh → config-watcher агент → ответ "нет"  
**Сессия:** новая  
**Сценарий:** разовая корректировка → агент должен сказать "системных проблем нет"

### Диалог

**Сообщение 1 →**
```
Создай файл /tmp/cw-test-a.yaml со следующим содержимым и ничего больше — никаких комментариев, никаких пояснений, только yaml:

host: localhost
port: 6379
```

`[ожидаемый ответ Claude]` Использует Write. Создаёт файл. Подтверждает создание.

---

**Сообщение 2 →**
```
нет, переделай — port должен быть 6380, не 6379. Исправь файл.
```

`[ожидаемый ответ Claude после Stop хука]`  
В статусбаре появляется: *"Анализирую паттерны коррекций..."*  
Затем Claude продолжает ответ (это значит хук вернул `{"ok": false}`) и запускает config-watcher агента.  
Агент анализирует и сообщает: **"Анализ завершён, системных проблем не обнаружено."** — это правильно, ошибка разовая.

### Проверка после теста
```bash
# 1. Хук создал correction-flag и cursor
SESSION=$(ls /tmp/claude-correction-flag-* 2>/dev/null | sed 's|/tmp/claude-correction-flag-||')
echo "Session ID: $SESSION"
echo "--- correction-flag (должен существовать):"
cat /tmp/claude-correction-flag-$SESSION 2>/dev/null || echo "ОТСУТСТВУЕТ"
echo "--- cursor (должен существовать):"
cat /tmp/claude-cursor-$SESSION 2>/dev/null || echo "ОТСУТСТВУЕТ"
echo "--- watcher-ran (должен существовать после работы агента):"
ls /tmp/claude-watcher-ran-$SESSION 2>/dev/null && echo "ЕСТЬ" || echo "ОТСУТСТВУЕТ"
```

```bash
# 2. pending-changes.md не создан (системной проблемы нет)
ls ~/.claude/pending-changes.md 2>/dev/null && echo "СОЗДАН (неожиданно)" || echo "ОТСУТСТВУЕТ (OK)"
```

### Очистка
```bash
rm -f /tmp/cw-test-a.yaml
```

---

## Тест A+: Автоматический flow — с гарантированным предложением

**Проверяет:** Stop hook → агент → предложение → "да" → изменение применено → pending-changes.md удалён  
**Сессия:** новая  
**Сценарий:** Claude нарушает правило о docstrings (правило в python.md говорит "только для public API", но Claude добавляет к вспомогательной функции)

### Диалог

**Сообщение 1 →**
```
Создай файл /tmp/cw-test-aplus.py с двумя функциями:
1. Публичная функция `calculate_total(prices: list[float]) -> float` — считает сумму цен
2. Вспомогательная функция `_format_price(value: float) -> str` — форматирует цену как строку с двумя знаками

Добавь Google-style docstrings к обеим функциям.
```

`[ожидаемый ответ Claude]` Использует Write. Создаёт файл с обеими функциями и docstrings к обеим.

---

**Сообщение 2 →**
```
нет, это неправильно — функция _format_price внутренняя (prefixed with _), ей не нужен docstring. Переделай файл — удали docstring только у _format_price.
```

`[ожидаемый ответ Claude после Stop хука]`  
Хук срабатывает (статусбар: *"Анализирую паттерны коррекций..."*).  
Claude продолжает (хук вернул `ok:false`) и запускает config-watcher.  
Агент анализирует: правило в `python.md` говорит "только для public API" но не объясняет явно что private-функции (`_prefix`) не входят в public API.  
Агент предлагает:

```
[config-watcher] В `~/.claude/rules/python.md` уже есть правило, но оно не сработало (нет явного указания что _ prefix = не public API).
Предлагаю дополнить/переписать:
Было: `Docstrings: Google style, только для public API`
Стало: `Docstrings: Google style, только для public API. Функции с _ prefix не являются public API и не должны иметь docstring`

Подтвердить? (да/нет)
```

---

**Сообщение 3 →**
```
да
```

`[ожидаемый ответ Claude]` Агент редактирует `~/.claude/rules/python.md`. Подтверждает изменение. Удаляет запись из `pending-changes.md`.

### Проверка после теста
```bash
# 1. Правило обновлено в python.md
grep -i "prefix\|private\|internal\|_" ~/.claude/rules/python.md || echo "Правило не добавлено"
```

```bash
# 2. pending-changes.md отсутствует или не содержит эту запись
cat ~/.claude/pending-changes.md 2>/dev/null || echo "ОТСУТСТВУЕТ (OK)"
```

```bash
# 3. Файл создан корректно (для сравнения)
cat /tmp/cw-test-aplus.py
```

### Очистка
```bash
rm -f /tmp/cw-test-aplus.py
# Если правило в python.md было изменено и ты хочешь откатить:
# git -C ~/.claude checkout rules/python.md  # если есть git
# или отредактируй вручную
```

---

## Тест B: Нет Edit/Write → хук молчит

**Проверяет:** detect-correction.sh не срабатывает если Claude не редактировал файлы  
**Сессия:** новая  
**Сценарий:** вопрос-ответ, Claude только пишет текст — хук должен тихо выйти

### Диалог

**Сообщение 1 →**
```
Что такое Redis Sentinel?
```

`[ожидаемый ответ Claude]` Объясняет без использования Edit/Write.

---

**Сообщение 2 →**
```
нет, это неправильно. Переделай объяснение — фокусируйся только на failover механизме.
```

`[ожидаемый ответ Claude]` Отвечает **без** продолжения после Stop хука. Claude просто переформулирует ответ и останавливается. config-watcher **не** запускается.

### Проверка после теста
```bash
# correction-flag НЕ должен быть создан
ls /tmp/claude-correction-flag-* 2>/dev/null && echo "СОЗДАН (ошибка!)" || echo "ОТСУТСТВУЕТ (OK)"
```

---

## Тест C: Отклонение предложения → pending-changes.md очищается

**Проверяет:** ответ "нет" на предложение агента  
**Сессия:** новая  
**Сценарий:** тот же что A+, но ответ "нет"

### Диалог

Повтори **Сообщение 1** и **Сообщение 2** из Теста A+.

Когда агент предложит изменение →

**Сообщение 3 →**
```
нет
```

`[ожидаемый ответ Claude]` Агент удаляет запись из `pending-changes.md`. Подтверждает отклонение. `python.md` не изменён.

### Проверка после теста
```bash
# python.md не изменён — нет упоминания _ prefix в context docstring
grep -i "_prefix\|private function" ~/.claude/rules/python.md && echo "ИЗМЕНЁН (ошибка!)" || echo "Не изменён (OK)"
```

```bash
# pending-changes.md отсутствует
cat ~/.claude/pending-changes.md 2>/dev/null || echo "ОТСУТСТВУЕТ (OK)"
```

### Очистка
```bash
rm -f /tmp/cw-test-aplus.py
```

---

## Тест D: Защита от повторного анализа (watcher-ran flag)

**Проверяет:** после того как агент отработал, следующий Stop в той же сессии не запускает агента повторно  
**Сессия:** продолжение сессии после Теста A+  
**Шаги:**

1. После завершения Теста A+ (в той же сессии) — выполни ещё один Exchange с Edit/Write и коррекцией.

**Сообщение 1 →**
```
Создай файл /tmp/cw-test-d.txt с текстом: "version: 1"
```

**Сообщение 2 →**
```
нет, исправь — текст должен быть "version: 2"
```

`[ожидаемый ответ Claude]`  
Хук срабатывает, видит `watcher-ran` флаг **отсутствует** (он был сброшен при прошлом Stop), поэтому снова запускает агента.  
НО агент проверяет `/tmp/claude-proposed-{session_id}` — там уже есть запись о предыдущем предложении.  
Агент сообщает: "Анализ завершён, предложений нет" (дублирование заблокировано).

### Проверка
```bash
SESSION=$(ls /tmp/claude-correction-flag-* 2>/dev/null | sed 's|/tmp/claude-correction-flag-||' | head -1)
echo "--- proposed log:"
cat /tmp/claude-proposed-$SESSION 2>/dev/null || echo "ОТСУТСТВУЕТ"
```

### Очистка
```bash
rm -f /tmp/cw-test-d.txt
```

---

## Тест E: Ручной вызов /config-watch

**Проверяет:** скилл запускает агента в Режиме B (весь транскрипт, обработка pending-changes.md)  
**Сессия:** новая  
**Сценарий:** вначале создаём контекст, потом вызываем скилл

### Подготовка — создай pending-changes.md
```bash
cat > ~/.claude/pending-changes.md << 'EOF'
## [2026-04-06] ~/.claude/rules/feedback.md
Тип: новое правило
Предложение: - Не добавлять приветственные фразы ("Конечно!", "Отличный вопрос!") в начало ответов
Статус: ожидает подтверждения
EOF
```

### Диалог

**Сообщение 1 →**
```
Создай файл /tmp/cw-test-e.txt с текстом: "hello"
```

**Сообщение 2 →**
```
Переименуй файл /tmp/cw-test-e.txt в /tmp/cw-test-e-renamed.txt (создай новый, старый удали)
```

`[ожидаемый ответ Claude]` Создаёт файл, переименовывает через Write + Bash.

---

**Сообщение 3 →**
```
/config-watch
```

`[ожидаемый ответ Claude]`  
1. Агент запускается в Режиме B
2. **Сначала** показывает содержимое `pending-changes.md`:
   ```
   [config-watcher] Есть незакрытые предложения из прошлых сессий:
   ...Не добавлять приветственные фразы...
   Применить? (да/нет/пропустить)
   ```

---

**Сообщение 4 →**
```
нет
```

`[ожидаемый ответ Claude]` Агент удаляет запись, затем анализирует транскрипт текущей сессии с cursor=0. Сообщает о найденных/не найденных системных проблемах.

### Проверка после теста
```bash
# pending-changes.md удалён (запись была одна)
cat ~/.claude/pending-changes.md 2>/dev/null || echo "ОТСУТСТВУЕТ (OK)"
```

### Очистка
```bash
rm -f /tmp/cw-test-e.txt /tmp/cw-test-e-renamed.txt
rm -f ~/.claude/pending-changes.md 2>/dev/null || true
```

---

## Тест F: SessionStart hook — pending-changes.md при старте новой сессии

**Проверяет:** `session-start-pending.sh` показывает pending-changes.md при открытии новой сессии  
**Сессия:** закрыть текущую, открыть новую  
**Требует действия:** закрыть и переоткрыть Claude Code

### Подготовка (в терминале, ДО открытия новой сессии)
```bash
cat > ~/.claude/pending-changes.md << 'EOF'
## [2026-04-06] ~/.claude/rules/code-style.md
Тип: новое правило
Предложение: - Не добавлять trailing newline summary после code blocks
Статус: ожидает подтверждения

## [2026-04-06] ~/.claude/rules/python.md
Тип: дополнить
Предложение: - Не использовать `pass` в abstract методах без `raise NotImplementedError`
Статус: ожидает подтверждения
EOF
```

### Действие

**Закрой текущую сессию Claude Code. Открой новую.**

`[ожидаемый результат при старте]`  
Claude сразу показывает в начале сессии:
```
=== config-watcher: незакрытые предложения ===
Есть предложения по изменению конфигов от предыдущей сессии:

## [2026-04-06] ~/.claude/rules/code-style.md
...
## [2026-04-06] ~/.claude/rules/python.md
...

Команды: 'применить pending changes' | 'отклонить pending changes' | продолжи работу
================================================
```

### Диалог (в новой сессии)

**Сообщение 1 →**
```
применить pending changes
```

`[ожидаемый ответ Claude]`  
Агент config-watcher применяет оба изменения в соответствующие файлы, удаляет записи, удаляет `pending-changes.md`.

### Проверка после теста
```bash
# Изменения применены
grep -i "trailing\|summary" ~/.claude/rules/code-style.md || echo "В code-style.md не найдено (OK если агент выбрал другой файл)"
grep -i "pass\|NotImplementedError" ~/.claude/rules/python.md || echo "В python.md не найдено"
```

```bash
# pending-changes.md удалён
cat ~/.claude/pending-changes.md 2>/dev/null || echo "ОТСУТСТВУЕТ (OK)"
```

### Альтернативный тест F' — отклонить все

Вместо "применить" напиши:

**Сообщение 1 →**
```
отклонить pending changes
```

Ожидается: обе записи удалены, файлы правил не изменены, `pending-changes.md` удалён.

---

## Тест G: /config-watch + apply из pending (комбинированный)

**Проверяет:** весь ручной путь + обработку pending в одном сценарии  
**Сессия:** новая

### Подготовка
```bash
# Создаём pending с одной записью
cat > ~/.claude/pending-changes.md << 'EOF'
## [2026-04-06] ~/.claude/rules/feedback.md
Тип: новое правило
Предложение: - Отвечать на вопросы кратко, без вводных фраз
Статус: ожидает подтверждения
EOF
```

### Диалог

**Сообщение 1 →**
```
Создай файл /tmp/cw-test-g.py с функцией `def greet(name: str) -> str` которая возвращает "Hello, {name}!"
```

**Сообщение 2 →**
```
нет, переделай — функция должна возвращать "Hi, {name}!" вместо "Hello"
```

`[ожидаемый]` Claude редактирует файл.

**Сообщение 3 →**
```
/config-watch
```

`[ожидаемый]` Агент:
1. Показывает pending → спрашивает применить/отклонить/пропустить

**Сообщение 4 →**
```
пропустить
```

`[ожидаемый]` Агент сохраняет pending запись, переходит к анализу транскрипта. Если находит системную проблему — предлагает. Если нет — "проблем не найдено".

### Проверка
```bash
# pending-changes.md должен остаться (мы сказали "пропустить")
cat ~/.claude/pending-changes.md 2>/dev/null && echo "ЕСТЬ (OK)" || echo "УДАЛЁН (ошибка!)"
```

### Очистка
```bash
rm -f /tmp/cw-test-g.py ~/.claude/pending-changes.md
```

---

## Итоговая очистка после всех тестов

```bash
# Удалить все тестовые файлы
rm -f /tmp/cw-test-*.{py,txt,yaml}

# Удалить pending-changes.md если остался
rm -f ~/.claude/pending-changes.md

# Посмотреть /tmp файлы текущей сессии (информационно)
ls /tmp/claude-* 2>/dev/null || echo "нет tmp файлов"
# /tmp файлы удаляются автоматически при перезагрузке системы
```

---

## Матрица покрытия

| Тест | Компонент | Ветка |
|---|---|---|
| Unit | `detect-correction.sh` | все входы + loop protection |
| Unit | `session-start-pending.sh` | пустой/непустой/отсутствует |
| A | Stop hook → агент → "нет проблем" | автоматический, нет proposal |
| A+ | Stop hook → агент → proposal → "да" | автоматический, применение |
| C | Stop hook → агент → proposal → "нет" | автоматический, отклонение |
| D | watcher-ran + proposed лог | защита от дублей |
| B | Нет Edit/Write → хук молчит | ложное срабатывание |
| E | `/config-watch` → pending → "нет" → анализ | ручной режим B |
| F | SessionStart → pending → "применить" | при старте сессии |
| F' | SessionStart → pending → "отклонить" | при старте сессии |
| G | `/config-watch` → pending "пропустить" → анализ | ручной + skip |

---

## Диагностика проблем

```bash
# Смотреть состояние /tmp в реальном времени
watch -n2 'ls -la /tmp/claude-* 2>/dev/null || echo "нет файлов"'

# Проверить что хук зарегистрирован
cat ~/.claude/settings.json | python3 -m json.tool | grep -A3 "Stop"

# Проверить что скрипт исполняемый
ls -la ~/.claude/hooks/detect-correction.sh
ls -la ~/.claude/hooks/session-start-pending.sh

# Запустить хук вручную с тестовыми данными (безопасно)
echo '{"session_id":"manual-test","transcript_path":"/nonexistent","stop_hook_active":false}' | \
  bash ~/.claude/hooks/detect-correction.sh; echo "Exit: $?"
```
