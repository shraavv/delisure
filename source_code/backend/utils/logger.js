const c = {
  reset:  '\x1b[0m',
  dim:    '\x1b[2m',
  bold:   '\x1b[1m',
  red:    '\x1b[31m',
  green:  '\x1b[32m',
  yellow: '\x1b[33m',
  blue:   '\x1b[34m',
  magenta:'\x1b[35m',
  cyan:   '\x1b[36m',
  gray:   '\x1b[90m',
  bgRed:   '\x1b[41m\x1b[97m',
  bgGreen: '\x1b[42m\x1b[30m',
  bgYellow:'\x1b[43m\x1b[30m',
  bgBlue:  '\x1b[44m\x1b[97m',
};

const LEVELS = { debug: 0, info: 1, warn: 2, error: 3, off: 4 };
const LEVEL = LEVELS[(process.env.LOG_LEVEL || 'debug').toLowerCase()] ?? 0;

function ts() {
  return new Date().toISOString().replace('T', ' ').slice(11, 23);
}

function _fmt(tag, color, msg) {
  return `${c.gray}${ts()}${c.reset} ${color}${c.bold}${tag}${c.reset} ${msg}`;
}

function section(title, color = c.cyan) {
  const line = '═'.repeat(65);
  console.log(`\n${color}${line}${c.reset}`);
  console.log(`${color}${c.bold} ▶ ${title}${c.reset}`);
  console.log(`${color}${line}${c.reset}`);
}

function endSection(color = c.cyan) {
  console.log(`${color}${'═'.repeat(65)}${c.reset}\n`);
}

function debug(tag, msg) {
  if (LEVEL > LEVELS.debug) return;
  console.log(_fmt(`[${tag}]`, c.gray, msg));
}
function info(tag, msg)  { if (LEVEL > LEVELS.info)  return; console.log(_fmt(`[${tag}]`, c.blue, msg)); }
function ok(tag, msg)    { if (LEVEL > LEVELS.info)  return; console.log(_fmt(`[${tag}]`, c.green, msg)); }
function warn(tag, msg)  { if (LEVEL > LEVELS.warn)  return; console.log(_fmt(`[${tag}]`, c.yellow, msg)); }
function error(tag, msg) { if (LEVEL > LEVELS.error) return; console.log(_fmt(`[${tag}]`, c.red, msg)); }

function kv(pairs, indent = 2) {
  const maxKey = Math.max(...pairs.map(([k]) => String(k).length));
  for (const [k, v] of pairs) {
    const key = String(k).padEnd(maxKey);
    console.log(`${' '.repeat(indent)}${c.gray}${key}${c.reset}  ${c.cyan}${v}${c.reset}`);
  }
}

function table(rows, headers) {
  if (!rows.length) return;
  const keys = headers || Object.keys(rows[0]);
  const widths = keys.map(k => Math.max(k.length, ...rows.map(r => String(r[k] ?? '').length)));
  const line = (cells) => '│ ' + cells.map((c, i) => String(c).padEnd(widths[i])).join(' │ ') + ' │';
  const sep = '├' + widths.map(w => '─'.repeat(w + 2)).join('┼') + '┤';
  const top = '┌' + widths.map(w => '─'.repeat(w + 2)).join('┬') + '┐';
  const bot = '└' + widths.map(w => '─'.repeat(w + 2)).join('┴') + '┘';
  console.log(c.gray + top + c.reset);
  console.log(c.gray + line(keys) + c.reset);
  console.log(c.gray + sep + c.reset);
  for (const r of rows) console.log(line(keys.map(k => r[k] ?? '')));
  console.log(c.gray + bot + c.reset);
}

function badge(text, kind = 'info') {
  const bg = kind === 'error' ? c.bgRed
          : kind === 'warn' ? c.bgYellow
          : kind === 'success' ? c.bgGreen
          : c.bgBlue;
  return `${bg} ${text} ${c.reset}`;
}

function scoreBar(value, max = 1.0, width = 20) {
  const fill = Math.round((value / max) * width);
  const color = value > 0.7 ? c.red : value > 0.3 ? c.yellow : c.green;
  return color + '█'.repeat(fill) + c.gray + '░'.repeat(width - fill) + c.reset + ` ${(value * 100).toFixed(0)}%`;
}

module.exports = {
  c, ts, section, endSection, debug, info, ok, warn, error, kv, table, badge, scoreBar,
};
