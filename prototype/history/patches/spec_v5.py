"""specimen.js v5: nuggets and botryoidal masses in the new style (smooth organic lumps, crust in the hollows, banding)."""
import os
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)

# crust islands anywhere on the surface, not only near the rock line
rep("uFr:{value:dt.fr || 0}});", "uFr:{value:dt.fr || 0}, uIs:{value:dt.is || 0}});")
rep("uniform float uDH, uDA, uFr; uniform vec3 uRC;", "uniform float uDH, uDA, uFr, uIs; uniform vec3 uRC;")
rep("        dirt = max(dirt, smoothstep(.64, .67, fbm(vRP * 5.5 + 11.0)) * (1.0 - smoothstep(.0, .8, edge)));",
    "        dirt = max(dirt, smoothstep(.64, .67, fbm(vRP * 5.5 + 11.0)) * max(1.0 - smoothstep(.0, .8, edge), uIs));")

# a smooth organic lump: a sphere swollen by rounded bumps, pocked by pits, with a cavity value for shading the hollows
rep("const ROCK_SHAPES =", r"""// o: {r, sx, sy, sz, wave, bumps:[[n, size, h]], pits:[n, size, depth], seg}
function lumpGeo(rng, o){
  const g = new THREE.SphereGeometry(1, o.seg || 96, Math.round((o.seg || 96) * .66)), p = g.attributes.position, v = new THREE.Vector3(), cav = new Float32Array(p.count);
  const rd = () => new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize();
  const bumps = (o.bumps || []).flatMap(([n, size, h]) => Array.from({length:n}, () => [rd(), size * (.55 + rng() * .9), h * (.5 + rng() * .9)]));
  const pits = o.pits ? Array.from({length:o.pits[0]}, () => [rd(), o.pits[1] * (.5 + rng()), o.pits[2] * (.5 + rng())]) : [];
  const ks = Array.from({length:5}, (_, k) => [rd().multiplyScalar((1.5 + rng() * 2) * (1 + k * .9)), rng() * 6.3, (o.wave || 0) / (1 + k * 1.1)]);
  const hmax = bumps.reduce((m, b) => Math.max(m, b[2]), .001);
  for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i).normalize();
    // smooth maximum of the caps, so neighbouring grapes melt into each other
    let b = 0, sum = 0; for (const [d, ar, h] of bumps) { const a = Math.acos(Math.max(-1, Math.min(1, v.dot(d)))); if (a < ar) { const t = a / ar, hh = h * Math.sqrt(1 - t * t); sum += Math.exp(hh * 60); b = Math.max(b, hh); } }
    if (sum > 0) b = Math.log(sum) / 60;
    let pit = 0; for (const [d, ar, dep] of pits) { const a = Math.acos(Math.max(-1, Math.min(1, v.dot(d)))); if (a < ar) pit = Math.max(pit, dep * (1 - (a / ar) * (a / ar))); }
    let n = 0; for (const [k, ph, amp] of ks) n += Math.sin(v.dot(k) + ph) * amp;
    cav[i] = Math.max(0, Math.min(1, (bumps.length ? 1 - b / hmax : 0) * .6 + pit * 8 + Math.max(0, -n) * 2));
    v.multiplyScalar(o.r * (1 + n + b - pit)); p.setXYZ(i, v.x * (o.sx || 1), v.y * (o.sy || 1), v.z * (o.sz || 1)); }
  g.computeVertexNormals(); return {g, cav};
}
const tintCav = (g, cav, k, base = new THREE.Color(1, 1, 1)) => { const cc = new Float32Array(cav.length * 3), c = new THREE.Color();
  for (let i = 0; i < cav.length; i++) { c.copy(base).multiplyScalar(1 - cav[i] * k); c.toArray(cc, i * 3); } g.setAttribute('color', new THREE.BufferAttribute(cc, 3)); return g; };
const ROCK_SHAPES =""")

# ---------- nuggets ----------
i = s.index("  if (layout === 'nugget') {"); j = s.index("  } else if (layout === 'botryoid') {")
s = s[:i] + r"""  if (layout === 'nugget') {
    // native metal: soft rounded lumps, hammered and pitted, with iron-oxide (or green patina on copper) packed into the hollows
    const copper = o.sid === 'nativecu', crust = new THREE.Color(copper ? 0x2f8a62 : 0x5a3218).convertSRGBToLinear();
    const mm = irid(new THREE.MeshPhysicalMaterial({color:col, vertexColors:true, metalness:1, roughness:.26 + rng() * .14, clearcoat:.3, envMapIntensity:1.7, bumpMap:SPEC.grain, bumpScale:.006}), 0, 0, 0, 0, {h:-99, a:.3, col:crust, fr:0, is:copper ? .45 : .22});
    const lump = (r, at, o2 = {}) => { const L = lumpGeo(rng, Object.assign({r, sx:1.2 + rng() * .3, sy:.7 + rng() * .25, sz:1, wave:.16, bumps:[[14, .5, .14], [40, .2, .05]], pits:[30, .12, .05]}, o2));
      const m = add(new THREE.Mesh(tintCav(L.g, L.cav, .55), mm)); m.position.copy(at); m.rotation.set(rng() * 6.3, rng() * 6.3, rng() * 6.3); return m; };
    if (!copper && rng() < .45) {
      // gold set in a lump of milky vein quartz
      const Q = lumpGeo(rng, {r:.55, sx:1.25, sy:.85, sz:1, wave:.22, bumps:[[8, .6, .12]], pits:[20, .15, .06], seg:64});
      const qm = irid(new THREE.MeshPhysicalMaterial({color:0xece9e2, vertexColors:true, roughness:.35, clearcoat:.4, flatShading:true}), 0, 0, 0, 0, {h:-99, a:.3, col:new THREE.Color(0x6a3a1a).convertSRGBToLinear(), fr:.9, is:.18});
      const q = add(new THREE.Mesh(tintCav(Q.g, Q.cav, .5), qm));
      const qp = Q.g.attributes.position, tmp = new THREE.Vector3();
      for (let k = 0, n = 3 + Math.floor(rng() * 4); k < n; k++) { tmp.fromBufferAttribute(qp, Math.floor(rng() * qp.count)); lump(.1 + rng() * .14, tmp.clone().multiplyScalar(.95), {seg:56}); }
    } else {
      lump(.5, new THREE.Vector3());
      for (let k = 0, n = Math.floor(rng() * 3); k < n; k++) lump(.14 + rng() * .14, new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize().multiplyScalar(.45), {seg:56});
    }
    // dendrites: branching wires with rounded joints, the classic look of crystallised copper and wire gold
    if (copper || rng() < .4) { const list = [], joints = [], grow = (p, d, l, r, depth) => { list.push({p:p.clone(), d:d.clone(), l, r}); const e = p.clone().addScaledVector(d, l); joints.push([e, r * 1.5]);
        if (depth > 0) for (let k = 0, n = 2 + (rng() < .3 ? 1 : 0); k < n; k++) grow(e, d.clone().add(new THREE.Vector3(rng() - .5, rng() * .5, rng() - .5).multiplyScalar(1.2)).normalize(), l * (.68 + rng() * .15), r * .78, depth - 1); };
      for (let k = 0, n = copper ? 4 : 2; k < n; k++) { const d = new THREE.Vector3(rng() - .5, .4 + rng() * .6, rng() - .5).normalize(); grow(d.clone().multiplyScalar(.35), d, .16, .03, 4); }
      const cyl = new THREE.CylinderGeometry(1, 1, 1, 10); cyl.translate(0, .5, 0);
      const im = new THREE.InstancedMesh(cyl, new THREE.MeshPhysicalMaterial({color:col, metalness:1, roughness:.3, envMapIntensity:1.7}), list.length), mt = new THREE.Matrix4(), q = new THREE.Quaternion();
      list.forEach((L, k) => { q.setFromUnitVectors(up, L.d); mt.compose(L.p, q, new THREE.Vector3(L.r, L.l, L.r)); im.setMatrixAt(k, mt); }); add(im);
      inst(new THREE.SphereGeometry(1, 12, 8), new THREE.MeshPhysicalMaterial({metalness:1, roughness:.3, envMapIntensity:1.7}), joints.length, (k, e, sc, c) => { sc.setScalar(joints[k][1]); c.copy(col); return joints[k][0]; }); }
""" + s[j:]

# ---------- botryoidal masses ----------
i = s.index("  } else if (layout === 'botryoid') {"); j = s.index("  } else if (layout === 'single') {")
s = s[:i] + r"""  } else if (layout === 'botryoid') {
    // one flowing mass of melted-together grapes (or a stand of rounded stalagmites), banded like a polished slab, weathered in the hollows
    const banded = ['malachite', 'azurite', 'chrysocolla'].includes(o.sid), crust = new THREE.Color(o.sid === 'opal' ? 0x8a7a68 : banded ? 0x2a1a10 : 0x4a3424).convertSRGBToLinear();
    const bm = irid(new THREE.MeshPhysicalMaterial({color:col, vertexColors:true, roughness:o.sid === 'opal' ? .12 : .22, clearcoat:.8, clearcoatRoughness:.15, envMapIntensity:1.4}),
      o.sid === 'opal' ? .95 : Math.max(irk, .12), 0, 0, banded ? .5 : o.sid === 'opal' ? 0 : .18, {h:-.3, a:.35, col:crust, fr:0, is:.08});
    if (rng() < .35) {
      // rounded stalagmites crowded together on a crusty foot
      for (let k = 0, n = 4 + Math.floor(rng() * 5); k < n; k++) { const len = .6 + rng() * .8, L = lumpGeo(rng, {r:.5, sx:.34 + rng() * .12, sy:len, sz:.34 + rng() * .12, wave:.05, bumps:[[30, .35, .1], [90, .14, .035]], seg:72});
        const m = add(new THREE.Mesh(tintCav(L.g, L.cav, .6), bm)); m.position.set((rng() - .5) * .7, len * .35 - .2, (rng() - .5) * .5); m.rotation.set((rng() - .5) * .35, rng() * 6.3, (rng() - .5) * .35); }
      const F = lumpGeo(rng, {r:.55, sx:1.3, sy:.35, sz:1, wave:.1, bumps:[[40, .3, .08], [120, .12, .03]], seg:72}); add(new THREE.Mesh(tintCav(F.g, F.cav, .6), bm)).position.y = -.3;
    } else {
      const M = lumpGeo(rng, {r:.55, sx:1.2 + rng() * .3, sy:.75 + rng() * .25, sz:1, wave:.12, bumps:[[46, .42, .16], [180, .14, .045]]});
      add(new THREE.Mesh(tintCav(M.g, M.cav, .6), bm));
      for (let k = 0, n = Math.floor(rng() * 3); k < n; k++) { const L = lumpGeo(rng, {r:.18 + rng() * .14, wave:.1, bumps:[[20, .45, .14], [60, .16, .05]], seg:64});
        add(new THREE.Mesh(tintCav(L.g, L.cav, .6), bm)).position.copy(new THREE.Vector3(rng() - .5, rng() * .6, rng() - .5).normalize().multiplyScalar(.5)); }
    }
""" + s[j:]

rep("const hasBase = !['floater', 'radial', 'columnar', 'geode'].includes(layout)", "const hasBase = !['floater', 'radial', 'columnar', 'geode', 'nugget', 'botryoid'].includes(layout)")
open(p, 'w', encoding='utf-8').write(s)
print('ok')
