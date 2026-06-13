#!/usr/bin/env sh
# Installer for the rtk node --test filter pack (Linux / macOS / WSL).
# POSIX sh; safe to run repeatedly (idempotent).
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PACK_FILTERS="$SCRIPT_DIR/filters.toml"
HOOK_SCRIPT="$SCRIPT_DIR/hook/rtk-node-test-hook.mjs"
MERGE="$SCRIPT_DIR/lib/merge.mjs"

DO_RTK=0; DO_GLOBAL=0; DO_PROJECT=0; PROJECT_DIR=""; DO_ALIAS=0; DO_HOOK=0; ASSUME_YES=0

usage() {
  cat <<EOF
rtk node --test filter pack installer

Usage: ./install.sh [options]
  --install-rtk      Install rtk if it's not on PATH (tries brew, cargo, then curl|sh)
  --global           Install the filter into your user-global rtk config (all projects)
  --project [DIR]    Install as project-local .rtk/filters.toml in DIR (default: cwd) + rtk trust
  --alias            Append a 'ntest' alias (ntest = rtk node --test) to your shell rc
  --hook             Install the optional Claude Code PreToolUse hook (auto-rewrites node --test)
  --all              Shorthand for: --global --alias
  -y, --yes          Non-interactive (assume yes)
  -h, --help         This help

With no options, runs interactively.
Requires: node (you're filtering 'node --test', so you have it), rtk.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --install-rtk) DO_RTK=1 ;;
    --global) DO_GLOBAL=1 ;;
    --project) DO_PROJECT=1; case "${2:-}" in -*|"") : ;; *) PROJECT_DIR="$2"; shift ;; esac ;;
    --alias) DO_ALIAS=1 ;;
    --hook) DO_HOOK=1 ;;
    --all) DO_GLOBAL=1; DO_ALIAS=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

ask() { # ask "prompt" -> 0 if yes
  [ "$ASSUME_YES" = 1 ] && return 0
  printf '%s [y/N] ' "$1"; read -r ans || return 1
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# Interactive defaults if no action flags given
if [ "$DO_RTK$DO_GLOBAL$DO_PROJECT$DO_ALIAS$DO_HOOK" = "00000" ]; then
  echo "Interactive install. Press Enter for the default (No) on each prompt."
  ask "Install rtk if missing?" && DO_RTK=1 || true
  ask "Install filter user-globally (recommended)?" && DO_GLOBAL=1 || true
  ask "Also add the 'ntest' alias?" && DO_ALIAS=1 || true
  ask "Install the optional Claude Code auto-rewrite hook?" && DO_HOOK=1 || true
fi

config_dir() {
  case "$(uname -s)" in
    Darwin) echo "$HOME/Library/Application Support/rtk" ;;
    *) echo "${XDG_CONFIG_HOME:-$HOME/.config}/rtk" ;;
  esac
}

install_rtk() {
  if command -v rtk >/dev/null 2>&1; then echo "rtk already installed: $(command -v rtk)"; return; fi
  echo "Installing rtk..."
  if command -v brew >/dev/null 2>&1; then brew install rtk-ai/tap/rtk
  elif command -v cargo >/dev/null 2>&1; then cargo install --git https://github.com/rtk-ai/rtk rtk
  else curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
  fi
}

require_rtk() {
  command -v rtk >/dev/null 2>&1 || {
    echo "ERROR: rtk is not on PATH. Re-run with --install-rtk, or see README.md." >&2
    exit 1
  }
}

[ "$DO_RTK" = 1 ] && install_rtk

if [ "$DO_GLOBAL" = 1 ]; then
  require_rtk
  dst="$(config_dir)/filters.toml"
  node "$MERGE" filters-global "$PACK_FILTERS" "$dst"
  echo "User-global filter installed. Applies to ALL your projects (no 'rtk trust' needed)."
fi

if [ "$DO_PROJECT" = 1 ]; then
  require_rtk
  dir="${PROJECT_DIR:-$PWD}"
  mkdir -p "$dir/.rtk"
  cp "$PACK_FILTERS" "$dir/.rtk/filters.toml"
  ( cd "$dir" && rtk trust )
  echo "Project filter installed at $dir/.rtk/filters.toml and trusted."
fi

if [ "$DO_ALIAS" = 1 ]; then
  rc="$HOME/.bashrc"; [ -n "${ZSH_VERSION:-}" ] && rc="$HOME/.zshrc"
  [ "${SHELL##*/}" = "zsh" ] && rc="$HOME/.zshrc"
  line="alias ntest='rtk node --test'"
  if [ -f "$rc" ] && grep -qF "$line" "$rc" 2>/dev/null; then
    echo "alias already present in $rc"
  else
    printf '\n# rtk node --test filter pack\n%s\n' "$line" >> "$rc"
    echo "added 'ntest' alias to $rc (run: source $rc)"
  fi
fi

if [ "$DO_HOOK" = 1 ]; then
  settings="$HOME/.claude/settings.json"
  node "$MERGE" settings-hook "$settings" "$HOOK_SCRIPT"
  echo "Optional hook installed. Restart Claude Code so it reloads hooks."
fi

echo "Done. Verify with: rtk verify --require-all   (then try: rtk node --test <file>)"
