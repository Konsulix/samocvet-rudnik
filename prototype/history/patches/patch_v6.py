"""v6 of «Забой»: zonal darkness — lit havens (lift, old lanterns, fungi, grotto, lake, lava) and deep dark with the best loot."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:100])
    s = s.replace(a, b)

# ---------------- generation: fungi fields, old lanterns along the main drifts ----------------
rep("  // gas in dead ends", r"""  // glowing fungus fields and old lanterns hung along the main drifts
  lv.fungi = [];
  if (b.id !== 'fire') for (const i of lv.decor.moss.slice().sort(() => Math.random() - .5)) {
    if (lv.fungi.length >= 12) break;
    if (lv.dist[i] > 6 && lv.fungi.every(j => Math.abs(j % W - i % W) + Math.abs(Math.floor(j / W) - Math.floor(i / W)) > 6)) lv.fungi.push(i); }
  lv.lamps = [];
  { const goals = lv.marks.filter(m => m.type !== 'pit').map(m => m.c); let far = 0; for (const i of floors) if (lv.dist[i] > lv.dist[far]) far = i; if (goals.length < 2) goals.push(far);
    for (const goal of goals) { let i = goal; const road = [];
      while (lv.dist[i] > 0) { road.push(i); const nx = N4.map(([dx, dy]) => i + dx + dy * W).find(j => lv.dist[j] === lv.dist[i] - 1); if (nx === undefined) break; i = nx; }
      road.reverse(); let next = ri(5, 7);
      for (let k = 0; k < road.length; k++) { const c = road[k]; if (k < next || lv.dist[c] < 5) continue;
        const wall = N4.find(([dx, dy]) => !g[c + dx + dy * W]);
        if (!wall || lv.lamps.some(l => Math.abs(l.i % W - c % W) + Math.abs(Math.floor(l.i / W) - Math.floor(c / W)) < 5)) continue;
        lv.lamps.push({i:c, wall, on:Math.random() < .7}); next = k + ri(6, 9); } } }
  // gas in dead ends""")

# ---------------- generation: the light map, loot that rewards the dark, lairs in the dark ----------------
rep("  const lair = lv.grot.find(i => !shut(i)); if (lair !== undefined) lv.mons.push(newMon('crawler', lair));\n  return lv;",
r"""  const lair = lv.grot.find(i => !shut(i)); if (lair !== undefined) lv.mons.push(newMon('crawler', lair));
  // where the mine is lit without your lamp: light spreads along the floor and stops at rock
  const lum = new Float32Array(W * H * 3), srcs = [], rgb = c => [(c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255];
  srcs.push({i:idx(lift.x, lift.y), col:[1, .72, .42], r:6.5, k:.6});
  for (const l of lv.lamps) if (l.on) srcs.push({i:l.i, col:[1, .7, .4], r:4.5, k:.5});
  for (const i of lv.fungi) srcs.push({i, col:rgb(LOOK[b.id].glow || 0x9fffb0), r:3.4, k:.42});
  for (const m of lv.marks) {
    if (m.type === 'grot') srcs.push({i:m.c, col:rgb(GROT_C[b.id]), r:6.5, k:.65});
    if (m.type === 'lake') srcs.push({i:m.c, col:[.35, .75, .95], r:4.5, k:.32});
    if (m.type === 'lava') srcs.push({i:m.c, col:[1, .42, .12], r:6, k:.85});
    if (m.type === 'pit') srcs.push({i:m.c, col:b.id === 'fire' ? [1, .35, .1] : [.2, .4, .6], r:2.6, k:.3}); }
  for (const sr of srcs) { const sx = sr.i % W, sy = Math.floor(sr.i / W), seen = new Set([sr.i]), q = [sr.i];
    while (q.length) { const i = q.shift(), d = Math.hypot(i % W - sx, Math.floor(i / W) - sy), v = sr.k * Math.pow(Math.max(0, 1 - d / sr.r), 1.6);
      for (let c = 0; c < 3; c++) lum[i * 3 + c] += sr.col[c] * v;
      for (const [dx, dy] of N4) { const j = i + dx + dy * W; if (!seen.has(j) && g[j] === 1 && Math.hypot(j % W - sx, Math.floor(j / W) - sy) < sr.r) { seen.add(j); q.push(j); } } } }
  // rock faces catch the light of the floor in front of them
  for (let i = 0; i < W * H; i++) if (!g[i]) for (const [dx, dy] of N4) { const j = i + dx + dy * W; if (j >= 0 && j < W * H && g[j] === 1) for (let c = 0; c < 3; c++) lum[i * 3 + c] = Math.max(lum[i * 3 + c], lum[j * 3 + c] * .85); }
  lv.lum = lum; lv.lumAt = i => i < 0 || i >= W * H ? 0 : (lum[i * 3] + lum[i * 3 + 1] + lum[i * 3 + 2]) / 3;
  // the deep dark pays: richer finds where no light reaches
  const rollSid = (d, floor) => pickW(Object.entries(b.pool).filter(([s]) => s !== 'gold' && (!floor || s !== 'pyrite')).map(([s, wt]) => [s, wt * Math.pow(1 + d * 2.4, SP[s].r)]));
  for (const dep of lv.deps) { const dark = Math.max(0, 1 - lv.lumAt(dep.face) * 6); dep.dark = dark;
    if (dark > .6) { dep.d = Math.min(1, dep.d + .3 * dark); if (dep.sid && dep.kind !== 'nugget') dep.sid = rollSid(dep.d, dep.floor); } }
  for (let k = 0; k < 4; k++) { const w = take(w => lv.dist[w.face] > 10 && lv.lumAt(w.face) < .02, () => 1); if (!w) break; const d = Math.min(1, lv.dist[w.face] / lv.maxD + .35);
    const kind = pickW([['crystal', 3], ['druse', 3], ['geode', 2]]); lv.deps.push({id:lv.deps.length, i:w.i, x:w.x, y:w.y, face:w.face, kind, sid:kind === 'geode' ? null : rollSid(d, false), d, work:0, mesh:null, seenT:0, dark:1}); }
  // crawlers make their lairs in the dark
  const darkLairs = floors.filter(i => lv.dist[i] > 12 && !shut(i) && lv.lumAt(i) < .03);
  for (const mo of lv.mons) if (mo.type === 'crawler' && mo.home !== lair && darkLairs.length) { const i = darkLairs.splice(ri(0, darkLairs.length - 1), 1)[0]; Object.assign(mo, {home:i, x:(i % W) - W / 2 + .5, z:Math.floor(i / W) - H / 2 + .5}); }
  return lv;""")

# ---------------- rendering: the light map on every lit surface ----------------
rep("let gridTex = null, mist = null,", r"""const ZONE = {tex:{value:null}, flick:{value:1}};
function makeZoneTex(){
  const d = new Uint8Array(W * H * 4); for (let i = 0; i < W * H; i++) for (let c = 0; c < 3; c++) d[i * 4 + c] = Math.min(255, L.lum[i * 3 + c] * 255);
  const t = new THREE.DataTexture(d, W, H, THREE.RGBAFormat); t.magFilter = t.minFilter = THREE.LinearFilter; t.needsUpdate = true; return t;
}
// any lit material also receives the mine's own light from the zone map
function zoneify(mat, tag = 'z'){
  if (!mat || !mat.isMeshStandardMaterial || mat.userData.zoned) return; mat.userData.zoned = true;
  const prev = mat.onBeforeCompile;
  mat.onBeforeCompile = (sh, r) => {
    if (prev) prev.call(mat, sh, r);
    sh.uniforms.uZone = ZONE.tex; sh.uniforms.uZF = ZONE.flick;
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec2 vZW;`).replace('#include <project_vertex>', `#include <project_vertex>
      vec4 zwp = vec4(transformed, 1.0);
      #ifdef USE_INSTANCING
        zwp = instanceMatrix * zwp;
      #endif
      vZW = (modelMatrix * zwp).xz;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform sampler2D uZone; uniform float uZF; varying vec2 vZW;`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      totalEmissiveRadiance += diffuseColor.rgb * texture2D(uZone, (vZW + vec2(${W / 2}.0, ${H / 2}.0)) / vec2(${W}.0, ${H}.0)).rgb * uZF * 1.15;`);
  };
  mat.customProgramCacheKey = () => tag;
  mat.needsUpdate = true;
}
let gridTex = null, mist = null,""")
rep("  const look = LOOK[L.b.id]; gridTex = makeGridTex();", "  const look = LOOK[L.b.id]; gridTex = makeGridTex(); ZONE.tex.value = makeZoneTex();")
rep("    const spots = L.decor.moss.filter(() => Math.random() < .35).slice(0, 16);",
    "    const spots = L.fungi.flatMap(i => [i, ...N8.map(([dx, dy]) => i + dx + dy * W).filter(j => L.g[j] && !L.block.has(j) && !L.water.has(j) && Math.random() < .4)]);")
rep("""  faceSmooth = Math.PI;
  syncTiles(waterMesh, L.water, .06); syncTiles(lavaMesh, L.lava, .04);
  resize3();""", r"""  // old lanterns on the drift walls; some still burn
  for (const lp of L.lamps) { const g = new THREE.Group(), [dx, dy] = lp.wall;
    const box = new THREE.Mesh(new THREE.BoxGeometry(.13, .19, .13), new THREE.MeshBasicMaterial({color:lp.on ? 0xffcf88 : 0x2a2420})); box.position.y = 1.02; g.add(box);
    const cap = new THREE.Mesh(new THREE.ConeGeometry(.11, .09, 6), new THREE.MeshBasicMaterial({color:0x1c1814})); cap.position.y = 1.15; g.add(cap);
    if (lp.on) { const h = new THREE.Sprite(new THREE.SpriteMaterial({map:haloTex, color:0xffb060, blending:THREE.AdditiveBlending, depthWrite:false, transparent:true, opacity:.6})); h.scale.setScalar(1.7); h.position.y = 1.02; g.add(h); lp.halo = h; }
    g.position.set(wx(lp.i % W) + dx * .4, 0, wz(Math.floor(lp.i / W)) + dy * .4); scene.add(g); }
  faceSmooth = Math.PI;
  syncTiles(waterMesh, L.water, .06); syncTiles(lavaMesh, L.lava, .04);
  zoneify(floorMat, 'zf'); zoneify(wallMat, 'zw');
  scene.traverse(o => { const m = o.material; if (Array.isArray(m)) m.forEach(x => zoneify(x)); else zoneify(m); });
  resize3();""")
rep("  const g = new THREE.Group(), mat = new THREE.MeshStandardMaterial({color:0x7a6a5a, roughness:.95, flatShading:true});",
    "  const g = new THREE.Group(), mat = new THREE.MeshStandardMaterial({color:0x7a6a5a, roughness:.95, flatShading:true}); zoneify(mat);")
rep("  SHARED.t.value = t;", "  SHARED.t.value = t;\n  ZONE.flick.value = .93 + .07 * Math.sin(t * 6.3) * Math.sin(t * 2.7);\n  for (const lp of L.lamps) if (lp.halo) lp.halo.material.opacity = .5 * ZONE.flick.value + Math.random() * .03;")

# ---------------- what the light means ----------------
rep("""function litBy(x, z){
  if (S.flare && Math.hypot(x - S.flare.x, z - S.flare.z) < 4.2 && los(S.flare.x, S.flare.z, x, z)) return true;
  if (S.lamp <= 0)""", """const zoneAt = (x, z) => L.lumAt(cellAt(x, z));
// seen if it stands in the mine's own light, in a flare, or in your beam
function litBy(x, z){
  if (S.flare && Math.hypot(x - S.flare.x, z - S.flare.z) < 4.2 && los(S.flare.x, S.flare.z, x, z)) return true;
  if (zoneAt(x, z) > .16 && Math.hypot(x - S.pos.x, z - S.pos.z) < 12) return true;
  return litByLamp(x, z);
}
function litByLamp(x, z){
  if (S.lamp <= 0)""")
rep("|| (mo.lit && mo.type === 'crawler')) {", "|| (mo.type === 'crawler' && S.lamp > 0 && litByLamp(mo.x, mo.z))) {")
rep("spd = mo.lit && S.lamp > 0 ? -.6 : 2.25;", "spd = mo.lit ? -.6 : 2.25; // any light: the beam, a flare, a lantern, the fungi")
rep("if (mo.lit && S.lamp > 0) { mo.anger = 4; }", "if (S.lamp > 0 && litByLamp(mo.x, mo.z)) { mo.anger = 4; }")
rep("if (S.lamp <= 0) { S.darkT += dt;", "if (S.lamp <= 0 && zoneAt(S.pos.x, S.pos.z) < .16) { S.darkT += dt;")
rep("  if (S.lamp <= 0) w.push('Темно — к лифту');\n  else if (f < .25) w.push('Фонарь гаснет — пора назад');",
    "  const zl = zoneAt(S.pos.x, S.pos.z);\n"
    "  if (S.lamp <= 0) w.push(zl > .16 ? 'Здесь светло — ползуны не подойдут' : 'Темно — к свету или к лифту');\n"
    "  else if (f < .25) w.push('Фонарь гаснет — пора назад');\n"
    "  else if (zl < .03 && L.dist[S.cell] > 8) w.push('Глухая тьма');")
rep("$('#dread').style.opacity = Math.min(.9, S.dread).toFixed(2);", "$('#dread').style.opacity = Math.min(.9, S.dread + (zoneAt(S.pos.x, S.pos.z) < .03 ? .22 : 0)).toFixed(2);")
rep("    <li>Белый круг вокруг шахтёра", "    <li>Шахта освещена местами: у лифта, под старыми фонарями, у светящихся грибов, в гроте, у озера и лавы. Там всё видно без фонаря, и ползуны туда не заходят. Если фонарь погас, беги к свету. Самое ценное лежит в глухой тьме.</li>\n    <li>Белый круг вокруг шахтёра")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
