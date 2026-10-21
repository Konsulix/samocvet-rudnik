// Pulls the game's tables out of the browser prototype into godot/data/game_data.json,
// so the Godot version plays with exactly the same levels, minerals and prices.
// Run from the repo root: node godot/tools/export_data.js
const fs = require('fs'), path = require('path'), vm = require('vm');
const root = path.resolve(__dirname, '..', '..');
const src = fs.readFileSync(path.join(root, 'prototype/web/samocvet_src.html'), 'utf8');
const spec = fs.readFileSync(path.join(root, 'prototype/web/specimen.js'), 'utf8');

// the literal after `const NAME = `, found by matching brackets (strings and comments skipped)
function literal(text, name){
  const m = new RegExp(`const ${name} = `).exec(text); if (!m) throw new Error('missing ' + name);
  let i = m.index + m[0].length; const start = i, open = text[i]; if (!'[{'.includes(open)) throw new Error('not a literal: ' + name);
  let depth = 0, q = null;
  for (; i < text.length; i++) {
    const ch = text[i];
    if (q) { if (ch === '\\') { i++; continue; } if (ch === q) q = null; continue; }
    if (ch === '/' && text[i + 1] === '/') { i = text.indexOf('\n', i); continue; }
    if (ch === "'" || ch === '"' || ch === '`') { q = ch; continue; }
    if (ch === '[' || ch === '{') depth++;
    else if (ch === ']' || ch === '}') { depth--; if (!depth) return text.slice(start, i + 1); }
  }
  throw new Error('unterminated ' + name);
}
const ev = s => vm.runInNewContext('(' + s + ')');
const out = {};
for (const n of ['SP', 'GR', 'LEVELS', 'AREAS', 'CHEST', 'SETS', 'DEPTHS', 'DMODS', 'DSHORT', 'EQUIP', 'JEWELS', 'CUTS', 'CUTN', 'PRE', 'BOOSTS', 'GEMS']) out[n] = ev(literal(src, n));
for (const n of ['RAR', 'RC']) out[n] = ev(new RegExp(`const RAR = (\\[[^\\]]*\\]), RC = (\\[[^\\]]*\\])`).exec(src)[n === 'RAR' ? 1 : 2]);
for (const n of ['HABIT', 'TRAITS']) out[n] = ev(literal(spec, n));
// colours as #rrggbb strings, which Godot reads with Color.html()
for (const k in out.SP) out.SP[k].c = '#' + out.SP[k].c.toString(16).padStart(6, '0');
const file = path.join(root, 'godot/data/game_data.json');
fs.mkdirSync(path.dirname(file), {recursive:true});
fs.writeFileSync(file, JSON.stringify(out, null, 1));
console.log('wrote', path.relative(root, file), Object.keys(out).map(k => `${k}:${Array.isArray(out[k]) ? out[k].length : Object.keys(out[k]).length}`).join(' '));
