"""Самоцветный рудник v2: gas, timber locks, geode blocks, levels 16–30, pre-level boosters, win streak, hints, area chests, a third mine, cutting."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS ----------------
rep("@media (prefers-reduced-motion:reduce)", """.pgoals{display:flex;gap:12px;justify-content:center;flex-wrap:wrap}
.pgoals span{display:flex;align-items:center;gap:4px;font-family:var(--display);font-size:16px}
.pgoals canvas{width:38px;height:38px}
.pre{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;width:100%}
.preb{position:relative;display:flex;flex-direction:column;align-items:center;gap:2px;border-radius:16px;padding:8px 4px 6px;background:#111a29;border:2px solid var(--line);font-size:12px}
.preb canvas{width:46px;height:46px}
.preb small{color:var(--muted);font-size:11px}
.preb.on{border-color:var(--good);background:#13301f}
.preb .tag{position:absolute;top:-9px;right:-4px;font-size:10px;background:var(--gold);color:#3a2200;border-radius:999px;padding:1px 6px}
.streak{width:100%;border-radius:14px;padding:8px 10px;background:linear-gradient(90deg,#3a1d0e,#5a2a10);border:1px solid #c8702a;color:#ffd0a0;font-size:13px}
.streak b{color:#ffe0a0}
.spec-host.cutting canvas{animation:wob .17s ease-in-out infinite}
.cuts{display:flex;flex-direction:column;gap:8px;width:100%}
.cutopt{display:flex;flex-direction:column;gap:3px;text-align:left;background:#111a29;border:1px solid var(--line);border-radius:14px;padding:8px 10px}
.cutopt:disabled{opacity:.45}
.cutopt .h{display:flex;justify-content:space-between;align-items:baseline}
.cutopt .h b{font-family:var(--display);font-size:14px;color:var(--gold)}
.cutopt .h span{font-family:var(--display);font-size:16px}
.cutopt small{color:var(--muted);font-size:12px}
@media (prefers-reduced-motion:reduce)""")

# ---------------- levels 16–30 ----------------
rep("""  {moves:34, vein:true, hard:true, goals:[['nug'], ['rock'], ['mud']], map:'.nn..nn.|........|RRRRRRRR|........|mmmmmmmm|mmmmmmmm|........|RRRRRRRR|........'},
];""", """  {moves:34, vein:true, hard:true, goals:[['nug'], ['rock'], ['mud']], map:'.nn..nn.|........|RRRRRRRR|........|mmmmmmmm|mmmmmmmm|........|RRRRRRRR|........'},
  // g gas that spreads, l timber lock over a stone, G..x a 2×2 geode block
  {moves:22, goals:[['gas']], map:'........|........|........|........|...gg...|...gg...|........|........|........'},
  {moves:22, goals:[['lock']], map:'........|........|.l.ll.l.|........|........|.l.ll.l.|........|........|........'},
  {moves:24, vein:true, goals:[['geo'], ['rock']], map:'........|........|...Gx...|...xx...|........|........|..rrrr..|........|........'},
  {moves:30, goals:[['gas'], ['lock'], ['mud']], map:'gg....gg|g......g|........|..llll..|..llll..|........|........|mmmmmmmm|mmmmmmmm'},
  {moves:34, hard:true, goals:[['nug'], ['geo'], ['gas']], map:'#.nn.n.#|#......#|.Gx..Gx.|.xx..xx.|........|........|........|gggggggg|........'},
  {moves:30, goals:[['lock'], ['mud']], map:'llllllll|........|.mmmmmm.|.mmllmm.|.mmllmm.|.mmmmmm.|........|llllllll|........'},
  {moves:28, vein:true, goals:[['gas'], ['geo']], map:'...gg...|..g..g..|.g.Gx.g.|g..xx..g|.g....g.|..g..g..|...gg...|........|........'},
  {moves:30, goals:[['nug'], ['geo'], ['lock']], map:'n.n..n.n|........|RlRllRlR|........|.Gx..Gx.|.xx..xx.|........|........|........'},
  {moves:26, goals:[['gas'], ['c', 4, 30]], map:'##....##|#......#|........|gg....gg|gg....gg|........|........|#......#|##....##'},
  {moves:32, vein:true, hard:true, goals:[['geo'], ['mud'], ['gas']], map:'.Gx..Gx.|.xx..xx.|........|mmmmmmmm|mllmmllm|mmmmmmmm|........|gg.gg.gg|........'},
  {moves:30, goals:[['geo'], ['rock']], map:'rrrrrrrr|rGxrrGxr|rxxrrxxr|rrrrrrrr|........|........|........|........|........'},
  {moves:32, goals:[['lock'], ['gas']], map:'llllllll|l......l|l.gggg.l|l.g..g.l|l.g..g.l|l.gggg.l|l......l|llllllll|........'},
  {moves:30, vein:true, goals:[['nug'], ['geo'], ['mud']], map:'n......n|........|..Gx....|..xx.Gx.|.....xx.|........|mmmmmmmm|mmmmmmmm|........'},
  {moves:26, goals:[['gas'], ['lock']], map:'###..###|##....##|#......#|gg....gg|ggllllgg|gg....gg|#......#|##....##|###..###'},
  {moves:36, vein:true, hard:true, goals:[['nug'], ['geo'], ['gas']], map:'.nn..nn.|RRRRRRRR|.Gx..Gx.|.xx..xx.|gggggggg|........|llllllll|........|........'},
];""")

# ---------------- a third mine, chests, more sets ----------------
rep("""    tasks:[['rubble', 'Расчистить отвалы', 2], ['timber', 'Укрепить вход', 2], ['rails', 'Пути для вагонеток', 3], ['lamps', 'Электрическое освещение', 3], ['cart', 'Рудная вагонетка', 3], ['headframe', 'Копёр Медной горы', 4]]},
];""", """    tasks:[['rubble', 'Расчистить отвалы', 2], ['timber', 'Укрепить вход', 2], ['rails', 'Пути для вагонеток', 3], ['lamps', 'Электрическое освещение', 3], ['cart', 'Рудная вагонетка', 3], ['headframe', 'Копёр Медной горы', 4]]},
  {n:'Огненный горизонт', sub:'Камчатка, у вулкана', pool:{garnet:16, pyrite:10, gypsum:8, opal:8, quartz:8, gold:4, sapphire:3, ruby:1.5, diamond:.5},
    tasks:[['rubble', 'Убрать застывшую лаву', 3], ['timber', 'Жаропрочная крепь', 3], ['rails', 'Рельсы через пепел', 3], ['lamps', 'Прожекторы', 4], ['cart', 'Вагонетка для рубинов', 4], ['headframe', 'Огненный копёр', 5]]},
];
// a chest for every finished task, like the area chest in Royal Match
const CHEST = [{coins:100}, {pick:1}, {coins:200}, {dyn:1}, {coins:300}, {pre:'bomb'}];
const chestText = c => c.coins ? `${c.coins} монет` : c.pick ? 'кирка' : c.dyn ? 'динамит' : 'заряд перед уровнем';""")
rep("""  {id:'gem', n:'Самоцветы', need:['emerald', 'aquamarine', 'beryl', 'gold'], reward:{coins:2000, pick:2, dyn:2}},
];""", """  {id:'gem', n:'Самоцветы', need:['emerald', 'aquamarine', 'beryl', 'gold'], reward:{coins:2000, pick:2, dyn:2}},
  {id:'fire', n:'Огненное сердце', need:['garnet', 'opal', 'sapphire', 'ruby'], reward:{coins:3000, pick:2, dyn:2}},
  {id:'crown', n:'Корона рудника', need:['diamond', 'ruby', 'sapphire', 'emerald'], reward:{coins:8000, pick:4, dyn:4}},
];
// cutting a kept specimen: a coin gamble on value
const CUTS = [{id:'cab', n:'Кабошон', p:.94, m:1.35, fail:.85, cost:150}, {id:'facet', n:'Фацетная огранка', p:.66, m:2.3, fail:.5, cost:400}, {id:'master', n:'Мастер-огранка', p:.36, m:4.5, fail:.25, cost:1200}];
const CUTN = {cab:'кабошон', facet:'фацетная', master:'мастер-огранка', broken:'треснул на круге'};""")

# ---------------- scene: the volcano mine ----------------
rep("  const has = id => built.includes(id), cu = ai === 1;", "  const has = id => built.includes(id), cu = ai === 1, fire = ai === 2;")
rep("  const hill = cu ? ['#2f5a46', '#1a3328'] : ['#5a4a3e', '#2c241e'], sky = cu ? ['#16303a', '#0e1a22'] : ['#1f2a44', '#101826'];",
    "  const hill = fire ? ['#3a2a2a', '#1a1010'] : cu ? ['#2f5a46', '#1a3328'] : ['#5a4a3e', '#2c241e'], sky = fire ? ['#4a1a12', '#1a0a08'] : cu ? ['#16303a', '#0e1a22'] : ['#1f2a44', '#101826'];")
rep("""  <path d="M0 150 L70 70 L120 100 L180 40 L250 95 L300 65 L360 120 L360 250 L0 250Z" fill="url(#hill)"/>""",
    """  ${fire ? `<path d="M0 160 L60 120 L120 140 L165 46 L195 46 L250 140 L300 110 L360 150 L360 250 L0 250Z" fill="url(#hill)"/><ellipse cx="180" cy="46" rx="18" ry="5" fill="#ff7a2a"/><circle cx="180" cy="40" r="34" fill="url(#glow)" opacity=".7"/>
    <path d="M176 50 Q170 80 182 100 Q190 120 178 140" stroke="#ff6a1a" stroke-width="4" fill="none" opacity=".9"/><path d="M188 52 Q200 76 196 96" stroke="#ffb03a" stroke-width="2.5" fill="none" opacity=".8"/>
    <g fill="#ffb03a" opacity=".6">${[20, 60, 300, 330].map((x, k) => `<circle cx="${x}" cy="${40 + k * 12}" r="1.6"/>`).join('')}</g>` : `<path d="M0 150 L70 70 L120 100 L180 40 L250 95 L300 65 L360 120 L360 250 L0 250Z" fill="url(#hill)"/>`}""")
rep("""<path d="M0 196 Q180 176 360 196 L360 250 L0 250Z" fill="${cu ? '#24402f' : '#3a2e24'}"/>""", """<path d="M0 196 Q180 176 360 196 L360 250 L0 250Z" fill="${fire ? '#2a1a16' : cu ? '#24402f' : '#3a2e24'}"/>""")
rep("""  ${has('rubble') ? '' : `<g fill="#7a6a58" stroke="#3a3028" stroke-width="1.5">""", """  ${has('rubble') ? '' : `<g fill="${fire ? '#3a1a10' : '#7a6a58'}" stroke="${fire ? '#ff6a1a' : '#3a3028'}" stroke-width="1.5">""")

# ---------------- art: gas, timber lock, geode block ----------------
rep("const SPR = {};", r"""function drawGas(x, S){
  x.save(); x.translate(S / 2, S / 2);
  for (const [bx, by, br] of [[-.18, .06, .22], [.16, .07, .22], [0, -.12, .24], [-.05, .17, .2], [.2, -.12, .15], [-.22, -.12, .14]]) {
    const g = x.createRadialGradient(bx * S - br * S * .3, by * S - br * S * .3, 1, bx * S, by * S, br * S); g.addColorStop(0, '#efffb0'); g.addColorStop(.6, '#a2dc3c'); g.addColorStop(1, '#4a7a1a');
    x.fillStyle = g; x.beginPath(); x.arc(bx * S, by * S, br * S, 0, 6.29); x.fill(); }
  x.fillStyle = 'rgba(255,255,255,.65)'; x.beginPath(); x.arc(-S * .1, -S * .16, S * .045, 0, 6.29); x.fill(); x.beginPath(); x.arc(S * .14, S * .02, S * .03, 0, 6.29); x.fill();
  x.restore();
}
function drawLock(x, S){
  x.save(); const p = S * .1, w = S - p * 2;
  x.strokeStyle = '#3a2410'; x.lineWidth = S * .14; x.strokeRect(p, p, w, w);
  x.strokeStyle = '#b07a3e'; x.lineWidth = S * .09; x.strokeRect(p, p, w, w);
  x.strokeStyle = '#8a5a2c'; x.lineWidth = S * .08; x.beginPath(); x.moveTo(p + S * .04, p + S * .04); x.lineTo(S - p - S * .04, S - p - S * .04); x.stroke();
  x.fillStyle = '#d8dce4'; for (const [a, b] of [[p, p], [S - p, p], [p, S - p], [S - p, S - p]]) { x.beginPath(); x.arc(a, b, S * .045, 0, 6.29); x.fill(); }
  x.restore();
}
const NOD = new Image(); NOD.src = 'img/nodule.webp';
function drawGeodeIcon(x, S){ if (NOD.complete && NOD.naturalWidth) x.drawImage(NOD, S * .06, S * .06, S * .88, S * .88); else { x.fillStyle = '#7a6a58'; x.beginPath(); x.arc(S / 2, S / 2, S * .38, 0, 6.29); x.fill(); } }
const SPR = {};""")
rep("const mudSpr = S => sprite('mud', S, drawMud);", "const mudSpr = S => sprite('mud', S, drawMud);\nconst gasSpr = S => sprite('gas', S, drawGas);\nconst lockSpr = S => sprite('lock', S, drawLock);")

# ---------------- board state ----------------
rep("let G, ROCK, MUD, VOID, uid = 1;", "let G, ROCK, MUD, VOID, GAS, LOCK, GEOC, uid = 1;")
rep("const open = (r, c) => playable(r, c) && !ROCK[r][c];", "const open = (r, c) => playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0;")
rep("function startLevel(n){\n  const def = levelDef(n);\n  L = {n, moves:def.moves, vein:!!def.vein, hard:!!def.hard, colors:5, goals:[], over:false, coinsWon:0};",
    "function startLevel(n, pre = []){\n  const def = levelDef(n);\n  L = {n, moves:def.moves, vein:!!def.vein, hard:!!def.hard, colors:5, goals:[], over:false, coinsWon:0, bonus:[], geos:[], idle:now(), hint:null, gasHit:false};")
rep("VOID = Array.from({length:R}, () => Array(C).fill(false));", "VOID = Array.from({length:R}, () => Array(C).fill(false));\n  GAS = Array.from({length:R}, () => Array(C).fill(0)); LOCK = Array.from({length:R}, () => Array(C).fill(0)); GEOC = Array.from({length:R}, () => Array(C).fill(-1));")
rep("  let rocks = 0, muds = 0, nugs = 0;", "  let rocks = 0, muds = 0, nugs = 0, gas = 0, locks = 0;")
rep("    else if (ch === 'n') { const g = newGem(r, c, -1); g.item = 'nug'; G[r][c] = g; nugs++; }",
    "    else if (ch === 'n') { const g = newGem(r, c, -1); g.item = 'nug'; G[r][c] = g; nugs++; }\n"
    "    else if (ch === 'g') { GAS[r][c] = 1; gas++; }\n"
    "    else if (ch === 'l') { LOCK[r][c] = 1; locks++; }\n"
    "    else if (ch === 'G') { const gi = L.geos.length; L.geos.push({r, c, hp:4, hitAt:0}); for (const [dr, dc] of [[0, 0], [0, 1], [1, 0], [1, 1]]) GEOC[r + dr][c + dc] = gi; }")
rep("    else if (gdef[0] === 'nug') L.goals.push({k:'nug', left:nugs, shown:nugs});",
    "    else if (gdef[0] === 'nug') L.goals.push({k:'nug', left:nugs, shown:nugs});\n"
    "    else if (gdef[0] === 'gas') L.goals.push({k:'gas', left:gas, shown:gas});\n"
    "    else if (gdef[0] === 'lock') L.goals.push({k:'lock', left:locks, shown:locks});\n"
    "    else if (gdef[0] === 'geo') L.goals.push({k:'geo', left:L.geos.length, shown:L.geos.length});")
rep("  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) { const g = G[r][c]; if (g) { g.y = r - R - 1 - Math.random() * 2; } }",
    "  // boosters chosen before the level land on the board as ready specials\n"
    "  { const cand = []; for (let r = 1; r < R - 1; r++) for (let c = 0; c < C; c++) { const g = G[r][c]; if (g && g.t >= 0 && !LOCK[r][c]) cand.push(g); }\n"
    "    for (const sp of pre) { if (!cand.length) break; const g = cand.splice(ri(0, cand.length - 1), 1)[0]; g.sp = sp; g.t = -1; } }\n"
    "  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) { const g = G[r][c]; if (g) { g.y = r - R - 1 - Math.random() * 2; } }")

# ---------------- hits on the new blockers ----------------
rep("  B = {t0:now(), cleared:new Set(), rockHit:new Set(), maxT:0, q:[...events], cascade:B ? B.cascade : 0};",
    "  B = {t0:now(), cleared:new Set(), rockHit:new Set(), geoHit:new Set(), maxT:0, q:[...events], cascade:B ? B.cascade : 0};")
rep("  const g = G[r][c]; if (!g || g.item || B.cleared.has(k)) return;\n  B.cleared.add(k); g.dyingAt = B.t0 + t;",
    r"""  if (GAS[r][c]) { // gas pops with one hit
    if (kind === 'adj' && B.rockHit.has(k)) return; B.rockHit.add(k);
    GAS[r][c] = 0; L.gasHit = true; goalHit('gas', null, r, c, t); later(t, () => { SFX.rock(); debris(r, c, '#a2dc3c', 12); }); return; }
  if (GEOC[r][c] >= 0) { // a geode block takes one hit per blast, four in all
    const gi = GEOC[r][c], geo = L.geos[gi]; if (B.geoHit.has(gi) || geo.hp <= 0) return; B.geoHit.add(gi); geo.hp--;
    later(t, () => { SFX.crack(4 - geo.hp); geo.hitAt = now(); debris(geo.r + .5, geo.c + .5, '#9a8a78', 12); });
    if (geo.hp <= 0) { for (const [dr, dc] of [[0, 0], [0, 1], [1, 0], [1, 1]]) GEOC[geo.r + dr][geo.c + dc] = -1; goalHit('geo', null, geo.r, geo.c, t);
      L.bonus.push(rollStone(++save.uid, save.area, .5)); later(t, () => { const [x, y] = cellScreen(geo.r + .5, geo.c + .5); sparkle(x, y, '#d8b8ff', 26); SFX.reveal(1); toast('Жеода расколота: камень ждёт вас в конце уровня'); }); }
    return; }
  if (LOCK[r][c]) { // the timber breaks, the stone under it stays
    if (kind === 'adj') return; LOCK[r][c] = 0; goalHit('lock', null, r, c, t); later(t, () => { SFX.rock(); debris(r, c, '#b07a3e', 10); }); B.cleared.add(k); return; }
  const g = G[r][c]; if (!g || g.item || B.cleared.has(k)) return;
  B.cleared.add(k); g.dyingAt = B.t0 + t;""")
rep("if (playable(rr, cc) && ROCK[rr][cc]) hit(rr, cc, t, 'adj');", "if (playable(rr, cc) && (ROCK[rr][cc] || GAS[rr][cc] || GEOC[rr][cc] >= 0)) hit(rr, cc, t, 'adj');")
rep("    let w = 0; if (ROCK[rr][cc] && need.has('rock')) w = 6;",
    "    let w = 0; if (GAS[rr][cc] && need.has('gas')) w = 6; else if (GEOC[rr][cc] >= 0 && need.has('geo')) w = 6; else if (LOCK[rr][cc] && need.has('lock')) w = 5; else if (ROCK[rr][cc] && need.has('rock')) w = 6;")
rep("  const fly = () => flyTo(r, c, gi, k === 'c' ? gemSpr(t, 64) : k === 'rock' ? rockSpr(1, 64) : k === 'mud' ? mudSpr(64) : nugSpr(64));",
    "  const fly = () => flyTo(r, c, gi, k === 'c' ? gemSpr(t, 64) : k === 'rock' ? rockSpr(1, 64) : k === 'mud' ? mudSpr(64) : k === 'gas' ? gasSpr(64) : k === 'lock' ? lockSpr(64) : k === 'geo' ? sprite('geoic', 64, drawGeodeIcon) : nugSpr(64));")
rep("    const ic = iconCanvas((x, S) => { if (g.k === 'c') drawGem(x, g.t, S); else if (g.k === 'rock') drawRock(x, 1, S); else if (g.k === 'mud') drawMud(x, S); else drawNugget(x, S); });",
    "    const ic = goalIcon(g);")
rep("function renderGoal(i){", "function goalIcon(g){ return iconCanvas((x, S) => { if (g.k === 'c') drawGem(x, g.t, S); else if (g.k === 'rock') drawRock(x, 1, S); else if (g.k === 'mud') drawMud(x, S); else if (g.k === 'gas') drawGas(x, S); else if (g.k === 'lock') { drawGem(x, 2, S); drawLock(x, S); } else if (g.k === 'geo') drawGeodeIcon(x, S); else drawNugget(x, S); }); }\nfunction renderGoal(i){")

# ---------------- moving around locks ----------------
rep("  const tryswap = (r1, c1, r2, c2) => { if (!open(r2, c2) || !G[r1][c1] || !G[r2][c2]) return false;", "  const tryswap = (r1, c1, r2, c2) => { if (!open(r2, c2) || !G[r1][c1] || !G[r2][c2] || LOCK[r1][c1] || LOCK[r2][c2]) return false;")
rep("      if (r > 0 && open(r - 1, c) && G[r - 1][c]) { G[r][c] = G[r - 1][c]; G[r - 1][c] = null; moved = true; continue; }",
    "      if (r > 0 && open(r - 1, c) && G[r - 1][c] && !LOCK[r - 1][c]) { G[r][c] = G[r - 1][c]; G[r - 1][c] = null; moved = true; continue; }")
rep("      const fromAbove = r > 0 && open(r - 1, c);", "      const fromAbove = r > 0 && open(r - 1, c) && !LOCK[r - 1][c];")
rep("if (sr >= 0 && open(sr, sc) && G[sr][sc] && !(open(r, sc) && !G[r][sc]))", "if (sr >= 0 && open(sr, sc) && G[sr][sc] && !LOCK[sr][sc] && !(open(r, sc) && !G[r][sc]))")
rep("const g = G[r][c]; if (g && !g.sp && !g.item) { cells.push([r, c]); gems.push(g); } }", "const g = G[r][c]; if (g && !g.sp && !g.item && !LOCK[r][c]) { cells.push([r, c]); gems.push(g); } }")
rep("  const a = G[r1][c1], b = G[r2][c2]; if (!a || !b) return;\n  busy = true; SFX.swap();",
    "  const a = G[r1][c1], b = G[r2][c2]; if (!a || !b) return;\n  if (LOCK[r1][c1] || LOCK[r2][c2]) { SFX.bad(); return; }\n  busy = true; SFX.swap(); L.idle = now(); L.hint = null;")
rep("function useMove(){ L.moves--; renderMoves(); }", "function useMove(){ L.moves--; L.gasHit = false; renderMoves(); }")

# ---------------- turn end: gas spreads if you ignored it ----------------
rep("""async function afterTurn(){
  await flightsDone();
  if (goalsDone()) { L.over = true; await finale(); return win(); }
  if (L.moves <= 0) { L.over = true; await wait(300); return outOfMoves(); }
  busy = false;
}""", """async function afterTurn(){
  await flightsDone();
  if (goalsDone()) { L.over = true; await finale(); return win(); }
  await gasSpread();
  if (L.moves <= 0) { L.over = true; await wait(300); return outOfMoves(); }
  busy = false; L.idle = now(); L.hint = null;
}
async function gasSpread(){
  if (L.gasHit) { L.gasHit = false; return; }
  const cand = [];
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (GAS[r][c]) for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const rr = r + dr, cc = c + dc; const g = playable(rr, cc) && G[rr][cc]; if (g && g.t >= 0 && !g.sp && !g.item && !LOCK[rr][cc]) cand.push([rr, cc]); }
  if (!cand.length) return;
  const [r, c] = cand[ri(0, cand.length - 1)]; G[r][c] = null; GAS[r][c] = 1;
  const gi = L.goals.findIndex(g => g.k === 'gas'); if (gi >= 0) { L.goals[gi].left++; L.goals[gi].shown++; renderGoal(gi); }
  const [x, y] = cellScreen(r, c); sparkle(x, y, '#c8f070', 14); noise(.5, 500, .15, 'bandpass'); toast('Газ расползается — задевайте его каждый ход');
  await wait(260);
}""")

# ---------------- hints after a pause ----------------
rep("function hasMoves(){", r"""function findMove(){
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) { const g = G[r][c]; if (g && g.sp) return [r, c, r, c]; }
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) for (const [dr, dc] of [[0, 1], [1, 0]]) { const r2 = r + dr, c2 = c + dc;
    if (!open(r, c) || !open(r2, c2) || !G[r][c] || !G[r2][c2] || LOCK[r][c] || LOCK[r2][c2]) continue;
    const a = G[r][c]; G[r][c] = G[r2][c2]; G[r2][c2] = a; const ok = findGroups().length > 0; G[r2][c2] = G[r][c]; G[r][c] = a; if (ok) return [r, c, r2, c2]; }
  return null;
}
function hasMoves(){""")
rep("  if (L && !$('#game').hidden) drawBoard(t);", "  if (L && !$('#game').hidden) { if (!busy && !L.over && !booster && !L.hint && t - L.idle > 5000) L.hint = findMove(); drawBoard(t); }")
rep("  if (g.convertAt && t >= g.convertAt && !g.sp) { s *= 1 + Math.sin((t - g.convertAt) / 40) * .1; }",
    "  if (g.convertAt && t >= g.convertAt && !g.sp) { s *= 1 + Math.sin((t - g.convertAt) / 40) * .1; }\n"
    "  const h = L.hint; if (h && !busy && ((g.y === h[0] && g.x === h[1]) || (g.y === h[2] && g.x === h[3]))) { s *= 1 + Math.max(0, Math.sin((t - L.idle) / 140)) * .12; }")
rep("board.addEventListener('pointerdown', e => {\n  if (busy || !L || L.over) return; ac();", "board.addEventListener('pointerdown', e => {\n  if (busy || !L || L.over) return; ac(); L.idle = now(); L.hint = null;")

# ---------------- drawing the new blockers ----------------
rep("  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c) && ROCK[r][c]) x.drawImage(rockSpr(ROCK[r][c], S * 2), PAD + c * S, PAD + r * S, S, S);",
    r"""  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c) && ROCK[r][c]) x.drawImage(rockSpr(ROCK[r][c], S * 2), PAD + c * S, PAD + r * S, S, S);
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c) && GAS[r][c]) { const w = S * (1 + Math.sin(t / 400 + r + c) * .04); x.drawImage(gasSpr(S * 2), PAD + (c + .5) * S - w / 2, PAD + (r + .5) * S - w / 2, w, w); }
  for (const geo of L.geos) if (geo.hp > 0) { const px = PAD + geo.c * S, py = PAD + geo.r * S, sh = now() - geo.hitAt < 220 ? Math.sin((now() - geo.hitAt) / 18) * 3 : 0;
    x.save(); x.translate(px + S + sh, py + S);
    const gl = x.createRadialGradient(0, 0, S * .3, 0, 0, S * 1.1); gl.addColorStop(0, `rgba(200,150,255,${.15 + (4 - geo.hp) * .08})`); gl.addColorStop(1, 'rgba(200,150,255,0)'); x.fillStyle = gl; x.fillRect(-S, -S, S * 2, S * 2);
    if (NOD.complete && NOD.naturalWidth) x.drawImage(NOD, -S * .95, -S * .95, S * 1.9, S * 1.9);
    if (geo.hp < 4) { x.strokeStyle = '#ffe6a8'; x.lineWidth = 2.2; x.shadowColor = '#d0a0ff'; x.shadowBlur = 8; x.save(); x.translate(-S * .84, -S * .84); x.scale(S * 1.68 / 100, S * 1.68 / 100);
      for (const d of crackPaths(geo.r * 31 + geo.c, (4 - geo.hp) * 2)) x.stroke(new Path2D(d)); x.restore(); x.shadowBlur = 0; }
    x.restore(); }""")
rep("  x.restore();\n  // rockets, drills, lightning, shockwaves", "  x.restore();\n  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c) && LOCK[r][c]) x.drawImage(lockSpr(S * 2), PAD + c * S, PAD + r * S, S, S);\n  // rockets, drills, lightning, shockwaves")
# a flash when a special is born
rep("    for (const s of created) { const g = newGem(s.r, s.c, -1); g.sp = s.sp; g.s = .2; G[s.r][s.c] = g; tween(g, {s:1}, 260, 'back'); }",
    "    for (const s of created) { const g = newGem(s.r, s.c, -1); g.sp = s.sp; g.s = .2; G[s.r][s.c] = g; tween(g, {s:1}, 260, 'back'); rings.push({r:s.r, c:s.c, rad:.3, t0:now()}); }")

# ---------------- pre-level panel, streak, bonus stones, confetti ----------------
rep("const BLANK = () => ({level:1, coins:400, stars:0, lives:5, lifeAt:0, area:0, built:[[], []], boost:{pick:2, dyn:2}, coll:[], sets:[], uid:1000, up:{lab:0}, mute:false});",
    "const BLANK = () => ({level:1, coins:400, stars:0, lives:5, lifeAt:0, area:0, built:[[], [], []], boost:{pick:2, dyn:2}, pre:{rocket:1, bomb:1, orb:0}, streak:0, coll:[], sets:[], uid:1000, up:{lab:0}, mute:false});")
rep("let save = (() => { try { const s = JSON.parse(localStorage.getItem('samocvet-v1') || 'null'); return s ? Object.assign(BLANK(), s) : BLANK(); } catch (e) { return BLANK(); } })();",
    "let save = (() => { try { const s = JSON.parse(localStorage.getItem('samocvet-v1') || 'null'); if (!s) return BLANK(); const b = BLANK(); const o = Object.assign(b, s); o.pre = Object.assign(BLANK().pre, s.pre); while (o.built.length < 3) o.built.push([]); return o; } catch (e) { return BLANK(); } })();")
rep("function win(){\n  SFX.win(); buzz([60, 40, 120]);\n  const coins = 20 + L.coinsWon; save.coins += coins; save.stars += 1; save.level = Math.max(save.level, L.n + 1); persist();",
    "function win(){\n  SFX.win(); buzz([60, 40, 120]); confetti();\n  const coins = 20 + L.coinsWon; save.coins += coins; save.stars += 1; save.level = Math.max(save.level, L.n + 1); save.streak++; persist();")
rep("    <p>Звёзды тратятся на обустройство рудника.</p><button class=\"btn green\" id=\"next\">Дальше</button>`",
    "    ${save.streak >= 2 ? `<div class=\"streak\">Серия побед: <b>${save.streak}</b>. ${streakText()}</div>` : '<p>Звёзды тратятся на обустройство рудника.</p>'}<button class=\"btn green\" id=\"next\">Дальше</button>`")
rep("  if (L.vein) stoneChoice(after); else after();", "  const bonus = () => bonusFlow(after);\n  if (L.vein) stoneChoice(bonus); else bonus();")
rep("function stoneChoice(done){", r"""function bonusFlow(done){
  const s = L.bonus.shift(); if (!s) return done();
  openStone([s], 0, () => bonusFlow(done), 'Камень из жеоды на поле');
}
function confetti(){ const cols = GEMS.map(g => g.c).concat(['#ffd27a', '#ffffff']); for (let k = 0; k < 140; k++) parts.push({x:rnd(0, innerWidth), y:rnd(-80, -10), vx:rnd(-1.5, 1.5), vy:rnd(1, 4), g:.06, life:0, max:rnd(90, 150), s:rnd(4, 8), c:cols[k % cols.length], sq:true}); }
const PRE = [{id:'rocket', n:'Динамит', d:'2 шашки', price:300, sp:['rh', 'rv']}, {id:'bomb', n:'Заряд', d:'связка', price:400, sp:['bomb']}, {id:'orb', n:'Резонатор', d:'жеода', price:600, sp:['orb']}];
const streakFree = () => [save.streak >= 2 && 'rocket', save.streak >= 4 && 'bomb', save.streak >= 6 && 'orb'].filter(Boolean);
const streakText = () => { const f = streakFree(); return f.length ? `Бесплатно на старте: ${f.map(id => PRE.find(p => p.id === id).n.toLowerCase()).join(', ')}.` : 'Ещё победа — и динамит на старте бесплатно.'; };
function levelPanel(){
  const n = save.level, def = levelDef(n), free = streakFree(), sel = new Set(free);
  // what the level asks for, read from its map
  const cnt = ch => (def.map || '').split('').filter(x => x === ch).length;
  const gl = def.goals.map(g => g[0] === 'c' ? {k:'c', t:g[1], n:g[2]} : g[0] === 'rock' ? {k:'rock', n:cnt('r') + cnt('R') * 2} : g[0] === 'mud' ? {k:'mud', n:cnt('m')} : g[0] === 'nug' ? {k:'nug', n:cnt('n')} : g[0] === 'gas' ? {k:'gas', n:cnt('g')} : g[0] === 'lock' ? {k:'lock', n:cnt('l')} : {k:'geo', n:cnt('G')});
  const draw = () => {
    openOv(`<h2>Уровень ${n}</h2><p>${def.moves} ходов${def.hard ? ' · сложный' : ''}${def.vein ? ' · жила: в конце выбор камня' : ''}</p>
      <div class="pgoals" id="pg"></div>
      ${save.streak >= 2 ? `<div class="streak">Серия побед: <b>${save.streak}</b>. ${streakText()}</div>` : ''}
      <div class="pre">${PRE.map(p => { const fr = free.includes(p.id), have = save.pre[p.id];
        return `<button class="preb${sel.has(p.id) ? ' on' : ''}" data-pre="${p.id}" type="button"><span id="pi-${p.id}"></span><b>${p.n}</b><small>${fr ? 'бесплатно' : have ? `есть ${have}` : `${p.price} монет`}</small>${fr ? '<span class="tag">серия</span>' : ''}</button>`; }).join('')}</div>
      <button class="btn green" id="goLvl">Играть</button><button class="btn ghost" data-close>Назад</button>`, () => {
      const pg = $('#pg'); gl.forEach(g => { const sp = document.createElement('span'); sp.appendChild(goalIcon(g)); sp.append(String(g.n)); pg.appendChild(sp); });
      PRE.forEach(p => $('#pi-' + p.id).appendChild(iconCanvas((x, S) => drawSpecial(x, p.sp[0], S))));
      ov.querySelectorAll('[data-pre]').forEach(b => b.onclick = () => { const id = b.dataset.pre, p = PRE.find(x => x.id === id);
        if (free.includes(id)) return;
        if (sel.has(id)) sel.delete(id); else if (save.pre[id]) sel.add(id); else if (save.coins >= p.price) { save.coins -= p.price; save.pre[id]++; persist(); SFX.coin(); sel.add(id); } else return toast('Не хватает монет');
        draw(); });
      $('#goLvl').onclick = () => { const sps = []; for (const id of sel) { const p = PRE.find(x => x.id === id); if (!free.includes(id)) save.pre[id]--; sps.push(...p.sp); } persist(); closeOv(); startLevel(n, sps); };
    });
  };
  draw();
}
function stoneChoice(done){""")
rep("function openStone(stones, idx, done){\n  const s = stones[idx]; let hits = 0;\n  openOv(`<h2>Расколите камень</h2>",
    "function openStone(stones, idx, done, title = 'Расколите камень'){\n  const s = stones[idx]; let hits = 0;\n  openOv(`<h2>${title}</h2>")
rep("    <div class=\"missed\">Остальные были: ${others.map(o => `<span style=\"color:${RC[o.tier]}\">${SP[o.sid].n}</span>`).join('')}</div>",
    "    ${others.length ? `<div class=\"missed\">Остальные были: ${others.map(o => `<span style=\"color:${RC[o.tier]}\">${SP[o.sid].n}</span>`).join('')}</div>` : ''}")
# losing breaks the streak
rep("    $('#giveup').onclick = () => { tickLives(); save.lives = Math.max(0, save.lives - 1);", "    $('#giveup').onclick = () => { tickLives(); save.streak = 0; save.lives = Math.max(0, save.lives - 1);")
rep("$('#leave').onclick = () => { tickLives(); save.lives = Math.max(0, save.lives - 1);", "$('#leave').onclick = () => { tickLives(); save.streak = 0; save.lives = Math.max(0, save.lives - 1);")
rep("  startLevel(save.level); };", "  levelPanel(); };")
rep("  $('#playBtn').innerHTML = `Уровень ${save.level}<small>${def.moves} ходов${def.hard ? ' · сложный' : ''}</small>${def.vein ? '<span class=\"vein\">жила · выбор камня</span>' : ''}`;",
    "  $('#playBtn').innerHTML = `Уровень ${save.level}<small>${def.moves} ходов${def.hard ? ' · сложный' : ''}${save.streak >= 2 ? ` · серия ${save.streak}` : ''}</small>${def.vein ? '<span class=\"vein\">жила · выбор камня</span>' : ''}`;")

# ---------------- area chest per task ----------------
rep("save.stars -= t[2]; built.push(t[0]); persist(); SFX.build(); closeOv(); goHome();",
    "save.stars -= t[2]; built.push(t[0]); const ch = CHEST[A.tasks.indexOf(t)] || {coins:100}; if (ch.coins) save.coins += ch.coins; if (ch.pick) save.boost.pick += ch.pick; if (ch.dyn) save.boost.dyn += ch.dyn; if (ch.pre) save.pre[ch.pre]++; persist(); SFX.build(); closeOv(); goHome(); setTimeout(() => toast(`Сундук рудника: ${chestText(ch)}`), 500);")
rep("    <div class=\"list\">${A.tasks.map(([id, n, cost]) => { const has = built.includes(id); return `<div class=\"task${has ? ' done' : ''}\"><div><b>${n}</b><p>${has ? 'Готово' : `Стоимость: ★ ${cost}`}</p></div>",
    "    <div class=\"list\">${A.tasks.map(([id, n, cost], i) => { const has = built.includes(id); return `<div class=\"task${has ? ' done' : ''}\"><div><b>${n}</b><p>${has ? 'Готово' : `★ ${cost} · в сундуке: ${chestText(CHEST[i] || {coins:100})}`}</p></div>")

# ---------------- cutting in the collection ----------------
rep("""      <button class="btn" id="sellC">Продать · ${fmt(s.value)} монет</button><button class="btn ghost" id="closeC">Закрыть</button>`, () => {
      specMount($('#specHost'), {seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, legend:s.legend});""",
"""      ${s.cut ? `<p>Огранка: ${CUTN[s.cut]}</p>` : '<button class="btn" style="background:linear-gradient(#d2b0ff,#8a4ff0);color:#1a0b33;box-shadow:0 5px 0 #3e1f78" id="cutC">Огранить<small>рискнуть ради цены</small></button>'}
      <button class="btn" id="sellC">Продать · ${fmt(s.value)} монет</button><button class="btn ghost" id="closeC">Закрыть</button>`, () => {
      specMount($('#specHost'), {seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, legend:s.legend, cut:s.cut});
      const cb = $('#cutC'); if (cb) cb.onclick = () => cutPanel(s);""")
rep("function renderColl(){", r"""function cutPanel(s){
  specUnmount();
  const chance = c => Math.min(.98, c.p + s.gi * .025);
  openOv(`<h2>Огранка</h2><p>${SP[s.sid].n} · сейчас ${fmt(s.value)} монет</p><div class="cuts">${CUTS.map((c, i) => `<button class="cutopt" data-cut="${i}" type="button" ${save.coins < c.cost ? 'disabled' : ''}><div class="h"><b>${c.n}</b><span>${Math.round(chance(c) * 100)}%</span></div>
    <small>удача: ${fmt(s.value * c.m)} · провал: ${fmt(s.value * c.fail)} · работа ${c.cost} монет</small></button>`).join('')}</div><button class="btn ghost" data-close>Не рисковать</button>`, () => {
    ov.querySelectorAll('[data-cut]').forEach(b => b.onclick = async () => { const c = CUTS[+b.dataset.cut]; if (save.coins < c.cost) return; save.coins -= c.cost; persist();
      const win = Math.random() < chance(c);
      openOv(`<div class="reveal"><div class="spec-host cutting" id="specHost"></div></div><h2>${c.n}…</h2>`, () => specMount($('#specHost'), {seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, legend:s.legend}));
      for (let k = 0; k < 10; k++) { await wait(160); noise(.15, 3000, .15, 'bandpass'); const h = $('#specHost'); if (h) { const r = h.getBoundingClientRect(); sparkle(r.left + r.width / 2, r.top + r.height * .6, '#fff2c0', 6); } }
      s.cut = win ? c.id : 'broken'; s.value = Math.round(s.value * (win ? c.m : c.fail)); persist(); specUnmount();
      if (win) { SFX.reveal(Math.min(4, s.tier + 1)); confetti(); } else SFX.lose();
      openOv(`<div class="reveal"><div class="spec-host" id="specHost"></div></div><h2>${win ? 'Огранка удалась!' : 'Камень треснул'}</h2><p>Теперь он стоит ${fmt(s.value)} монет.</p><button class="btn green" id="okC">Отлично</button>`, () => {
        specMount($('#specHost'), {seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, legend:s.legend, cut:s.cut}); $('#okC').onclick = () => { specUnmount(); closeOv(); renderColl(); }; });
    });
  });
}
function renderColl(){""")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
