"""v5 of «Забой»: a crew of specialists with active abilities, and gem cutting in the lab."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:100])
    s = s.replace(a, b)

def between(start, end, new):
    global s
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + s[j:]

# ---------------- CSS ----------------
rep(".fxc{position:fixed;", r""".crew{display:grid;grid-template-columns:62px minmax(0, 1fr);gap:12px;background:linear-gradient(160deg, rgba(30,50,60,.94), rgba(12,24,30,.96));border:1px solid #3c5c6a;border-radius:16px;padding:12px;box-shadow:0 10px 24px rgba(0,0,0,.5)}
.crew.sel{border-color:var(--cc);box-shadow:0 0 22px color-mix(in srgb, var(--cc) 30%, transparent), 0 10px 24px rgba(0,0,0,.5)}
.crew-b{width:62px;height:62px;border-radius:50%;display:grid;place-items:center;color:var(--cc);background:radial-gradient(circle at 35% 30%, color-mix(in srgb, var(--cc) 35%, #10202a), #08141a 70%);border:2px solid var(--cc);box-shadow:inset 0 2px 0 rgba(255,255,255,.15), 0 0 16px color-mix(in srgb, var(--cc) 35%, transparent);flex:none}
.crew-b svg{width:30px;height:30px}
.crew.locked .crew-b{filter:grayscale(.7) brightness(.7)}
.crew-t{display:flex;flex-direction:column;gap:6px;min-width:0}
.crew-h{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
.crew-h b{font-family:var(--game);font-weight:400;font-size:20px}
.crew-h span{font-size:11.5px;color:var(--cc);text-transform:uppercase;letter-spacing:.1em;font-weight:600}
.crew ul{margin:0;padding-left:16px;font-size:12.5px;color:#c6d0ce}
.crew-ab{display:flex;gap:8px;align-items:flex-start;font-size:12px;color:var(--muted);background:rgba(0,0,0,.28);border-radius:10px;padding:6px 8px}
.crew-ab i{font-style:normal;color:var(--cc);font-size:17px;line-height:1;text-shadow:0 0 8px var(--cc)}
.crew-ab b{color:var(--fg)}
.crew-on{font-family:var(--game);color:var(--cc);font-size:14px;letter-spacing:.04em}
.crew .buy{align-self:flex-start;display:flex;gap:10px;align-items:center;padding:8px 12px}
.crew .btn{align-self:flex-start;padding:9px 16px}
.hero-chip{display:flex;align-items:center;gap:10px;width:100%;max-width:440px;background:rgba(8,16,20,.84);border:1px solid var(--cc);border-radius:16px;padding:6px 12px 6px 6px;text-align:left;box-shadow:0 0 18px color-mix(in srgb, var(--cc) 22%, transparent)}
.hero-chip .crew-b{width:42px;height:42px}
.hero-chip .crew-b svg{width:22px;height:22px}
.hero-chip b{font-family:var(--game);font-weight:400;font-size:16px;display:block}
.hero-chip small{font-size:11.5px;color:var(--muted)}
.hero-chip em{margin-left:auto;font-style:normal;font-size:12px;color:var(--cc);font-weight:600;white-space:nowrap}
.abil{position:fixed;z-index:11;right:14px;bottom:calc(98px + env(safe-area-inset-bottom, 0px));width:68px;height:68px;border-radius:50%;border:2px solid var(--cc);background:radial-gradient(circle at 35% 30%, color-mix(in srgb, var(--cc) 40%, #10202a), #08141a 72%);color:#fff;display:grid;place-items:center;box-shadow:0 0 18px color-mix(in srgb, var(--cc) 40%, transparent), 0 4px 0 #050c0f;touch-action:manipulation;overflow:hidden;padding:0}
.abil::before{content:"";position:absolute;inset:0;background:conic-gradient(rgba(0,0,0,.72) calc(var(--p, 0) * 360deg), transparent 0)}
.abil .ab-i{position:relative;font-size:27px;line-height:1;color:var(--cc);text-shadow:0 0 10px var(--cc);margin-top:-8px}
.abil .ab-n{position:absolute;bottom:7px;left:0;right:0;text-align:center;font-size:9px;font-weight:700;letter-spacing:.03em;text-transform:uppercase}
.abil .ab-cd{position:absolute;font-family:var(--mono);font-weight:700;font-size:21px;text-shadow:0 1px 4px #000}
.abil.ready{animation:abr 1.6s ease-in-out infinite}
@keyframes abr{50%{box-shadow:0 0 30px var(--cc), 0 4px 0 #050c0f}}
.cutbtn{width:100%;max-width:420px;background:linear-gradient(#d2b0ff, #8a4ff0);color:#1a0b33;box-shadow:inset 0 1px 0 rgba(255,255,255,.5), 0 4px 0 #3e1f78}
.cutbtn:active{box-shadow:0 1px 0 #3e1f78}
.cuts{display:flex;flex-direction:column;gap:8px;width:100%;max-width:420px}
.cut{text-align:left;background:linear-gradient(160deg, rgba(30,50,60,.96), rgba(12,24,30,.98));border:1px solid #3c5c6a;border-radius:14px;padding:10px 12px;display:flex;flex-direction:column;gap:4px;box-shadow:0 4px 0 #050c0f}
.cut:active:not(:disabled){transform:translateY(2px);box-shadow:0 2px 0 #050c0f}
.cut:disabled{opacity:.45;cursor:default}
.cut-h{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
.cut-h b{font-family:var(--game);font-weight:400;font-size:17px;color:#f6cd84}
.cut-p{font-family:var(--mono);font-weight:700;font-size:19px;color:var(--pc)}
.cut p{margin:0;font-size:12.5px;color:var(--muted)}
.cut-v{display:flex;justify-content:space-between;gap:8px;font-family:var(--mono);font-size:12px}
.cut-v span:first-child{color:var(--anom)}
.cut-v span:last-child{color:#ff8a78}
.cut-c{font-family:var(--mono);font-size:11px;color:var(--muted);display:flex;flex-wrap:wrap;gap:4px 10px}
.cut-c .no{color:var(--danger)}
.cutting-t{font-family:var(--game);font-size:20px;color:#e2c8ff;text-shadow:0 0 14px rgba(160,110,255,.6)}
.cbar{width:min(300px, 80%);height:10px;border-radius:5px;background:rgba(255,255,255,.1);overflow:hidden}
.cbar i{display:block;height:100%;width:0;background:linear-gradient(90deg, #8a4ff0, #fff2c0);transition:width .15s}
.wheel{position:absolute;inset:6%;border-radius:50%;background:repeating-conic-gradient(rgba(255,255,255,.09) 0 5deg, transparent 5deg 10deg);border:2px solid rgba(255,255,255,.14);opacity:0;transition:opacity .3s}
.arena.cutting .wheel{opacity:1;animation:spin .3s linear infinite}
.arena.cutting .gem{animation:wob .17s ease-in-out infinite}
@keyframes wob{50%{transform:rotate(3deg) scale(.97)}}
.gem.cut img{filter:brightness(1.2) contrast(1.25) saturate(1.35) drop-shadow(0 0 22px var(--rc))}
.gem.cut::after{content:"";position:absolute;inset:12%;border-radius:50%;mix-blend-mode:overlay;animation:spin 6s linear infinite;background:conic-gradient(from 0deg, transparent 0 20deg, rgba(255,255,255,.6) 24deg, transparent 30deg 110deg, rgba(255,255,255,.5) 114deg, transparent 120deg 220deg, rgba(255,255,255,.55) 224deg, transparent 230deg)}
.gem.broken img{filter:grayscale(.6) brightness(.6) contrast(1.2)}
.gem.broken::after{content:"";position:absolute;inset:18%;background:linear-gradient(115deg, transparent 47%, rgba(255,255,255,.75) 48%, transparent 50%), linear-gradient(35deg, transparent 55%, rgba(255,255,255,.6) 56%, transparent 58%)}
.app .nav{grid-template-columns:repeat(5, 1fr);gap:5px}
.app .nav button{font-size:10px;letter-spacing:-.01em;padding:8px 0 6px}
.fxc{position:fixed;""")
rep('<div id="marks"></div>', '<div id="marks"></div>\n<button type="button" class="abil" id="abil" hidden aria-label="Способность"><span class="ab-i" id="abI"></span><span class="ab-cd" id="abCd"></span><span class="ab-n" id="abN"></span></button>')

# ---------------- data: the crew ----------------
rep("const LAMP_T = [110, 140, 170, 200, 240]", r"""// the crew: one specialist goes down, each with passives and an active ability
const CREW = {
  miner:{n:'Савва', role:'Забойщик', c:'#e3a857', ico:'pick', pas:['+2 к здоровью', 'Кайлом бьёт сильнее'], ab:{id:'rest', n:'Привал', g:'✚', d:'восстанавливает 1 здоровье', cd:50}, cost:null},
  geo:{n:'Вера', role:'Геолог', c:'#b47cff', ico:'lens', pas:['Блики трофеев видно дальше и шире', 'Обкалывает на 40% быстрее, сколы реже'], ab:{id:'scan', n:'Сейсмоскан', g:'◉', d:'на 8 с подсвечивает все трофеи в радиусе 14 м', cd:40}, cost:{money:600, copper:15}},
  spel:{n:'Лёва', role:'Спелеолог', c:'#7fe0c8', ico:'helm', pas:['Шаги и работа тише на 40%', 'Фонарь горит на 25% дольше'], ab:{id:'flare', n:'Фальшфейер', g:'✸', d:'бросает огонь вперёд: 12 с света, ползуны пятятся', cd:45}, cost:{money:400, carbide:15}},
  blast:{n:'Гордей', role:'Взрывник', c:'#ff7a3a', ico:'tnt', pas:['+2 заряда на спуск', 'Завалы, стены и жилы — вдвое быстрее'], ab:{id:'blast', n:'Шашка', g:'✹', d:'оглушает и ранит всех рядом, рушит завалы', cd:30}, cost:{money:500, iron:20, carbide:10}},
};
const CICO = {
  pick:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><g transform="rotate(-35 12 12)"><path d="M4 9Q12 1.5 20 9"/><path d="M12 5.2V22"/></g></svg>',
  lens:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="10" r="6"/><path d="M14.5 14.5 21 21"/><path d="M8 8.5l2-2 2 2-2 2z"/></svg>',
  helm:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 16a8 8 0 0 1 16 0z"/><path d="M2 16h20"/><circle cx="12" cy="10" r="2"/><path d="M12 4v2"/></svg>',
  tnt:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="10" width="5" height="11" rx="1"/><rect x="10" y="10" width="5" height="11" rx="1"/><path d="M12.5 10c0-4 2.5-6 6-6"/><path d="M19 2.5l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z"/></svg>'};
// cutting: a gamble on the polishing wheel
const CUTS = [
  {id:'cab', n:'Кабошон', d:'Гладкая полировка. Почти без риска.', m:1.35, p:.94, fail:.85, cost:{carbide:4}},
  {id:'facet', n:'Фацетная огранка', d:'Грани и игра света. Может треснуть.', m:2.3, p:.7, fail:.5, cost:{carbide:10, money:100}},
  {id:'master', n:'Мастер-огранка', d:'Ювелирная работа. Удаётся редко.', m:4.5, p:.4, fail:.25, cost:{carbide:18, copper:6, money:400}, lab:1},
];
const CUTN = {cab:'кабошон', facet:'фацетная', master:'мастер-огранка', broken:'треснул на круге'};
const cutChance = (c, it) => Math.max(.05, Math.min(.98, c.p + it.res.gi * .04 - Math.min(3, it.dmg || 0) * .1 + save.up.lab * .05));
const LAMP_T = [110, 140, 170, 200, 240]""")
rep("finds:[], coll:[], rec:{}, uid:0,", "finds:[], coll:[], rec:{}, crew:['miner'], hero:'miner', uid:0,")

# ---------------- sounds ----------------
rep("  pebble(){", "  grind(){ noise(.16, 3000, .18, 'bandpass'); tone(rnd(1800, 2500), 0, .12, .02, 'sawtooth'); },\n"
    "  scan(){ [0, 1, 2, 3].forEach(k => tone(1300 - k * 220, k * .14, .6, .05, 'sine')); noise(.6, 900, .08, 'bandpass'); },\n"
    "  flare(){ noise(1.6, 2600, .22, 'highpass'); tone(300, 0, .3, .05, 'triangle'); },\n"
    "  pebble(){")

# ---------------- run setup: passives ----------------
rep("const bag = BAGS[save.up.bag], lampT = LAMP_T[save.up.lamp];", "const bag = BAGS[save.up.bag], lampT = Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1)), hpX = save.hero === 'miner' ? 2 : 0;")
rep("hp:4 + save.up.kit, hpMax:4 + save.up.kit,", "hp:4 + save.up.kit + hpX, hpMax:4 + save.up.kit + hpX,")
rep("charges:1 + save.up.charge, pending:null,", "charges:1 + save.up.charge + (save.hero === 'blast' ? 2 : 0), pending:null,")
rep("noise:.6, noiseVis:.6,", "hero:save.hero, abCd:0, scanT:0, scanAt:null, flare:null, noise:.6, noiseVis:.6,")
rep("$('#compass').hidden = false; $('#film').hidden = false;", "$('#compass').hidden = false; $('#film').hidden = false; setupAbil();")
rep("'#dig', '#findcard', '#note'].forEach(s => $(s).hidden = true);", "'#dig', '#findcard', '#note', '#abil'].forEach(s => $(s).hidden = true);")

# ---------------- scene: scan ring, flare ----------------
rep("  // how far your noise carries", r"""  // the geologist's seismic ring and the speleologist's flare (its light always exists, so no shader recompiles)
  scanRing = new THREE.Mesh(new THREE.RingGeometry(.93, 1, 96), new THREE.MeshBasicMaterial({color:0xc69bff, transparent:true, opacity:0, depthWrite:false, blending:THREE.AdditiveBlending}));
  scanRing.rotation.x = -Math.PI / 2; scanRing.position.y = .06; scene.add(scanRing);
  flareObj = new THREE.Group(); { const fl = new THREE.PointLight(0xff5a2a, 0, 7.5, 2); fl.position.y = .5; flareObj.add(fl);
    const fm = new THREE.Mesh(new THREE.CylinderGeometry(.04, .04, .35, 6), new THREE.MeshBasicMaterial({color:0xff7040})); fm.rotation.z = 1.2; fm.position.y = .06; flareObj.add(fm);
    const fh = new THREE.Sprite(new THREE.SpriteMaterial({map:haloTex, color:0xff6030, blending:THREE.AdditiveBlending, depthWrite:false, transparent:true, opacity:.9})); fh.scale.setScalar(1.9); fh.position.y = .25; flareObj.add(fh);
    flareObj.userData = {light:fl, mesh:fm, halo:fh}; fm.visible = fh.visible = false; scene.add(flareObj); }
  // how far your noise carries""")
rep("let gridTex = null, mist = null, noiseRing = null, spores = null;", "let gridTex = null, mist = null, noiseRing = null, spores = null, scanRing = null, flareObj = null;")

# ---------------- draw ----------------
rep("u.halo.material.opacity += (lit * .55 - u.halo.material.opacity) * Math.min(1, dt * 6);",
    "u.halo.material.opacity += (lit * .55 + (S.scanT > 0 && dep.scanned ? .4 : 0) - u.halo.material.opacity) * Math.min(1, dt * 6);\n"
    "    if (S.scanT > 0 && dep.scanned) u.glint.material.opacity += .45 + .55 * tw;")
rep("  S.noiseVis += (S.noise - S.noiseVis) * Math.min(1, dt * 10);", r"""  if (S.scanT > 0 && S.scanAt) { const age = 8 - S.scanT; scanRing.position.set(S.scanAt.x, .06, S.scanAt.z); scanRing.scale.setScalar(Math.max(.1, Math.min(1, age / 1.3)) * 14); scanRing.material.opacity = Math.max(0, .75 - age * .45); } else scanRing.material.opacity = 0;
  { const fu = flareObj.userData; if (S.flare) { flareObj.position.set(S.flare.x, 0, S.flare.z); const fk = Math.min(1, S.flare.t / 1.5) * (.8 + Math.random() * .35); fu.light.intensity = 2.8 * fk; fu.mesh.visible = fu.halo.visible = true; fu.halo.material.opacity = .9 * fk; }
    else { fu.light.intensity = 0; fu.mesh.visible = fu.halo.visible = false; } }
  S.noiseVis += (S.noise - S.noiseVis) * Math.min(1, dt * 10);""")

# ---------------- simulation: passives, flare light, ability timers ----------------
rep("function litBy(x, z){\n  if (S.lamp <= 0)", "function litBy(x, z){\n  if (S.flare && Math.hypot(x - S.flare.x, z - S.flare.z) < 4.2 && los(S.flare.x, S.flare.z, x, z)) return true;\n  if (S.lamp <= 0)")
rep("  if (d > spot.distance * 1.3) return false;", "  const geo = S.hero === 'geo';\n  if (d > spot.distance * (geo ? 1.8 : 1.3)) return false;")
rep("  return Math.abs(a) < spot.angle * 2.4 && los(S.pos.x, S.pos.z, x, z);", "  return Math.abs(a) < spot.angle * (geo ? 3.2 : 2.4) && los(S.pos.x, S.pos.z, x, z);")
rep("function noiseAt(r){ S.noise = Math.max(S.noise, r);", "function noiseAt(r){ if (S.hero === 'spel') r *= .6; S.noise = Math.max(S.noise, r);")
rep("S.noise = Math.max(moving ? (sneak ? 1.1 : inWater ? 3.4 : 2.7) : .6, S.noise - dt * 5);",
    "S.noise = Math.max((moving ? (sneak ? 1.1 : inWater ? 3.4 : 2.7) : .6) * (S.hero === 'spel' ? .6 : 1), S.noise - dt * 5);\n"
    "  S.abCd = Math.max(0, S.abCd - dt); S.scanT = Math.max(0, S.scanT - dt);\n"
    "  if (S.flare && (S.flare.t -= dt) <= 0) S.flare = null;")
rep("dep.work += dt * speed * .55;", "dep.work += dt * speed * .55 * (S.hero === 'geo' ? 1.4 : 1);")
rep("const digRisk = dep => Math.min(.85, .06 + dep.heat * .13 + (dep.kind === 'druse' ? .05 : 0));",
    "const digRisk = dep => Math.min(.85, (.06 + dep.heat * .13 + (dep.kind === 'druse' ? .05 : 0)) * (S && S.hero === 'geo' ? .6 : 1));")
rep("    tg.o.work = (tg.o.work || 0) + dt * speed;\n    showWork(`${RES[tg.o.type].n}: жила`", "    tg.o.work = (tg.o.work || 0) + dt * speed * (S.hero === 'blast' ? 2 : 1);\n    showWork(`${RES[tg.o.type].n}: жила`")
rep("tg.o.work += dt * speed; showWork('Разбираете завал'", "tg.o.work += dt * speed * (S.hero === 'blast' ? 2 : 1); showWork('Разбираете завал'")
rep("tg.o.work = (tg.o.work || 0) + dt * speed; showWork('Пробиваете", "tg.o.work = (tg.o.work || 0) + dt * speed * (S.hero === 'blast' ? 2 : 1); showWork('Пробиваете")
rep("mo.hp -= 1 + save.up.pick;", "mo.hp -= 1 + save.up.pick + (S.hero === 'miner' ? 1 : 0);")
rep("      if (mo.hp <= 0) { mo.alive = false; scene.remove(mo.mesh); S.kills++; save.st.monsters++; toast(mo.type === 'golem' ? 'Голем рассыпался' : 'Ползун затих', mo.type === 'golem' ? 'Из обломков посыпались кристаллы руды.' : '', '', 'var(--anom)'); if (mo.type === 'golem') { addRes('copper', 6); addRes('carbide', 4); } } }",
    "      if (mo.hp <= 0) killMon(mo); }")
rep("function showWork(t, f, c){", r"""function killMon(mo){
  mo.alive = false; scene.remove(mo.mesh); S.kills++; save.st.monsters++;
  toast(mo.type === 'golem' ? 'Голем рассыпался' : 'Ползун затих', mo.type === 'golem' ? 'Из обломков посыпались кристаллы руды.' : '', '', 'var(--anom)');
  if (mo.type === 'golem') { addRes('copper', 6); addRes('carbide', 4); }
}
function setupAbil(){
  const c = CREW[S.hero], el = $('#abil'); el.hidden = false; el.style.setProperty('--cc', c.c);
  $('#abI').textContent = c.ab.g; $('#abN').textContent = c.ab.n; $('#abCd').textContent = ''; el.style.setProperty('--p', 0); el.classList.add('ready');
}
function useAbility(){
  if (!S || S.mode !== 'walk' || S.abCd > 0) return;
  const c = CREW[S.hero], ab = c.ab;
  if (ab.id === 'rest') {
    if (S.hp >= S.hpMax) return toast('Привал не нужен', 'Здоровье полное.', '', 'var(--muted)');
    S.hp++; hud(); SFX.build(); toast('Привал', `Здоровье: ${S.hp} из ${S.hpMax}`, '', c.c);
  } else if (ab.id === 'scan') {
    S.scanT = 8; S.scanAt = {x:S.pos.x, z:S.pos.z}; let n = 0;
    for (const d of L.deps) { d.scanned = !!d.mesh && Math.hypot(d.mesh.position.x - S.pos.x, d.mesh.position.z - S.pos.z) < 14; if (d.scanned) n++; }
    SFX.scan(); toast('Сейсмоскан', n ? `Трофеев поблизости: ${n}` : 'Рядом пусто — ищите глубже.', '', c.c);
  } else if (ab.id === 'flare') {
    let x = S.pos.x, z = S.pos.z; const fx = Math.sin(S.face), fz = Math.cos(S.face);
    for (let k = 0; k < 22; k++) { const nx = x + fx * .25, nz = z + fz * .25; if (solidAt(Math.floor(nx + W / 2), Math.floor(nz + H / 2))) break; x = nx; z = nz; }
    S.flare = {x, z, t:12}; SFX.flare(); noiseAt(4);
  } else if (ab.id === 'blast') {
    SFX.boom(); S.shake = 1; buzz([80, 40, 120]);
    const f = document.createElement('div'); f.className = 'flash'; document.body.appendChild(f); setTimeout(() => f.remove(), 800);
    let hit = 0;
    for (const mo of L.mons) if (mo.alive && Math.hypot(mo.x - S.pos.x, mo.z - S.pos.z) < 3.5) { mo.stun = 4; mo.hp -= 3; mo.state = 'hunt'; hit++; if (mo.hp <= 0) killMon(mo); }
    for (const [dx, dy] of N8) { const j = S.cell + dx + dy * W; if (L.rubble.has(j)) { scene.remove(L.rubble.get(j).mesh); L.rubble.delete(j); } else if (L.cracked.has(j) && (!dx || !dy)) openCrack(j); }
    noiseAt(12); ctx(); toast('Шашка', hit ? `Оглушено: ${hit}` : 'Грохот на всю шахту.', '', c.c);
  }
  S.abCd = ab.cd;
}
function showWork(t, f, c){""")
rep("  $('#dread').style.opacity = Math.min(.9, S.dread).toFixed(2);",
    "  $('#dread').style.opacity = Math.min(.9, S.dread).toFixed(2);\n"
    "  { const ab = CREW[S.hero].ab, ae = $('#abil'); ae.style.setProperty('--p', (S.abCd / ab.cd).toFixed(3)); $('#abCd').textContent = S.abCd > 0 ? Math.ceil(S.abCd) : ''; ae.classList.toggle('ready', S.abCd <= 0); }")
rep("$('#digBtn').addEventListener('pointerdown',", "$('#abil').addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); ac(); useAbility(); });\n$('#digBtn').addEventListener('pointerdown',")

# ---------------- hub: crew tab and the chosen hero ----------------
rep("  museum:'<svg", "  crew:'<svg viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M4 16a8 8 0 0 1 16 0z\"/><path d=\"M2 16h20\"/><circle cx=\"12\" cy=\"10\" r=\"2\"/><path d=\"M7 20h10\"/></svg>',\n  museum:'<svg")
rep("  const nav = [['go', 'Шахта', 0], ['shop', 'Мастерская', 0],", "  const nav = [['go', 'Шахта', 0], ['crew', 'Бригада', 0], ['shop', 'Мастерская', 0],")
rep("      ${open ? `<button type=\"button\" class=\"play\" data-run=\"${b.id}\">Спуститься<small>фонарь ${LAMP_T[save.up.lamp]} с",
    "      ${(h => `<button type=\"button\" class=\"hero-chip\" data-tab=\"crew\" style=\"--cc:${h.c}\"><span class=\"crew-b\">${CICO[h.ico]}</span><span><b>${h.n}</b><small>${h.role} · ${h.ab.n}</small></span><em>сменить ›</em></button>`)(CREW[save.hero])}\n"
    "      ${open ? `<button type=\"button\" class=\"play\" data-run=\"${b.id}\">Спуститься<small>фонарь ${Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1))} с")
rep("    if (tab === 'shop') { sub = 'снаряжение и лебёдка';",
    r"""    if (tab === 'crew') { sub = `в бригаде: ${save.crew.length} из ${Object.keys(CREW).length}`;
      inner = Object.entries(CREW).map(([id, c]) => { const have = save.crew.includes(id), sel = save.hero === id;
        return `<div class="crew${sel ? ' sel' : ''}${have ? '' : ' locked'}" style="--cc:${c.c}"><div class="crew-b">${CICO[c.ico]}</div><div class="crew-t">
          <div class="crew-h"><b>${c.n}</b><span>${c.role}</span></div>
          <ul>${c.pas.map(p => `<li>${p}</li>`).join('')}</ul>
          <div class="crew-ab"><i>${c.ab.g}</i><span><b>${c.ab.n}</b> — ${c.ab.d}. Перезарядка ${c.ab.cd} с.</span></div>
          ${sel ? '<div class="crew-on">✓ Идёт в забой</div>' : have ? `<button type="button" class="btn" data-hero="${id}">Взять в забой</button>` : `<button type="button" class="buy" data-hire="${id}"${canPay(c.cost) ? '' : ' disabled'}><span class="cost">${costHTML(c.cost)}</span>Нанять</button>`}
        </div></div>`; }).join(''); }
    else if (tab === 'shop') { sub = 'снаряжение и лебёдка';""")
rep("  const h = e.target.closest('[data-hz]');",
    "  const hr = e.target.closest('[data-hero]'); if (hr) { save.hero = hr.dataset.hero; persist(); SFX.step(); return renderCamp(); }\n"
    "  const hi = e.target.closest('[data-hire]'); if (hi) { const id = hi.dataset.hire, c = CREW[id]; if (!save.crew.includes(id) && canPay(c.cost)) { pay(c.cost); save.crew.push(id); save.hero = id; SFX.build(); persist(); renderCamp(); toast(`${c.n} в бригаде`, `${c.role}: ${c.ab.n.toLowerCase()} — ${c.ab.d}.`, '', c.c); } return; }\n"
    "  const h = e.target.closest('[data-hz]');")
rep("'.logo, .bld, .fc, .sec-h, .vh, .play'", "'.logo, .bld, .fc, .sec-h, .vh, .play, .crew, .hero-chip'")

# ---------------- lab: cutting ----------------
between("function revealFind(){", "/* ===================== sheets & events", r"""function revealFind(){
  const it = ST.it, res = it.res, sp = SP[res.sid], tier = Math.min(4, sp.r + (res.gi >= 3 ? 1 : 0)), a = $('#arena');
  a.style.setProperty('--rc', RC[tier]); a.innerHTML = `<div class="rays"></div><div class="wheel"></div><div class="gem">${imgTag(res.sid)}</div>`;
  SFX.reveal(tier); const [x, y] = elXY(a);
  burst(x, y, {n:26, colors:['#8a7660', '#5e4e3e', '#b09a80'], speed:8, grav:.35, size:7, kind:'chip'});
  burst(x, y, {n:20 + tier * 14, colors:[RC[tier], '#ffffff'], speed:4 + tier, size:3.5});
  $('#stHint').textContent = '';
  ST.news = [];
  if (!save.coll.some(c => c.sid === res.sid)) ST.news.push('Новый вид для музея');
  noteBest();
  save.st.opened++; persist();
  renderOut();
}
function noteBest(){
  const res = ST.it.res, sp = SP[res.sid];
  if (!save.st.best || res.value > save.st.best.value) { if (save.st.best) ST.news.push(`Лучшая находка: ${fmt(res.value)} ₽`); save.st.best = {name:sp.n, value:res.value}; }
}
function renderOut(){
  const it = ST.it, res = it.res, sp = SP[res.sid], news = ST.news || [], canCut = !res.cut && !(it.dmg >= 3);
  $('#stOut').innerHTML = `<div class="label"><div class="no"><span>№ ${String(it.id).padStart(5, '0')}</span><span>${RAR[sp.r].toLowerCase()}</span></div><h3>${sp.n}</h3>
      <div class="sub">${it.kind === 'geode' ? 'из жеоды · ' : ''}${BIOM[it.biome].place}, ${it.depth} м</div>
      <dl>${it.g ? `<dt>Вес</dt><dd>${fmtW(it.g)}</dd>` : `<dt>Размер</dt><dd>${it.w}×${it.h}</dd>`}${it.dmg ? `<dt>Сколы</dt><dd>${it.dmg >= 3 ? 'обломки' : it.dmg}</dd>` : ''}<dt>Качество</dt><dd><span class="qual" style="--gc:${GR_C[res.gi]}">${GR[res.gi].n}</span></dd>${res.cut ? `<dt>Огранка</dt><dd>${CUTN[res.cut]}</dd>` : ''}</dl>
      <div class="val"><span>Оценка</span><span>${fmt(res.value)} ₽</span></div></div>
    ${news.length ? `<div class="news">${news.map(n => `<div>★ ${n}</div>`).join('')}</div>` : ''}
    ${canCut ? '<button type="button" class="btn cutbtn" data-cut>Огранить<small>рискнуть ради цены</small></button>' : ''}
    <div class="two" style="width:100%"><button type="button" class="ghost" data-keep>В музей</button><button type="button" class="btn" data-sell>Продать · ${fmt(res.value)} ₽</button></div>`;
}
function openCut(){
  const it = ST.it, v = it.res.value;
  $('#stOut').innerHTML = `<div class="cuts">${CUTS.map((c, k) => { const p = cutChance(c, it), lab = !c.lab || save.up.lab >= c.lab, ok = lab && canPay(c.cost);
      return `<button type="button" class="cut" data-cutopt="${k}"${ok ? '' : ' disabled'}><div class="cut-h"><b>${c.n}</b><span class="cut-p" style="--pc:${p > .7 ? 'var(--anom)' : p > .45 ? 'var(--lamp)' : 'var(--danger)'}">${Math.round(p * 100)}%</span></div>
        <p>${c.d}</p><div class="cut-v"><span>удача: ${fmt(v * c.m)} ₽</span><span>провал: ${fmt(v * c.fail)} ₽</span></div>
        <div class="cut-c">${lab ? costHTML(c.cost) : `<span class="no">нужно оборудование лаборатории ур. ${c.lab}</span>`}</div></button>`; }).join('')}</div>
    <button type="button" class="ghost" data-cutback style="width:100%;max-width:420px">Не рисковать</button>`;
}
function doCut(k){
  const c = CUTS[k], it = ST.it, res = it.res;
  if (ST.busy || res.cut || !canPay(c.cost) || (c.lab && save.up.lab < c.lab)) return;
  pay(c.cost); persist();
  ST.busy = true; const a = $('#arena'), win = Math.random() < cutChance(c, it), sp = SP[res.sid], tier = Math.min(4, sp.r + (res.gi >= 3 ? 1 : 0));
  a.classList.add('cutting');
  $('#stOut').innerHTML = `<div class="cutting-t">${c.n}…</div><div class="cbar"><i id="cbar"></i></div>`;
  let n = 0;
  const finish = () => {
    a.classList.remove('cutting'); ST.busy = false; const gem = a.querySelector('.gem'), [x, y] = elXY(a);
    if (win) { res.value = Math.round(res.value * c.m); res.cut = c.id; gem.classList.add('cut'); SFX.reveal(Math.min(4, tier + 1)); burst(x, y, {n:40 + tier * 10, colors:[RC[tier], '#ffffff', '#fff2c0'], speed:6 + tier, size:3.6}); ST.news = [`${c.n} удалась: ×${String(c.m).replace('.', ',')}`]; }
    else { res.value = Math.round(res.value * c.fail); res.cut = 'broken'; gem.classList.add('broken'); SFX.shatter(); buzz([60, 40, 120]); burst(x, y, {n:30, colors:['#d8d0c0', '#8a8070'], speed:7, grav:.35, size:4, kind:'chip'}); ST.news = ['Камень треснул на круге']; }
    noteBest(); persist(); renderOut();
  };
  const iv = setInterval(() => { n++; SFX.grind(); const [x, y] = elXY(a); burst(x, y + 50, {n:6, colors:['#fff6d0', RC[tier]], speed:5, grav:.25, size:2.2}); $('#cbar').style.width = Math.min(100, n * 9.5) + '%'; if (n >= 11) { clearInterval(iv); setTimeout(finish, 220); } }, 170);
}
function decideFind(keep){
  if (ST.busy) return;
  const it = ST.it, res = it.res;
  save.finds = save.finds.filter(x => x.id !== it.id);
  if (keep) save.coll.push({id:it.id, sid:res.sid, gi:res.gi, value:res.value, biome:it.biome, depth:it.depth, size:`${it.w}×${it.h}`, g:it.g, cut:res.cut});
  else { save.money += res.value; SFX.coin(); }
  persist();
  const next = save.finds[0];
  if (next) openFind(next.id); else { stage.hidden = true; ST = null; renderCamp(); }
}

""")
rep("stage.addEventListener('click', e => { if (e.target.closest('#arena')) return hitFind();",
    "stage.addEventListener('click', e => { if (e.target.closest('[data-cutopt]')) return doCut(+e.target.closest('[data-cutopt]').dataset.cutopt); if (e.target.closest('[data-cut]')) return openCut(); if (e.target.closest('[data-cutback]')) return renderOut(); if (e.target.closest('#arena')) return hitFind();")
rep("<div class=\"rows\"><div class=\"row\"><span>Качество</span><span>${GR[s.gi].n}</span></div>",
    "<div class=\"rows\"><div class=\"row\"><span>Качество</span><span>${GR[s.gi].n}</span></div>${s.cut ? `<div class=\"row\"><span>Огранка</span><span>${CUTN[s.cut]}</span></div>` : ''}")

# help
rep("    <li>Белый круг вокруг шахтёра", "    <li>В бригаде четыре специалиста: забойщик, геолог, спелеолог и взрывник. В забой идёт один. У каждого свои сильные стороны и способность — круглая кнопка справа внизу.</li>\n    <li>Белый круг вокруг шахтёра")
rep("Трофей раскрывается в лаборатории.", "Трофей раскрывается в лаборатории.", 0)

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
