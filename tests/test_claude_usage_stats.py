import importlib.util
from pathlib import Path

import pytest

SCRIPT = Path.home() / ".claude" / "bin" / "claude-usage-stats.py"
spec = importlib.util.spec_from_file_location("claude_usage_stats", SCRIPT)
usage_stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage_stats)

TS = "2026-10-30T10:00:00.000Z"


@pytest.fixture
def stats():
    return usage_stats.Stats()


def tool_use_record(name, tool_input, tool_id="toolu_1"):
    return {
        "type": "assistant",
        "timestamp": TS,
        "message": {"content": [{"type": "tool_use", "id": tool_id, "name": name, "input": tool_input}]},
    }


def test_project_name_core_ai_dir_decodes_to_short_name():
    home_encoded = usage_stats.re.sub(r"[^A-Za-z0-9]", "-", str(Path.home()))
    transcript = usage_stats.PROJECTS_DIR / f"{home_encoded}-core-ai" / "abc.jsonl"
    assert usage_stats.project_name(transcript) == "core-ai"


def test_session_id_subagent_transcript_returns_parent_session():
    transcript = usage_stats.PROJECTS_DIR / "p" / "sess-1" / "subagents" / "agent-x.jsonl"
    assert usage_stats.session_id(transcript) == "sess-1"


def test_handle_record_agent_without_type_counts_general_purpose(stats):
    usage_stats.handle_record(stats, tool_use_record("Agent", {"prompt": "x"}), "s", "p", "")
    assert stats.get("agents", "general-purpose").count == 1


def test_handle_record_duplicate_tool_use_id_counted_once(stats):
    record = tool_use_record("Skill", {"skill": "worklog"})
    usage_stats.handle_record(stats, record, "s", "p", "")
    usage_stats.handle_record(stats, record, "s2", "p", "")
    assert stats.get("skills", "worklog").count == 1


def test_handle_record_mcp_tool_counts_server(stats):
    usage_stats.handle_record(stats, tool_use_record("mcp__github__get_me", {}), "s", "p", "")
    assert stats.get("mcp_servers", "github").count == 1


def test_handle_record_read_claude_rule_counts_config_read(stats):
    path = str(usage_stats.CLAUDE_DIR / "rules" / "routing.md")
    usage_stats.handle_record(stats, tool_use_record("Read", {"file_path": path}), "s", "p", "")
    assert stats.get("config_reads", "rules/routing.md").count == 1


def test_handle_record_slash_command_counts_slash(stats):
    record = {"type": "user", "uuid": "u1", "timestamp": TS,
              "message": {"content": "<command-name>/worklog</command-name>"}}
    usage_stats.handle_record(stats, record, "s", "p", "")
    assert stats.get("slash", "worklog").count == 1


def test_handle_record_before_since_is_ignored(stats):
    usage_stats.handle_record(stats, tool_use_record("Bash", {"command": "ls"}), "s", "p", "2026-11-01")
    assert stats.get("tools", "Bash").count == 0
