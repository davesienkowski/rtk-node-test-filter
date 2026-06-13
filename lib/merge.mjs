#!/usr/bin/env node
// Cross-platform structured-edit helper used by install.sh / install.ps1.
// Node is a safe dependency here: the whole point is filtering `node --test`.
//
// Usage:
//   node lib/merge.mjs filters-global <srcFilters> <dstFilters>
//   node lib/merge.mjs settings-hook  <settingsJson> <hookScriptAbsPath>
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';

const BEGIN = '# >>> rtk-node-test-filter >>>';
const END = '# <<< rtk-node-test-filter <<<';

function extractBlock(text) {
  const b = text.indexOf(BEGIN);
  const e = text.indexOf(END);
  if (b === -1 || e === -1 || e < b) {
    throw new Error('managed markers not found in source filters.toml');
  }
  return text.slice(b, e + END.length);
}

function mergeFiltersGlobal(src, dst) {
  const block = extractBlock(readFileSync(src, 'utf8'));
  let target = existsSync(dst) ? readFileSync(dst, 'utf8') : '';

  if (!/^\s*schema_version\s*=/m.test(target)) {
    target = 'schema_version = 1\n' + (target ? '\n' + target : '');
  }

  const b = target.indexOf(BEGIN);
  const e = target.indexOf(END);
  if (b !== -1 && e !== -1 && e > b) {
    target = target.slice(0, b) + block + target.slice(e + END.length);
  } else {
    target = target.replace(/\s*$/, '') + '\n\n' + block + '\n';
  }

  mkdirSync(dirname(dst), { recursive: true });
  writeFileSync(dst, target);
  console.log(`merged [filters.node] into ${dst}`);
}

function settingsHook(settingsPath, hookScript) {
  let settings = {};
  if (existsSync(settingsPath)) {
    const txt = readFileSync(settingsPath, 'utf8').trim();
    if (txt) settings = JSON.parse(txt);
  }
  settings.hooks ||= {};
  settings.hooks.PreToolUse ||= [];

  const command = `node ${hookScript}`;
  const already = JSON.stringify(settings.hooks.PreToolUse).includes(hookScript);
  if (already) {
    console.log('hook already registered — no change');
    return;
  }
  settings.hooks.PreToolUse.push({
    matcher: 'Bash',
    hooks: [{ type: 'command', command }],
  });
  mkdirSync(dirname(settingsPath), { recursive: true });
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  console.log(`registered PreToolUse hook in ${settingsPath}`);
}

const [, , cmd, a, b] = process.argv;
try {
  if (cmd === 'filters-global') mergeFiltersGlobal(a, b);
  else if (cmd === 'settings-hook') settingsHook(a, b);
  else { console.error(`unknown command: ${cmd}`); process.exit(2); }
} catch (err) {
  console.error(`merge.mjs ${cmd} failed: ${err.message}`);
  process.exit(1);
}
