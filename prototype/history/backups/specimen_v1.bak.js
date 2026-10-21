/* ===================== specimens: every find is a one-off mineral sculpture ===================== */
// crystal habit per species
const HABIT = {quartz:'prism', amethyst:'prism', calcite:'scaleno', fluorite:'cube', malachite:'botryoid', azurite:'botryoid', gypsum:'blade', pyrite:'cube', gold:'nugget',
  garnet:'dodeca', beryl:'prism', aquamarine:'prism', emerald:'prism', opal:'botryoid', sapphire:'barrel', ruby:'barrel', diamond:'octa', nativecu:'nugget', cuprite:'octa',
  chrysocolla:'botryoid', halite:'cube', sylvite:'cube', celestine:'blade', anhydrite:'blade', pyrope:'dodeca', chrysolite:'prism'};
// rare traits: each one changes the look and the price
const TRAITS = [
  {id:'irid', n:'радужная плёнка', p:.16, m:1.4},
  {id:'moss', n:'моховик', p:.14, m:1.15},
  {id:'coral', n:'коралловая корка', p:.14, m:1.2},
  {id:'phantom', n:'фантом', p:.1, m:1.3},
  {id:'twin', n:'двойник', p:.09, m:1.25},
  {id:'bubbles', n:'газовые пузырьки', p:.09, m:1.2},
  {id:'scepter', n:'скипетр', p:.04, m:1.8},
  {id:'aurora', n:'северное сияние', p:.015, m:3},
];
const TR = Object.fromEntries(TRAITS.map(t => [t.id, t]));
function rollTraits(it, gi){
  const rng = mulberry(it.id * 7919 + 13), luck = 1 + gi * .15 + save.up.lab * .1 + (it.legend ? 1.2 : 0), out = [];
  for (const t of TRAITS) if (rng() < t.p * luck) out.push(t.id);
  return out.slice(0, 3);
}
const SPEC = {r:null, scene:null, cam:null, env:null, live:null, raf:0, host:null};
function specInit(){
  if (SPEC.r) return true;
  if (!window.THREE) return false;
  const c = document.createElement('canvas'); c.width = c.height = 512; c.className = 'specv';
  try { SPEC.r = new THREE.WebGLRenderer({canvas:c, antialias:true}); } catch (e) { SPEC.r = null; return false; }
  const r = SPEC.r; r.setPixelRatio(1); r.setSize(512, 512, false);
  r.outputEncoding = THREE.sRGBEncoding; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = .9;
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  const s = SPEC.scene = new THREE.Scene(); s.background = new THREE.Color(0xe3e2de);
  // a soft studio for reflections and refraction: grey room, big white softboxes
  const es = new THREE.Scene(); es.add(new THREE.Mesh(new THREE.BoxGeometry(10, 10, 10), new THREE.MeshBasicMaterial({color:0x2e2e2c, side:THREE.BackSide})));
  for (const [x, y, z, w, h] of [[0, 4.9, 0, 6, 6], [-4.9, 1.2, 1, 4, 3], [4.9, 2, -1, 3, 4], [0, 1, 4.9, 6, 2.5], [1, -1, -4.9, 4, 2]]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({color:0xffffff, side:THREE.DoubleSide})); p.position.set(x, y, z); p.lookAt(0, 0, 0); es.add(p); }
  const pm = new THREE.PMREMGenerator(r); SPEC.env = pm.fromScene(es, .03).texture; s.environment = SPEC.env;
  s.add(new THREE.HemisphereLight(0xffffff, 0x8a867e, .35));
  const key = new THREE.DirectionalLight(0xfff2e2, 1.25); key.position.set(2.2, 4, 3); key.castShadow = true; key.shadow.mapSize.set(1024, 1024);
  Object.assign(key.shadow.camera, {left:-2, right:2, top:2, bottom:-2}); key.shadow.bias = -.0006; key.shadow.radius = 5; s.add(key);
  const rim = new THREE.DirectionalLight(0xdce6ff, .8); rim.position.set(-3, 2, -3); s.add(rim);
  // the museum stand: plinth, disc, thin rod
  const white = new THREE.MeshStandardMaterial({color:0xf2f1ec, roughness:.85}), steel = new THREE.MeshStandardMaterial({color:0xc4c4c4, metalness:1, roughness:.28});
  const plinth = new THREE.Mesh(new THREE.BoxGeometry(2.6, .6, 1.7), white); plinth.position.y = -1.62; plinth.receiveShadow = true; s.add(plinth);
  const disc = new THREE.Mesh(new THREE.CylinderGeometry(.24, .24, .014, 40), steel); disc.position.y = -1.313; disc.receiveShadow = true; s.add(disc);
  const rod = new THREE.Mesh(new THREE.CylinderGeometry(.013, .013, .56, 10), steel); rod.position.y = -1.03; rod.castShadow = true; s.add(rod);
  SPEC.cam = new THREE.PerspectiveCamera(28, 1, .1, 50); SPEC.cam.position.set(0, .45, 6.4); SPEC.cam.lookAt(0, .28, 0);
  return true;
}
// a thin oily rainbow over the crystal faces
function irid(mat, k){
  mat.onBeforeCompile = sh => {
    sh.uniforms.uIr = {value:k};
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vOP;`).replace('#include <begin_vertex>', `#include <begin_vertex>
      vOP = position;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform float uIr; varying vec3 vOP;`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      float fr = 1.0 - abs(dot(normalize(normal), normalize(vViewPosition)));
      float hue = fr * 2.4 + sin(vOP.x * 9.0 + vOP.y * 5.0) * .35 + sin(vOP.z * 11.0 - vOP.y * 7.0) * .25;
      vec3 ir = .5 + .5 * cos(6.2832 * (hue + vec3(0.0, .33, .67)));
      float msk = smoothstep(.15, .85, sin(vOP.y * 6.0 + vOP.x * 4.0 + vOP.z * 3.0) * .5 + .5);
      totalEmissiveRadiance += ir * uIr * (uIr > 1.5 ? .7 + .6 * fr : .2 + .8 * fr * fr) * (uIr > 1.5 ? 1.0 : .35 + .65 * msk);`);
  };
  mat.customProgramCacheKey = () => 'irid' + (mat.flatShading ? 'f' : 's');
  return mat;
}
function disposeTree(g){ g.traverse(o => { if (o.geometry) o.geometry.dispose(); if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(m => m.dispose()); }); }
// wobble every vertex by a function of its position, so shared corners stay together
function warp(g, rng, amt, freq = 1){
  const ks = Array.from({length:5}, () => [new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize().multiplyScalar((2 + rng() * 5) * freq), rng() * 6.3]);
  const p = g.attributes.position, v = new THREE.Vector3();
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); let n = 0; for (const [k, ph] of ks) n += Math.sin(v.dot(k) + ph); v.multiplyScalar(1 + n * amt / 5); p.setXYZ(i, v.x, v.y, v.z); }
  g.computeVertexNormals(); return g;
}
function crystalGeo(habit, rng, cfg){
  const r = .32, h = cfg.h || 1.1, tip = cfg.tip ?? (1.1 + rng() * .8);
  let g;
  if (habit === 'prism' || habit === 'blade') g = new THREE.LatheGeometry([new THREE.Vector2(0, 0), new THREE.Vector2(r, 0), new THREE.Vector2(r * (cfg.scepter ? .75 : 1), h * .62), new THREE.Vector2(r * (cfg.scepter ? 1.45 : 1), h * .72), new THREE.Vector2(r * (cfg.scepter ? 1.45 : 1), h), new THREE.Vector2(r * .08, h + r * tip), new THREE.Vector2(0, h + r * tip)], 6);
  else if (habit === 'barrel') g = new THREE.LatheGeometry([new THREE.Vector2(0, 0), new THREE.Vector2(r * .75, 0), new THREE.Vector2(r * 1.05, h * .3), new THREE.Vector2(r * 1.05, h * .7), new THREE.Vector2(r * .8, h), new THREE.Vector2(0, h)], 6);
  else if (habit === 'scaleno') { g = new THREE.OctahedronGeometry(.3, 0); g.scale(1, 2.4, 1); g.translate(0, .65, 0); }
  else if (habit === 'cube') { const s = .32 + rng() * .1; g = new THREE.BoxGeometry(s, s * (.9 + rng() * .3), s); g.translate(0, s * .5, 0); }
  else if (habit === 'octa') { g = new THREE.OctahedronGeometry(.32, 0); g.translate(0, .3, 0); }
  else if (habit === 'dodeca') { g = new THREE.DodecahedronGeometry(.3, 0); g.translate(0, .28, 0); }
  else { g = new THREE.SphereGeometry(.2, 20, 14); g.translate(0, .15, 0); }
  if (habit === 'blade') g.scale(1.3, 1, .38);
  g = g.index ? g.toNonIndexed() : g;
  // tiny irregularities so it looks grown, not machined
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i), z = p.getZ(i), n = Math.sin(x * 37 + y * 13) * Math.sin(z * 29 - y * 7); p.setXYZ(i, x * (1 + n * .05), y, z * (1 + n * .05)); }
  g.computeVertexNormals(); return g;
}
function gemGeo(cut){
  if (cut === 'cab') return new THREE.LatheGeometry([new THREE.Vector2(0, 0), new THREE.Vector2(.6, 0), new THREE.Vector2(.56, .16), new THREE.Vector2(.38, .34), new THREE.Vector2(0, .4)], 40);
  const n = cut === 'master' ? 16 : 8;
  return new THREE.LatheGeometry([new THREE.Vector2(0, 0), new THREE.Vector2(.58, .46), new THREE.Vector2(.62, .5), new THREE.Vector2(.44, .66), new THREE.Vector2(0, .7)], n);
}
// o: {seed, sid, kind, gi, traits, cut, legend}
function buildSpecimen(o){
  const rng = mulberry((o.seed || 1) * 2654435761 % 4294967296), sp = SP[o.sid] || SP.quartz, habit = HABIT[o.sid] || 'prism', tr = new Set(o.traits || []);
  const gi = o.gi ?? 1, root = new THREE.Group(), col = new THREE.Color(sp.c).convertSRGBToLinear();
  if (gi < 2) col.lerp(new THREE.Color(0xb8b4ac).convertSRGBToLinear(), .25 - gi * .1);
  const irk = tr.has('aurora') ? 1.9 : tr.has('irid') ? 1 : o.legend ? .45 : .14;
  const metal = habit === 'nugget' || o.sid === 'pyrite';
  // glass: see-through faces on both sides, strong studio reflections, a faint inner glow so the colour holds against the light backdrop
  const cmat = () => irid(metal ? new THREE.MeshPhysicalMaterial({color:col, metalness:.95, roughness:.25, clearcoat:1, flatShading:true, envMapIntensity:1.6})
    : new THREE.MeshPhysicalMaterial({color:col, emissive:col.clone().multiplyScalar(.12), roughness:Math.max(.02, .16 - gi * .035), metalness:.05, clearcoat:1, clearcoatRoughness:.04, flatShading:true, envMapIntensity:2.4,
      transparent:true, opacity:habit === 'octa' || habit === 'dodeca' ? .72 : Math.max(.42, .8 - gi * .09), side:THREE.DoubleSide, depthWrite:false}), irk);
  const add = (m, cast = true) => { m.castShadow = cast; m.receiveShadow = true; root.add(m); return m; };
  // a cut stone sits alone on the stand
  if (o.cut && o.cut !== 'broken') {
    const m = new THREE.MeshPhysicalMaterial({color:col, roughness:.02, transmission:.9, clearcoat:1, flatShading:o.cut !== 'cab', envMapIntensity:2.2});
    irid(m, o.cut === 'master' ? .45 : .2);
    const gem = add(new THREE.Mesh(gemGeo(o.cut), m)); gem.rotation.x = o.cut === 'cab' ? 0 : Math.PI; gem.position.y = o.cut === 'cab' ? 0 : .7;
    const prong = new THREE.MeshStandardMaterial({color:0xd8c38a, metalness:1, roughness:.25});
    for (let k = 0; k < 4; k++) { const pr = add(new THREE.Mesh(new THREE.CylinderGeometry(.02, .02, .3, 6), prong)); const a = k * Math.PI / 2 + .4; pr.position.set(Math.cos(a) * .52, .12, Math.sin(a) * .52); pr.rotation.z = Math.cos(a) * .4; pr.rotation.x = -Math.sin(a) * .4; }
    return root;
  }
  // host rock: porous, dark, with rusty and pale spots
  const rock = warp(new THREE.IcosahedronGeometry(.62, 3), rng, .55, 1.2); rock.scale(1.15, .58, .95);
  { const cc = new Float32Array(rock.attributes.position.count * 3), p = rock.attributes.position, base = new THREE.Color().setHSL(.07 + rng() * .05, .1 + rng() * .1, .1 + rng() * .08).convertSRGBToLinear(), rust = new THREE.Color(0x8a5a32).convertSRGBToLinear(), pale = new THREE.Color(0xb8b2a4).convertSRGBToLinear(), c = new THREE.Color();
    for (let i = 0; i < p.count; i++) { const n = Math.sin(p.getX(i) * 13 + p.getZ(i) * 9) * Math.sin(p.getY(i) * 17 + p.getX(i) * 5); c.copy(base);
      if (n > .7) c.lerp(rust, .3); else if (n < -.7) c.lerp(pale, .25); c.toArray(cc, i * 3); }
    rock.setAttribute('color', new THREE.BufferAttribute(cc, 3)); }
  const rockMesh = add(new THREE.Mesh(rock, new THREE.MeshStandardMaterial({vertexColors:true, roughness:.95, flatShading:true})));
  const pos = rock.attributes.position, top = [];
  for (let i = 0; i < pos.count; i += 3) if (pos.getY(i) > .05) top.push(new THREE.Vector3(pos.getX(i), pos.getY(i), pos.getZ(i)));
  const pick = () => top[Math.floor(rng() * top.length)] || new THREE.Vector3(0, .3, 0);
  // the crystals
  const kind = o.kind || 'crystal', many = kind === 'druse' || kind === 'geode' ? 5 + Math.floor(rng() * 6) : kind === 'nugget' ? 1 : 1 + Math.floor(rng() * 2);
  if (habit === 'nugget') {
    const g = warp(new THREE.IcosahedronGeometry(.42, 2), rng, 1.1, 1.6); g.scale(1.2, .8, 1);
    const m = add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({color:col, metalness:1, roughness:.3, flatShading:true, envMapIntensity:1.6}))); m.position.y = .35;
    for (let k = 0; k < 3; k++) { const s = add(new THREE.Mesh(warp(new THREE.IcosahedronGeometry(.14, 1), rng, 1, 2), m.material)); s.position.copy(pick()).multiplyScalar(1.05); }
  } else if (habit === 'botryoid') {
    const m = new THREE.MeshPhysicalMaterial({color:col, roughness:.18, clearcoat:1, clearcoatRoughness:.1, envMapIntensity:1.3}); if (o.sid === 'opal') irid(m, .9); else if (irk > .1) irid(m, irk);
    const n = 14 + Math.floor(rng() * 14);
    for (let k = 0; k < n; k++) { const s = add(new THREE.Mesh(new THREE.SphereGeometry(.07 + rng() * .14, 18, 12), m)); s.position.copy(pick()).multiplyScalar(.98); s.position.y += rng() * .08; }
  } else {
    const mat = cmat(), count = Math.max(1, many) * (tr.has('twin') && many < 3 ? 2 : 1); let first = null;
    for (let k = 0; k < count; k++) {
      const main = k === 0, h = main ? 1.15 + rng() * .5 : .45 + rng() * .6, s = main ? 1.2 + rng() * .3 : .55 + rng() * .5;
      const g = crystalGeo(habit, rng, {h, scepter:main && tr.has('scepter'), tip:kind === 'shard' || o.cut === 'broken' ? .05 : undefined});
      const c = add(new THREE.Mesh(g, mat)); if (main) first = c; const at = main ? new THREE.Vector3((rng() - .5) * .2, .3, (rng() - .5) * .2) : pick();
      c.position.copy(at); c.scale.setScalar(s);
      const lean = main ? .15 : .35 + rng() * .45, a = rng() * 6.28; c.rotation.set(Math.cos(a) * lean, rng() * 6.28, Math.sin(a) * lean);
      if (tr.has('twin') && k === 1) { c.position.copy(first.position); c.rotation.set(.9, rng() * 6.28, -.4); c.scale.setScalar(s * .9); }
      if (!metal && gi < 2) { const fog = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .85}), new THREE.MeshStandardMaterial({color:0xf2efe8, roughness:1, transparent:true, opacity:.35 - gi * .12, depthWrite:false})); fog.scale.setScalar(.7); fog.position.y = .04; c.add(fog); }
      if (main && tr.has('phantom')) { const ph = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .7}), new THREE.MeshStandardMaterial({color:col.clone().offsetHSL(.05, .2, -.15), roughness:.5, transparent:true, opacity:.55}));
        ph.scale.setScalar(.62); ph.position.y = .05; c.add(ph); }
    }
    if (kind === 'geode') { const rind = add(new THREE.Mesh(new THREE.TorusGeometry(.6, .06, 8, 40), new THREE.MeshStandardMaterial({color:0xd8d4e0, roughness:.4}))); rind.rotation.x = Math.PI / 2; rind.position.y = .22; rind.scale.set(1.1, .95, 1); }
  }
  // accessory growths, as on real specimens: moss, coral crust, gas bubbles, rust dust
  const inst = (geo, mat, n, place) => { const im = new THREE.InstancedMesh(geo, mat, n), mt = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), sc = new THREE.Vector3(), c = new THREE.Color();
    for (let k = 0; k < n; k++) { const r = place(k, e, sc, c); q.setFromEuler(e); mt.compose(r, q, sc); im.setMatrixAt(k, mt); im.setColorAt(k, c); } im.castShadow = true; add(im); };
  if (tr.has('coral') || rng() < .35) {
    const pal = [[0xff6a2a, 0xffb040, 0xd8302a], [0x3a6aff, 0x7fb4ff, 0x1a2a8a], [0xf4f0e8, 0xd8d0c0, 0xb8b0a0], [0xff4a8a, 0xffb0d0, 0x8a2a5a]][Math.floor(rng() * 4)];
    const seeds = Array.from({length:tr.has('coral') ? 6 : 2}, pick), n = tr.has('coral') ? 700 : 160;
    inst(new THREE.IcosahedronGeometry(1, 1), new THREE.MeshStandardMaterial({roughness:.75}), n, (k, e, sc, c) => { const s0 = seeds[k % seeds.length], r = rng() * .16;
      const v = s0.clone().add(new THREE.Vector3((rng() - .5) * r * 2, rng() * r * 1.4, (rng() - .5) * r * 2)); e.set(rng() * 3, rng() * 3, 0); sc.setScalar(.018 + rng() * .04); c.set(pal[Math.floor(rng() * 3)]).convertSRGBToLinear(); return v; });
  }
  if (tr.has('moss') || rng() < .2) {
    const seeds = Array.from({length:tr.has('moss') ? 7 : 2}, pick), n = tr.has('moss') ? 900 : 180;
    inst(new THREE.CylinderGeometry(.15, .5, 1, 4), new THREE.MeshStandardMaterial({roughness:.8}), n, (k, e, sc, c) => { const s0 = seeds[k % seeds.length], r = .14;
      const v = s0.clone().add(new THREE.Vector3((rng() - .5) * r * 2, rng() * .04, (rng() - .5) * r * 2)); e.set((rng() - .5) * 1.1, rng() * 3, (rng() - .5) * 1.1); const l = .04 + rng() * .1; sc.set(.01, l, .01); v.y += l / 2; c.setHSL(.2 + rng() * .1, .55 + rng() * .3, .28 + rng() * .25).convertSRGBToLinear(); return v; });
  }
  if (tr.has('bubbles')) {
    inst(new THREE.SphereGeometry(1, 14, 10), new THREE.MeshPhysicalMaterial({roughness:.02, transmission:.9, clearcoat:1, envMapIntensity:2}), 40, (k, e, sc, c) => { const v = pick().clone().multiplyScalar(1.02); v.y += rng() * .5; sc.setScalar(.015 + rng() * .05); c.set(0xffffff); return v; });
  }
  if (o.legend) { const halo = add(new THREE.Mesh(new THREE.TorusGeometry(.9, .008, 6, 80), new THREE.MeshBasicMaterial({color:0xe4ae39})), false); halo.rotation.x = Math.PI / 2; halo.position.y = .1; }
  return root;
}
// fit the specimen above the rod
// fit only real geometry: instanced growths report a unit-sphere box at the origin
function boxOf(g){ g.updateMatrixWorld(true); const b = new THREE.Box3(), t = new THREE.Box3();
  g.traverse(o => { if (o.isMesh && !o.isInstancedMesh && o.geometry) { if (!o.geometry.boundingBox) o.geometry.computeBoundingBox(); t.copy(o.geometry.boundingBox).applyMatrix4(o.matrixWorld); b.union(t); } }); return b; }
function seat(g){
  const b = boxOf(g), sz = b.getSize(new THREE.Vector3()), s = Math.min(2.45 / Math.max(.01, sz.y), 2.25 / Math.max(.01, sz.x, sz.z));
  g.scale.multiplyScalar(s); const b2 = boxOf(g), c = b2.getCenter(new THREE.Vector3());
  g.position.x -= c.x; g.position.z -= c.z; g.position.y += -.72 - b2.min.y; return g;
}
const specOf = (it, res) => ({seed:it.id, sid:res.sid, kind:it.kind, gi:res.gi, traits:res.traits, cut:res.cut, legend:it.legend});
const SPEC_CACHE = new Map();
function specThumb(o){
  const key = [o.seed, o.sid, o.kind, o.gi, (o.traits || []).join('.'), o.cut || '', o.legend ? 1 : 0].join('|');
  if (SPEC_CACHE.has(key)) return SPEC_CACHE.get(key);
  if (!specInit()) return null;
  const g = seat(buildSpecimen(o)); g.rotation.y = .5;
  if (SPEC.live) SPEC.live.visible = false;
  SPEC.scene.add(g); SPEC.r.render(SPEC.scene, SPEC.cam);
  const c = document.createElement('canvas'); c.width = c.height = 256; c.getContext('2d').drawImage(SPEC.r.domElement, 0, 0, 256, 256);
  const url = c.toDataURL('image/jpeg', .86);
  SPEC.scene.remove(g); disposeTree(g); if (SPEC.live) SPEC.live.visible = true;
  SPEC_CACHE.set(key, url); return url;
}
// the slowly turning specimen in the lab
function specMount(host, o){
  if (!host || !specInit()) return false;
  specUnmount();
  SPEC.live = seat(buildSpecimen(o)); SPEC.scene.add(SPEC.live); SPEC.host = host;
  host.innerHTML = ''; host.appendChild(SPEC.r.domElement); host.classList.add('live');
  let last = performance.now();
  const spin = now => { SPEC.raf = requestAnimationFrame(spin); const dt = Math.min(.05, (now - last) / 1000); last = now; if (SPEC.live) SPEC.live.rotation.y += dt * .45; SPEC.r.render(SPEC.scene, SPEC.cam); };
  SPEC.raf = requestAnimationFrame(spin); return true;
}
function specUnmount(){
  cancelAnimationFrame(SPEC.raf); SPEC.raf = 0;
  if (SPEC.live) { SPEC.scene.remove(SPEC.live); disposeTree(SPEC.live); SPEC.live = null; }
  if (SPEC.r && SPEC.r.domElement.parentNode) SPEC.r.domElement.remove();
}
// museum cards get their photos one per frame, so the screen never stalls
function fillSpecs(){
  const el = document.querySelector('img[data-spec]:not([data-done])'); if (!el) return;
  el.dataset.done = 1; const s = save.coll.find(x => x.id === +el.dataset.spec);
  if (s) { const u = specThumb({seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, cut:s.cut, legend:s.legend}); if (u) { el.src = u; el.style.filter = 'none'; el.classList.add('spec'); } }
  setTimeout(fillSpecs, 30);
}

