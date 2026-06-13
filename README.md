# rtk `node --test` filter pack

> **For GSD users:** [GSD](https://github.com/opengsd/gsd-core) (and its
> `@opengsd/gsd-core` engine) runs its entire `.cjs` test suite through
> `node --test` — the single biggest unfiltered token sink when working on it.
> This pack (install `--global --alias`, then use `ntest` / `rtk node --test`)
> cuts a passing suite from dozens-to-hundreds of lines down to the summary,
> while still surfacing full detail on a failure. It does **not** modify GSD or
> its workflows — it's a local output filter you opt into.
>
> One caveat: GSD's workflow *bash-shim blocks* run many commands inside a single
> `bash -c` call, which rtk can't see into — so this helps the `node --test` runs
> you invoke directly (the test suite), not commands buried inside a workflow block.

A tiny, standalone [rtk](https://github.com/rtk-ai/rtk) ("Rust Token Killer")
filter that compresses the output of the **Node.js built-in test runner**
(`node --test`) before it reaches an AI coding agent (Claude Code, Codex, Gemini
CLI, …). An all-passing run collapses to its summary; a failing run keeps the
failure and its diagnostics.

It's pure rtk-side regex, so behavior is **identical on Linux, macOS, and
Windows**. Nothing here is tied to any particular project.

```
$ node --test tests/foo.test.cjs      # 73 lines of TAP
$ rtk node --test tests/foo.test.cjs  #  8 lines:
# tests 7
# suites 3
# pass 7
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 263.0
```

On failures it keeps the `not ok` line plus `error` / `expected` / `actual` /
`stack` / `location`, and the full raw output is tee'd to a log file by rtk.

## Install

You need **Node.js** (you're filtering `node --test`, so you have it) and
**rtk**. The installer can install rtk for you.

**Linux / macOS / WSL**
```bash
git clone https://github.com/davesienkowski/rtk-node-test-filter
cd rtk-node-test-filter
./install.sh            # interactive
# or non-interactive:
./install.sh --install-rtk --global --alias        # recommended
./install.sh --project .                            # this repo only (+ rtk trust)
./install.sh --hook                                 # optional auto-rewrite in Claude Code
```

**Windows (PowerShell)**
```powershell
git clone https://github.com/davesienkowski/rtk-node-test-filter
cd rtk-node-test-filter
./install.ps1                       # interactive
./install.ps1 -InstallRtk -Global -Alias
./install.ps1 -Project .
./install.ps1 -Hook
```

### Two scopes

- **`--global`** → merges `[filters.node]` into your user-global rtk config
  (`~/.config/rtk/filters.toml`, macOS `~/Library/Application Support/rtk/`,
  Windows `%APPDATA%\rtk\`). Applies to **every project**, no trust step.
- **`--project [DIR]`** → drops `.rtk/filters.toml` into a repo and runs
  `rtk trust`. Use this to **commit the filter into a shared/team repo** so
  everyone who clones it gets the same behavior (each runs `rtk trust` once).

You don't need both — pick global for your own machine, project for sharing in a
repo.

## Making it fire (important)

rtk's editor hook only auto-rewrites a fixed built-in command set; it does **not**
auto-route `node --test`. So the filter only runs when the command reaches rtk.
Two ways to get that:

1. **Alias (default, portable):** `--alias` installs `ntest='rtk node --test'`.
   Use `ntest <file>` instead of `node --test <file>`.
2. **Optional Claude Code hook (`--hook`):** registers a tiny PreToolUse hook
   (`hook/rtk-node-test-hook.mjs`) that auto-rewrites a standalone
   `node --test …` Bash command to `rtk node --test …`. It **fails open** (any
   parse error / compound command / already-wrapped command → runs unchanged) and
   is additive to rtk's own hook. Claude Code only.

## Verify / uninstall

```bash
rtk verify --require-all        # runs the filter's inline tests (should pass)
```
Uninstall: delete the `# >>> rtk-node-test-filter >>>` … `<<<` block from your
global `filters.toml` (or delete the project `.rtk/`), remove the `ntest` alias
line, and remove the hook entry from `~/.claude/settings.json`.

## License

MIT
