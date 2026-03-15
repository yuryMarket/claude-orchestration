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
    ARGV0=rg /Users/yury_shubianok/.vscode/extensions/anthropic.claude-code-2.1.72-darwin-arm64/resources/native-binary/claude "$@"
  elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    ARGV0=rg /Users/yury_shubianok/.vscode/extensions/anthropic.claude-code-2.1.72-darwin-arm64/resources/native-binary/claude "$@"
  elif [[ $BASHPID != $$ ]]; then
    exec -a rg /Users/yury_shubianok/.vscode/extensions/anthropic.claude-code-2.1.72-darwin-arm64/resources/native-binary/claude "$@"
  else
    (exec -a rg /Users/yury_shubianok/.vscode/extensions/anthropic.claude-code-2.1.72-darwin-arm64/resources/native-binary/claude "$@")
  fi
}
fi
export PATH=/opt/homebrew/opt/python\@3.14/Frameworks/Python.framework/Versions/3.14/bin\:/Users/yury_shubianok/.rd/bin\:/Users/yury_shubianok/.local/bin\:/Users/yury_shubianok/.local/bin\:/usr/local/bin\:/System/Cryptexes/App/usr/bin\:/usr/bin\:/bin\:/usr/sbin\:/sbin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin\:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin\:/opt/pmk/env/global/bin\:/opt/homebrew/bin\:/usr/local/munki\:/usr/local/munkireport\:/Applications/iTerm.app/Contents/Resources/utilities
