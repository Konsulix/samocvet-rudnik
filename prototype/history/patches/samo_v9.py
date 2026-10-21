"""Самоцветный рудник v9: the find is the level. Every board hides a specimen in the rock; dig it out gently (matches, pickaxe) or fast (blasts chip it)."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- grid ----------------
rep("let G, ROCK, MUD, VOID, GAS, LOCK, GEOC, uid = 1;", "let G, ROCK, MUD, VOID, GAS, LOCK, GEOC, FIND, uid = 1;")
rep("const open = (r, c) => playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0;", "const open = (r, c) => playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0 && !FIND[r][c];")
rep("GEOC = Array.from({length:R}, () => Array(C).fill(-1));", "GEOC = Array.from({length:R}, () => Array(C).fill(-1)); FIND = Array.from({length:R}, () => Array(C).fill(false));")
rep("if (playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0 && !G[r][c] && !LOCK[r][c] && !MUD[r][c]) a.push([r, c]); return a; };",
    "if (playable(r, c) && !ROCK[r][c] && !GAS[r][c] && GEOC[r][c] < 0 && !FIND[r][c] && !G[r][c] && !LOCK[r][c] && !MUD[r][c]) a.push([r, c]); return a; };")

# ---------------- bury the specimen at level start (before depth mutations so they avoid it) ----------------
rep("  // the deeper you dig, the harder the board\n", r"""  // the find: a specimen sealed in a 2x2 block of rock, somewhere in the lower half
  { const ok = (r, c) => [[0, 0], [0, 1], [1, 0], [1, 1]].every(([dr, dc]) => { const rr = r + dr, cc = c + dc; return playable(rr, cc) && !ROCK[rr][cc] && !GAS[rr][cc] && GEOC[rr][cc] < 0 && !LOCK[rr][cc] && !MUD[rr][cc] && !G[rr][cc]; });
    const spots = []; for (let r = 3; r < R - 2; r++) for (let c = 1; c < C - 2; c++) if (ok(r, c)) spots.push([r, c, Math.abs(r - 5.5) + Math.abs(c + .5 - C / 2) * .7]);
    spots.sort((a, b) => a[2] - b[2]);
    if (spots.length) { const [r, c] = spots[ri(0, Math.min(5, spots.length - 1))], hp = Math.min(9, 4 + Math.floor(n / 6) + dl);
      const stone = rollStone(++save.uid, save.area, (def.hard ? .6 : .2) + dl * .35, dl); persist();
      L.find = {r, c, hp, hpMax:hp, integ:100, stone, done:false, hitAt:0, img:null};
      for (const [dr, dc] of [[0, 0], [0, 1], [1, 0], [1, 1]]) FIND[r + dr][c + dc] = true;
      const url = specThumb({seed:stone.id, sid:stone.sid, kind:stone.kind, gi:stone.gi, traits:stone.traits, legend:stone.legend}); if (url) { const im = new Image(); im.src = url; L.find.img = im; } } }
  // the deeper you dig, the harder the board
""")
rep("  for (const gdef of def.goals) {\n    if (gdef[0] === 'c')", "  if (L.find) L.goals.push({k:'find', left:1, shown:1});\n  for (const gdef of def.goals) {\n    if (gdef[0] === 'c')")

# ---------------- hits ----------------
rep("""  if (LOCK[r][c]) { // the timber breaks, the stone under it stays""", r"""  if (FIND[r][c]) { // the find: careful work peels the rock, blasts chip the stone itself
    const F = L.find; if (!F || F.done || B.findHit) return; B.findHit = true; F.hp--;
    const rough = kind !== 'adj' && kind !== 'pick'; if (rough) F.integ = Math.max(10, F.integ - Math.round(12 * (1 - save.eq.lift * .25)));
    later(t, () => { if (!L) return; F.hitAt = now(); rough ? SFX.crack(3) : SFX.rock(); debris(F.r + .5, F.c + .5, rough ? '#ffb090' : '#9a8a78', rough ? 16 : 9); renderGoal(L.goals.findIndex(g => g.k === 'find'));
      if (rough) { const [x, y] = cellScreen(F.r + .5, F.c + .5); popText(x, y, `скол −${Math.round(12 * (1 - save.eq.lift * .25))}%`); } });
    if (F.hp <= 0) { F.done = true; for (const [dr, dc] of [[0, 0], [0, 1], [1, 0], [1, 1]]) FIND[F.r + dr][F.c + dc] = false; goalHit('find', null, F.r, F.c, t);
      later(t, () => { const [x, y] = cellScreen(F.r + .5, F.c + .5); sparkle(x, y, RC[F.stone.tier], 40); SFX.reveal(F.stone.tier); toast(`Образец извлечён · целостность ${F.integ}%`); }); }
    return; }
  if (LOCK[r][c]) { // the timber breaks, the stone under it stays""")
rep("if (playable(rr, cc) && (ROCK[rr][cc] || GAS[rr][cc] || GEOC[rr][cc] >= 0)) hit(rr, cc, t, 'adj'); }",
    "if (playable(rr, cc) && (ROCK[rr][cc] || GAS[rr][cc] || GEOC[rr][cc] >= 0 || FIND[rr][cc])) hit(rr, cc, t, 'adj'); }")
rep("B = {t0:now(), cleared:new Set(), rockHit:new Set(), geoHit:new Set(), maxT:0,", "B = {t0:now(), cleared:new Set(), rockHit:new Set(), geoHit:new Set(), findHit:false, maxT:0,")
rep("  if (id === 'pick') await resolve([{r, c, t:0, kind:'fx'}]);", "  if (id === 'pick') await resolve([{r, c, t:0, kind:'pick'}]);")
# hints steer towards the find
rep("let w = 0; if (GAS[rr][cc] && need.has('gas')) w = 6;", "let w = 0; if (FIND[rr][cc] && need.has('find')) w = 7; else if (GAS[rr][cc] && need.has('gas')) w = 6;")

# a little floating text for chips
rep("function confetti(){", r"""function popText(x, y, txt){ const el = document.createElement('div'); el.textContent = txt; el.style.cssText = `position:fixed;left:${x}px;top:${y}px;transform:translate(-50%,-50%);z-index:40;pointer-events:none;font:800 14px var(--body);color:#ffb090;text-shadow:0 2px 4px #000;transition:transform .9s ease-out, opacity .9s`; document.body.appendChild(el);
  requestAnimationFrame(() => { el.style.transform = 'translate(-50%,-160%)'; el.style.opacity = '0'; }); setTimeout(() => el.remove(), 950); }
function confetti(){""")

# ---------------- goals: icon and integrity readout ----------------
rep("function renderGoal(i){ const g = L.goals[i], el = goalEls[i]; if (!el) return; el.querySelector('b').textContent = g.shown > 0 ? g.shown : '✓'; el.classList.toggle('done', g.shown <= 0); }",
    "function renderGoal(i){ const g = L.goals[i], el = goalEls[i]; if (!el) return; el.querySelector('b').textContent = g.k === 'find' ? (L.find.done ? `✓ ${L.find.integ}%` : `${L.find.integ}%`) : g.shown > 0 ? g.shown : '✓'; el.classList.toggle('done', g.shown <= 0); }")
rep("function goalIcon(g){ return iconCanvas((x, S) => { if (g.k === 'c')", "function goalIcon(g){ return iconCanvas((x, S) => { if (g.k === 'find') drawFindIcon(x, S, L && L.find ? RC[L.find.stone.tier] : '#c8b0ff'); else if (g.k === 'c')")
rep("k === 'geo' ? sprite('geoic', 64, drawGeodeIcon) : nugSpr(64));", "k === 'geo' ? sprite('geoic', 64, drawGeodeIcon) : k === 'find' ? sprite('findic', 64, (x, S) => drawFindIcon(x, S, RC[L.find.stone.tier])) : nugSpr(64));")
rep("function drawGeodeIcon(x, S){", r"""// the find in the goal bar: a crystal glinting out of a lump of rock, glow in its rarity colour
function drawFindIcon(x, S, glow){
  const g = x.createRadialGradient(S / 2, S / 2, S * .05, S / 2, S / 2, S * .5); g.addColorStop(0, glow); g.addColorStop(1, 'rgba(0,0,0,0)'); x.globalAlpha = .55; x.fillStyle = g; x.fillRect(0, 0, S, S); x.globalAlpha = 1;
  x.fillStyle = '#6a5e52'; x.beginPath(); x.ellipse(S / 2, S * .66, S * .36, S * .2, 0, 0, 6.29); x.fill();
  x.fillStyle = '#e8f0ff'; x.beginPath(); x.moveTo(S * .5, S * .14); x.lineTo(S * .64, S * .34); x.lineTo(S * .6, S * .66); x.lineTo(S * .4, S * .66); x.lineTo(S * .36, S * .34); x.closePath(); x.fill();
  x.fillStyle = glow; x.globalAlpha = .55; x.beginPath(); x.moveTo(S * .5, S * .14); x.lineTo(S * .64, S * .34); x.lineTo(S * .6, S * .66); x.lineTo(S * .5, S * .66); x.closePath(); x.fill(); x.globalAlpha = 1;
  x.fillStyle = '#4e443a'; x.beginPath(); x.ellipse(S / 2, S * .72, S * .38, S * .14, 0, 0, 6.29); x.fill();
}
function drawGeodeIcon(x, S){""")

# ---------------- drawing the sealed specimen ----------------
rep("  // stones (clipped to the tray so new ones slide in from its top edge)", r"""  // the find: the real specimen, seen through rock that thins with every layer peeled
  if (L.find && !L.find.done) { const F = L.find, px = PAD + F.c * S, py = PAD + F.r * S, sh = now() - F.hitAt < 220 ? Math.sin((now() - F.hitAt) / 18) * 3 : 0, k = F.hp / F.hpMax, col = RC[F.stone.tier];
    x.save(); x.translate(px + sh, py); x.beginPath(); x.roundRect(2, 2, S * 2 - 4, S * 2 - 4, S * .3); x.clip();
    x.fillStyle = '#05070a'; x.fillRect(0, 0, S * 2, S * 2);
    const pulse = .25 + .15 * Math.sin(t / 500), gl = x.createRadialGradient(S, S, S * .1, S, S, S * 1.1); gl.addColorStop(0, col); gl.addColorStop(1, 'rgba(0,0,0,0)'); x.globalAlpha = pulse * (1.2 - k); x.fillStyle = gl; x.fillRect(0, 0, S * 2, S * 2);
    x.globalAlpha = .35 + (1 - k) * .65; if (F.img && F.img.complete) x.drawImage(F.img, -S * .1, -S * .1, S * 2.2, S * 2.2);
    x.globalAlpha = .25 + k * .7; x.drawImage(rockSpr(2, S * 4), 0, 0, S * 2, S * 2); x.globalAlpha = 1;
    if (F.integ < 100) { x.strokeStyle = '#ffb090'; x.lineWidth = 1.6; x.shadowColor = '#ff6a40'; x.shadowBlur = 6; x.save(); x.scale(S * 2 / 100, S * 2 / 100);
      for (const d of crackPaths(F.r * 13 + F.c, Math.ceil((100 - F.integ) / 12))) x.stroke(new Path2D(d)); x.restore(); x.shadowBlur = 0; }
    x.restore();
    x.strokeStyle = col; x.globalAlpha = .5 + .3 * Math.sin(t / 400); x.lineWidth = 2; x.beginPath(); x.roundRect(px + 2, py + 2, S * 2 - 4, S * 2 - 4, S * .3); x.stroke(); x.globalAlpha = 1;
    x.fillStyle = 'rgba(0,0,0,.6)'; x.fillRect(px + S * .55, py + S * 1.62, S * .9, S * .28); x.fillStyle = '#fff'; x.font = `800 ${Math.round(S * .2)}px Nunito, sans-serif`; x.textAlign = 'center'; x.fillText('●'.repeat(F.hp), px + S, py + S * 1.83, S * .86); }
  // stones (clipped to the tray so new ones slide in from its top edge)""")

# ---------------- the reward: the find comes first, the vein choice is gone ----------------
rep("  const bonus = () => bonusFlow(after);\n  if (L.vein) stoneChoice(bonus); else bonus();",
    r"""  const bonus = () => bonusFlow(after);
  if (L.find && L.find.done) { const F = L.find, s = Object.assign({}, F.stone), loss = Math.floor((100 - F.integ) / 20), gi = Math.max(0, s.gi - loss);
    s.value = Math.round(s.value * GR[gi].m / GR[s.gi].m * (hasJewel('diadem') ? 1.1 : 1)); s.gi = gi; s.integ = F.integ;
    s.tier = Math.min(4, SP[s.sid].r + (gi >= 3 ? 1 : 0) + (s.legend ? 1 : 0)); showStone([s], 0, bonus); }
  else bonus();""")
rep("""      <div class="row"><span>Вес</span><b>${fmtW(s.g)}</b></div><div class="row"><span>Качество</span><b>${GR[s.gi].n}</b></div><div class="row"><span>Оценка</span><b>${mon(s.value)}</b></div>""",
    """      <div class="row"><span>Вес</span><b>${fmtW(s.g)}</b></div><div class="row"><span>Качество</span><b>${GR[s.gi].n}</b></div>${s.integ != null ? `<div class="row"><span>Целостность</span><b style="color:${s.integ >= 90 ? 'var(--good)' : s.integ >= 60 ? '#ffd27a' : '#ff9a8a'}">${s.integ}%</b></div>` : ''}<div class="row"><span>Оценка</span><b>${mon(s.value)}</b></div>""")
rep("""  openOv(`<h2>Ходы закончились</h2><p>Осталось целей: ${left}. Ещё пять ходов?</p>""",
    """  openOv(`<h2>Ходы закончились</h2><p>Осталось целей: ${left}.${L.find && !L.find.done ? ' Образец так и останется в породе.' : ''} Ещё пять ходов?</p>""")

# ---------------- texts that talked about veins ----------------
rep("  $('#lvlName').textContent = `Уровень ${L.n} · ${DEPTHS[L.depth].m} м${L.vein ? ' · жила' : ''}${L.hard ? ' · сложный' : ''}`;",
    "  $('#lvlName').textContent = `Уровень ${L.n} · ${DEPTHS[L.depth].m} м${L.hard ? ' · сложный' : ''}`;")
rep("${def.hard ? ' · сложный' : ''}${def.vein ? ' · жила: в конце выбор камня' : ''}</p>", "${def.hard ? ' · сложный' : ''} · в породе ждёт образец</p>")
rep("""${save.streak >= 2 ? ` · серия ${save.streak}` : ''}</small>${def.vein ? '<span class="vein">жила · выбор камня</span>' : ''}`;""", """${save.streak >= 2 ? ` · серия ${save.streak}` : ''}</small>`;""")
rep("{id:'lift', n:'Лебёдка', d:'+1 камень на выбор в жиле', cost:[1200, 4000]}", "{id:'lift', n:'Лебёдка', d:'взрывы откалывают от находки на 25% меньше', cost:[1200, 4000]}")
rep("perk:'+1 камень на выбор в жилах'", "perk:'находки на 10% дороже'")
# the pre-level goal list shows the find too
rep("      const pg = $('#pg'); gl.forEach(g => {", "      const pg = $('#pg'); { const sp = document.createElement('span'); sp.appendChild(iconCanvas((x, S) => drawFindIcon(x, S, '#c8b0ff'))); sp.append('образец'); pg.appendChild(sp); }\n      gl.forEach(g => {")

# stoneChoice is no longer used
i = s.index("function stoneChoice(done){"); j = s.index("function crackPaths(", i); s = s[:i] + s[j:]
open(P, 'w', encoding='utf-8').write(s)
print('ok')
