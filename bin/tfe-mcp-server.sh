#!/bin/zsh
# Wrapper для terraform-mcp-server.
# VSCode/Claude Code, запущенный из Dock/Finder, НЕ читает ~/.zshenv, поэтому
# MCP-сервер не получает TFE_TOKEN/TFE_ADDRESS. Здесь мы сами их подтягиваем,
# чтобы секрет оставался только в ~/.zshenv и не дублировался в ~/.claude.json.
[ -f "$HOME/.zshenv" ] && source "$HOME/.zshenv"
exec "$HOME/go/bin/terraform-mcp-server" "$@"
