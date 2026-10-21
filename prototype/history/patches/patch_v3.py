"""v3 of «Забой»: the find as an event, dread in the dark, landmarks, tilted camera."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:90])
    s = s.replace(a, b)

def between(start, end, new, keep_end=True):
    global s
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + (s[j:] if keep_end else s[j + len(end):])

# ---------- CSS ----------
rep(".fxc{position:fixed;", """.dig{position:fixed;z-index:11;left:50%;bottom:calc(166px + env(safe-area-inset-bottom, 0px));transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;gap:6px}
.dig-pips{display:flex;gap:4px;align-items:center;font-size:11px;color:var(--muted);text-shadow:0 1px 4px #000}
.dig-pips i{width:16px;height:6px;border-radius:2px;background:rgba(255,255,255,.14)}
.dig-pips i.on{background:var(--anom)}
.dig-btn{border:1.5px solid var(--rk, var(--anom));background:rgba(16,34,42,.94);border-radius:999px;padding:10px 24px;font-weight:600;font-size:15px;box-shadow:0 0 18px color-mix(in srgb, var(--rk, var(--anom)) 35%, transparent);touch-action:manipulation;user-select:none;-webkit-user-select:none}
.dig-btn small{display:block;font-weight:500;font-size:11.5px;color:var(--rk, var(--anom))}
.dig.good .dig-btn{animation:pulse .2s}
.dig.bad{animation:shk .3s}
@keyframes pulse{50%{transform:scale(1.07)}}
@keyframes shk{25%{transform:translateX(calc(-50% - 7px))}75%{transform:translateX(calc(-50% + 7px))}}
.findcard{position:fixed;z-index:13;left:50%;top:31%;transform:translate(-50%,-50%);width:min(330px, calc(100% - 32px));display:flex;gap:12px;align-items:center;background:linear-gradient(160deg, rgba(23,50,64,.97), rgba(10,22,28,.97));border:1.5px solid var(--fc);border-radius:14px;padding:12px 14px;box-shadow:0 0 44px color-mix(in srgb, var(--fc) 45%, transparent), 0 10px 30px rgba(0,0,0,.6)}
.findcard.pop{animation:card .55s cubic-bezier(.2,1.4,.4,1)}
@keyframes card{from{transform:translate(-50%,-50%) scale(.55);opacity:0}}
.findcard .fimg{width:66px;height:66px;flex:none;filter:drop-shadow(0 0 12px var(--fc))}
.findcard .fimg img{width:100%;height:100%;object-fit:contain}
.findcard .fr{font-size:11px;text-transform:uppercase;letter-spacing:.1em;color:var(--fc);font-weight:600}
.findcard b{display:block;font-family:var(--display);font-size:19px;line-height:1.15}
.findcard .fw{font-family:var(--mono);font-size:16px;font-weight:700}
.findcard .fd{font-size:12px;color:var(--danger)}
.findcard em{display:block;font-style:normal;font-size:12.5px;color:var(--lamp);margin-top:3px;font-weight:600}
.gemflash{position:fixed;inset:0;z-index:12;pointer-events:none;background:radial-gradient(circle at 50% 45%, color-mix(in srgb, var(--fc) 50%, transparent), transparent 62%);animation:flash .9s ease-out forwards}
.note{position:fixed;z-index:13;left:50%;bottom:calc(150px + env(safe-area-inset-bottom, 0px));transform:translateX(-50%);width:min(340px, calc(100% - 32px));background:var(--paper);color:var(--ink);border-radius:3px;padding:12px 14px;box-shadow:0 10px 30px rgba(0,0,0,.6);font-family:var(--display);font-style:italic;font-size:15.5px;line-height:1.35;animation:fxin .35s both}
.note .sig{display:block;text-align:right;font-size:13px;color:var(--ink2);margin-top:4px}
.note .gain{display:block;font-family:var(--body);font-style:normal;font-size:12px;color:#7a4a10;font-weight:600;margin-top:6px}
.dread{position:fixed;inset:0;z-index:6;pointer-events:none;opacity:0;transition:opacity .5s;box-shadow:inset 0 0 160px 70px rgba(0,0,0,.95);animation:dread 1.1s ease-in-out infinite}
@keyframes dread{50%{box-shadow:inset 0 0 200px 100px rgba(0,0,0,1)}}
.fxc{position:fixed;""")

# ---------- HTML ----------
rep('<div class="vign" id="vign"></div>', '<div class="dread" id="dread"></div>\n<div class="vign" id="vign"></div>')
rep('<div class="toastbox" id="toasts"></div>', '''<div class="dig" id="dig" hidden><div class="dig-pips"><span>целостность</span><span id="digPips" style="display:flex;gap:4px"></span></div><button type="button" class="dig-btn" id="digBtn">Сильный удар<small id="digRisk"></small></button></div>
<div class="findcard" id="findcard" hidden></div>
<div class="note" id="note" hidden></div>
<div class="toastbox" id="toasts"></div>''')

# ---------- data ----------
rep("const LAMP_T = [110, 140, 170, 200, 240]", """// weights: most finds are small, a few are monsters
const WT = {crystal:[25, 320], druse:[240, 2600], nugget:[3, 120], geode:[450, 4800]};
const WMED = Object.fromEntries(Object.entries(WT).map(([k, [a, b]]) => [k, Math.sqrt(a * b)]));
const GROT_C = {adit:0xb47cff, flood:0x7fd8ff, fire:0xff3a5a};
const NOTE_SIG = ['штейгер Кузьмин, 1903', 'артель Сысоева', 'Е. Ф.', 'подпись размыта', 'забойщик Тимофей', 'М. Л., десятник'];
const LAMP_T = [110, 140, 170, 200, 240]""")
rep("const itemName = it => it.kind === 'geode' ? 'Жеода' : `${KIND[it.kind]}: ${SP[it.sid].n.toLowerCase()}`;",
    "const itemName = it => { const base = it.kind === 'geode' ? 'жеода' : SP[it.sid].n.toLowerCase(); return it.dmg >= 3 ? `Обломки: ${base}` : it.kind === 'geode' ? 'Жеода' : `${KIND[it.kind]}: ${base}`; };\n"
    "function rollW(kind, d){ const [a, b] = WT[kind]; let g = a * Math.pow(b / a, Math.pow(Math.random(), 1.7 - d * .7)); if (Math.random() < .04) g *= rnd(1.4, 2.2); return g; }\n"
    "const fmtW = g => g >= 1000 ? `${(g / 1000).toFixed(2).replace('.', ',')} кг` : `${Math.round(g)} г`;\n"
    "const clamp1 = v => Math.max(-1, Math.min(1, v));")
rep("finds:[], coll:[], uid:0,", "finds:[], coll:[], rec:{}, uid:0,")
rep("st:Object.assign(b.st, s.st)});", "st:Object.assign(b.st, s.st), rec:Object.assign(b.rec, s.rec)});")

# ---------- sound: stereo, ambience ----------
rep("function noise(dur, freq, vol, type = 'lowpass'){", "function outNode(a, pan){ if (!pan || !a.createStereoPanner) return a.destination; const p = a.createStereoPanner(); p.pan.value = clamp1(pan); p.connect(a.destination); return p; }\nfunction noise(dur, freq, vol, type = 'lowpass', pan = 0){")
rep("s.connect(f); f.connect(g); g.connect(a.destination); s.start();\n}", "s.connect(f); f.connect(g); g.connect(outNode(a, pan)); s.start();\n}")
rep("function tone(freq, at, dur, vol, type = 'sine'){", "function tone(freq, at, dur, vol, type = 'sine', pan = 0){")
rep("o.connect(g); g.connect(a.destination); o.start(t);", "o.connect(g); g.connect(outNode(a, pan)); o.start(t);")
rep("  skitter(v){ for (let k = 0; k < 4; k++) noise(.03, 3500, .05 * v, 'highpass'); },\n  growl(){ tone(55, 0, .9, .12, 'sawtooth'); noise(.8, 120, .2); },",
    """  skitter(v, p){ for (let k = 0; k < 4; k++) noise(.03, 3500, .06 * v, 'highpass', p); tone(5200, .05, .03, .01 * v, 'square', p); },
  growl(p){ tone(55, 0, .9, .12, 'sawtooth', p); noise(.8, 120, .2, 'lowpass', p); },
  drip(p){ const f = rnd(1300, 2300); tone(f, 0, .1, .03, 'sine', p); tone(f * 1.6, .025, .07, .014, 'sine', p); },
  creak(p){ noise(.9, rnd(300, 600), .07, 'bandpass', p); tone(rnd(70, 95), 0, .8, .02, 'sawtooth', p); },
  shimmer(r, p){ [0, 4, 7, 11, 14].slice(0, 2 + r).forEach((st, k) => tone(1568 * Math.pow(2, st / 12), k * .09, .7, .018 + r * .008, 'triangle', p)); },
  strike(){ noise(.12, 1800, .5, 'bandpass'); tone(320, 0, .08, .08, 'square'); },
  chip(){ noise(.25, 4200, .5, 'highpass'); tone(2400, 0, .2, .05, 'square'); tone(1700, .05, .2, .04, 'square'); },
  shatter(){ noise(.7, 3200, .6, 'highpass'); [1800, 1400, 1000, 700].forEach((f, k) => tone(f, k * .06, .2, .05, 'square')); },
  sting(){ tone(98, 0, .7, .1, 'sawtooth'); tone(104, 0, .7, .08, 'sawtooth'); noise(.5, 2600, .18, 'highpass'); },
  heart(){ tone(55, 0, .18, .2, 'sine'); tone(50, .2, .2, .14, 'sine'); },
  pebble(){ [0, 1, 2, 3].forEach(k => tone(900 - k * 140, .4 + k * .5, .12, .035 / (k + 1), 'triangle')); },""")
rep("const buzz = p => {", """let ambN = null;
function ambStart(){
  const a = ac(); if (!a || ambN) return;
  const len = a.sampleRate * 3, b = a.createBuffer(1, len, a.sampleRate), d = b.getChannelData(0); let last = 0;
  for (let i = 0; i < len; i++) { last = (last + .02 * (Math.random() * 2 - 1)) / 1.02; d[i] = last * 3.5; }
  const src = a.createBufferSource(); src.buffer = b; src.loop = true;
  const f = a.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 170;
  const g = a.createGain(); g.gain.setValueAtTime(0, a.currentTime); g.gain.linearRampToValueAtTime(.3, a.currentTime + 2.5);
  src.connect(f); f.connect(g); g.connect(a.destination); src.start(); ambN = {src, g};
}
function ambStop(){ if (!ambN || !AC) return; try { ambN.g.gain.linearRampToValueAtTime(0, AC.currentTime + .4); ambN.src.stop(AC.currentTime + .5); } catch (e) {} ambN = null; }
const buzz = p => {""")

# ---------- cave generation: landmarks ----------
between("  // crystal clusters growing out of the floor in open caves", "  // gas in dead ends", r"""  // landmarks: a glowing grotto, a lake (lava on the fire horizon), a chasm, old carts with notes
  lv.block = new Set(); lv.decor = {moss:[], rocks:[], crys:[]}; lv.marks = []; lv.pit = new Set(); lv.grot = []; lv.carts = [];
  const openAt = i => N8.every(([dx, dy]) => g[i + dx + dy * W] === 1);
  const centers = [];
  const pickC = minD => { const c = floors.filter(i => lv.dist[i] > minD && openAt(i) && centers.every(j => Math.hypot(i % W - j % W, Math.floor(i / W) - Math.floor(j / W)) > 9)); if (!c.length) return null; const i = c[ri(0, c.length - 1)]; centers.push(i); return i; };
  const disk = (c, r) => floors.filter(i => Math.hypot(i % W - c % W, Math.floor(i / W) - Math.floor(c / W)) <= r && lv.dist[i] > 4 && !lv.block.has(i));
  const shut = j => lv.block.has(j) || lv.lava.has(j);
  // would closing these cells cut off part of the mine?
  const keepsLinked = cells => { const off = new Set(cells), seen = new Uint8Array(W * H), q = [idx(lift.x, lift.y)]; seen[q[0]] = 1; let n = 1;
    while (q.length) { const i = q.pop(); for (const [dx, dy] of N4) { const j = i + dx + dy * W; if (!seen[j] && g[j] === 1 && !off.has(j) && !shut(j)) { seen[j] = 1; n++; q.push(j); } } }
    return n === floors.filter(i => !off.has(i) && !shut(i)).length; };
  const gc = pickC(10);
  if (gc !== null) { lv.grot = disk(gc, 3.2); lv.marks.push({type:'grot', c:gc, cells:lv.grot, found:false}); }
  const lc = pickC(8);
  if (lc !== null) {
    if (b.id === 'fire') { const cells = disk(lc, rnd(1.6, 2.3)); if (keepsLinked(cells)) { cells.forEach(i => lv.lava.set(i, {shown:true, pool:true})); lv.marks.push({type:'lava', c:lc, cells, found:false}); } }
    else { const cells = disk(lc, b.id === 'flood' ? rnd(3, 4) : rnd(2.4, 3.2)); cells.forEach(i => lv.water.set(i, {shown:false, lake:true})); lv.marks.push({type:'lake', c:lc, cells, found:false}); }
  }
  const pc = pickC(7);
  if (pc !== null) { const cells = [pc, ...N8.map(([dx, dy]) => pc + dx + dy * W).filter(() => Math.random() < .7)];
    if (keepsLinked(cells)) { cells.forEach(i => { lv.pit.add(i); lv.block.add(i); }); lv.marks.push({type:'pit', c:pc, cells, found:false}); } }
  for (let k = 0; k < 2; k++) {
    const c = floors.filter(i => lv.dist[i] > 8 && !shut(i) && !lv.water.has(i) && N4.filter(([dx, dy]) => !g[i + dx + dy * W]).length === 1 && lv.carts.every(o => Math.abs(o.i % W - i % W) + Math.abs(Math.floor(o.i / W) - Math.floor(i / W)) > 12));
    if (!c.length) break;
    const i = pickW(c.map(i => [i, lv.dist[i]])); lv.carts.push({i, wall:N4.find(([dx, dy]) => !g[i + dx + dy * W]), used:false, work:0, mesh:null});
  }
  // crystal clusters growing out of the floor: in the grotto, on the shore, in open caves
  const floorDep = (i, boost) => { const d = Math.min(1, lv.dist[i] / lv.maxD + boost);
    const kind = pickW([['druse', 3], ['crystal', 2], ['geode', 1 + d * 2]]);
    const sid = kind === 'geode' ? null : pickW(Object.entries(b.pool).filter(([s]) => s !== 'gold' && s !== 'pyrite').map(([s, wt]) => [s, wt * Math.pow(1 + d * 2.4, SP[s].r)]));
    const face = N4.map(([dx, dy]) => i + dx + dy * W).find(j => g[j] === 1 && !shut(j)) ?? i;
    lv.block.add(i); lv.deps.push({id:lv.deps.length, i, x:i % W, y:Math.floor(i / W), face, kind, sid, d, work:0, mesh:null, floor:true}); };
  const free = i => !shut(i) && !lv.water.has(i) && !lv.carts.some(c => c.i === i) && keepsLinked([i]);
  const placeIn = (cells, n, boost) => { const c = cells.filter(openAt); for (let k = 0, tries = 0; k < n && c.length && tries < 24; tries++) { const i = c.splice(ri(0, c.length - 1), 1)[0]; if (free(i)) { floorDep(i, boost); k++; } } };
  if (lv.grot.length) placeIn(lv.grot, 2, .3);
  const pool = lv.marks.find(m => m.type === 'lake' || m.type === 'lava');
  if (pool) { const inPool = new Set(pool.cells); placeIn(floors.filter(i => !inPool.has(i) && N4.some(([dx, dy]) => inPool.has(i + dx + dy * W))), 1, .2); }
  placeIn(floors.filter(i => lv.dist[i] > 9), 5, 0);
  for (const i of floors) {
    if (lv.dist[i] < 3 || shut(i) || lv.water.has(i)) continue;
    const nearWall = N4.some(([dx, dy]) => !g[i + dx + dy * W]);
    if (nearWall && Math.random() < .22) lv.decor.rocks.push(i);
    if (Math.random() < (b.id === 'flood' ? .1 : .055)) lv.decor.moss.push(i);
    if (nearWall && Math.random() < .045) lv.decor.crys.push(i);
  }
""")
rep("const lairs = floors.filter(i => lv.dist[i] > 14);", "const lairs = floors.filter(i => lv.dist[i] > 14 && !shut(i));")
rep("  for (let k = 0; k < b.golems && rich[k]; k++) lv.mons.push(newMon('golem', rich[k].face));",
    "  for (let k = 0; k < b.golems && rich[k]; k++) lv.mons.push(newMon('golem', rich[k].face));\n"
    "  // something lives in the grotto\n"
    "  const lair = lv.grot.find(i => !shut(i)); if (lair !== undefined) lv.mons.push(newMon('crawler', lair));")

# ---------- camera: tilted like Bullet Echo ----------
rep("const CAM = {h:14, back:2.6};", "const CAM = {h:14, back:9, pitch:56 * Math.PI / 180, x:0, z:0, lx:0, lz:0};")
rep("const half = Math.tan(25 * Math.PI / 180) * a; CAM.h = Math.max(10, Math.min(15.5, 4.4 / half)); CAM.back = CAM.h * .22; }",
    "const half = Math.tan(25 * Math.PI / 180) * a, D = Math.max(11, Math.min(17, 4.2 / half)); CAM.h = D * Math.sin(CAM.pitch); CAM.back = D * Math.cos(CAM.pitch); }")
rep("h = rnd(1.15, 1.75);", "h = rnd(1, 1.4);")
rep("""  camera.position.x += (S.pos.x - camera.position.x) * Math.min(1, dt * 5) + (Math.random() - .5) * sh;
  camera.position.z += (S.pos.z + CAM.back - camera.position.z) * Math.min(1, dt * 5) + (Math.random() - .5) * sh;
  camera.position.y = CAM.h; camera.lookAt(camera.position.x, 0, camera.position.z - CAM.back);""",
"""  // the camera leans the way the lamp looks
  CAM.lx += (fx * 1.4 - CAM.lx) * Math.min(1, dt * 2.5); CAM.lz += (fz * 1.4 - CAM.lz) * Math.min(1, dt * 2.5);
  CAM.x += (S.pos.x + CAM.lx - CAM.x) * Math.min(1, dt * 5); CAM.z += (S.pos.z + CAM.lz - CAM.z) * Math.min(1, dt * 5);
  camera.position.set(CAM.x + (Math.random() - .5) * sh, CAM.h, CAM.z + CAM.back + (Math.random() - .5) * sh); camera.lookAt(CAM.x, 0, CAM.z);""")
rep("  camera.position.set(S.pos.x, CAM.h, S.pos.z + CAM.back);",
    "  CAM.x = S.pos.x; CAM.z = S.pos.z; CAM.lx = 0; CAM.lz = -1.4; camera.position.set(CAM.x, CAM.h, CAM.z + CAM.back);\n"
    "  ambStart(); $('#dread').style.opacity = 0;")

# ---------- scene: rarity glints, landmarks ----------
rep("    const tint = dep.kind === 'geode' ? 0xc690ff : color;\n    const gl = new THREE.Sprite(new THREE.SpriteMaterial({map:glintTex, color:tint,",
    "    const tint = dep.kind === 'geode' ? 0xc690ff : color, rr = dep.sid ? SP[dep.sid].r : 2;\n"
    "    // the glint carries the rarity colour: you can tell a jackpot from the edge of the beam\n"
    "    const gl = new THREE.Sprite(new THREE.SpriteMaterial({map:glintTex, color:dep.kind === 'geode' ? 0xc690ff : RC[rr],")
rep("gl.scale.set(1.2, 1.2, 1.2); gl.position.set(0, dep.floor ? .5 : .1, 0); g.add(gl);",
    "gl.scale.setScalar(1 + rr * .22); gl.position.set(0, dep.floor ? .5 : .1, 0); g.add(gl);")
rep("  // lift: the one warm light down here", r"""  // landmarks
  const qf = new THREE.Quaternion().setFromEuler(new THREE.Euler(-Math.PI / 2, 0, 0)), one = new THREE.Vector3(1, 1, 1);
  if (L.grot.length) { const GC = GROT_C[L.b.id], cells = L.grot.filter(i => !L.block.has(i));
    const gm = new THREE.InstancedMesh(new THREE.OctahedronGeometry(.11, 0), new THREE.MeshStandardMaterial({color:new THREE.Color(GC).multiplyScalar(.45), emissive:GC, emissiveIntensity:.3, roughness:.12, metalness:.2, flatShading:true}), cells.length * 5);
    let k = 0; for (const i of cells) { const ws = N4.filter(([dx, dy]) => !L.g[i + dx + dy * W]);
      for (let m = 0; m < 5; m++) { const s = rnd(.8, 2.7), side = ws.length && Math.random() < .65 ? ws[ri(0, ws.length - 1)] : [rnd(-.6, .6), rnd(-.6, .6)];
        e.set(rnd(-.6, .6), rnd(0, 3), rnd(-.6, .6)); q.setFromEuler(e);
        mt.compose(new THREE.Vector3(wx(i % W) + side[0] * .42 + rnd(-.2, .2), .12 * s, wz(Math.floor(i / W)) + side[1] * .42 + rnd(-.2, .2)), q, new THREE.Vector3(s * .8, s * 3, s * .8)); gm.setMatrixAt(k++, mt); } }
    gm.count = k; scene.add(gm);
    const c = L.marks.find(m => m.type === 'grot').c, gLight = new THREE.PointLight(GC, .8, 5.5, 2); gLight.position.set(wx(c % W), .7, wz(Math.floor(c / W))); scene.add(gLight); }
  if (L.pit.size) {
    const pm = new THREE.InstancedMesh(new THREE.PlaneGeometry(1.03, 1.03), new THREE.MeshBasicMaterial({color:0x000000}), L.pit.size); let k = 0;
    for (const i of L.pit) { mt.compose(new THREE.Vector3(wx(i % W), .012, wz(Math.floor(i / W))), qf, one); pm.setMatrixAt(k++, mt); } scene.add(pm);
    const edge = []; for (const i of L.pit) for (const [dx, dy] of N4) { const j = i + dx + dy * W; if (!L.pit.has(j) && L.g[j]) edge.push([i, dx, dy]); }
    const rm = new THREE.InstancedMesh(new THREE.DodecahedronGeometry(.12, 0), new THREE.MeshStandardMaterial({color:0x6a5a4a, roughness:.95, flatShading:true}), edge.length * 3); k = 0;
    for (const [i, dx, dy] of edge) for (let n = 0; n < 3; n++) { e.set(rnd(0, 3), rnd(0, 3), rnd(0, 3)); q.setFromEuler(e); const s = rnd(.6, 1.4), t = rnd(-.45, .45);
      mt.compose(new THREE.Vector3(wx(i % W) + dx * .5 + (dy ? t : 0), .04 * s, wz(Math.floor(i / W)) + dy * .5 + (dx ? t : 0)), q, new THREE.Vector3(s, s * .6, s)); rm.setMatrixAt(k++, mt); }
    scene.add(rm);
    const c = L.marks.find(m => m.type === 'pit').c, deep = new THREE.Mesh(new THREE.CircleGeometry(1.3, 24), new THREE.MeshBasicMaterial({map:haloTex, color:L.b.id === 'fire' ? 0xff4010 : 0x1e4060, transparent:true, opacity:L.b.id === 'fire' ? .55 : .3, blending:THREE.AdditiveBlending, depthWrite:false}));
    deep.rotation.x = -Math.PI / 2; deep.position.set(wx(c % W), .02, wz(Math.floor(c / W))); scene.add(deep); }
  for (const c of L.carts) {
    const g = new THREE.Group(), wood = new THREE.MeshStandardMaterial({color:0x5a4128, roughness:.85}), iron = new THREE.MeshStandardMaterial({color:0x3a3632, roughness:.55, metalness:.7});
    const body = new THREE.Mesh(new THREE.BoxGeometry(.8, .4, .52), wood); body.position.y = .36; body.castShadow = true; g.add(body);
    const rim = new THREE.Mesh(new THREE.BoxGeometry(.84, .05, .56), iron); rim.position.y = .57; g.add(rim);
    for (const [a, z] of [[-.26, -.27], [.26, -.27], [-.26, .27], [.26, .27]]) { const w = new THREE.Mesh(new THREE.CylinderGeometry(.11, .11, .05, 10), iron); w.rotation.x = Math.PI / 2; w.position.set(a, .11, z); g.add(w); }
    for (const z of [-.27, .27]) { const r = new THREE.Mesh(new THREE.BoxGeometry(2.4, .03, .04), iron); r.position.set(0, .02, z); g.add(r); }
    for (let n = -2; n <= 2; n++) { const sl = new THREE.Mesh(new THREE.BoxGeometry(.09, .03, .78), wood); sl.position.set(n * .5, .01, 0); g.add(sl); }
    const lump = new THREE.Mesh(new THREE.DodecahedronGeometry(.2, 0), new THREE.MeshStandardMaterial({color:0x9a9488, roughness:.7, flatShading:true})); lump.position.set(.1, .55, 0); lump.scale.set(1.3, .6, 1); g.add(lump);
    const [dx, dy] = c.wall; g.position.set(wx(c.i % W) + dx * .14, 0, wz(Math.floor(c.i / W)) + dy * .14); g.rotation.y = dx ? Math.PI / 2 : 0; c.mesh = g; scene.add(g); }

  // lift: the one warm light down here""")
rep("  faceSmooth = Math.PI;\n  resize3();\n}", "  faceSmooth = Math.PI;\n  syncTiles(waterMesh, L.water, .06); syncTiles(lavaMesh, L.lava, .04);\n  resize3();\n}")

# ---------- run state ----------
rep("hurtFlash:0, kills:0};", "hurtFlash:0, kills:0, dread:0, heartT:0, flickT:0, ambT:2, recs:{}, digDep:null};")
rep("  canvas.hidden = true; ['#hud', '#bottom', '#compass', '#work', '#joy', '#film'].forEach(s => $(s).hidden = true);",
    "  canvas.hidden = true; ['#hud', '#bottom', '#compass', '#work', '#joy', '#film', '#dig', '#findcard', '#note'].forEach(s => $(s).hidden = true);\n  ambStop(); $('#dread').style.opacity = 0;")

# ---------- draw ----------
rep("const frac = S.lamp / S.lampMax, flick = frac < .15 && on ? (Math.random() < .1 ? .3 : 1) : 1;",
    "const frac = S.lamp / S.lampMax, flick = on && S.flickT > 0 ? (Math.random() < .5 ? .12 : .6) : frac < .15 && on ? (Math.random() < .1 ? .3 : 1) : 1;")
rep("    u.glint.material.opacity = lit * (.35 + .65 * tw);",
    "    u.glint.material.opacity = lit * (.35 + .65 * tw) + (dep.hint ? .1 + .6 * Math.pow(Math.max(0, Math.sin(t * 3.1 + u.phase)), 8) : 0);")
rep("    mo.eyes.children.forEach(e => e.material.opacity = mo.lit ? .5 : .5 + .4 * Math.sin(t * 3 + mo.x));",
    "    const blink = !mo.lit && Math.sin(t * .8 + mo.home) > .95;\n"
    "    mo.eyes.children.forEach(e => e.material.opacity = blink ? 0 : mo.lit ? .5 : .55 + .35 * Math.sin(t * 3 + mo.x));")

# ---------- tick: ambience, glimmers at the edge of the beam, landmark discovery ----------
rep("  // input: joystick / keys / tap-path", """  // the mine breathes: drips and creaks from left and right; the lamp stutters when something is close
  S.ambT -= dt;
  if (S.ambT <= 0) { S.ambT = rnd(1.8, 5); const p = rnd(-.9, .9); if (Math.random() < .75) SFX.drip(p); else SFX.creak(p); }
  if (S.lamp > 0 && Math.random() < S.dread * dt * 1.4) S.flickT = rnd(.08, .3);
  S.flickT = Math.max(0, S.flickT - dt);
  // input: joystick / keys / tap-path""")
rep("    for (const dep of L.deps) if (dep.mesh) dep.lit = litBy(dep.mesh.position.x, dep.mesh.position.z) || (Math.hypot(dep.mesh.position.x - S.pos.x, dep.mesh.position.z - S.pos.z) < 1.3);",
    """    for (const dep of L.deps) if (dep.mesh) { const p = dep.mesh.position;
      dep.lit = litBy(p.x, p.z) || Math.hypot(p.x - S.pos.x, p.z - S.pos.z) < 1.3;
      dep.hint = !dep.lit && S.lamp > 0 && edgeOfBeam(p.x, p.z);
      if ((dep.lit || dep.hint) && !dep.noticed) { dep.noticed = true; SFX.shimmer(dep.sid ? SP[dep.sid].r : 2, clamp1((p.x - S.pos.x) / 6)); } }
    for (const m of L.marks) if (!m.found && m.cells.some(i => L.seen[i])) discover(m);""")
rep("function noiseAt(r){", """// just outside the cone: far glints still catch the eye
function edgeOfBeam(x, z){
  const dx = x - S.pos.x, dz = z - S.pos.z, d = Math.hypot(dx, dz);
  if (d > spot.distance * 1.3) return false;
  let a = Math.atan2(dx, dz) - S.face; a = Math.atan2(Math.sin(a), Math.cos(a));
  return Math.abs(a) < spot.angle * 2.4 && los(S.pos.x, S.pos.z, x, z);
}
const MARKS = {grot:['Кристаллический грот', 'Стены заросли кристаллами — они светятся сами. Самое ценное здесь, но здесь и кто-то живёт.'],
  lake:['Подземное озеро', 'Вода ледяная: в ней идёшь медленнее, а фонарь садится быстрее.'],
  lava:['Лавовое озеро', 'Не подходите вплотную. Рядом с жаром растут рубины.'],
  pit:['Провал', 'Дна не видно. Брошенный камень летит очень долго.']};
function discover(m){
  m.found = true; const [t, d] = MARKS[m.type];
  toast(t, d, '', m.type === 'grot' ? hex(GROT_C[L.b.id]) : m.type === 'lake' ? 'var(--water)' : m.type === 'lava' ? 'var(--lava)' : 'var(--muted)');
  if (m.type === 'pit') SFX.pebble(); else SFX.shimmer(2, 0);
}
function noiseAt(r){""")

# ---------- acting: careful chipping vs. a risky strong blow ----------
rep("    return showWork('Отбиваетесь', 1, 'var(--danger)');", "    $('#dig').hidden = true; S.digDep = null;\n    return showWork('Отбиваетесь', 1, 'var(--danger)');")
rep("""  const tg = adjTarget();
  if (!tg) return hideWork();
  faceTo(tg.i);""", """  const tg = adjTarget();
  if (!tg) return hideWork();
  if (tg.k !== 'trophy') { $('#dig').hidden = true; S.digDep = null; }
  if (tg.i !== S.cell) faceTo(tg.i);""")
rep("""  } else if (tg.k === 'trophy') {
    const need = tg.o.kind === 'geode' ? 4 : tg.o.kind === 'druse' ? 3.5 : 2.6;
    tg.o.work += dt * speed;
    showWork(tg.o.kind === 'geode' ? 'Вынимаете жеоду' : `${KIND[tg.o.kind]}: аккуратно вынимаете`, tg.o.work / need, tg.o.sid ? hex(SP[tg.o.sid].c) : '#c690ff');
    S.pickT = (S.pickT || 0) - dt; if (S.pickT <= 0) { S.pickT = .45; SFX.pick(); noiseAt(8); sparkGas(); }
    if (tg.o.work >= need) takeTrophy(tg.o);""", """  } else if (tg.k === 'trophy') {
    // careful chipping is slow and safe; the strong blow is fast and can split the crystal
    const dep = tg.o;
    if (dep.hp === undefined) { dep.hp = 3; dep.heat = 0; dep.need = dep.kind === 'geode' ? 5 : dep.kind === 'druse' ? 4.5 : dep.kind === 'nugget' ? 2.2 : 3.4; }
    dep.work += dt * speed * .55; dep.heat = Math.max(0, dep.heat - dt * .6); S.digDep = dep;
    showWork(dep.kind === 'geode' ? 'Обкалываете жеоду' : `${KIND[dep.kind]}: аккуратно обкалываете`, dep.work / dep.need, dep.sid ? hex(SP[dep.sid].c) : '#c690ff');
    showDig(dep);
    S.pickT = (S.pickT || 0) - dt; if (S.pickT <= 0) { S.pickT = .45; SFX.pick(); noiseAt(8); sparkGas(); }
    if (dep.work >= dep.need) takeTrophy(dep);
  } else if (tg.k === 'cart') {
    tg.o.work += dt; showWork('Осматриваете вагонетку', tg.o.work / 1.4, '#d9c39a');
    S.pickT = (S.pickT || 0) - dt; if (S.pickT <= 0) { S.pickT = .5; SFX.step(); }
    if (tg.o.work >= 1.4) openCart(tg.o);""")
rep("  for (const [dx, dy] of N4) { const j = S.cell + dx + dy * W; if (L.rubble.has(j)) return {k:'rubble', o:L.rubble.get(j), i:j}; }",
    "  for (const c of L.carts) if (!c.used && (c.i === S.cell || near(c.i))) return {k:'cart', o:c, i:c.i};\n"
    "  for (const [dx, dy] of N4) { const j = S.cell + dx + dy * W; if (L.rubble.has(j)) return {k:'rubble', o:L.rubble.get(j), i:j}; }")
rep("function hideWork(){ $('#work').hidden = true; }", r"""function hideWork(){ $('#work').hidden = true; $('#dig').hidden = true; if (S) S.digDep = null; }
const digRisk = dep => Math.min(.85, .06 + dep.heat * .13 + (dep.kind === 'druse' ? .05 : 0));
function showDig(dep){
  const el = $('#dig'); el.hidden = false;
  const r = Math.round(digRisk(dep) * 100), key = dep.hp + ':' + r; if (el.dataset.k === key) return; el.dataset.k = key;
  $('#digPips').innerHTML = [0, 1, 2].map(k => `<i class="${k < dep.hp ? 'on' : ''}"></i>`).join('');
  $('#digRisk').textContent = `быстрее · риск скола ${r}%`;
  el.style.setProperty('--rk', r > 40 ? 'var(--danger)' : r > 18 ? 'var(--lamp)' : 'var(--anom)');
}
function strike(){
  const dep = S && S.mode === 'walk' && S.digDep; if (!dep || !dep.mesh) return;
  const risk = digRisk(dep); dep.heat += 1;
  SFX.strike(); S.shake = Math.max(S.shake, .12); buzz(12); noiseAt(9); sparkGas();
  const [x, y] = elXY($('#work')); burst(x, y - 30, {n:8, colors:['#8a7660', '#b09a80'], speed:3, grav:.3, size:4, kind:'chip'});
  if (Math.random() < risk) {
    dep.hp--; S.shake = .35; buzz([30, 30, 60]); anim($('#dig'), 'bad');
    if (dep.hp <= 0) { SFX.shatter(); return takeTrophy(dep); }
    SFX.chip(); toast('Скол!', `Трофей треснул: качество ниже. Осталось ${dep.hp} из 3.`, '', 'var(--danger)');
  } else { dep.work += dep.need * .24 * (1 + .2 * save.up.pick); anim($('#dig'), 'good'); }
  if (dep.work >= dep.need) takeTrophy(dep); else showDig(dep);
}
function findCard(item, rec){
  const el = $('#findcard'), geo = item.kind === 'geode', shard = item.dmg >= 3, r = geo ? 2 : SP[item.sid].r, col = shard ? '#8a7a6a' : geo ? '#c690ff' : RC[r];
  el.style.setProperty('--fc', col);
  el.innerHTML = `<div class="fimg">${itemImg(item)}</div><div><div class="fr">${shard ? 'раскололся' : geo ? 'жеода · что внутри — загадка' : RAR[r]}</div><b>${itemName(item)}</b><span class="fw">${fmtW(item.g)}</span>${item.dmg && !shard ? `<span class="fd"> · сколов: ${item.dmg}</span>` : ''}${rec ? `<em>${rec}</em>` : ''}</div>`;
  el.hidden = false; anim(el, 'pop'); clearTimeout(findCard.t); findCard.t = setTimeout(() => { el.hidden = true; }, rec ? 4300 : 3000);
  if (shard) return;
  const f = document.createElement('div'); f.className = 'gemflash'; f.style.setProperty('--fc', col); document.body.appendChild(f); setTimeout(() => f.remove(), 950);
  const [x, y] = elXY(el); burst(x, y, {n:16 + r * 10, colors:[col, '#ffffff'], speed:3 + r, size:3.2});
}
const dirName = (dx, dy) => { const ns = dy < 0 ? 'северо' : 'юго', ew = dx > 0 ? 'востоку' : 'западу', ax = Math.abs(dx), ay = Math.abs(dy);
  return ax > ay * 2 ? `К ${ew}` : ay > ax * 2 ? `К ${dy < 0 ? 'северу' : 'югу'}` : `К ${ns}-${ew}`; };
function openCart(c){
  c.used = true; hideWork();
  const was = S.lamp; S.lamp = Math.min(S.lampMax, S.lamp + 30); SFX.ore();
  const tgt = L.marks.find(m => !m.found && !m.hinted);
  let text = 'Самое богатое — в дальних выработках, где темнее всего. Береги карбид и не стой к темноте спиной.';
  if (tgt) { tgt.hinted = true; const dir = dirName(tgt.c % W - c.i % W, Math.floor(tgt.c / W) - Math.floor(c.i / W));
    text = {grot:`${dir} отсюда — грот, весь в кристаллах, светится сам по себе. Мы туда не пошли: что-то там шуршало.`,
      lake:`${dir} — подземное озеро. По берегу что-то блестит, но вода ледяная и карбид в ней садится вдвое.`,
      lava:`${dir} жар такой, что сапоги дымятся. Там течёт сама земля, а камни рядом красные, как кровь.`,
      pit:`${dir} — провал. Бросил камень и так и не услышал дна.`}[tgt.type]; }
  const el = $('#note');
  el.innerHTML = `«${text}»<span class="sig">— ${NOTE_SIG[ri(0, NOTE_SIG.length - 1)]}</span><span class="gain">В вагонетке карбид: фонарь +${Math.round(S.lamp - was)} с</span>`;
  el.hidden = false; anim(el, 'fx-in'); clearTimeout(openCart.t); openCart.t = setTimeout(() => { el.hidden = true; }, 9000);
  hudTick();
}""")

# ---------- taking a trophy: weight, damage, the card, a provisional record ----------
between("function takeTrophy(dep){", "function sparkGas(){", r"""function takeTrophy(dep){
  const dmg = dep.hp === undefined ? 0 : 3 - Math.max(0, dep.hp), shard = dmg >= 3;
  dep.g = dep.g || rollW(dep.kind, dep.d);
  const area = shard ? [1, 1] : dep.kind === 'geode' ? [2, 2] : dep.kind === 'druse' ? [2, 2] : dep.kind === 'nugget' ? [1, 1] : [1, 2];
  const item = {id:nid(), kind:dep.kind, sid:dep.sid, w:area[0], h:area[1], d:dep.d, depth:Math.round(Math.max(0, L.dist[dep.face]) * 4), biome:S.b.id, g:Math.round(shard ? dep.g * rnd(.08, .2) : dep.g), dmg};
  scene.remove(dep.mesh); dep.mesh = null; hideWork(); if (dep.floor) L.block.delete(dep.i);
  let rec = '';
  if (!shard) {
    const k = dep.kind === 'geode' ? 'geode' : dep.sid, prev = Math.max(save.rec[k] || 0, S.recs[k] || 0);
    if (item.g > prev) { S.recs[k] = item.g; rec = prev ? `Рекорд вида! Было ${fmtW(prev)} — донесите до лифта` : 'Первый такой — донесите до лифта'; }
    SFX.trophy(dep.sid ? SP[dep.sid].r : 2);
  }
  findCard(item, rec);
  if (!place(S.bag, item)) { S.pending = item; openBag(); }
  hud(); ctx();
}
""")
assert "function sparkGas(){" in s

# ---------- monsters: wandering, glimpses, dread ----------
between("function monsters(dt){", "function hazards(dt){", r"""function stepPath(mo, spd, dt){
  const n = mo.path[0]; if (n === undefined) return;
  const tx = wx(n % W), tz = wz(Math.floor(n / W)), ex = tx - mo.x, ez = tz - mo.z, ed = Math.hypot(ex, ez);
  if (ed < .1) mo.path.shift(); else { const st = Math.min(ed, spd * dt); mo.x += ex / ed * st; mo.z += ez / ed * st; mo.heading = Math.atan2(ex, ez); }
}
function monsters(dt){
  let dread = 0;
  for (const mo of L.mons) {
    if (!mo.alive) continue;
    const dx = S.pos.x - mo.x, dz = S.pos.z - mo.z, d = Math.hypot(dx, dz), pan = clamp1(-dx / 6);
    mo.lit = litBy(mo.x, mo.z);
    // catching one in the beam out of nowhere
    if (mo.lit && !mo.wasLit && S.t - (mo.stungT ?? -99) > 7) { mo.stungT = S.t; SFX.sting(); S.shake = Math.max(S.shake, .3); buzz(40); }
    mo.wasLit = mo.lit;
    mo.near = mo.state === 'hunt' ? d < 8 : d < 3.5;
    mo.cd -= dt; mo.stun = Math.max(0, (mo.stun || 0) - dt);
    if (mo.state === 'sleep') {
      if (d < (S.lamp > 0 ? 3 : 6) || (mo.lit && mo.type === 'crawler')) { mo.state = 'hunt'; if (mo.type === 'golem') SFX.growl(pan); continue; }
      // crawlers wander around their lair
      if (mo.type === 'crawler') {
        mo.roamT = (mo.roamT ?? rnd(1, 5)) - dt;
        if (mo.roamT <= 0) { mo.roamT = rnd(4, 9); const t = mo.home + ri(-4, 4) + ri(-4, 4) * W; if (t > 0 && t < W * H && walkable(t)) mo.path = path(cellAt(mo.x, mo.z), t, 300) || []; }
        stepPath(mo, .9, dt);
      }
      continue;
    }
    if (!mo.lit) dread = Math.max(dread, 1 - d / 7);
    let spd = 0;
    if (mo.type === 'crawler') {
      // light freezes a crawler; in the dark it closes in
      spd = mo.lit && S.lamp > 0 ? -.6 : 2.25;
    } else {
      // a golem is drawn to light and loses you in the dark
      if (mo.lit && S.lamp > 0) { mo.anger = 4; } else mo.anger = Math.max(0, (mo.anger || 0) - dt);
      spd = mo.anger > 0 ? 1.7 : 0;
      if (!mo.anger) { const hx = wx(mo.home % W) - mo.x, hz = wz(Math.floor(mo.home / W)) - mo.z, hd = Math.hypot(hx, hz); if (hd > .3) { mo.x += hx / hd * dt; mo.z += hz / hd * dt; } }
    }
    if (mo.stun > 0) spd = 0;
    if (spd !== 0 && d > .7) {
      mo.pathT -= dt;
      if (spd > 0) { if (mo.pathT <= 0) { mo.pathT = .5; mo.path = path(cellAt(mo.x, mo.z), S.cell, 900) || []; } stepPath(mo, spd, dt); }
      else { mo.heading = Math.atan2(dx, dz); const nx = mo.x - dx / d * -spd * dt, nz = mo.z - dz / d * -spd * dt; if (walkable(cellAt(nx, nz))) { mo.x = nx; mo.z = nz; } }
    }
    if (d < .85 && mo.cd <= 0 && mo.stun <= 0) { mo.cd = mo.type === 'golem' ? 1.6 : 1.2; hurt(mo.type === 'golem' ? 2 : 1, mo.type === 'golem' ? 'Удар голема' : 'Ползун вцепился в ногу'); }
    mo.sound -= dt;
    if (!mo.lit && d < 9 && mo.sound <= 0) { mo.sound = rnd(1.2, 2.4); mo.type === 'crawler' ? SFX.skitter(1 - d / 9, pan) : SFX.growl(pan); }
  }
  // something is close and you can't see it
  S.dread += (dread - S.dread) * Math.min(1, dt * 3);
  if (S.dread > .3) { S.heartT -= dt; if (S.heartT <= 0) { S.heartT = 1.15 - S.dread * .55; SFX.heart(); } }
}
""")
rep("  $('#hOil').classList.toggle('low', f < .25);", "  $('#hOil').classList.toggle('low', f < .25);\n  $('#dread').style.opacity = Math.min(.9, S.dread).toFixed(2);")

# ---------- leaving: records only count once they are up top ----------
rep("  save.st.ups++; save.st.deepest = Math.max(save.st.deepest, depth); persist();",
    "  let recs = 0; for (const it of items) if (!(it.dmg >= 3) && it.g) { const k = it.kind === 'geode' ? 'geode' : it.sid; if (it.g > (save.rec[k] || 0)) { save.rec[k] = it.g; recs++; } }\n"
    "  save.st.ups++; save.st.deepest = Math.max(save.st.deepest, depth); persist();")
rep("<div class=\"row\"><span>Глубина</span><span>${depth} м</span></div></div>",
    "<div class=\"row\"><span>Глубина</span><span>${depth} м</span></div>${recs ? `<div class=\"row\"><span>Рекорды веса</span><span>★ ${recs}</span></div>` : ''}</div>")
rep("${items.map(it => `<div class=\"fc dirty\">${itemImg(it)}<span class=\"n\">${itemName(it)}</span><span class=\"m\">${it.w}×${it.h}</span></div>`).join('')}",
    "${items.map(it => `<div class=\"fc dirty\">${itemImg(it)}<span class=\"n\">${itemName(it)}</span><span class=\"m\">${it.g ? fmtW(it.g) : `${it.w}×${it.h}`}</span></div>`).join('')}")

# ---------- lab value: weight and chips matter ----------
rep("  const gi = pickW(GR.map((g, k) => [k, g.w * Math.pow(luck, k * .55)]));\n  const sizeM = [0, 1, 2.2, 3.6, 5.2][it.w * it.h] || 5;\n  return {sid, gi, value:Math.round(SP[sid].v * sizeM * GR[gi].m * (it.kind === 'geode' ? 1.8 : 1))};",
    "  const dm = Math.min(3, it.dmg || 0), gi = Math.max(0, pickW(GR.map((g, k) => [k, g.w * Math.pow(luck, k * .55)])) - Math.min(dm, 2));\n"
    "  const sizeM = [0, 1, 2.2, 3.6, 5.2][it.w * it.h] || 5, wf = it.g ? Math.max(.4, Math.min(3, it.g / WMED[it.kind])) : 1;\n"
    "  return {sid, gi, value:Math.round(SP[sid].v * sizeM * GR[gi].m * (it.kind === 'geode' ? 1.8 : 1) * Math.pow(wf, .8) * [1, .75, .5, .15][dm])};")
rep("<dl><dt>Размер</dt><dd>${it.w}×${it.h}</dd>",
    "<dl>${it.g ? `<dt>Вес</dt><dd>${fmtW(it.g)}</dd>` : `<dt>Размер</dt><dd>${it.w}×${it.h}</dd>`}${it.dmg ? `<dt>Сколы</dt><dd>${it.dmg >= 3 ? 'обломки' : it.dmg}</dd>` : ''}")
rep("<div class=\"st-top\"><div class=\"t\">${itemName(it)}</div><div class=\"s\">${BIOM[it.biome].name} · ${it.depth} м · ${it.w}×${it.h}</div></div>",
    "<div class=\"st-top\"><div class=\"t\">${itemName(it)}</div><div class=\"s\">${BIOM[it.biome].name} · ${it.depth} м · ${it.g ? fmtW(it.g) : `${it.w}×${it.h}`}</div></div>")
rep("<span class=\"m\">${it.w}×${it.h} · ${it.depth} м</span></button>`).join('')}</div>",
    "<span class=\"m\">${it.g ? fmtW(it.g) : `${it.w}×${it.h}`} · ${it.depth} м</span></button>`).join('')}</div>")
rep("save.coll.push({id:it.id, sid:res.sid, gi:res.gi, value:res.value, biome:it.biome, depth:it.depth, size:`${it.w}×${it.h}`});",
    "save.coll.push({id:it.id, sid:res.sid, gi:res.gi, value:res.value, biome:it.biome, depth:it.depth, size:`${it.w}×${it.h}`, g:it.g});")
rep("<div class=\"row\"><span>Размер</span><span>${s.size}</span></div>", "<div class=\"row\"><span>${s.g ? 'Вес' : 'Размер'}</span><span>${s.g ? fmtW(s.g) : s.size}</span></div>")

# ---------- museum: weight records ----------
rep("      <div class=\"rows\"><div class=\"row\"><span>Спусков</span>",
    "      ${Object.keys(save.rec).length ? `<div class=\"sec-h\"><h2>Рекорды веса</h2></div><div class=\"rows\">${Object.entries(save.rec).sort((a, b) => (b[0] === 'geode' ? 2 : SP[b[0]].r) - (a[0] === 'geode' ? 2 : SP[a[0]].r) || b[1] - a[1]).map(([k, g]) => `<div class=\"row\"><span>${k === 'geode' ? 'Жеода' : SP[k].n}</span><span>${fmtW(g)}</span></div>`).join('')}</div>` : ''}\n"
    "      <div class=\"rows\"><div class=\"row\"><span>Спусков</span>")

# ---------- input & help ----------
rep("$('#bottom').addEventListener('click', e => {",
    "$('#digBtn').addEventListener('pointerdown', e => { e.preventDefault(); e.stopPropagation(); ac(); strike(); });\n"
    "$('#findcard').addEventListener('click', () => $('#findcard').hidden = true);\n"
    "$('#note').addEventListener('click', () => $('#note').hidden = true);\n"
    "$('#bottom').addEventListener('click', e => {")
rep("    <li>Остановитесь — шахтёр работает сам: отбивается от монстра рядом, долбит жилу, вынимает трофей, разбирает завал.</li>",
    "    <li>Остановитесь — шахтёр работает сам: отбивается от монстра рядом, долбит жилу, вынимает трофей, разбирает завал.</li>\n"
    "    <li>Трофей он обкалывает медленно и бережно. «Сильный удар» быстрее, но может дать скол. Чем чаще бьёте, тем выше риск, а три скола превращают находку в обломки.</li>\n"
    "    <li>Цвет блика подсказывает редкость ещё с края луча. У каждой находки есть вес. Рекорд засчитывается, только если вы донесёте её до лифта.</li>\n"
    "    <li>В старых вагонетках есть карбид для фонаря и записки прошлых бригад: они подсказывают, где грот, озеро или провал.</li>")
rep("Ползуны замирают в луче и подкрадываются в темноте — особенно пока вы стоите лицом к стене и работаете.",
    "Ползуны замирают в луче и подкрадываются в темноте — особенно пока вы стоите лицом к стене и работаете. Слушайте: шорох слышен с той стороны, откуда он идёт, а если застучало сердце, кто-то совсем рядом.")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
