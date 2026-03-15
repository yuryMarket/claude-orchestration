# Snapshot file
# Unset all aliases to avoid conflicts with functions
unalias -a 2>/dev/null || true
# Functions
# Shell Options
setopt nohashdirs
setopt login
# Aliases
alias -- code-unsafe='NODE_TLS_REJECT_UNAUTHORIZED=0 code'
alias -- run-help=man
alias -- which-command=whence
# Check for rg availability
if ! (unalias rg 2>/dev/null; command -v rg) >/dev/null 2>&1; then
  function rg {
  if [[ -n $ZSH_VERSION ]]; then
    ARGV0=rg /Users/yury_shubianok/.local/share/claude/versions/2.1.74 "$@"
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=rg /Users/yury_shubianok/.local/share/claude/versions/2.1.74 "$@"
  elif [[ $BASHPID != $$ ]]; then
    exec -a rg /Users/yury_shubianok/.local/share/claude/versions/2.1.74 "$@"
  else
    (exec -a rg /Users/yury_shubianok/.local/share/claude/versions/2.1.74 "$@")
  fi
}
fi
export PATH='/Users/yury_shubianok/.rd/bin:/Users/yury_shubianok/.local/bin:/Users/yury_shubianok/Library/Application Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Users/yury_shubianok/Library/Application Support/Code/User/globalStorage/github.copilot-chat/copilotCli:/Users/yury_shubianok/.local/bin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/opt/pmk/env/global/bin:/opt/homebrew/bin:/usr/local/munki:/usr/local/munkireport:/Users/yury_shubianok/Library/Application Support/Code/User/globalStorage/github.copilot-chat/debugCommand:/Users/yury_shubianok/Library/Application Support/Code/User/globalStorage/github.copilot-chat/copilotCli:/Users/yury_shubianok/.local/bin:/Users/yury_shubianok/.rd/bin:/Applications/iTerm.app/Contents/Resources/utilities:/Users/yury_shubianok/.vscode/extensions/ms-python.debugpy-2025.18.0-darwin-arm64/bundled/scripts/noConfigScripts'
