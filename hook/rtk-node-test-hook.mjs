#!/usr/bin/env node
// Optional Claude Code PreToolUse hook: auto-rewrite a standalone
// `node --test ...` Bash command to `rtk node --test ...` so the rtk filter
// fires without you typing the `rtk` prefix.
//
// It is additive to rtk's own hook: rtk passes `node --test` through untouched,
// so this hook is the only one that rewrites it (no conflict).
//
// SAFETY: fails open. Any parse error, non-Bash tool, compound command, or
// already-rtk-wrapped command => emit nothing and exit 0 (command runs as-is).
//
// Register in ~/.claude/settings.json (the installer can do this for you):
//   { "hooks": { "PreToolUse": [ { "matcher": "Bash",
//     "hooks": [ { "type": "command",
//       "command": "node /ABS/PATH/rtk-node-test-hook.mjs" } ] } ] } }

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  try {
    const payload = JSON.parse(raw);
    if (payload.tool_name !== 'Bash') return;
    const cmd = (payload.tool_input && payload.tool_input.command) || '';

    // Only handle a SINGLE, simple `node ... --test ...` invocation.
    // Bail on shell metacharacters so we never corrupt a compound command.
    if (/[|&;<>`$()]|&&|\|\|/.test(cmd)) return;
    if (/^\s*rtk\b/.test(cmd)) return;            // already wrapped
    if (!/^\s*node\b/.test(cmd)) return;          // must start with node
    if (!/\s--test\b/.test(cmd)) return;          // must be a test run

    const rewritten = 'rtk ' + cmd.trim();
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecisionReason: 'rtk node --test auto-rewrite',
        updatedInput: { command: rewritten },
      },
    }));
  } catch {
    // fail open — never block the user's command
  }
});
