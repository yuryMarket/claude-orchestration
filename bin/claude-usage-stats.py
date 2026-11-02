#!/usr/bin/env python3
"""Статистика использования ~/.claude: агенты, скиллы, rules, хуки, MCP-серверы, конфиг-файлы.

Источники: транскрипты ~/.claude/projects/**/*.jsonl и история промптов ~/.claude/history.jsonl.
Скрипт только читает данные и пишет Markdown-отчёт.
"""
import argparse
import json
import re
from collections import Counter
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

HOME = Path.home()
CLAUDE_DIR = HOME / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"
HISTORY_FILE = CLAUDE_DIR / "history.jsonl"
CLAUDE_JSON = HOME / ".claude.json"

COMMAND_RE = re.compile(r"<command-name>/?([^<\s]+)</command-name>")
CLAUDE_PATH_RE = re.compile(r"(?:~|" + re.escape(str(HOME)) + r")/\.claude/([\w.\-/]+)")
HOOK_FILE_RE = re.compile(r"hooks/([\w.\-]+)")
FILE_TOOLS = {"Read", "Edit", "Write", "MultiEdit", "NotebookEdit"}
AGENT_TOOLS = {"Agent", "Task"}
DEFAULT_AGENT = "general-purpose"
IGNORED_PREFIXES = (
    "projects/", "file-history/", "plugins/", "cache/", "shell-snapshots/", "session-env/", "telemetry/",
    "backups/", "downloads/", "ide/", "state/", "statsig/", "todos/", "sessions/", "skills/synced/",
)
CONFIG_TEXT_GLOBS = ("*.md", "rules/*.md", "agents/*/AGENT.md", "agents/*.md", "skills/*/*.md", "hooks/*", "settings.json")
TOP_LIMIT = 30


@dataclass
class Usage:
    count: int = 0
    last: str = ""
    sessions: set = field(default_factory=set)
    projects: Counter = field(default_factory=Counter)

    def hit(self, timestamp: str, session: str, project: str) -> None:
        self.count += 1
        self.last = max(self.last, timestamp)
        self.sessions.add(session)
        self.projects[project] += 1


class Stats:
    CATEGORIES = (
        "tools", "agents", "skills", "slash", "mcp_servers", "mcp_tools",
        "config_reads", "config_writes", "config_bash", "rules_loaded", "hooks_fired", "history_slash",
    )

    def __init__(self) -> None:
        self.data = {name: {} for name in self.CATEGORIES}
        self.seen: set = set()
        self.files = 0
        self.sessions: set = set()
        self.first_ts = ""
        self.last_ts = ""
        self.history_range = ("", "")

    def hit(self, category: str, key: str, timestamp: str, session: str, project: str) -> None:
        self.data[category].setdefault(key, Usage()).hit(timestamp, session, project)

    def get(self, category: str, key: str) -> Usage:
        return self.data[category].get(key, Usage())


def project_name(transcript: Path) -> str:
    encoded = transcript.relative_to(PROJECTS_DIR).parts[0]
    home_prefix = re.sub(r"[^A-Za-z0-9]", "-", str(HOME))
    rest = encoded[len(home_prefix):].lstrip("-") if encoded.startswith(home_prefix) else encoded
    return rest or "~"


def session_id(transcript: Path) -> str:
    parts = transcript.parts
    if "subagents" in parts:
        return parts[parts.index("subagents") - 1]
    return transcript.stem


def claude_relpath(raw_path: str) -> str | None:
    path = str(Path(raw_path).expanduser())
    prefix = str(CLAUDE_DIR) + "/"
    if not path.startswith(prefix):
        return None
    rel = path[len(prefix):]
    if rel.startswith(IGNORED_PREFIXES) or (CLAUDE_DIR / rel).is_dir():
        return None
    return rel


def handle_tool_use(stats: Stats, name: str, tool_input: dict, ctx: tuple) -> None:
    stats.hit("tools", name, *ctx)
    if name in AGENT_TOOLS:
        stats.hit("agents", tool_input.get("subagent_type") or DEFAULT_AGENT, *ctx)
    elif name == "Skill" and tool_input.get("skill"):
        stats.hit("skills", tool_input["skill"], *ctx)
    elif name.startswith("mcp__"):
        stats.hit("mcp_servers", name.split("__")[1], *ctx)
        stats.hit("mcp_tools", name, *ctx)
    elif name in FILE_TOOLS:
        rel = claude_relpath(tool_input.get("file_path") or tool_input.get("notebook_path") or "")
        if rel:
            stats.hit("config_reads" if name == "Read" else "config_writes", rel, *ctx)
    elif name == "Bash":
        for match in {m.rstrip(".") for m in CLAUDE_PATH_RE.findall(tool_input.get("command", ""))}:
            rel = claude_relpath(f"{CLAUDE_DIR}/{match}")
            if rel:
                stats.hit("config_bash", rel, *ctx)


def message_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text")
    return ""


def handle_record(stats: Stats, record: dict, session: str, project: str, since: str) -> None:
    timestamp = record.get("timestamp", "")
    if not timestamp or timestamp < since:
        return
    ctx = (timestamp, session, project)
    record_type = record.get("type")
    message = record.get("message") or {}

    if record_type == "assistant":
        for block in message.get("content") or []:
            if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("id") not in stats.seen:
                stats.seen.add(block.get("id"))
                handle_tool_use(stats, block.get("name", "?"), block.get("input") or {}, ctx)
        return

    uuid = record.get("uuid")
    if uuid in stats.seen:
        return
    stats.seen.add(uuid)

    if record_type == "user":
        for command in COMMAND_RE.findall(message_text(message.get("content"))):
            stats.hit("slash", command, *ctx)
    elif record_type == "attachment":
        attachment = record.get("attachment") or {}
        if attachment.get("type") == "nested_memory":
            rel = claude_relpath(attachment.get("path", ""))
            if rel:
                stats.hit("rules_loaded", rel, *ctx)
        elif attachment.get("command"):
            match = HOOK_FILE_RE.search(attachment["command"])
            stats.hit("hooks_fired", match.group(1) if match else attachment["command"], *ctx)


def scan_transcripts(stats: Stats, since: str) -> None:
    for transcript in sorted(PROJECTS_DIR.rglob("*.jsonl")):
        stats.files += 1
        session, project = session_id(transcript), project_name(transcript)
        with transcript.open(encoding="utf-8", errors="replace") as handle:
            for line in handle:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(record, dict):
                    continue
                handle_record(stats, record, session, project, since)
                timestamp = record.get("timestamp", "")
                if timestamp >= since and timestamp:
                    stats.sessions.add(session)
                    stats.first_ts = min(stats.first_ts or timestamp, timestamp)
                    stats.last_ts = max(stats.last_ts, timestamp)


def scan_history(stats: Stats, since: str) -> None:
    if not HISTORY_FILE.exists():
        return
    first, last = "", ""
    with HISTORY_FILE.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            timestamp = datetime.fromtimestamp(entry.get("timestamp", 0) / 1000, tz=UTC).isoformat()
            if timestamp < since:
                continue
            first, last = min(first or timestamp, timestamp), max(last, timestamp)
            display = (entry.get("display") or "").strip()
            if display.startswith("/") and len(display) > 1:
                command = display.split()[0][1:]
                project = entry.get("project", "")
                project = Path(project).name if project and project != str(HOME) else "~"
                stats.hit("history_slash", command, timestamp, entry.get("sessionId", ""), project)
    stats.history_range = (first, last)


def load_config_texts() -> dict[str, str]:
    texts = {}
    for pattern in CONFIG_TEXT_GLOBS:
        for path in CLAUDE_DIR.glob(pattern):
            if path.is_file():
                texts[str(path.relative_to(CLAUDE_DIR))] = path.read_text(encoding="utf-8", errors="replace")
    return texts


def count_references(texts: dict[str, str], needle: str, own_paths: set[str]) -> int:
    pattern = re.compile(r"(?<![\w-])" + re.escape(needle) + r"(?![\w-])")
    return sum(1 for rel, text in texts.items() if rel not in own_paths and pattern.search(text))


def inventory() -> dict:
    agents = sorted(
        [d.name for d in (CLAUDE_DIR / "agents").iterdir() if (d / "AGENT.md").exists()]
        + [f.stem for f in (CLAUDE_DIR / "agents").glob("*.md")]
    )
    skills = sorted(d.name for d in (CLAUDE_DIR / "skills").iterdir() if (d / "SKILL.md").exists())
    rules = {}
    for rule in sorted((CLAUDE_DIR / "rules").glob("*.md")):
        head = rule.read_text(encoding="utf-8", errors="replace").split("\n---", 1)[0]
        rules[rule.name] = head.startswith("---") and "\npaths:" in head
    hooks = sorted(
        f.name for f in (CLAUDE_DIR / "hooks").iterdir()
        if f.is_file() and f.suffix in {".sh", ".js", ".py", ""} and not f.name.startswith(".")
    )
    return {"agents": agents, "skills": skills, "rules": rules, "hooks": hooks}


def configured_mcp_servers() -> set[str]:
    if not CLAUDE_JSON.exists():
        return set()
    try:
        config = json.loads(CLAUDE_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return set()
    servers = set(config.get("mcpServers") or {})
    for project in (config.get("projects") or {}).values():
        servers |= set((project or {}).get("mcpServers") or {})
    return {re.sub(r"[^\w-]", "_", name) for name in servers}


def short_date(timestamp: str) -> str:
    return timestamp[:10] if timestamp else "—"


def top_projects(usage: Usage, limit: int = 3) -> str:
    return ", ".join(f"{name} ({count})" for name, count in usage.projects.most_common(limit)) or "—"


def table(headers: list[str], rows: list[list]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    lines += ["| " + " | ".join(str(cell) for cell in row) + " |" for row in rows]
    return "\n".join(lines)


def usage_rows(entries: dict[str, Usage], limit: int = TOP_LIMIT) -> list[list]:
    ranked = sorted(entries.items(), key=lambda item: (-item[1].count, item[0]))[:limit]
    return [[f"`{key}`", u.count, len(u.sessions), short_date(u.last), top_projects(u)] for key, u in ranked]


def skill_usage(stats: Stats, skill: str) -> tuple[Usage, Usage, Usage]:
    variants = (skill, f"user:{skill}")
    pick = lambda category: next((stats.get(category, v) for v in variants if stats.get(category, v).count), Usage())
    return pick("skills"), pick("slash"), pick("history_slash")


def build_report(stats: Stats, inv: dict, texts: dict[str, str], since_label: str) -> str:
    out = [f"# Статистика использования ~/.claude — {date.today().isoformat()}", ""]
    hist_first, hist_last = stats.history_range
    out += [
        "## Охват данных", "",
        f"- Период: {since_label}",
        (f"- Транскрипты: {stats.files} файлов, {len(stats.sessions)} сессий, "
        f"{short_date(stats.first_ts)} — {short_date(stats.last_ts)}"),
        f"- История промптов (`history.jsonl`, только слэш-команды): {short_date(hist_first)} — {short_date(hist_last)}",
        "",
    ]

    own = lambda *paths: set(paths)
    unused = {"agents": [], "skills": [], "rules": [], "hooks_unregistered": [], "hooks_silent": [], "mcp": []}

    agent_rows = []
    for agent in inv["agents"]:
        usage = stats.get("agents", agent)
        refs = count_references(texts, agent, own(f"agents/{agent}/AGENT.md", f"agents/{agent}.md"))
        agent_rows.append([f"`{agent}`", usage.count, len(usage.sessions), short_date(usage.last), top_projects(usage), refs])
        if not usage.count:
            unused["agents"].append(f"`{agent}` (ссылок в конфиге: {refs})")
    agent_rows.sort(key=lambda row: -row[1])
    builtin_agents = {k: v for k, v in stats.data["agents"].items() if k not in inv["agents"]}

    skill_rows = []
    for skill in inv["skills"]:
        tool_use, slash, history = skill_usage(stats, skill)
        last = max(tool_use.last, slash.last, history.last)
        refs = count_references(texts, skill, {p for p in texts if p.startswith(f"skills/{skill}/")})
        skill_rows.append([f"`{skill}`", tool_use.count, slash.count, history.count, short_date(last), refs])
        if not (tool_use.count or slash.count or history.count):
            unused["skills"].append(f"`{skill}` (ссылок в конфиге: {refs})")
    skill_rows.sort(key=lambda row: -(row[1] + row[2] + row[3]))
    own_skill_names = set(inv["skills"]) | {f"user:{s}" for s in inv["skills"]}
    other_skills = {k: v for k, v in stats.data["skills"].items() if k not in own_skill_names}

    rule_rows = []
    for rule, scoped in inv["rules"].items():
        rel = f"rules/{rule}"
        loads = stats.get("rules_loaded", rel)
        reads = stats.get("config_reads", rel).count + stats.get("config_bash", rel).count
        writes = stats.get("config_writes", rel).count
        refs = count_references(texts, rule, own(rel))
        mode = "по `paths:`" if scoped else "всегда в контексте"
        last = max(loads.last, stats.get("config_reads", rel).last, stats.get("config_writes", rel).last)
        rule_rows.append([f"`{rule}`", mode, loads.count if scoped else "—", reads, writes, refs, short_date(last)])
        if scoped and not loads.count:
            unused["rules"].append(f"`{rule}` — ни разу не подгружался по `paths:` (ссылок: {refs})")
        elif not scoped and not refs:
            unused["rules"].append(f"`{rule}` — всегда в контексте, но ни один конфиг на него не ссылается")

    settings_text = texts.get("settings.json", "")
    hook_texts = {rel: text for rel, text in texts.items() if rel.startswith("hooks/")}
    hook_rows = []
    for hook in inv["hooks"]:
        registered = hook in settings_text
        used_by = [rel.split("/", 1)[1] for rel, text in hook_texts.items() if rel != f"hooks/{hook}" and hook in text]
        fired = stats.get("hooks_fired", hook)
        status = "settings.json" if registered else (f"из {', '.join(used_by[:2])}" if used_by else "**нет**")
        hook_rows.append([f"`{hook}`", status, fired.count, short_date(fired.last)])
        if not registered and not used_by:
            unused["hooks_unregistered"].append(f"`{hook}`")
        elif registered and not fired.count:
            unused["hooks_silent"].append(f"`{hook}`")

    configured = configured_mcp_servers()
    for server in sorted(configured - set(stats.data["mcp_servers"])):
        unused["mcp"].append(f"`{server}`")

    out += ["## Главное: что не используется", ""]
    sections = [
        ("Агенты без единого вызова", unused["agents"]),
        ("Скиллы без единого вызова (Skill-инструмент, слэш-команда, история промптов)", unused["skills"]),
        ("Rules — кандидаты на ревизию", unused["rules"]),
        ("Хуки — файлы, которые нигде не зарегистрированы", unused["hooks_unregistered"]),
        ("Хуки — зарегистрированы, но ни одного залогированного срабатывания (см. ограничения)", unused["hooks_silent"]),
        ("MCP-серверы — настроены в `~/.claude.json`, но ни одного вызова", unused["mcp"]),
    ]
    for title, items in sections:
        out += [f"**{title}:** " + (", ".join(items) if items else "нет"), ""]

    out += [
        "## Агенты", "",
        "Свои агенты из `~/.claude/agents/`. «Ссылок» — сколько других конфиг-файлов упоминают агента.", "",
        table(["Агент", "Вызовов", "Сессий", "Последний", "Проекты (топ-3)", "Ссылок"], agent_rows), "",
        "Встроенные и плагинные агенты:", "",
        table(["Агент", "Вызовов", "Сессий", "Последний", "Проекты (топ-3)"], usage_rows(builtin_agents)), "",
    ]

    out += [
        "## Скиллы", "",
        ("Skill — вызовы через инструмент Skill; /cmd — слэш-команда в транскриптах; "
        "история — слэш-команда в `history.jsonl`."), "",
        table(["Скилл", "Skill", "/cmd", "История", "Последний", "Ссылок"], skill_rows), "",
    ]
    if other_skills:
        out += ["Встроенные и плагинные скиллы (через Skill):", "",
                table(["Скилл", "Вызовов", "Сессий", "Последний", "Проекты (топ-3)"], usage_rows(other_skills)), ""]
    own_commands = set(inv["skills"]) | {f"user:{s}" for s in inv["skills"]}
    other_slash = {
        f"{k} ({source})": v
        for category, source in (("slash", "транскрипты"), ("history_slash", "история"))
        for k, v in stats.data[category].items() if k not in own_commands
    }
    if other_slash:
        out += ["Прочие слэш-команды (встроенные команды CLI):", "",
                table(["Команда", "Раз", "Сессий", "Последний", "Проекты (топ-3)"], usage_rows(other_slash, 20)), ""]

    out += [
        "## Rules", "",
        ("Подгрузок — сколько раз rule с `paths:` подгрузился в контекст. Чтений — явные Read и упоминания в Bash. "
        "Ссылок — сколько других конфиг-файлов упоминают rule."), "",
        table(["Rule", "Режим", "Подгрузок", "Чтений", "Правок", "Ссылок", "Последний"], rule_rows), "",
    ]

    out += [
        "## Хуки", "",
        "«Срабатываний» — только залогированные в транскриптах (хуки с выводом или доп. контекстом).", "",
        table(["Файл", "Зарегистрирован", "Срабатываний", "Последний"], hook_rows), "",
    ]
    unknown_hooks = {k: v for k, v in stats.data["hooks_fired"].items() if k not in inv["hooks"]}
    if unknown_hooks:
        out += ["Прочие хуки из логов (плагины, inline-команды):", "",
                table(["Хук", "Срабатываний", "Сессий", "Последний", "Проекты (топ-3)"], usage_rows(unknown_hooks)), ""]

    mcp_rows = []
    for server, usage in sorted(stats.data["mcp_servers"].items(), key=lambda item: -item[1].count):
        tools = Counter({k.split("__", 2)[2]: v.count for k, v in stats.data["mcp_tools"].items()
                         if k.split("__")[1] == server})
        top_tools = ", ".join(f"{name} ({count})" for name, count in tools.most_common(3))
        mcp_rows.append([f"`{server}`", usage.count, len(usage.sessions), short_date(usage.last), top_tools])
    out += ["## MCP-серверы", "", table(["Сервер", "Вызовов", "Сессий", "Последний", "Топ-3 инструмента"], mcp_rows), ""]

    config_keys = set(stats.data["config_reads"]) | set(stats.data["config_writes"]) | set(stats.data["config_bash"])
    config_rows = []
    for key in config_keys:
        reads, writes, bash = (stats.get(c, key) for c in ("config_reads", "config_writes", "config_bash"))
        config_rows.append([f"`{key}`", reads.count, writes.count, bash.count,
                            short_date(max(reads.last, writes.last, bash.last))])
    config_rows.sort(key=lambda row: -(row[1] + row[2] + row[3]))
    out += [
        f"## Файлы ~/.claude (топ-{TOP_LIMIT})", "",
        "Read — явное чтение; Edit/Write — правки; Bash — упоминание пути в shell-команде.", "",
        table(["Файл", "Read", "Edit/Write", "Bash", "Последний"], config_rows[:TOP_LIMIT]), "",
    ]

    out += [f"## Инструменты Claude Code (топ-{TOP_LIMIT})", "",
            table(["Инструмент", "Вызовов", "Сессий", "Последний", "Проекты (топ-3)"],
                  usage_rows({k: v for k, v in stats.data["tools"].items() if not k.startswith("mcp__")})), ""]

    out += [
        "## Ограничения", "",
        ("- Транскрипты хранятся `cleanupPeriodDays` дней (по умолчанию 30) — более старые вызовы агентов и инструментов "
        "не видны. `history.jsonl` дополняет картину по слэш-командам, если он ведётся."),
        ("- Rules без `paths:` и `CLAUDE.md` загружаются в каждую сессию автоматически — для них показатель "
        "востребованности косвенный (ссылки, чтения, правки)."),
        ("- Срабатывания хуков логируются, только когда хук вернул вывод или контекст. Ноль у хука-уведомителя "
        "или форматтера не означает, что хук не работает."),
        "- Вызовы внутри субагентов учтены (транскрипты `subagents/`). Повторы при resume/fork исключены по id.",
        ("- claude.ai-коннекторы (`claude_ai_*`) не видны в `~/.claude.json`, поэтому в список "
        "«настроены, но не используются» не попадают."),
        "",
    ]
    return "\n".join(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=0, help="учитывать только последние N дней (0 — всё)")
    parser.add_argument(
        "--output", type=Path,
        default=HOME / "docs" / "reports" / f"{date.today().isoformat()}-claude-config-usage.md",
        help="путь к Markdown-отчёту",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    since = (datetime.now(UTC) - timedelta(days=args.days)).isoformat() if args.days else ""
    since_label = f"последние {args.days} дней" if args.days else "все доступные данные"

    stats = Stats()
    scan_transcripts(stats, since)
    scan_history(stats, since)
    report = build_report(stats, inventory(), load_config_texts(), since_label)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")
    print(f"Отчёт: {args.output}")


if __name__ == "__main__":
    main()
