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
// dt: the crystal grows out of rock {h: rock line height, a: how ragged, col: rock colour, fr: frosted patches}
const GLSL_NOISE = `float h3(vec3 p){ p = fract(p * .3183099 + .1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float vn(vec3 x){ vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
      mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z); }
  float fbm(vec3 p){ return vn(p) * .5 + vn(p * 2.03) * .25 + vn(p * 4.01) * .125 + vn(p * 8.02) * .0625; }`;
function irid(mat, k, rf = 0, st = 0, band = 0, dt = null){
  mat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, {uIr:{value:k}, uRf:{value:rf}, uSt:{value:st}, uBd:{value:band}});
    if (dt) Object.assign(sh.uniforms, {uDH:{value:dt.h}, uDA:{value:dt.a}, uRC:{value:dt.col}, uFr:{value:dt.fr || 0}});
    const D = dt ? '#define DIRT\n' : '';
    sh.vertexShader = D + sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vOP;
      #ifdef DIRT
        attribute vec3 aRP; varying vec3 vRP;
      #endif`).replace('#include <begin_vertex>', `#include <begin_vertex>
      vOP = position;
      #ifdef DIRT
        vRP = aRP;
      #endif`);
    sh.fragmentShader = D + sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform float uIr, uRf, uSt, uBd; varying vec3 vOP;
      #ifdef DIRT
        uniform float uDH, uDA, uFr; uniform vec3 uRC; varying vec3 vRP;
        ${GLSL_NOISE}
      #endif`).replace('#include <color_fragment>', `#include <color_fragment>
      float dirt = 0.0, frost = 0.0;
      #ifdef DIRT
        // below a ragged line the crystal turns into the rock it grew from; just above it, milky and etched
        float edge = vRP.y - (uDH + (fbm(vRP * 4.0) - .47) * uDA + (fbm(vRP * 1.7 + 3.0) - .5) * uDA * .9);
        dirt = 1.0 - smoothstep(-.012, .012, edge);
        // islands of crust above the line, and windows where the crystal shows through below it
        dirt = max(dirt, smoothstep(.64, .67, fbm(vRP * 5.5 + 11.0)) * (1.0 - smoothstep(.0, .8, edge)));
        dirt *= 1.0 - smoothstep(.68, .71, fbm(vRP * 6.0 + 21.0)) * smoothstep(-.7, -.08, edge);
        float rim = 1.0 - smoothstep(.0, .05, abs(edge));
        frost = (1.0 - smoothstep(0.0, .3, edge)) * (1.0 - dirt) * .85;
        frost = max(frost, smoothstep(.6, .72, fbm(vRP * 2.6 + 7.0)) * uFr);
        vec3 rk = uRC * (.2 + 1.4 * fbm(vRP * 26.0)) * (.65 + .6 * vn(vRP * 3.0));
        rk = mix(rk, vec3(.3, .11, .035) * (.6 + .8 * vn(vRP * 30.0)), smoothstep(.5, .75, vn(vRP * 6.0 + 5.0)) * .7);
        rk = mix(rk, rk * 1.7 + .04, rim * .6);
        diffuseColor.rgb = mix(diffuseColor.rgb, vec3(.86, .88, .9), frost * .5);
        diffuseColor.a = mix(diffuseColor.a, .96, frost * .55);
        diffuseColor.rgb = mix(diffuseColor.rgb, rk, dirt); diffuseColor.a = mix(diffuseColor.a, 1.0, dirt);
      #endif`).replace('#include <roughnessmap_fragment>', `#include <roughnessmap_fragment>
      roughnessFactor = mix(mix(roughnessFactor, .5, frost), .95, dirt);`).replace('#include <metalnessmap_fragment>', `#include <metalnessmap_fragment>
      metalnessFactor *= 1.0 - dirt;`).replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
      float stb = sin(vOP.y * 70.0 + sin(vOP.x * 9.0 + vOP.z * 7.0) * 3.0) * sin(vOP.y * 23.0 + vOP.x * 5.0);
      normal = normalize(normal + uSt * (1.0 - dirt) * vec3(0.0, stb * .075, 0.0));
      #ifdef DIRT
        vec3 gp = vRP * 38.0;
        normal = normalize(normal + (dirt * 1.1 + frost * .25) * (vec3(vn(gp), vn(gp + 3.1), vn(gp + 5.7)) - .5));
      #endif`).replace('#include <lights_physical_fragment>', `#include <lights_physical_fragment>
      #ifdef CLEARCOAT
        material.clearcoat *= 1.0 - max(dirt, frost * .6);
      #endif`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      float clean = 1.0 - max(dirt, frost * .7);
      if (uBd > 0.0) diffuseColor.rgb *= 1.0 - uBd * (.5 + .5 * sin(length(vOP) * 140.0 + sin(vOP.x * 20.0) * 1.5));
      float fr = 1.0 - abs(dot(normalize(normal), normalize(vViewPosition)));
      float hue = fr * 2.4 + sin(vOP.x * 9.0 + vOP.y * 5.0) * .35 + sin(vOP.z * 11.0 - vOP.y * 7.0) * .25;
      vec3 ir = .5 + .5 * cos(6.2832 * (hue + vec3(0.0, .33, .67)));
      float msk = smoothstep(.15, .85, sin(vOP.y * 6.0 + vOP.x * 4.0 + vOP.z * 3.0) * .5 + .5);
      totalEmissiveRadiance += ir * uIr * clean * (uIr > 1.5 ? .7 + .6 * fr : .2 + .8 * fr * fr) * (uIr > 1.5 ? 1.0 : .35 + .65 * msk);
      #ifdef ENVMAP_TYPE_CUBE_UV
        if (uRf > 0.0) {
          vec3 nW = inverseTransformDirection(normalize(normal), viewMatrix), iW = inverseTransformDirection(normalize(-vViewPosition), viewMatrix);
          vec3 cr = vec3(textureCubeUV(envMap, refract(iW, nW, .64), .03).r, textureCubeUV(envMap, refract(iW, nW, .61), .03).g, textureCubeUV(envMap, refract(iW, nW, .58), .03).b);
          totalEmissiveRadiance += cr * diffuseColor.rgb * 1.3 * uRf * clean;
        }
      #endif`);
  };
  mat.userData.dirt = !!dt;
  mat.customProgramCacheKey = () => 'xtal' + (mat.flatShading ? 'f' : 's') + (mat.vertexColors ? 'v' : '') + (rf > 0 ? 'r' : '') + (st > 0 ? 's' : '') + (band > 0 ? 'b' : '') + (dt ? 'd' : '');
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
// a chunky column: uneven polygon section, slanted broken top or a point, foot sunk into the rock
// o: {sides, w, d, h, point, slope, taper}; zc: colour zoning as in crystalGeo
function prismGeo(rng, o, zc = {}){
  const n = o.sides, a0 = n === 4 ? .785 + (rng() - .5) * .2 : rng() * 6.28, ring = [];
  for (let k = 0; k < n; k++) { const a = a0 + k / n * 6.2832 + (rng() - .5) * (n === 4 ? .12 : .3), rr = 1 + (rng() - .5) * .3; ring.push([Math.cos(a) * o.w * rr, Math.sin(a) * o.d * rr]); }
  const b = rng() * 6.28, sx = Math.cos(b) * (o.slope || 0), sz = Math.sin(b) * (o.slope || 0), tp = o.taper ?? (.9 + rng() * .12), y0 = o.y0 ?? -.3;
  const bot = ring.map(([x, z]) => [x, y0, z]), top = ring.map(([x, z]) => [x * tp, o.point ? o.h : o.h + sx * x * tp + sz * z * tp, z * tp]);
  const tris = [];
  for (let k = 0; k < n; k++) { const j = (k + 1) % n; tris.push([bot[k], bot[j], top[j]], [bot[k], top[j], top[k]]); }
  if (o.point) { const ap = [(rng() - .5) * o.w * .3, o.h + Math.max(o.w, o.d) * (1.1 + rng() * .9), (rng() - .5) * o.d * .3];
    for (let k = 0; k < n; k++) tris.push([top[k], top[(k + 1) % n], ap]); }
  else { const c = top.reduce((s, p) => [s[0] + p[0] / n, s[1] + p[1] / n, s[2] + p[2] / n], [0, 0, 0]); for (let k = 0; k < n; k++) tris.push([top[k], top[(k + 1) % n], c]); }
  const cb = [0, y0, 0]; for (let k = 0; k < n; k++) tris.push([bot[k], bot[(k + 1) % n], cb]);
  // wind every face outward, so double-sided shading knows which side is the front
  const all = tris.flat(), ctr = all.reduce((s, p) => [s[0] + p[0] / all.length, s[1] + p[1] / all.length, s[2] + p[2] / all.length], [0, 0, 0]);
  const pos = new Float32Array(tris.length * 9), A = new THREE.Vector3(), B = new THREE.Vector3(), C = new THREE.Vector3(), N = new THREE.Vector3();
  tris.forEach((t, i) => { A.fromArray(t[0]); B.fromArray(t[1]); C.fromArray(t[2]); N.subVectors(B, A).cross(C.clone().sub(A));
    const m = A.clone().add(B).add(C).multiplyScalar(1 / 3).sub(new THREE.Vector3(...ctr)); const q = N.dot(m) < 0 ? [t[0], t[2], t[1]] : t; q.forEach((p, k) => pos.set(p, i * 9 + k * 3)); });
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const cc = new Float32Array(pos.length), cA = zc.cA || new THREE.Color(1, 1, 1), cB = zc.cB || cA, c = new THREE.Color(), hTot = o.h + o.w * 2 - y0;
  for (let i = 0; i < pos.length; i += 3) { const t = Math.min(1, Math.max(0, (pos[i + 1] - y0) / hTot)); c.copy(cA).lerp(cB, (zc.zk || 0) * t * t * (3 - 2 * t)); c.toArray(cc, i); }
  g.setAttribute('color', new THREE.BufferAttribute(cc, 3)); g.computeVertexNormals(); return g;
}
// random points on a mesh's surface in its parent's space, with outward normals
function surfPts(mesh, n, rng, keep = null){
  mesh.updateMatrix(); const p = mesh.geometry.attributes.position, tris = p.count / 3, out = [], a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3();
  for (let guard = 0; out.length < n && guard < n * 30; guard++) { const t = Math.floor(rng() * tris); a.fromBufferAttribute(p, t * 3); b.fromBufferAttribute(p, t * 3 + 1); c.fromBufferAttribute(p, t * 3 + 2);
    let u = rng(), v = rng(); if (u + v > 1) { u = 1 - u; v = 1 - v; }
    const pt = a.clone().add(b.clone().sub(a).multiplyScalar(u)).add(c.clone().sub(a).multiplyScalar(v)).applyMatrix4(mesh.matrix);
    const nw = b.clone().sub(a).cross(c.clone().sub(a)).normalize().transformDirection(mesh.matrix);
    if (keep && !keep(pt, nw)) continue; out.push([pt, nw]); }
  return out;
}
// soft smoky veils for the inside of clear crystals
function wispTex(seed){
  const rng = mulberry(seed), t = canvasTex(256, 256, x => { for (let k = 0; k < 70; k++) { const px = 40 + rng() * 176, py = 30 + rng() * 196, r = 10 + rng() * 40, g = x.createRadialGradient(px, py, 0, px, py, r);
    g.addColorStop(0, `rgba(255,255,255,${.12 + rng() * .25})`); g.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = g; x.fillRect(0, 0, 256, 256); }
    x.globalCompositeOperation = 'destination-in'; const e = x.createRadialGradient(128, 128, 60, 128, 128, 128); e.addColorStop(0, 'rgba(0,0,0,1)'); e.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = e; x.fillRect(0, 0, 256, 256); });
  return t;
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
  return {mesh, top, nrm, base};
}
// o: {seed, sid, kind, gi, traits, cut, legend}
function buildSpecimen(o){
  const rng = mulberry((o.seed || 1) * 2654435761 % 4294967296), sp = SP[o.sid] || SP.quartz, habit = HABIT[o.sid] || 'prism', tr = new Set(o.traits || []);
  const gi = o.gi ?? 1, root = new THREE.Group(), col = new THREE.Color(sp.c).convertSRGBToLinear();
  col.offsetHSL((rng() - .5) * .03, (rng() - .5) * .15, (rng() - .5) * .06);
  if (gi < 2) col.lerp(new THREE.Color(0xb8b4ac).convertSRGBToLinear(), .25 - gi * .1);
  root.userData.glow = col.clone();
  let irk = tr.has('aurora') ? 1.9 : tr.has('irid') ? 1 : o.legend ? .45 : .14;
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
  const DT = {h:-99, a:.4, col:new THREE.Color(.1, .1, .1), fr:rng() < .5 ? .7 : 0};
  const cmat = () => irid(metal ? new THREE.MeshPhysicalMaterial({color:0xffffff, vertexColors:true, metalness:.95, roughness:.25, clearcoat:1, flatShading:true, envMapIntensity:1.6})
    : new THREE.MeshPhysicalMaterial({color:0xffffff, vertexColors:true, emissive:col.clone().multiplyScalar(.08), roughness:Math.max(.02, .16 - gi * .035), metalness:.05, clearcoat:1, clearcoatRoughness:.04, flatShading:true, envMapIntensity:2.2,
      transparent:true, opacity:layout === 'columnar' || layout === 'cluster' ? .36 + (gi < 2 ? .14 : 0) : habit === 'octa' || habit === 'dodeca' ? .8 : Math.max(.5, .82 - gi * .07), side:THREE.DoubleSide, depthWrite:false}), irk, .16 + gi * .07, ['prism', 'blade', 'barrel', 'scaleno'].includes(habit) ? 1 : 0, 0, metal ? null : DT);
  const kind = o.kind || 'crystal', elongated = ['prism', 'blade', 'barrel', 'scaleno'].includes(habit), needsRock = tr.has('moss') || tr.has('coral');
  let layout = kind === 'geode' ? 'geode' : habit === 'nugget' ? 'nugget' : habit === 'botryoid' ? 'botryoid'
    : tr.has('floater') && elongated ? 'floater' : habit === 'blade' && rng() < .55 ? 'rosette'
    : elongated && ((kind === 'druse' && rng() < .2) || (kind === 'crystal' && rng() < .08)) ? 'radial'
    : kind === 'druse' ? 'cluster' : (elongated || habit === 'cube') && rng() < .75 ? 'columnar' : 'single';
  if (needsRock && (layout === 'floater' || layout === 'radial')) layout = kind === 'druse' ? 'cluster' : 'single';
  const rtype = layout === 'columnar' ? ['basalt', 'basalt', 'ironstone', 'ironstone', 'limestone'][Math.floor(rng() * 5)] : layout === 'nugget' && rng() < .6 ? 'quartzite' : layout === 'rosette' ? 'limestone' : ['basalt', 'basalt', 'quartzite', 'ironstone', 'limestone'][Math.floor(rng() * 5)];
  let pick = () => new THREE.Vector3(0, 0, 0), nrm = v => v.clone().normalize();
  const rockMat = c => irid(new THREE.MeshPhysicalMaterial({color:0xffffff, roughness:.95, flatShading:true}), 0, 0, 0, 0, {h:99, a:.3, col:c.clone(), fr:0});
  const useRock = shape => { const R = makeRock(rng, rtype, shape); R.mesh.material.dispose(); R.mesh.material = rockMat(R.base); add(R.mesh); DT.col.copy(R.base); pick = () => R.top[Math.floor(rng() * R.top.length)] || new THREE.Vector3(0, .3, 0); nrm = R.nrm; return R; };
  // some columns are dark and oily with a rainbow sheen, like hematite-coated quartz
  const dark = layout === 'columnar' && !metal && rng() < .22;
  if (layout === 'columnar' || layout === 'cluster') irk = Math.max(irk, dark ? .75 : .3);
  const mat = metal || ['nugget', 'botryoid'].includes(layout) ? null : cmat();
  if (dark && mat) { mat.color.setRGB(.09, .09, .1); mat.opacity = .93; mat.metalness = .45; mat.roughness = .1; mat.emissive.multiplyScalar(.3); }
  let main = null;
  const crystal = (h, s, at, dir, extra = {}, mo = null) => { const g = crystalGeo(habit, rng, Object.assign({h, tip:kind === 'shard' || o.cut === 'broken' ? .05 : undefined}, zcfg(), extra));
    const c = add(new THREE.Mesh(g, mo || mat || cmat())); c.position.copy(at); c.scale.setScalar(s); c.quaternion.setFromUnitVectors(up, dir.clone().normalize()); c.rotateY(rng() * 6.28); return c; };
  const inst = (geo, m, n, place, parent = root) => { if (n <= 0) return; const im = new THREE.InstancedMesh(geo, m, n), mt = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), sc = new THREE.Vector3(), c = new THREE.Color();
    for (let k = 0; k < n; k++) { const r = place(k, e, sc, c); q.setFromEuler(e); mt.compose(r, q, sc); im.setMatrixAt(k, mt); im.setColorAt(k, c); } im.castShadow = true; add(im, true, parent); };
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
    main = crystal(1.15 + rng() * .5, 1.2 + rng() * .3, at, lean(up, .35), {scepter:tr.has('scepter')}); DT.h = at.y + .1 + rng() * .25; DT.a = .35;
    for (let k = 0, n = Math.floor(rng() * 3); k < n; k++) { const p = pick(); crystal(.45 + rng() * .5, .5 + rng() * .4, p, lean(nrm(p).lerp(up, .5), .6)); }
    if (tr.has('twin')) { const t = crystal(1 + rng() * .4, 1.05, at, lean(new THREE.Vector3(.8, 1, .3), .3)); t.rotateZ(.6); }
  } else if (layout === 'cluster') {
    // a druse: a crumbling plate bristling with crystals of every size, their feet frosted and crusted over
    useRock(rng() < .6 ? 'slab' : 'long'); DT.local = true; DT.h = .1 + rng() * .14; DT.a = .3;
    const cubic = habit === 'cube', prismy = elongated || cubic, cm = mat || cmat(), sides = cubic || habit === 'blade' ? 4 : 6;
    const top = () => { let b = pick(); for (let k = 0; k < 5; k++) { const c = pick(); if (c.y - Math.hypot(c.x, c.z) * .3 > b.y - Math.hypot(b.x, b.z) * .3) b = c; } return b; };
    for (let k = 0, n = 14 + Math.floor(rng() * 14); k < n; k++) {
      const f = k ? Math.pow(rng(), 1.8) : 1, p = k ? pick() : top(), dir = lean(nrm(p).lerp(up, k ? .55 : .85), k ? .6 : .25);
      let c;
      if (prismy) { const w = (.05 + f * .15) * (cubic ? 1.3 : 1), h = cubic ? w * (1.3 + rng() * .7) : w * (3 + rng() * 3.5);
        c = add(new THREE.Mesh(prismGeo(rng, {sides, w, d:w * (habit === 'blade' ? .6 : .75 + rng() * .35), h, point:!cubic && rng() < .7, slope:rng() < .3 ? .5 : 0, y0:-w * .8}, zcfg()), cm));
        c.position.copy(p); c.quaternion.setFromUnitVectors(up, dir); c.rotateY(rng() * 6.28); c.renderOrder = 2; c.userData.col = true; }
      else c = crystal(.3 + f * .6, .35 + f * .6, p, dir);
      c.userData.local = true; if (!main) main = c; }
  } else if (layout === 'columnar') {
    // chunky columns pushing out of a crumbling rock that still climbs up their feet
    // often there is no separate rock at all: the columns themselves crumble into it
    const R = makeRock(rng, rtype, rng() < .5 ? 'small' : 'chunk'); DT.col.copy(R.base);
    if (rng() < .45) { R.mesh.material.dispose(); R.mesh.material = rockMat(R.base); add(R.mesh); R.mesh.scale.multiplyScalar(.7); R.mesh.position.y = -.2; } else disposeTree(R.mesh);
    const cubic = habit === 'cube', sides = cubic || habit === 'blade' || rng() < .3 ? 4 : 6, axis = lean(up, cubic ? .3 : .55);
    const n = kind === 'druse' ? 4 + Math.floor(rng() * 4) : 1 + Math.floor(rng() * 3), cm = mat || cmat();
    for (let k = 0; k < n; k++) {
      const w = (k ? .13 + rng() * .17 : .27 + rng() * .13) * (cubic ? 1.25 : 1), h = cubic ? w * (1.5 + rng() * .8) : k ? .45 + rng() * .9 : 1.45 + rng() * .65;
      const g = prismGeo(rng, {sides, w, d:habit === 'blade' ? w * .62 : w * (.7 + rng() * .45), h, point:!cubic && rng() < .45, slope:rng() < .65 ? .4 + rng() * 1.1 : 0}, zcfg());
      const c = add(new THREE.Mesh(g, cm)); c.renderOrder = 2; c.userData.col = true;
      c.position.set(k ? (rng() - .5) * .55 : 0, -.05, k ? (rng() - .5) * .4 : 0);
      c.quaternion.setFromUnitVectors(up, lean(axis, cubic ? 1.2 : .35)); c.rotateY(rng() * 6.28);
      if (!main) main = c; }
    DT.h = .3 + rng() * .45; DT.a = .5 + rng() * .5;
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
    const outer = warp(new THREE.SphereGeometry(1, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), rng, .3, 1.6);
    const ocol = new THREE.Color().setHSL(R.h[0], R.s[0] + .05, R.l[0] + .06).convertSRGBToLinear();
    add(new THREE.Mesh(outer, rockMat(ocol)), true, shell);
    const inner = new THREE.Mesh(new THREE.SphereGeometry(.9, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({color:col.clone().lerp(new THREE.Color(.25, .27, .3), .6).multiplyScalar(.35), roughness:.92, envMapIntensity:.3, side:THREE.BackSide}));
    add(inner, true, shell);
    // a glittering carpet of tiny crystals over the cave wall
    inst(new THREE.OctahedronGeometry(1, 0), new THREE.MeshPhysicalMaterial({roughness:.08, clearcoat:1, flatShading:true, envMapIntensity:2.4}), 800, (k, e, sc, c) => {
      const d = new THREE.Vector3(rng() - .5, rng() * .98 + .02, rng() - .5).normalize(); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.008 + rng() * .014); sc.y *= 1.7;
      c.copy(col).multiplyScalar(.6 + rng() * .5); return d.multiplyScalar(.885); }, shell);
    // agate rind: fine bands from the dark outer crust through grey and milky layers to a hint of the stone's own colour
    const hue = new THREE.Color(sp.c).getHSL({}).h, band = (t, c) => { const r = t * 40, j = Math.sin(r * 2.1) * .5 + Math.sin(r * .37) * .5;
      return t < .25 ? c.setHSL((20 + j * 8) / 360, .35 + j * .15, .12 + t * .4 + j * .06) : c.setHSL(t > .8 ? hue : (30 + j * 180) / 360, t > .8 ? .3 : .06 + j * .08, .18 + t * .28 + j * .12); };
    // a broken, uneven lip instead of a clean ring
    const rg = new THREE.RingGeometry(.84, 1.01, 120, 16), rp = rg.attributes.position, wob = Array.from({length:4}, () => [1 + Math.floor(rng() * 9), rng() * 6.3]);
    for (let i = 0; i < rp.count; i++) { const x = rp.getX(i), y = rp.getY(i), a = Math.atan2(y, x), r = Math.hypot(x, y), t = (r - .84) / .17;
      let n = 0; for (const [f, ph] of wob) n += Math.sin(a * f + ph) * .25; n += Math.sin(a * 37 + r * 9) * .12;
      const rr = r + (t > .5 ? n * .03 : 0); rp.setXYZ(i, Math.cos(a) * rr, Math.sin(a) * rr, (n * .05 + Math.sin(a * 53) * .012) * (1 - Math.abs(t - .5))); }
    const rc = new Float32Array(rp.count * 3), bc = new THREE.Color();
    for (let i = 0; i < rp.count; i++) { const t = 1 - (Math.hypot(rp.getX(i), rp.getY(i)) - .84) / .2; band(Math.max(0, Math.min(1, t)), bc).convertSRGBToLinear().toArray(rc, i * 3); }
    rg.setAttribute('color', new THREE.BufferAttribute(rc, 3)); rg.computeVertexNormals();
    const rim = add(new THREE.Mesh(rg, new THREE.MeshStandardMaterial({vertexColors:true, roughness:.8, flatShading:true, depthWrite:false})), true, shell);
    rim.rotation.x = Math.PI / 2;
    // pointed crystals crowding the cave: milky at their roots, deep colour at the tips
    const gm = cmat(); if (!metal) { gm.opacity = .8; gm.emissive.copy(col).multiplyScalar(.18); }
    DT.local = true; DT.h = .06 + rng() * .08; DT.a = .2; DT.col.setRGB(.5, .5, .52); DT.fr = 0;
    const cRoot = new THREE.Color(.92, .93, .95).lerp(col, .45), cTip = col.clone().offsetHSL(0, .15, -.08), prismy = elongated || habit === 'cube';
    for (let k = 0, n = 80 + Math.floor(rng() * 40); k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng() * .95 + .05, rng() - .5).normalize(), f = Math.pow(rng(), 1.6);
      const dir = d.clone().negate().lerp(new THREE.Vector3(0, 1, 0), .15).add(new THREE.Vector3((rng() - .5) * .45, (rng() - .5) * .2, (rng() - .5) * .45)).normalize();
      let c;
      if (prismy) { const w = .05 + f * .13, h = habit === 'cube' ? w * 1.4 : Math.min(.42, w * (2.4 + rng() * 2.2));
        c = new THREE.Mesh(prismGeo(rng, {sides:habit === 'cube' ? 4 : 6, w, d:w * (.8 + rng() * .3), h, point:habit !== 'cube', y0:-w * .4}, {cA:cRoot, cB:cTip, zk:1}), gm);
        c.position.copy(d).multiplyScalar(.86); c.quaternion.setFromUnitVectors(up, dir); c.rotateY(rng() * 6.28); c.renderOrder = 2; shell.add(c); }
      else { c = crystal(.3 + f * .5, .4 + f * .5, d.clone().multiplyScalar(.86), dir, {cA:cRoot, cB:cTip, zk:1}, gm); shell.attach(c); }
      c.userData.local = true; if (!main) main = c; }
    shell.rotation.set(-Math.PI / 2 - .55, .35, 0);
    pick = () => { const a = rng() * Math.PI; return new THREE.Vector3(Math.cos(a), Math.sin(a) * .9, 0); }; nrm = v => v.clone().normalize();
  }

  // inside the main crystal: a ghost of an earlier crystal, golden rutile hairs, a milky core in cloudy stones
  if (main && mat) {
    const h = 1.2;
    if (tr.has('phantom')) { const ph = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .7}), new THREE.MeshStandardMaterial({color:col.clone().offsetHSL(.05, .2, -.15), roughness:.5, transparent:true, opacity:.55})); ph.scale.setScalar(.62); ph.position.y = .05; main.add(ph); }
    if (tr.has('rutile')) { const gm = new THREE.MeshStandardMaterial({color:0xd8a23a, metalness:1, roughness:.25, emissive:0x3a2208});
      const g = main.geometry; if (!g.boundingBox) g.computeBoundingBox(); const bb = g.boundingBox, w = Math.min(bb.max.x - bb.min.x, bb.max.z - bb.min.z), hh = bb.max.y - Math.max(0, bb.min.y);
      for (let k = 0; k < 22; k++) { const len = Math.min(hh * .7, w * 1.6) * (.4 + rng() * .6), n = new THREE.Mesh(new THREE.CylinderGeometry(.004, .004, len, 4), gm);
        n.position.set((bb.min.x + bb.max.x) / 2 + (rng() - .5) * w * .4, Math.max(0, bb.min.y) + hh * (.25 + rng() * .45), (bb.min.z + bb.max.z) / 2 + (rng() - .5) * w * .4); n.rotation.set((rng() - .5) * .8, rng() * 3, (rng() - .5) * .8); main.add(n); } }
    if (gi < 2) { const fog = new THREE.Mesh(crystalGeo(habit, rng, {h:h * .85}), new THREE.MeshStandardMaterial({color:0xf2efe8, roughness:1, transparent:true, opacity:.35 - gi * .12, depthWrite:false})); fog.scale.setScalar(.7); fog.position.y = .04; main.add(fog); }
  }
  // the look of a fine specimen: things trapped inside the clear crystal, crusts at the rock line
  const INC = [[0xe8b030, 0xe07020, 0xc02818, 0xf4e0b0], [0x8a4020, 0xb06030, 0x4a2010, 0xd09050], [0x1a1a1a, 0x3a3a3a, 0x6a6a6a, 0xe8e8e8], [0x2a4a2a, 0x4a6a3a, 0x1a2a1a, 0x8aa070]];
  const incI = Math.floor(rng() * INC.length), incP = INC[incI].map(h => new THREE.Color(h).convertSRGBToLinear());
  if (main && mat && layout !== 'geode' && rng() < (o.legend ? 1 : layout === 'columnar' ? .85 : .5 + gi * .1)) {
    const host = main, g = host.geometry; if (!g.boundingBox) g.computeBoundingBox(); const bb = g.boundingBox, cx = (bb.min.x + bb.max.x) / 2, cz = (bb.min.z + bb.max.z) / 2;
    const rx = (bb.max.x - bb.min.x) * .32, rz = (bb.max.z - bb.min.z) * .32, y0 = Math.max(bb.min.y, .05), y1 = bb.min.y + (bb.max.y - bb.min.y) * .82;
    const im = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshStandardMaterial({roughness:.45, metalness:incI === 0 ? .5 : .2, flatShading:true}), 360);
    const mt = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), sc = new THREE.Vector3(), c = new THREE.Color();
    const clouds = Array.from({length:2 + Math.floor(rng() * 3)}, () => new THREE.Vector3(cx + (rng() - .5) * rx, y0 + rng() * (y1 - y0), cz + (rng() - .5) * rz));
    for (let k = 0; k < 360; k++) { const cl = clouds[k % clouds.length], v = new THREE.Vector3((rng() - .5) * rx * 1.3, (rng() - .5) * .35, (rng() - .5) * rz * 1.3).multiplyScalar(Math.pow(rng(), .6)).add(cl);
      v.x = cx + Math.max(-rx, Math.min(rx, v.x - cx)); v.z = cz + Math.max(-rz, Math.min(rz, v.z - cz)); v.y = Math.max(y0, Math.min(y1, v.y));
      e.set(rng() * 3, rng() * 3, rng() * 3); q.setFromEuler(e); const s0 = .006 + Math.pow(rng(), 3) * .05; sc.set(s0, s0 * (.25 + rng() * .4), s0 * (.6 + rng() * .6));
      mt.compose(v, q, sc); im.setMatrixAt(k, mt); im.setColorAt(k, c.copy(incP[Math.floor(rng() * 4)]).multiplyScalar(.7 + rng() * .6)); }
    host.add(im);
    // smoky veils drifting through the body
    if (rng() < .7) { const wt = wispTex(o.seed || 1), wc = rng() < .5 ? incP[0] : rng() < .5 ? new THREE.Color(.04, .04, .05) : new THREE.Color(.9, .9, .92);
      for (let k = 0, m = 1 + Math.floor(rng() * 3); k < m; k++) { const pl = new THREE.Mesh(new THREE.PlaneGeometry(rx * 2.6, (y1 - y0) * (.4 + rng() * .4)), new THREE.MeshBasicMaterial({map:wt, color:wc, transparent:true, opacity:.55 + rng() * .3, depthWrite:false, side:THREE.DoubleSide}));
        pl.position.set(cx, y0 + (y1 - y0) * (.25 + rng() * .5), cz); pl.rotation.set((rng() - .5) * .6, rng() * 3.14, (rng() - .5) * .6); pl.renderOrder = 1; host.add(pl); } }
  }
  const cols = []; root.children.forEach(m => { if (m.isMesh && (m.userData.col || (mat && m.material === mat))) cols.push(m); });
  const nearLine = (p, n) => Math.abs(p.y - DT.h - .05) < .22 && n.y > -.3;
  if (cols.length && DT.h > -50 && layout !== 'geode' && (o.sid === 'pyrite' || rng() < .35)) {
    // bright little cubes, pyrite or galena, perched where crystal meets rock
    const pts = DT.local ? Array.from({length:22}, () => { const q = pick(); return [q, nrm(q)]; }) : cols.flatMap(m => surfPts(m, 14, rng, nearLine)).slice(0, 26), pc = new THREE.Color(rng() < .6 ? 0xd8c890 : 0xc8ccd2).convertSRGBToLinear();
    inst(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({metalness:1, roughness:.18, envMapIntensity:1.6, flatShading:true}), pts.length, (k, e, sc, c) => { const [p, nn] = pts[k], s0 = .03 + Math.pow(rng(), 2) * .08;
      e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(s0); c.copy(pc); return p.clone().addScaledVector(nn, s0 * .15); });
  }
  if (cols.length && (tr.has('coral') || rng() < .2)) {
    // a rusty, scruffy tuft of fine needles clinging to the crystal
    const at = cols.flatMap(m => surfPts(m, 3, rng, p => DT.local || DT.h < -50 || p.y > DT.h - .05)).slice(0, 1 + Math.floor(rng() * 2));
    const rc = [0x9a3a12, 0xc8601e, 0x5a200a, 0xe08a3a].map(h => new THREE.Color(h).convertSRGBToLinear());
    for (const [p, nn] of at) inst(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({roughness:.85}), 700, (k, e, sc, c) => {
      const d = new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize(); d.addScaledVector(nn, -d.dot(nn)).normalize();
      const r = Math.pow(rng(), .7) * .12, v = p.clone().addScaledVector(d, r).addScaledVector(nn, (.12 - r) * .3 * rng());
      e.set(rng() * 6, rng() * 6, rng() * 6); sc.set(.004, .015 + rng() * .03, .004); c.copy(rc[Math.floor(rng() * 4)]).multiplyScalar(.6 + rng() * .7); return v; });
  }
  // accessory growths, as on real specimens
  // a sparkling crust of tiny crystals over the big one
  if (main && tr.has('druzy')) { main.updateMatrix(); const gp = main.geometry.attributes.position, mt = main.matrix, v = new THREE.Vector3();
    inst(new THREE.OctahedronGeometry(1, 0), new THREE.MeshPhysicalMaterial({roughness:.1, clearcoat:1, flatShading:true, envMapIntensity:2.5}), 260, (k, e, sc, c) => {
      v.fromBufferAttribute(gp, Math.floor(rng() * gp.count)).applyMatrix4(mt); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.01 + rng() * .018); c.copy(col).lerp(new THREE.Color(1, 1, 1), .6); return v.clone(); }, main.parent); }
  const segs = (geoUnitY, m, list) => inst(geoUnitY, m, list.length, (k, e, sc, c) => { const L = list[k];
    e.setFromQuaternion(new THREE.Quaternion().setFromUnitVectors(up, L.d)); sc.set(L.r, L.l, L.r); c.copy(L.c); return L.p; });
  const cyl = new THREE.CylinderGeometry(1, 1, 1, 6); cyl.translate(0, .5, 0);
  const cone = new THREE.ConeGeometry(1, 1, 5); cone.translate(0, .5, 0);
  const pal = [[0xff6a2a, 0xffb040, 0xd8302a], [0x3a6aff, 0x7fb4ff, 0x1a2a8a], [0xf4f0e8, 0xd8d0c0, 0xb8b0a0], [0xff4a8a, 0xffb0d0, 0x8a2a5a], [0xd8e04a, 0xf4f0a0, 0x7a8a2a]][Math.floor(rng() * 5)].map(h => new THREE.Color(h).convertSRGBToLinear());
  const hasBase = !['floater', 'radial', 'columnar', 'geode'].includes(layout), strong = tr.has('coral');
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
  if (hasBase && tr.has('moss')) {
    const seeds = Array.from({length:tr.has('moss') ? 8 : 2}, pick), n = tr.has('moss') ? 1400 : 220;
    inst(new THREE.CylinderGeometry(.15, .5, 1, 4), new THREE.MeshStandardMaterial({roughness:.8}), n, (k, e, sc, c) => { const s0 = seeds[k % seeds.length], r = .14;
      const v = s0.clone().add(new THREE.Vector3((rng() - .5) * r * 2, rng() * .04, (rng() - .5) * r * 2)); e.set((rng() - .5) * 1.1, rng() * 3, (rng() - .5) * 1.1); const l = .03 + rng() * .09; sc.set(.006, l, .006); v.y += l / 2; c.setHSL(.2 + rng() * .1, .55 + rng() * .3, .28 + rng() * .25).convertSRGBToLinear(); return v; });
  }
  // a dusting of red hematite on some
  if (hasBase && rng() < .15) inst(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshStandardMaterial({roughness:.9}), 160, (k, e, sc, c) => { const v = pick().clone().multiplyScalar(1.01); sc.setScalar(.006 + rng() * .01); c.setHSL(.01, .6, .2 + rng() * .1).convertSRGBToLinear(); return v; });
  if (tr.has('bubbles')) {
    inst(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshPhysicalMaterial({roughness:.02, clearcoat:1, envMapIntensity:2.6, transparent:true, opacity:.4, depthWrite:false}), 40, (k, e, sc, c) => { const v = pick().clone().multiplyScalar(1.02); v.y += rng() * .5; sc.setScalar(.015 + rng() * .05); c.set(0xffffff); return v; });
  }
  root.updateMatrixWorld(true); const inv = new THREE.Matrix4().copy(root.matrixWorld).invert(), rel = new THREE.Matrix4(), tv = new THREE.Vector3();
  root.traverse(m => { if (!m.isMesh || m.isInstancedMesh || !m.material || !m.material.userData.dirt) return;
    const p = m.geometry.attributes.position, a = new Float32Array(p.count * 3);
    if (m.userData.local) { const g = m.geometry; if (!g.boundingBox) g.computeBoundingBox(); const bb = g.boundingBox, hgt = Math.max(.001, bb.max.y - bb.min.y);
      for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).sub(bb.min).multiplyScalar(1 / hgt); tv.toArray(a, i * 3); } }
    else { rel.multiplyMatrices(inv, m.matrixWorld); for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).applyMatrix4(rel); tv.toArray(a, i * 3); } } m.geometry.setAttribute('aRP', new THREE.BufferAttribute(a, 3)); });
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

