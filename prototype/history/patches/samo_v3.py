"""Самоцветный рудник v3: depth per mine (harder boards, richer rewards), equipment for coins, jewellery workshop."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS & nav ----------------
rep(".nav{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding-block:8px 10px}", ".nav{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;padding-block:8px 10px}")
rep("@media (prefers-reduced-motion:reduce)", """.depthrow{display:flex;align-items:center;gap:8px;width:100%;background:#111a29;border:1px solid var(--line);border-radius:14px;padding:8px 10px}
.depthrow button{width:34px;height:34px;border-radius:10px;background:#22324e;border:1px solid var(--line);font-size:18px;font-weight:800;flex:none}
.depthrow button:disabled{opacity:.3}
.depthrow div{flex:1;text-align:left}
.depthrow b{font-family:var(--display);font-size:15px;color:var(--gold)}
.depthrow small{display:block;color:var(--muted);font-size:11.5px}
.depthchip{display:inline-flex;align-items:center;gap:6px;margin-top:4px;font-size:12px;color:#ffd0a0;background:rgba(90,42,16,.5);border:1px solid #8a4a1a;border-radius:999px;padding:2px 10px}
.ctabs{display:grid;grid-template-columns:1fr 1fr;gap:6px;background:#111a29;border:1px solid var(--line);border-radius:14px;padding:4px}
.ctabs button{border-radius:10px;padding:8px 0;font-size:13px;color:var(--muted)}
.ctabs button.on{background:#22324e;color:var(--fg)}
.jw{display:grid;grid-template-columns:64px 1fr auto;gap:10px;align-items:center;background:#111a29;border:1px solid var(--line);border-radius:14px;padding:8px 10px;text-align:left}
.jw.own{border-color:var(--gold);background:linear-gradient(90deg,#2a2210,#111a29)}
.jw canvas{width:64px;height:64px}
.jw b{font-family:var(--display);font-size:14px}
.jw p{margin:2px 0 0;font-size:12px;color:var(--muted)}
.jw .perk{color:var(--good)}
.jw .go{border-radius:12px;padding:8px 10px;background:linear-gradient(#ffd77a,#e3a51e);color:#3a2200;font-family:var(--display);font-size:12px;box-shadow:0 3px 0 #7a4c08}
.jw .go:disabled{background:#2a3548;color:var(--muted);box-shadow:none}
.jw .go.sell{background:#2a3548;color:var(--fg);box-shadow:none;border:1px solid var(--line)}
@media (prefers-reduced-motion:reduce)""")
rep('<div class="nav"><button class="on" type="button">Рудник</button><button type="button" id="toColl">Коллекция</button></div>',
    '<div class="nav"><button class="on" type="button">Рудник</button><button type="button" id="toTech">Техника</button><button type="button" id="toColl">Коллекция</button></div>')
rep('<div class="nav"><button type="button" id="toHome">Рудник</button><button class="on" type="button">Коллекция</button></div>',
    '<div class="nav"><button type="button" id="toHome">Рудник</button><button type="button" id="toTech2">Техника</button><button class="on" type="button">Коллекция</button></div>')

# ---------------- a sixth colour for the deepest boards ----------------
rep("  {n:'аметист', c:'#a05ef7', d:'#46199a', l:'#dcc4ff', shape:'trillion'},\n];",
    "  {n:'аметист', c:'#a05ef7', d:'#46199a', l:'#dcc4ff', shape:'trillion'},\n  {n:'лунный камень', c:'#dfe8f4', d:'#5f6e86', l:'#ffffff', shape:'hex'},\n];")
rep("  if (shape === 'kite')", "  if (shape === 'hex') return Array.from({length:6}, (_, k) => [Math.cos(k / 6 * 6.283 - 1.571) * R * .95, Math.sin(k / 6 * 6.283 - 1.571) * R * .95]);\n  if (shape === 'kite')")

# ---------------- save ----------------
rep("pre:{rocket:1, bomb:1, orb:0}, streak:0, coll:[], sets:[],", "pre:{rocket:1, bomb:1, orb:0}, streak:0, eq:{lift:0, crush:0, food:0, vent:0}, depth:[0, 0, 0], depthSel:[0, 0, 0], jewels:[], coll:[], sets:[],")
rep("o.pre = Object.assign(BLANK().pre, s.pre);", "o.pre = Object.assign(BLANK().pre, s.pre); o.eq = Object.assign(BLANK().eq, s.eq);")

# ---------------- depth, equipment, jewellery data ----------------
rep("// cutting a kept specimen: a coin gamble on value", r"""// depth: every mine goes down in steps; deeper boards are harsher and pay more
const DEPTHS = [{m:50}, {m:200, tool:'Отбойный молоток', cost:800}, {m:350, tool:'Буровая установка', cost:2500}, {m:500, tool:'Проходческий комбайн', cost:6000}, {m:650, tool:'Глубинный бур', cost:15000}];
const DMODS = ['обычное поле', 'песчаник твердеет до гранита', 'на поле газ, ходов меньше', 'деревянная крепь на камнях', 'шестой цвет камней'];
const DSHORT = ['', 'гранит', 'газ', 'крепь', '6 цветов'];
const depthCost = (ai, k) => Math.round(DEPTHS[k].cost * (1 + ai * .8) / 50) * 50;
const depthPay = dl => 1 + dl * .5;
// equipment: permanent upgrades bought with coins
const EQUIP = [{id:'lift', n:'Лебёдка', d:'+1 камень на выбор в жиле', cost:[1200, 4000]}, {id:'crush', n:'Дробилка', d:'+25% монет за уровень', cost:[600, 2000, 6000]},
  {id:'food', n:'Провиант', d:'+1 ход на старте каждого уровня', cost:[1000, 3000, 9000]}, {id:'vent', n:'Вентиляция', d:'газ расползается вдвое реже', cost:[1500]}];
// jewellery: cut stones set in gold, worth more than the stones, some give lasting bonuses
const JEWELS = [
  {id:'ring', n:'Кольцо', d:'любой огранённый камень', m:1.5, need:[{}]},
  {id:'ear', n:'Серьги', d:'два огранённых камня одного вида', m:1.7, need:'pair'},
  {id:'pend', n:'Кулон', d:'огранённый редкий камень и ещё один', m:1.8, need:[{r:2}, {}]},
  {id:'brooch', n:'Брошь', d:'три огранённых камня разных видов', m:2, need:'trio', perk:'+5% ко всем монетам'},
  {id:'diadem', n:'Диадема', d:'два огранённых редких и два любых', m:2.3, need:[{r:2}, {r:2}, {}, {}], perk:'+1 камень на выбор в жилах'},
  {id:'crown', n:'Корона рудника', d:'огранённые рубин, сапфир, изумруд, алмаз и ещё один', m:3, need:[{sid:'ruby'}, {sid:'sapphire'}, {sid:'emerald'}, {sid:'diamond'}, {}], perk:'+10% ко всем монетам'},
];
const hexC = c => '#' + c.toString(16).padStart(6, '0');
const cutOK = s => s.cut && s.cut !== 'broken';
const hasJewel = id => save.jewels.some(j => j.rid === id);
const coinMul = () => 1 + (hasJewel('brooch') ? .05 : 0) + (hasJewel('crown') ? .1 : 0);
// the cheapest stones that satisfy a recipe, so the prized ones stay in the cabinet
function pickFor(j){
  const pool = save.coll.filter(cutOK).sort((a, b) => a.value - b.value);
  if (j.need === 'pair') { const by = {}; for (const st of pool) (by[st.sid] = by[st.sid] || []).push(st); const k = Object.keys(by).find(k => by[k].length >= 2); return k ? by[k].slice(0, 2) : null; }
  if (j.need === 'trio') { const out = [], seen = new Set(); for (const st of pool) if (!seen.has(st.sid)) { seen.add(st.sid); out.push(st); if (out.length === 3) return out; } return null; }
  const used = new Set(), out = [], rank = c => c.sid ? 2 : c.r ? 1 : 0;
  for (const c of j.need.slice().sort((a, b) => rank(b) - rank(a))) { const st = pool.find(x => !used.has(x) && (!c.sid || x.sid === c.sid) && (!c.r || SP[x.sid].r >= c.r)); if (!st) return null; used.add(st); out.push(st); }
  return out;
}
function drawJewel(x, S, id, cols){
  const gold = x.createLinearGradient(0, 0, S, S); gold.addColorStop(0, '#fff0a0'); gold.addColorStop(.5, '#e3a51e'); gold.addColorStop(1, '#8a5a06');
  const c = i => cols[i % cols.length] || '#ffffff';
  const gem = (cx, cy, r, col) => { const g = x.createRadialGradient(cx - r * .3, cy - r * .3, 1, cx, cy, r); g.addColorStop(0, '#ffffff'); g.addColorStop(.35, col); g.addColorStop(1, '#1a1a1a'); x.fillStyle = g; x.beginPath(); x.arc(cx, cy, r, 0, 6.29); x.fill(); x.strokeStyle = '#7a5208'; x.lineWidth = S * .02; x.stroke(); };
  x.save(); x.lineCap = 'round';
  if (id === 'ring') { x.strokeStyle = gold; x.lineWidth = S * .08; x.beginPath(); x.ellipse(S / 2, S * .62, S * .26, S * .22, 0, 0, 6.29); x.stroke(); gem(S / 2, S * .36, S * .14, c(0)); }
  else if (id === 'ear') { for (const dx of [-.18, .18]) { x.strokeStyle = gold; x.lineWidth = S * .04; x.beginPath(); x.arc(S / 2 + dx * S, S * .2, S * .06, 0, 6.29); x.stroke(); x.beginPath(); x.moveTo(S / 2 + dx * S, S * .26); x.lineTo(S / 2 + dx * S, S * .42); x.stroke(); gem(S / 2 + dx * S, S * .56, S * .12, c(dx < 0 ? 0 : 1)); } }
  else if (id === 'pend') { x.strokeStyle = gold; x.lineWidth = S * .03; x.beginPath(); x.moveTo(S * .15, S * .1); x.quadraticCurveTo(S / 2, S * .55, S * .85, S * .1); x.stroke(); gem(S / 2, S * .64, S * .17, c(0)); gem(S / 2, S * .4, S * .07, c(1)); }
  else if (id === 'brooch') { x.fillStyle = gold; for (let k = 0; k < 6; k++) { const a = k / 6 * 6.28; x.beginPath(); x.ellipse(S / 2 + Math.cos(a) * S * .2, S / 2 + Math.sin(a) * S * .2, S * .12, S * .07, a, 0, 6.29); x.fill(); } gem(S / 2, S / 2, S * .12, c(0)); gem(S * .3, S * .36, S * .07, c(1)); gem(S * .7, S * .64, S * .07, c(2)); }
  else if (id === 'diadem') { x.strokeStyle = gold; x.lineWidth = S * .06; x.beginPath(); x.arc(S / 2, S * .98, S * .46, Math.PI * 1.12, Math.PI * 1.88); x.stroke(); x.fillStyle = gold; x.beginPath(); x.moveTo(S * .5, S * .18); x.lineTo(S * .57, S * .44); x.lineTo(S * .43, S * .44); x.closePath(); x.fill(); [[.22, .64], [.38, .54], [.62, .54], [.78, .64]].forEach(([a, b], i) => gem(a * S, b * S, S * .08, c(i))); }
  else { x.fillStyle = gold; x.beginPath(); x.moveTo(S * .14, S * .78); x.lineTo(S * .1, S * .3); x.lineTo(S * .3, S * .52); x.lineTo(S * .5, S * .2); x.lineTo(S * .7, S * .52); x.lineTo(S * .9, S * .3); x.lineTo(S * .86, S * .78); x.closePath(); x.fill(); x.strokeStyle = '#7a5208'; x.lineWidth = S * .02; x.stroke();
    x.fillRect(S * .14, S * .74, S * .72, S * .1); [[.1, .3], [.5, .2], [.9, .3]].forEach(([a, b], i) => gem(a * S, b * S, S * .06, c(i))); [.3, .5, .7].forEach((a, i) => gem(a * S, S * .64, S * .07, c(i + 2))); }
  x.restore();
}
// cutting a kept specimen: a coin gamble on value""")

# ---------------- the level at depth ----------------
rep("function startLevel(n, pre = []){\n  const def = levelDef(n);\n  L = {n, moves:def.moves, vein:!!def.vein, hard:!!def.hard, colors:5,",
    "function startLevel(n, pre = [], dl = 0){\n  const def = levelDef(n);\n  L = {n, depth:dl, moves:def.moves - Math.floor(dl / 2) + save.eq.food, vein:!!def.vein, hard:!!def.hard, colors:dl >= 4 ? 6 : 5,")
rep("  for (const gdef of def.goals) {\n    if (gdef[0] === 'c')", r"""  // the deeper you dig, the harder the board
  { const free = () => { const a = []; for (let r = 1; r < R - 1; r++) for (let c = 0; c < C; c++) if (playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0 && !G[r][c] && !LOCK[r][c] && !MUD[r][c]) a.push([r, c]); return a; };
    if (dl >= 1) for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (ROCK[r][c] === 1) ROCK[r][c] = 2;
    if (dl >= 2) { const f = free(); for (let k = 0; k < dl + 1 && f.length; k++) { const [r, c] = f.splice(ri(0, f.length - 1), 1)[0]; GAS[r][c] = 1; } }
    if (dl >= 3) { const f = free(); for (let k = 0; k < dl * 2 && f.length; k++) { const [r, c] = f.splice(ri(0, f.length - 1), 1)[0]; LOCK[r][c] = 1; } }
    rocks = 0; gas = 0; locks = 0; for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) { if (ROCK[r][c]) rocks++; if (GAS[r][c]) gas++; if (LOCK[r][c]) locks++; } }
  for (const gdef of def.goals) {
    if (gdef[0] === 'c')""")
rep("  $('#lvlName').textContent = `Уровень ${L.n}${L.vein ? ' · жила' : ''}${L.hard ? ' · сложный' : ''}`;",
    "  $('#lvlName').textContent = `Уровень ${L.n} · ${DEPTHS[L.depth].m} м${L.vein ? ' · жила' : ''}${L.hard ? ' · сложный' : ''}`;")
rep("async function gasSpread(){\n  if (L.gasHit) { L.gasHit = false; return; }", "async function gasSpread(){\n  if (L.gasHit) { L.gasHit = false; return; }\n  if (save.eq.vent && Math.random() < .5) return;")

# ---------------- richer stones at depth ----------------
rep("function rollStone(seed, area, luck){", "function rollStone(seed, area, luck, dl = 0){")
rep("* Math.pow(6, rng()) * (legend ? 3 : 1));", "* Math.pow(6, rng()) * (legend ? 3 : 1) * (1 + dl * .35));")
rep("(kind === 'druse' ? 1.4 : kind === 'geode' ? 1.6 : 1) * 1.3);", "(kind === 'druse' ? 1.4 : kind === 'geode' ? 1.6 : 1) * 1.3 * (1 + dl * .25));")
rep("L.bonus.push(rollStone(++save.uid, save.area, .5));", "L.bonus.push(rollStone(++save.uid, save.area, .5 + L.depth * .35, L.depth));")
rep("  const left = L.moves + Math.round(L.coinsWon / 5), X = Math.min(5, 3 + Math.floor(left / 4)), luck = (L.hard ? .6 : 0) + Math.min(1, left / 15);\n  const stones = Array.from({length:X}, () => rollStone(++save.uid, save.area, luck)); persist();",
    "  const left = L.moves + Math.round(L.coinsWon / 5), X = Math.min(7, 3 + Math.floor(left / 4) + save.eq.lift + (hasJewel('diadem') ? 1 : 0) + Math.floor(L.depth / 2)), luck = (L.hard ? .6 : 0) + Math.min(1, left / 15) + L.depth * .35;\n  const stones = Array.from({length:X}, () => rollStone(++save.uid, save.area, luck, L.depth)); persist();")
rep("${X > 3 ? 'Оставшиеся ходы дали больше выбора.' : 'Больше ходов в запасе — больше выбор.'}", "${X > 3 ? 'Ходы в запасе, глубина и техника дали больше выбора.' : 'Больше ходов в запасе — больше выбор.'}")

# ---------------- coins: depth, crusher, jewels ----------------
rep("  const coins = 20 + L.coinsWon; save.coins += coins;", "  const coins = Math.round((20 + L.coinsWon) * depthPay(L.depth) * (1 + save.eq.crush * .25) * coinMul()); save.coins += coins;")
rep("<h2>Уровень ${L.n} пройден!</h2>", "<h2>Уровень ${L.n} пройден!</h2>${L.depth ? `<p>Глубина ${DEPTHS[L.depth].m} м: монеты ×${String(depthPay(L.depth)).replace('.', ',')}</p>` : ''}")
rep("    $('#sell').onclick = () => { save.coins += s.value;", "    $('#sell').onclick = () => { save.coins += Math.round(s.value * coinMul());")
rep("      $('#sellC').onclick = () => { save.coll = save.coll.filter(x => x !== s); save.coins += s.value;", "      $('#sellC').onclick = () => { save.coll = save.coll.filter(x => x !== s); save.coins += Math.round(s.value * coinMul());")

# ---------------- choosing depth before the level ----------------
rep("  const n = save.level, def = levelDef(n), free = streakFree(), sel = new Set(free);", "  const n = save.level, def = levelDef(n), free = streakFree(), sel = new Set(free), ai = Math.min(save.area, AREAS.length - 1);\n  let dl = Math.min(save.depthSel[ai] || 0, save.depth[ai] || 0);")
rep("    openOv(`<h2>Уровень ${n}</h2><p>${hod(def.moves)}${def.hard ? ' · сложный' : ''}${def.vein ? ' · жила: в конце выбор камня' : ''}</p>\n      <div class=\"pgoals\" id=\"pg\"></div>",
    "    openOv(`<h2>Уровень ${n}</h2><p>${hod(def.moves - Math.floor(dl / 2) + save.eq.food)}${def.hard ? ' · сложный' : ''}${def.vein ? ' · жила: в конце выбор камня' : ''}</p>\n      <div class=\"pgoals\" id=\"pg\"></div>\n"
    "      <div class=\"depthrow\"><button type=\"button\" id=\"dMinus\" ${dl <= 0 ? 'disabled' : ''} aria-label=\"Мельче\">−</button><div><b>Глубина ${DEPTHS[dl].m} м</b><small>${dl ? `${DSHORT.slice(1, dl + 1).join(', ')} · монеты ×${String(depthPay(dl)).replace('.', ',')}, камни дороже` : 'обычное поле и обычные награды'}</small></div><button type=\"button\" id=\"dPlus\" ${dl >= (save.depth[ai] || 0) ? 'disabled' : ''} aria-label=\"Глубже\">+</button></div>\n"
    "      ${(save.depth[ai] || 0) < DEPTHS.length - 1 ? `<p style=\"font-size:12px\">Глубже ${DEPTHS[(save.depth[ai] || 0)].m} м пустит только техника: ${DEPTHS[(save.depth[ai] || 0) + 1].tool.toLowerCase()}.</p>` : ''}")
rep("      $('#goLvl').onclick = () => { const sps = []; for (const id of sel) { const p = PRE.find(x => x.id === id); if (!free.includes(id)) save.pre[id]--; sps.push(...p.sp); } persist(); closeOv(); startLevel(n, sps); };",
    "      $('#dMinus').onclick = () => { dl = Math.max(0, dl - 1); save.depthSel[ai] = dl; persist(); draw(); };\n"
    "      $('#dPlus').onclick = () => { dl = Math.min(save.depth[ai] || 0, dl + 1); save.depthSel[ai] = dl; persist(); draw(); };\n"
    "      $('#goLvl').onclick = () => { const sps = []; for (const id of sel) { const p = PRE.find(x => x.id === id); if (!free.includes(id)) save.pre[id]--; sps.push(...p.sp); } persist(); closeOv(); startLevel(n, sps, dl); };")

# ---------------- home: depth chip, equipment screen ----------------
rep("  $('#areaName').textContent = A.n; $('#areaSub').textContent = A.sub;",
    "  $('#areaName').textContent = A.n; $('#areaSub').innerHTML = `${A.sub}<br><span class=\"depthchip\">⛏ копаете до ${DEPTHS[save.depth[ai] || 0].m} м</span>`;")
rep("function openTasks(){", r"""function openTech(){
  const ai = Math.min(save.area, AREAS.length - 1), A = AREAS[ai], d = save.depth[ai] || 0;
  openOv(`<h2>Техника</h2><p>${A.n}: копаете до ${DEPTHS[d].m} м. Глубже — злее поле и богаче находки. У вас ${mon(save.coins)}.</p>
    <div class="list">${DEPTHS.slice(1).map((t, i) => { const k = i + 1, has = d >= k, next = k === d + 1, cost = depthCost(ai, k);
      return `<div class="task${has ? ' done' : ''}"><div><b>${t.tool} · ${t.m} м</b><p>${has ? 'Куплено' : DMODS[k] + `, монеты ×${String(depthPay(k)).replace('.', ',')}`}</p></div><button class="go" data-depth="${k}" ${has || !next || save.coins < cost ? 'disabled' : ''}>${has ? '✓' : fmt(cost)}</button></div>`; }).join('')}</div>
    <div class="h3" style="align-self:flex-start">Снаряжение для всех рудников</div>
    <div class="list">${EQUIP.map(e => { const lv = save.eq[e.id], max = e.cost.length, cost = e.cost[lv];
      return `<div class="task${lv >= max ? ' done' : ''}"><div><b>${e.n} · ${lv}/${max}</b><p>${e.d}</p></div><button class="go" data-eq="${e.id}" ${lv >= max || save.coins < cost ? 'disabled' : ''}>${lv >= max ? '✓' : fmt(cost)}</button></div>`; }).join('')}</div>
    <button class="btn ghost" data-close>Закрыть</button>`, () => {
    ov.querySelectorAll('[data-depth]').forEach(b => b.onclick = () => { const k = +b.dataset.depth, cost = depthCost(ai, k); if (save.coins < cost || k !== (save.depth[ai] || 0) + 1) return;
      save.coins -= cost; save.depth[ai] = k; save.depthSel[ai] = k; persist(); SFX.build(); confetti(); goHome(); openTech(); toast(`${DEPTHS[k].tool}: открыта глубина ${DEPTHS[k].m} м`); });
    ov.querySelectorAll('[data-eq]').forEach(b => b.onclick = () => { const e = EQUIP.find(x => x.id === b.dataset.eq), cost = e.cost[save.eq[e.id]]; if (cost == null || save.coins < cost) return;
      save.coins -= cost; save.eq[e.id]++; persist(); SFX.build(); goHome(); openTech(); toast(`${e.n}: уровень ${save.eq[e.id]}`); });
  });
}
function openTasks(){""")
rep("$('#toColl').onclick = renderColl;", "$('#toColl').onclick = renderColl;\n$('#toTech').onclick = openTech;\n$('#toTech2').onclick = () => { goHome(); openTech(); };")

# ---------------- collection: specimens and the jewellery workshop ----------------
rep("function renderColl(){\n  showScreen('coll'); $('#pills2').innerHTML = pills();",
    "let collTab = 'spc';\nfunction renderColl(){\n  showScreen('coll'); $('#pills2').innerHTML = pills();\n  if (collTab === 'jw') return renderJewels();")
rep("  $('#collWrap').innerHTML = `<h2>Коллекция</h2>\n    <div class=\"h3\">Образцы · ${save.coll.length}</div>",
    "  $('#collWrap').innerHTML = `<h2>Коллекция</h2>${collTabs()}\n    <div class=\"h3\">Образцы · ${save.coll.length}</div>")
rep("<b>${SP[s.sid].n}</b><small>${fmtW(s.g)} · ${mon(s.value)}</small></button>", "<b>${SP[s.sid].n}${cutOK(s) ? ' ✦' : ''}</b><small>${fmtW(s.g)} · ${mon(s.value)}</small></button>")
rep("  $('#collWrap').querySelectorAll('[data-set]').forEach(", "  bindTabs();\n  $('#collWrap').querySelectorAll('[data-set]').forEach(")
rep("function cutPanel(s){", r"""const collTabs = () => `<div class="ctabs"><button type="button" data-ctab="spc" class="${collTab === 'spc' ? 'on' : ''}">Образцы</button><button type="button" data-ctab="jw" class="${collTab === 'jw' ? 'on' : ''}">Украшения · ${save.jewels.length}</button></div>`;
function bindTabs(){ $('#collWrap').querySelectorAll('[data-ctab]').forEach(b => b.onclick = () => { collTab = b.dataset.ctab; renderColl(); }); }
function renderJewels(){
  const cut = save.coll.filter(cutOK).length;
  $('#collWrap').innerHTML = `<h2>Коллекция</h2>${collTabs()}
    <p class="h3" style="text-transform:none;letter-spacing:0">Украшения собираются из огранённых камней коллекции (у вас ${cut}). Мастер берёт самые дешёвые подходящие, ценные остаются в витрине.</p>
    ${save.jewels.length ? `<div class="h3">Ваши украшения</div><div class="list">${save.jewels.map(j => { const R0 = JEWELS.find(x => x.id === j.rid);
      return `<div class="jw own"><span data-jwi="${j.id}"></span><div><b>${R0.n}</b><p>${j.names.join(', ')}</p><p>${mon(j.value)}${R0.perk ? ` · <span class="perk">${R0.perk}</span>` : ''}</p></div><button class="go sell" data-jsell="${j.id}" type="button">Продать</button></div>`; }).join('')}</div>` : ''}
    <div class="h3">Мастерская</div>
    <div class="list">${JEWELS.map(j => { const st = pickFor(j), val = st ? Math.round(st.reduce((a, x) => a + x.value, 0) * j.m) : 0;
      return `<div class="jw"><span data-jwr="${j.id}"></span><div><b>${j.n}</b><p>${j.d}</p>${j.perk ? `<p class="perk">${j.perk}</p>` : ''}${st ? `<p>Из: ${st.map(x => SP[x.sid].n).join(', ')} → ${mon(val)}</p>` : ''}</div><button class="go" data-craft="${j.id}" type="button" ${st ? '' : 'disabled'}>${st ? 'Собрать' : 'Нет камней'}</button></div>`; }).join('')}</div>`;
  bindTabs();
  $('#collWrap').querySelectorAll('[data-jwi]').forEach(el => { const j = save.jewels.find(x => x.id === +el.dataset.jwi); el.appendChild(iconCanvas((x, S) => drawJewel(x, S, j.rid, j.cols))); });
  $('#collWrap').querySelectorAll('[data-jwr]').forEach(el => { const j = JEWELS.find(x => x.id === el.dataset.jwr), st = pickFor(j); el.appendChild(iconCanvas((x, S) => drawJewel(x, S, j.id, st ? st.map(s => hexC(SP[s.sid].c)) : ['#5a6478']))); });
  $('#collWrap').querySelectorAll('[data-craft]').forEach(b => b.onclick = () => { const j = JEWELS.find(x => x.id === b.dataset.craft), st = pickFor(j); if (!st) return;
    const ids = new Set(st.map(x => x.id)); save.coll = save.coll.filter(x => !ids.has(x.id));
    const value = Math.round(st.reduce((a, x) => a + x.value, 0) * j.m);
    save.jewels.push({id:++save.uid, rid:j.id, cols:st.map(x => hexC(SP[x.sid].c)), names:st.map(x => SP[x.sid].n), value}); persist(); SFX.build(); confetti(); renderColl(); toast(`${j.n} готов${j.id === 'ring' || j.id === 'pend' ? '' : j.id === 'ear' ? 'ы' : 'а'}: ${mon(value)}`); });
  $('#collWrap').querySelectorAll('[data-jsell]').forEach(b => b.onclick = () => { const j = save.jewels.find(x => x.id === +b.dataset.jsell); if (!j) return;
    if (b.dataset.armed !== '1') { b.dataset.armed = '1'; b.textContent = `${mon(j.value)}?`; return; }
    save.jewels = save.jewels.filter(x => x !== j); save.coins += Math.round(j.value * coinMul()); persist(); SFX.coin(); renderColl(); });
}
function cutPanel(s){""")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
