/* ===================== specimens: every find is a one-off mineral sculpture ===================== */
// crystal habit per species
const HABIT = {quartz:'prism', amethyst:'prism', calcite:'scaleno', fluorite:'cube', malachite:'botryoid', azurite:'botryoid', gypsum:'blade', pyrite:'cube', gold:'nugget',
  garnet:'dodeca', beryl:'prism', aquamarine:'prism', emerald:'prism', opal:'botryoid', sapphire:'barrel', ruby:'barrel', diamond:'octa', nativecu:'nugget', cuprite:'octa',
  chrysocolla:'botryoid', halite:'cube', sylvite:'cube', celestine:'blade', anhydrite:'blade', pyrope:'dodeca', chrysolite:'prism'};
// rare traits: each one changes the look and the price
const TRAITS = [
  {id:'irid', n:'радужная плёнка', p:.15, m:1.4},
  {id:'moss', n:'моховик', p:.12, m:1.15},
  {id:'coral', n:'коралловая корка', p:.12, m:1.2},
  {id:'zoned', n:'зональный', p:.1, m:1.3},
  {id:'phantom', n:'фантом', p:.09, m:1.3},
  {id:'twin', n:'двойник', p:.08, m:1.25},
  {id:'druzy', n:'щётка поверх', p:.08, m:1.25},
  {id:'bubbles', n:'газовые пузырьки', p:.08, m:1.2},
  {id:'rutile', n:'волосатик', p:.06, m:1.5},
  {id:'floater', n:'плавающий кристалл', p:.05, m:1.6},
  {id:'scepter', n:'скипетр', p:.04, m:1.8},
  {id:'aurora', n:'северное сияние', p:.015, m:3},
];
const TR = Object.fromEntries(TRAITS.map(t => [t.id, t]));
function rollTraits(it, gi){
  const rng = mulberry(it.id * 7919 + 13), luck = 1 + gi * .15 + save.up.lab * .1 + (it.legend ? 1.2 : 0), out = [];
  for (const t of TRAITS) if (rng() < t.p * luck) out.push(t.id);
  return out.slice(0, 3);
}
const SPEC = {r:null, scene:null, cam:null, env:null, live:null, raf:0, drag:null, spinV:.45, tilt:0, glow:null};
const canvasTex = (w, h, draw) => { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), c); const t = new THREE.CanvasTexture(c); return t; };
function specInit(){
  if (SPEC.r) return true;
  if (!window.THREE) return false;
  const c = document.createElement('canvas'); c.width = c.height = 512; c.className = 'specv';
  try { SPEC.r = new THREE.WebGLRenderer({canvas:c, antialias:true}); } catch (e) { SPEC.r = null; return false; }
  const r = SPEC.r; r.setPixelRatio(1); r.setSize(512, 512, false);
  r.outputEncoding = THREE.sRGBEncoding; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1;
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  const s = SPEC.scene = new THREE.Scene();
  // a dark void with a faint glow in the middle
  const bg = canvasTex(512, 512, x => { const g = x.createRadialGradient(256, 240, 10, 256, 256, 360); g.addColorStop(0, '#1e2a31'); g.addColorStop(.5, '#0d1418'); g.addColorStop(1, '#030506');
    x.fillStyle = g; x.fillRect(0, 0, 512, 512); const im = x.getImageData(0, 0, 512, 512);
    for (let i = 0; i < im.data.length; i += 4) { const n = (Math.random() - .5) * 6; im.data[i] += n; im.data[i + 1] += n; im.data[i + 2] += n; } x.putImageData(im, 0, 0); });
  bg.encoding = THREE.sRGBEncoding; s.background = bg;
  SPEC.grain = canvasTex(256, 256, (x, cv) => { const im = x.createImageData(256, 256);
    for (let i = 0; i < im.data.length; i += 4) { const v = 128 + (Math.random() - .5) * 200; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; }
    x.putImageData(im, 0, 0); x.filter = 'blur(1px)'; x.drawImage(cv, 0, 0); });
  SPEC.grain.wrapS = SPEC.grain.wrapT = THREE.RepeatWrapping; SPEC.grain.repeat.set(3, 3);
  // a soft studio for reflections and refraction: dark room, big white softboxes
  const es = new THREE.Scene(); es.add(new THREE.Mesh(new THREE.BoxGeometry(10, 10, 10), new THREE.MeshBasicMaterial({color:0x1a1c1e, side:THREE.BackSide})));
  for (const [x, y, z, w, h] of [[0, 4.9, 0, 6, 6], [-4.9, 1.2, 1, 4, 3], [4.9, 2, -1, 3, 4], [0, 1, 4.9, 6, 2.5], [1, -1, -4.9, 4, 2]]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({color:0xffffff, side:THREE.DoubleSide})); p.position.set(x, y, z); p.lookAt(0, 0, 0); es.add(p); }
  const pm = new THREE.PMREMGenerator(r); SPEC.env = pm.fromScene(es, .03).texture; s.environment = SPEC.env;
  s.add(new THREE.HemisphereLight(0xbfd4ff, 0x1a1410, .3));
  const key = new THREE.DirectionalLight(0xfff0dc, 1.45); key.position.set(2.5, 3.5, 3); key.castShadow = true; key.shadow.mapSize.set(1024, 1024);
  Object.assign(key.shadow.camera, {left:-2, right:2, top:2, bottom:-2}); key.shadow.bias = -.0006; key.shadow.radius = 4; s.add(key);
  // two rims, cold and warm, cut the silhouette out of the dark
  const rl = new THREE.DirectionalLight(0x8fb8ff, 1.4); rl.position.set(-3.5, 1.5, -2.5); s.add(rl);
  const rr = new THREE.DirectionalLight(0xffc890, .9); rr.position.set(3.5, .4, -3); s.add(rr);
  const fill = new THREE.DirectionalLight(0xffffff, .25); fill.position.set(0, -2, 4); s.add(fill);
  // the coloured haze behind the stone
  const haze = canvasTex(256, 256, x => { const g = x.createRadialGradient(128, 128, 0, 128, 128, 128); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(.4, 'rgba(255,255,255,.35)'); g.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = g; x.fillRect(0, 0, 256, 256); });
  SPEC.glow = new THREE.Mesh(new THREE.PlaneGeometry(6.5, 6.5), new THREE.MeshBasicMaterial({map:haze, transparent:true, depthWrite:false, blending:THREE.AdditiveBlending, color:0x334455}));
  SPEC.glow.position.z = -2.4; s.add(SPEC.glow);
  SPEC.cam = new THREE.PerspectiveCamera(28, 1, .1, 50); SPEC.cam.position.set(0, .3, 6.6); SPEC.cam.lookAt(0, 0, 0);
  // turn it with a finger; let go and it keeps spinning, slowing to a drift
  c.style.touchAction = 'none';
  c.addEventListener('pointerdown', e => { SPEC.drag = {x:e.clientX, y:e.clientY}; try { c.setPointerCapture(e.pointerId); } catch (er) {} });
  c.addEventListener('pointermove', e => { if (!SPEC.drag || !SPEC.live) return; const dx = e.clientX - SPEC.drag.x, dy = e.clientY - SPEC.drag.y; SPEC.drag.x = e.clientX; SPEC.drag.y = e.clientY;
    SPEC.live.rotation.y += dx * .012; SPEC.spinV = Math.max(-9, Math.min(9, dx * .7)); SPEC.tilt = Math.max(-.7, Math.min(.7, SPEC.tilt + dy * .008)); });
  const end = () => { SPEC.drag = null; }; c.addEventListener('pointerup', end); c.addEventListener('pointercancel', end);
  return true;
}
// crystal shading: oily rainbow film, growth striations, refraction of the studio with slight dispersion, optional banding
function irid(mat, k, rf = 0, st = 0, band = 0){
  mat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, {uIr:{value:k}, uRf:{value:rf}, uSt:{value:st}, uBd:{value:band}});
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vOP;`).replace('#include <begin_vertex>', `#include <begin_vertex>
      vOP = position;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform float uIr, uRf, uSt, uBd; varying vec3 vOP;`).replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
      float stb = sin(vOP.y * 70.0 + sin(vOP.x * 9.0 + vOP.z * 7.0) * 3.0) * sin(vOP.y * 23.0 + vOP.x * 5.0);
      normal = normalize(normal + uSt * vec3(0.0, stb * .075, 0.0));`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      if (uBd > 0.0) diffuseColor.rgb *= 1.0 - uBd * (.5 + .5 * sin(length(vOP) * 140.0 + sin(vOP.x * 20.0) * 1.5));
      float fr = 1.0 - abs(dot(normalize(normal), normalize(vViewPosition)));
      float hue = fr * 2.4 + sin(vOP.x * 9.0 + vOP.y * 5.0) * .35 + sin(vOP.z * 11.0 - vOP.y * 7.0) * .25;
      vec3 ir = .5 + .5 * cos(6.2832 * (hue + vec3(0.0, .33, .67)));
      float msk = smoothstep(.15, .85, sin(vOP.y * 6.0 + vOP.x * 4.0 + vOP.z * 3.0) * .5 + .5);
      totalEmissiveRadiance += ir * uIr * (uIr > 1.5 ? .7 + .6 * fr : .2 + .8 * fr * fr) * (uIr > 1.5 ? 1.0 : .35 + .65 * msk);
      #ifdef ENVMAP_TYPE_CUBE_UV
        if (uRf > 0.0) {
          vec3 nW = inverseTransformDirection(normalize(normal), viewMatrix), iW = inverseTransformDirection(normalize(-vViewPosition), viewMatrix);
          vec3 cr = vec3(textureCubeUV(envMap, refract(iW, nW, .64), .03).r, textureCubeUV(envMap, refract(iW, nW, .61), .03).g, textureCubeUV(envMap, refract(iW, nW, .58), .03).b);
          totalEmissiveRadiance += cr * diffuseColor.rgb * 1.3 * uRf;
        }
      #endif`);
  };
  mat.customProgramCacheKey = () => 'xtal' + (mat.flatShading ? 'f' : 's') + (mat.vertexColors ? 'v' : '') + (rf > 0 ? 'r' : '') + (st > 0 ? 's' : '') + (band > 0 ? 'b' : '');
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
const V2 = (x, y) => new THREE.Vector2(x, y);
// cfg: {h, tip, scepter, dt (both ends), cA, cB, zk (colour zoning)}
function crystalGeo(habit, rng, cfg){
  const r = .32, h = cfg.h || 1.1, tip = cfg.tip ?? (1.1 + rng() * .8), sc = cfg.scepter ? 1.45 : 1, low = cfg.dt ? -r * tip : 0;
  let g;
  if (habit === 'prism' || habit === 'blade') g = new THREE.LatheGeometry([V2(0, low), V2(cfg.dt ? r * .08 : r, cfg.dt ? low : 0), V2(r, 0), V2(r * (cfg.scepter ? .75 : 1), h * .62), V2(r * sc, h * .72), V2(r * sc, h), V2(r * .08, h + r * tip), V2(0, h + r * tip)], 6);
  else if (habit === 'barrel') g = new THREE.LatheGeometry([V2(0, 0), V2(r * .75, 0), V2(r * 1.05, h * .3), V2(r * 1.05, h * .7), V2(r * .8, h), V2(0, h)], 6);
  else if (habit === 'scaleno') { g = new THREE.OctahedronGeometry(.3, 0); g.scale(1, 2.4, 1); g.translate(0, .65, 0); }
  else if (habit === 'cube') { const s = .32 + rng() * .1; g = new THREE.BoxGeometry(s, s * (.9 + rng() * .3), s); g.translate(0, s * .5, 0); }
  else if (habit === 'octa') { g = new THREE.OctahedronGeometry(.32, 0); g.translate(0, .3, 0); }
  else if (habit === 'dodeca') { g = new THREE.DodecahedronGeometry(.3, 0); g.translate(0, .28, 0); }
  else { g = new THREE.SphereGeometry(.2, 20, 14); g.translate(0, .15, 0); }
  if (habit === 'blade') g.scale(1.3, 1, .38);
  g = g.index ? g.toNonIndexed() : g;
  // small irregularities and a few knocked-off corners near the tips
  const p = g.attributes.position, top = h * .82, hs = (x, y, z) => { const v = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return v - Math.floor(v); };
  let y0 = 1e9, y1 = -1e9;
  for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i), z = p.getZ(i), n = Math.sin(x * 37 + y * 13) * Math.sin(z * 29 - y * 7);
    const chip = (y > top || (cfg.dt && y < low * .6)) && hs(x, y, z) > .72 ? .78 : 1; p.setXYZ(i, x * (1 + n * .05) * chip, y - (chip < 1 ? .03 * Math.sign(y || 1) : 0), z * (1 + n * .05) * chip);
    y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  // colour along the length: plain, smoky base, coloured tip or two-tone
  const cc = new Float32Array(p.count * 3), cA = cfg.cA || new THREE.Color(1, 1, 1), cB = cfg.cB || cA, zk = cfg.zk || 0, c = new THREE.Color();
  for (let i = 0; i < p.count; i++) { const t = (p.getY(i) - y0) / Math.max(.001, y1 - y0); c.copy(cA).lerp(cB, zk * (t * t * (3 - 2 * t))); c.toArray(cc, i * 3); }
  g.setAttribute('color', new THREE.BufferAttribute(cc, 3));
  g.computeVertexNormals(); return g;
}
function gemGeo(cut){
  if (cut === 'cab') return new THREE.LatheGeometry([V2(0, 0), V2(.6, 0), V2(.56, .16), V2(.38, .34), V2(0, .4)], 40);
  const n = cut === 'master' ? 16 : 8;
  return new THREE.LatheGeometry([V2(0, 0), V2(.58, .46), V2(.62, .5), V2(.44, .66), V2(0, .7)], n);
}
// host rock of several kinds and shapes: lumpy, pitted, darker in the pits
const ROCKS = {
  basalt:{h:[.07, .05], s:[.08, .1], l:[.12, .08], crust:[.1, .12, .55], rust:0x7a4a2a},
  quartzite:{h:[.1, .03], s:[.03, .04], l:[.6, .1], crust:[.1, .05, .85], rust:0x9a7a5a},
  ironstone:{h:[.03, .02], s:[.4, .15], l:[.22, .06], crust:[.09, .5, .45], rust:0x4a2010},
  limestone:{h:[.1, .03], s:[.15, .08], l:[.5, .08], crust:[.12, .1, .82], rust:0xa07a40},
};
const ROCK_SHAPES = {slab:[1.35, .42, 1.05], chunk:[1.05, .72, .95], long:[1.55, .5, .75], small:[.8, .55, .75]};
function makeRock(rng, type, shape){
  const R = ROCKS[type], S = ROCK_SHAPES[shape], g = new THREE.IcosahedronGeometry(.62, 4), cav = new Float32Array(g.attributes.position.count);
  const p = g.attributes.position, v = new THREE.Vector3(), u = new THREE.Vector3();
  const ks = Array.from({length:7}, (_, k) => [new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize().multiplyScalar((2 + rng() * 4) * (1 + k * .6)), rng() * 6.3, .14 / (1 + k * .7)]);
  const pores = Array.from({length:type === 'quartzite' ? 25 : 55}, () => [new THREE.Vector3(rng() - .5, rng() * .9 - .2, rng() - .5).normalize(), .05 + rng() * .11, .06 + rng() * .14]);
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); u.copy(v).normalize(); let n = 0; for (const [k, ph, a] of ks) n += Math.sin(v.dot(k) + ph) * a;
    let pit = 0; for (const [c, r, d] of pores) { const dd = u.distanceTo(c); if (dd < r) pit = Math.max(pit, d * (1 - (dd / r) * (dd / r))); }
    v.multiplyScalar(1 + n - pit); cav[i] = pit * 5 + Math.max(0, -n) * 2; p.setXYZ(i, v.x, v.y, v.z); }
  g.scale(...S); g.computeVertexNormals();
  const cc = new Float32Array(p.count * 3), c = new THREE.Color();
  const base = new THREE.Color().setHSL(R.h[0] + rng() * R.h[1], R.s[0] + rng() * R.s[1], R.l[0] + rng() * R.l[1]).convertSRGBToLinear();
  const crust = new THREE.Color().setHSL(...R.crust).convertSRGBToLinear(), rust = new THREE.Color(R.rust).convertSRGBToLinear();
  for (let i = 0; i < p.count; i++) { const n = Math.sin(p.getX(i) * 11 + p.getZ(i) * 7) * Math.sin(p.getY(i) * 15 + p.getX(i) * 4); c.copy(base);
    if (n > .62) c.lerp(crust, .28); else if (n < -.72) c.lerp(rust, .3);
    c.multiplyScalar(Math.max(.25, 1 - cav[i] * .9)); c.toArray(cc, i * 3); }
  g.setAttribute('color', new THREE.BufferAttribute(cc, 3));
  const mesh = new THREE.Mesh(g, new THREE.MeshStandardMaterial({vertexColors:true, roughness:type === 'quartzite' ? .7 : .96, flatShading:true, bumpMap:SPEC.grain, bumpScale:.03}));
  const top = [], ymax = S[1] * .62; for (let i = 0; i < p.count; i += 3) if (p.getY(i) > ymax * .25) top.push(new THREE.Vector3(p.getX(i), p.getY(i), p.getZ(i)));
  const nrm = w => new THREE.Vector3(w.x / (S[0] * S[0]), w.y / (S[1] * S[1]), w.z / (S[2] * S[2])).normalize();
  return {mesh, top, nrm};
}
// o: {seed, sid, kind, gi, traits, cut, legend}
function buildSpecimen(o){
  const rng = mulberry((o.seed || 1) * 2654435761 % 4294967296), sp = SP[o.sid] || SP.quartz, habit = HABIT[o.sid] || 'prism', tr = new Set(o.traits || []);
  const gi = o.gi ?? 1, root = new THREE.Group(), col = new THREE.Color(sp.c).convertSRGBToLinear();
  col.offsetHSL((rng() - .5) * .03, (rng() - .5) * .15, (rng() - .5) * .06);
  if (gi < 2) col.lerp(new THREE.Color(0xb8b4ac).convertSRGBToLinear(), .25 - gi * .1);
  root.userData.glow = col.clone();
  const irk = tr.has('aurora') ? 1.9 : tr.has('irid') ? 1 : o.legend ? .45 : .14;
  const metal = habit === 'nugget' || o.sid === 'pyrite', up = new THREE.Vector3(0, 1, 0);
  const add = (m, cast = true, parent = root) => { m.castShadow = cast; m.receiveShadow = true; parent.add(m); return m; };
  // a cut stone floats alone, tilted to show its table and pavilion
  if (o.cut && o.cut !== 'broken') {
    const m = new THREE.MeshPhysicalMaterial({color:col, emissive:col.clone().multiplyScalar(.06), roughness:.02, metalness:.05, clearcoat:1, flatShading:o.cut !== 'cab', envMapIntensity:2.6, transparent:true, opacity:.86, side:THREE.DoubleSide, depthWrite:false});
    irid(m, o.cut === 'master' ? .45 : .2, o.cut === 'cab' ? .35 : .85);
    const gem = add(new THREE.Mesh(gemGeo(o.cut), m)); gem.rotation.set(o.cut === 'cab' ? -.9 : Math.PI - .55, 0, .15);
    return root;
  }
  // colour zoning along the crystals
  const zone = tr.has('zoned') ? 1 : rng() < .35 ? .45 : 0, zmode = Math.floor(rng() * 3);
  const cA = zone ? (zmode === 0 ? new THREE.Color(1, 1, 1).lerp(col, .25) : zmode === 1 ? col.clone().multiplyScalar(.45) : col.clone().offsetHSL(.45, 0, 0)) : col.clone(), cB = col.clone();
  const zcfg = () => ({cA:zone ? cA : col, cB, zk:zone});
  const cmat = () => irid(metal ? new THREE.MeshPhysicalMaterial({color:0xffffff, vertexColors:true, metalness:.95, roughness:.25, clearcoat:1, flatShading:true, envMapIntensity:1.6})
    : new THREE.MeshPhysicalMaterial({color:0xffffff, vertexColors:true, emissive:col.clone().multiplyScalar(.08), roughness:Math.max(.02, .16 - gi * .035), metalness:.05, clearcoat:1, clearcoatRoughness:.04, flatShading:true, envMapIntensity:2.2,
      transparent:true, opacity:habit === 'octa' || habit === 'dodeca' ? .8 : Math.max(.5, .82 - gi * .07), side:THREE.DoubleSide, depthWrite:false}), irk, .16 + gi * .07, ['prism', 'blade', 'barrel', 'scaleno'].includes(habit) ? 1 : 0);
  const kind = o.kind || 'crystal', elongated = ['prism', 'blade', 'barrel', 'scaleno'].includes(habit), needsRock = tr.has('moss') || tr.has('coral');
  let layout = kind === 'geode' ? 'geode' : habit === 'nugget' ? 'nugget' : habit === 'botryoid' ? 'botryoid'
    : tr.has('floater') && elongated ? 'floater' : habit === 'blade' && rng() < .55 ? 'rosette'
    : elongated && ((kind === 'druse' && rng() < .35) || (kind === 'crystal' && rng() < .12)) ? 'radial' : kind === 'druse' ? 'cluster' : 'single';
  if (needsRock && (layout === 'floater' || layout === 'radial')) layout = kind === 'druse' ? 'cluster' : 'single';
  const rtype = layout === 'nugget' && rng() < .6 ? 'quartzite' : layout === 'rosette' ? 'limestone' : ['basalt', 'basalt', 'quartzite', 'ironstone', 'limestone'][Math.floor(rng() * 5)];
  let pick = () => new THREE.Vector3(0, 0, 0), nrm = v => v.clone().normalize();
  const useRock = shape => { const R = makeRock(rng, rtype, shape); add(R.mesh); pick = () => R.top[Math.floor(rng() * R.top.length)] || new THREE.Vector3(0, .3, 0); nrm = R.nrm; return R; };
  const mat = metal || ['nugget', 'botryoid'].includes(layout) ? null : cmat();
  let main = null;
  const crystal = (h, s, at, dir, extra = {}, mo = null) => { const g = crystalGeo(habit, rng, Object.assign({h, tip:kind === 'shard' || o.cut === 'broken' ? .05 : undefined}, zcfg(), extra));
    const c = add(new THREE.Mesh(g, mo || mat || cmat())); c.position.copy(at); c.scale.setScalar(s); c.quaternion.setFromUnitVectors(up, dir.clone().normalize()); c.rotateY(rng() * 6.28); return c; };
  const lean = (d, a) => d.clone().add(new THREE.Vector3((rng() - .5) * a, 0, (rng() - .5) * a)).normalize();

  if (layout === 'nugget') {
    useRock(rng() < .5 ? 'small' : 'chunk');
    const m = new THREE.MeshStandardMaterial({color:col, metalness:1, roughness:.3, flatShading:true, envMapIntensity:1.8});
    const g = warp(new THREE.IcosahedronGeometry(.42, 2), rng, 1.1, 1.6); g.scale(1.2, .8, 1);
    add(new THREE.Mesh(g, m)).position.copy(pick()).multiplyScalar(.8);
    for (let k = 0; k < 4; k++) add(new THREE.Mesh(warp(new THREE.IcosahedronGeometry(.1 + rng() * .08, 1), rng, 1, 2), m)).position.copy(pick()).multiplyScalar(1.02);
    // gold also grows as wires and leaves
    if (rng() < .55) { const list = []; const grow = (p, d, l, r, depth) => { list.push({p:p.clone(), d:d.clone(), l, r}); const e = p.clone().addScaledVector(d, l); if (depth > 0) for (let k = 0; k < 2; k++) grow(e, d.clone().add(new THREE.Vector3(rng() - .5, rng() * .4, rng() - .5)).normalize(), l * .75, r * .8, depth - 1); };
      for (let k = 0; k < 3; k++) { const at = pick(); grow(at, nrm(at).lerp(up, .4), .14, .02, 4); }
      const cyl = new THREE.CylinderGeometry(1, 1, 1, 6); cyl.translate(0, .5, 0); const im = new THREE.InstancedMesh(cyl, m, list.length), mt = new THREE.Matrix4(), q = new THREE.Quaternion();
      list.forEach((L, k) => { q.setFromUnitVectors(up, L.d); mt.compose(L.p, q, new THREE.Vector3(L.r, L.l, L.r)); im.setMatrixAt(k, mt); }); add(im); }
  } else if (layout === 'botryoid') {
    useRock(rng() < .5 ? 'slab' : 'chunk');
    const m = new THREE.MeshPhysicalMaterial({color:col, roughness:.18, clearcoat:1, clearcoatRoughness:.1, envMapIntensity:1.3});
    irid(m, o.sid === 'opal' ? .9 : irk, 0, 0, ['malachite', 'azurite', 'chrysocolla'].includes(o.sid) ? .45 : 0);
    // grape-like crust half sunk into the rock, small balls on big ones
    for (let k = 0, n = 34 + Math.floor(rng() * 30); k < n; k++) { const r = .05 + rng() * .13, at = pick(); add(new THREE.Mesh(new THREE.SphereGeometry(r, 22, 14), m)).position.copy(at).addScaledVector(nrm(at), -r * .35); }
  } else if (layout === 'single') {
    useRock(rng() < .6 ? 'small' : 'chunk');
    const at = new THREE.Vector3((rng() - .5) * .15, elongated ? .22 : .1, (rng() - .5) * .15);
    main = crystal(1.15 + rng() * .5, 1.2 + rng() * .3, at, lean(up, .35), {scepter:tr.has('scepter')});
    for (let k = 0, n = Math.floor(rng() * 3); k < n; k++) { const p = pick(); crystal(.45 + rng() * .5, .5 + rng() * .4, p, lean(nrm(p).lerp(up, .5), .6)); }
    if (tr.has('twin')) { const t = crystal(1 + rng() * .4, 1.05, at, lean(new THREE.Vector3(.8, 1, .3), .3)); t.rotateZ(.6); }
  } else if (layout === 'cluster') {
    useRock(rng() < .6 ? 'slab' : 'long');
    main = crystal(1.1 + rng() * .5, 1.15 + rng() * .3, new THREE.Vector3(0, .18, 0), lean(up, .3), {scepter:tr.has('scepter')});
    for (let k = 0, n = 6 + Math.floor(rng() * 8); k < n; k++) { const p = pick(); crystal(.35 + rng() * .7, .45 + rng() * .55, p, lean(nrm(p).lerp(up, .6), .7)); }
  } else if (layout === 'radial') {
    // a sunburst: crystals radiating from a small core
    if (rng() < .6) { const core = makeRock(rng, rtype, 'small'); core.mesh.scale.setScalar(.45); add(core.mesh); }
    const n = 14 + Math.floor(rng() * 12);
    for (let k = 0; k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize(); const c = crystal(.5 + rng() * .7, .55 + rng() * .45, d.clone().multiplyScalar(.12), d); if (!main) main = c; }
  } else if (layout === 'rosette') {
    // a desert rose: tiers of blades fanned around the axis
    useRock('small').mesh.scale.multiplyScalar(.7);
    for (let tier = 0; tier < 3; tier++) for (let k = 0, n = 6 + Math.floor(rng() * 4); k < n; k++) {
      const a = k / n * 6.28 + tier * .5 + rng() * .3, tilt = .55 + tier * .25 + rng() * .2;
      const d = new THREE.Vector3(Math.cos(a) * Math.sin(tilt), Math.cos(tilt), Math.sin(a) * Math.sin(tilt));
      const c = crystal(.35 + rng() * .25, .7 + rng() * .3 - tier * .12, new THREE.Vector3(0, .12 + tier * .1, 0), d); c.rotation.y += a; if (!main) main = c; }
  } else if (layout === 'floater') {
    // a doubly terminated crystal that grew loose, with a satellite or two
    main = crystal(1.2 + rng() * .4, 1.25, new THREE.Vector3(0, 0, 0), new THREE.Vector3(.55 + rng() * .3, 1, .2), {dt:true, scepter:tr.has('scepter')});
    for (let k = 0, n = 1 + Math.floor(rng() * 2); k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng(), rng() - .5); crystal(.35 + rng() * .3, .45, new THREE.Vector3((rng() - .5) * .3, .3 + rng() * .5, (rng() - .5) * .2), d, {dt:true}); }
  } else if (layout === 'geode') {
    // a cracked-open geode: rough shell, agate rind, a cave of crystals inside
    const shell = new THREE.Group(); root.add(shell);
    const R = ROCKS[rtype === 'quartzite' ? 'basalt' : rtype];
    const outer = warp(new THREE.SphereGeometry(1, 48, 24, 0, Math.PI * 2, 0, Math.PI / 2), rng, .25, 1.5);
    const ocol = new THREE.Color().setHSL(R.h[0], R.s[0], R.l[0] + .05).convertSRGBToLinear();
    add(new THREE.Mesh(outer, new THREE.MeshStandardMaterial({color:ocol, roughness:.95, flatShading:true, bumpMap:SPEC.grain, bumpScale:.04})), true, shell);
    const inner = new THREE.Mesh(new THREE.SphereGeometry(.9, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({color:new THREE.Color(0x6a7080).convertSRGBToLinear(), roughness:.55, side:THREE.BackSide}));
    add(inner, true, shell);
    const bands = canvasTex(256, 256, x => { for (let r = 128; r > 0; r -= 3) { const t = r / 128; x.fillStyle = `hsl(${210 + Math.sin(r * .7) * 20},${12 + Math.sin(r) * 10}%,${t > .93 ? 30 : 62 + Math.sin(r * 1.3) * 18}%)`; x.beginPath(); x.arc(128, 128, r, 0, 7); x.fill(); } });
    bands.encoding = THREE.sRGBEncoding;
    const rim = add(new THREE.Mesh(new THREE.RingGeometry(.9, 1.01, 72, 1), new THREE.MeshStandardMaterial({map:bands, roughness:.35, side:THREE.DoubleSide})), true, shell);
    rim.rotation.x = -Math.PI / 2;
    // dense, deeply coloured crystals lining the cave
    const gm = mat ? cmat() : null; if (gm) { gm.opacity = .93; gm.emissive.copy(col).multiplyScalar(.22); }
    for (let k = 0, n = 46 + Math.floor(rng() * 30); k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng() * .95 + .05, rng() - .5).normalize();
      const c = crystal(.3 + rng() * .35, .35 + rng() * .3, d.clone().multiplyScalar(.86), d.clone().negate(), {cA:col, cB:col.clone().offsetHSL(0, .1, .12), zk:1}, gm); shell.attach(c); if (!main) main = c; }
    shell.rotation.set(-Math.PI / 2 + .25, .35, 0);
    pick = () => { const a = rng() * Math.PI; return new THREE.Vector3(Math.cos(a), Math.sin(a) * .9, 0); }; nrm = v => v.clone().normalize();
  }

  // inside the main crystal: a ghost of an earlier crystal, golden rutile hairs, a milky core in cloudy stones
  if (main && mat) {
    const h = 1.2;
    if (tr.has('phantom')) { const ph = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .7}), new THREE.MeshStandardMaterial({color:col.clone().offsetHSL(.05, .2, -.15), roughness:.5, transparent:true, opacity:.55})); ph.scale.setScalar(.62); ph.position.y = .05; main.add(ph); }
    if (tr.has('rutile')) { const gm = new THREE.MeshStandardMaterial({color:0xd8a23a, metalness:1, roughness:.25, emissive:0x3a2208});
      for (let k = 0; k < 22; k++) { const n = new THREE.Mesh(new THREE.CylinderGeometry(.004, .004, .3 + rng() * .6, 4), gm); n.position.set((rng() - .5) * .3, .15 + rng() * h * .7, (rng() - .5) * .3); n.rotation.set((rng() - .5) * 1.6, rng() * 3, (rng() - .5) * 1.6); main.add(n); } }
    if (gi < 2) { const fog = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .85}), new THREE.MeshStandardMaterial({color:0xf2efe8, roughness:1, transparent:true, opacity:.35 - gi * .12, depthWrite:false})); fog.scale.setScalar(.7); fog.position.y = .04; main.add(fog); }
  }
  // accessory growths, as on real specimens
  const inst = (geo, m, n, place, parent = root) => { if (n <= 0) return; const im = new THREE.InstancedMesh(geo, m, n), mt = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), sc = new THREE.Vector3(), c = new THREE.Color();
    for (let k = 0; k < n; k++) { const r = place(k, e, sc, c); q.setFromEuler(e); mt.compose(r, q, sc); im.setMatrixAt(k, mt); im.setColorAt(k, c); } im.castShadow = true; add(im, true, parent); };
  // a sparkling crust of tiny crystals over the big one
  if (main && tr.has('druzy')) { main.updateMatrix(); const gp = main.geometry.attributes.position, mt = main.matrix, v = new THREE.Vector3();
    inst(new THREE.OctahedronGeometry(1, 0), new THREE.MeshPhysicalMaterial({roughness:.1, clearcoat:1, flatShading:true, envMapIntensity:2.5}), 260, (k, e, sc, c) => {
      v.fromBufferAttribute(gp, Math.floor(rng() * gp.count)).applyMatrix4(mt); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.01 + rng() * .018); c.copy(col).lerp(new THREE.Color(1, 1, 1), .6); return v.clone(); }, main.parent); }
  const segs = (geoUnitY, m, list) => inst(geoUnitY, m, list.length, (k, e, sc, c) => { const L = list[k];
    e.setFromQuaternion(new THREE.Quaternion().setFromUnitVectors(up, L.d)); sc.set(L.r, L.l, L.r); c.copy(L.c); return L.p; });
  const cyl = new THREE.CylinderGeometry(1, 1, 1, 6); cyl.translate(0, .5, 0);
  const cone = new THREE.ConeGeometry(1, 1, 5); cone.translate(0, .5, 0);
  const pal = [[0xff6a2a, 0xffb040, 0xd8302a], [0x3a6aff, 0x7fb4ff, 0x1a2a8a], [0xf4f0e8, 0xd8d0c0, 0xb8b0a0], [0xff4a8a, 0xffb0d0, 0x8a2a5a], [0xd8e04a, 0xf4f0a0, 0x7a8a2a]][Math.floor(rng() * 5)].map(h => new THREE.Color(h).convertSRGBToLinear());
  const hasBase = !['floater', 'radial'].includes(layout), strong = tr.has('coral');
  const style = !hasBase ? -1 : strong ? Math.floor(rng() * 3) : rng() < .4 ? 1 + Math.floor(rng() * 2) : -1;
  if (style === 0) {
    // coralloid branches: forking stems with knobbly tips
    const list = [], tips = [];
    const grow = (p, d, l, r, depth) => { list.push({p:p.clone(), d:d.clone(), l, r, c:pal[Math.min(2, 2 - depth % 3)]}); const end = p.clone().addScaledVector(d, l);
      if (depth <= 0 || l < .02) { tips.push(end); return; }
      for (let k = 0, n = 2 + (rng() < .35 ? 1 : 0); k < n; k++) grow(end, d.clone().add(new THREE.Vector3(rng() - .5, rng() * .5, rng() - .5).multiplyScalar(1.3)).normalize(), l * (.62 + rng() * .2), r * .72, depth - 1); };
    for (let k = 0; k < 6; k++) { const at = pick(); grow(at, nrm(at).lerp(up, .5).normalize(), .1 + rng() * .06, .016, 4); }
    segs(cyl, new THREE.MeshStandardMaterial({roughness:.7}), list);
    inst(new THREE.IcosahedronGeometry(1, 1), new THREE.MeshStandardMaterial({roughness:.6}), tips.length, (k, e, sc, c) => { sc.setScalar(.012 + rng() * .014); c.copy(pal[Math.floor(rng() * 2)]); return tips[k]; });
  } else if (style === 1) {
    // radiating needle sprays
    const list = [];
    for (let s0 = 0, n = strong ? 5 : 2; s0 < n; s0++) { const at = pick(), base = nrm(at).lerp(up, .3).normalize();
      for (let k = 0; k < 70; k++) { const d = base.clone().add(new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).multiplyScalar(1.4)).normalize(); if (d.dot(base) < .15) continue;
        list.push({p:at, d, l:.08 + rng() * .22, r:.006 + rng() * .006, c:pal[Math.floor(rng() * 3)]}); } }
    segs(cone, new THREE.MeshPhysicalMaterial({roughness:.25, clearcoat:.6}), list);
  } else if (style === 2) {
    // a crust of tiny crystals coating part of the rock
    const seeds = Array.from({length:strong ? 7 : 3}, pick), n = strong ? 900 : 300;
    inst(new THREE.OctahedronGeometry(1, 0), new THREE.MeshPhysicalMaterial({roughness:.2, clearcoat:1, flatShading:true}), n, (k, e, sc, c) => { const s0 = seeds[k % seeds.length], r = .17;
      const v = s0.clone().add(new THREE.Vector3((rng() - .5) * r * 2, (rng() - .5) * r * .6, (rng() - .5) * r * 2)); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.008 + rng() * .02); sc.y *= 1.6; c.copy(pal[Math.floor(rng() * 3)]); return v; });
  }
  if (hasBase && (tr.has('moss') || rng() < .18)) {
    const seeds = Array.from({length:tr.has('moss') ? 8 : 2}, pick), n = tr.has('moss') ? 1400 : 220;
    inst(new THREE.CylinderGeometry(.15, .5, 1, 4), new THREE.MeshStandardMaterial({roughness:.8}), n, (k, e, sc, c) => { const s0 = seeds[k % seeds.length], r = .14;
      const v = s0.clone().add(new THREE.Vector3((rng() - .5) * r * 2, rng() * .04, (rng() - .5) * r * 2)); e.set((rng() - .5) * 1.1, rng() * 3, (rng() - .5) * 1.1); const l = .03 + rng() * .09; sc.set(.006, l, .006); v.y += l / 2; c.setHSL(.2 + rng() * .1, .55 + rng() * .3, .28 + rng() * .25).convertSRGBToLinear(); return v; });
  }
  // a dusting of red hematite on some
  if (hasBase && rng() < .15) inst(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshStandardMaterial({roughness:.9}), 160, (k, e, sc, c) => { const v = pick().clone().multiplyScalar(1.01); sc.setScalar(.006 + rng() * .01); c.setHSL(.01, .6, .2 + rng() * .1).convertSRGBToLinear(); return v; });
  if (tr.has('bubbles')) {
    inst(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshPhysicalMaterial({roughness:.02, clearcoat:1, envMapIntensity:2.6, transparent:true, opacity:.4, depthWrite:false}), 40, (k, e, sc, c) => { const v = pick().clone().multiplyScalar(1.02); v.y += rng() * .5; sc.setScalar(.015 + rng() * .05); c.set(0xffffff); return v; });
  }
  if (o.legend) { const halo = add(new THREE.Mesh(new THREE.TorusGeometry(1.05, .008, 6, 90), new THREE.MeshBasicMaterial({color:0xe4ae39})), false); halo.rotation.x = Math.PI / 2 - .3; root.userData.glow = new THREE.Color(0xe4ae39); }
  return root;
}
// fit only real geometry: instanced growths report a unit-sphere box at the origin
function boxOf(g){ g.updateMatrixWorld(true); const b = new THREE.Box3(), t = new THREE.Box3();
  g.traverse(o => { if (o.isMesh && !o.isInstancedMesh && o.geometry) { if (!o.geometry.boundingBox) o.geometry.computeBoundingBox(); t.copy(o.geometry.boundingBox).applyMatrix4(o.matrixWorld); b.union(t); } }); return b; }
// centre the specimen in the void, inside a pivot that we turn
function seat(g){
  const b = boxOf(g), sz = b.getSize(new THREE.Vector3()), s = Math.min(2.5 / Math.max(.01, sz.y), 2.35 / Math.max(.01, sz.x, sz.z));
  g.scale.multiplyScalar(s); const c = boxOf(g).getCenter(new THREE.Vector3()); g.position.sub(c);
  const pivot = new THREE.Group(); pivot.add(g); pivot.userData.glow = g.userData.glow; return pivot;
}
function setGlow(p){ if (SPEC.glow) SPEC.glow.material.color.copy(p.userData.glow || new THREE.Color(0x334455)).multiplyScalar(.32); }
const specOf = (it, res) => ({seed:it.id, sid:res.sid, kind:it.kind, gi:res.gi, traits:res.traits, cut:res.cut, legend:it.legend});
const SPEC_CACHE = new Map();
function specThumb(o){
  const key = [o.seed, o.sid, o.kind, o.gi, (o.traits || []).join('.'), o.cut || '', o.legend ? 1 : 0].join('|');
  if (SPEC_CACHE.has(key)) return SPEC_CACHE.get(key);
  if (!specInit()) return null;
  const g = seat(buildSpecimen(o)); g.rotation.set(.12, .6, 0);
  const prevGlow = SPEC.glow.material.color.clone(); setGlow(g);
  if (SPEC.live) SPEC.live.visible = false;
  SPEC.scene.add(g); SPEC.r.render(SPEC.scene, SPEC.cam);
  const c = document.createElement('canvas'); c.width = c.height = 256; c.getContext('2d').drawImage(SPEC.r.domElement, 0, 0, 256, 256);
  const url = c.toDataURL('image/jpeg', .86);
  SPEC.scene.remove(g); disposeTree(g); SPEC.glow.material.color.copy(prevGlow); if (SPEC.live) SPEC.live.visible = true;
  SPEC_CACHE.set(key, url); return url;
}
// the floating specimen in the lab: drifts, turns, answers the finger
function specMount(host, o){
  if (!host || !specInit()) return false;
  specUnmount();
  SPEC.live = seat(buildSpecimen(o)); setGlow(SPEC.live); SPEC.scene.add(SPEC.live); SPEC.spinV = .45; SPEC.tilt = 0;
  host.innerHTML = ''; host.appendChild(SPEC.r.domElement); host.classList.add('live');
  let last = performance.now(), t = 0;
  const spin = now => { SPEC.raf = requestAnimationFrame(spin); const dt = Math.min(.05, (now - last) / 1000); last = now; t += dt;
    const L = SPEC.live; if (L) {
      if (!SPEC.drag) { SPEC.spinV += (.45 - SPEC.spinV) * Math.min(1, dt * 1.2); L.rotation.y += SPEC.spinV * dt; SPEC.tilt *= Math.max(0, 1 - dt * .8); }
      L.rotation.x += (SPEC.tilt + Math.sin(t * .7) * .06 - L.rotation.x) * Math.min(1, dt * 6); L.position.y = Math.sin(t * 1.1) * .06; }
    SPEC.r.render(SPEC.scene, SPEC.cam); };
  SPEC.raf = requestAnimationFrame(spin); return true;
}
function specUnmount(){
  cancelAnimationFrame(SPEC.raf); SPEC.raf = 0; SPEC.drag = null;
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

