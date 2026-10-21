"""specimen.js v3: columnar crystals fused into rock, inclusions, veils, pyrite cubes, rusty tufts."""
import os
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)

# material gets the rock line
rep("""  const zcfg = () => ({cA:zone ? cA : col, cB, zk:zone});
  const cmat = () => irid(""", """  const zcfg = () => ({cA:zone ? cA : col, cB, zk:zone});
  const DT = {h:-99, a:.4, col:new THREE.Color(.1, .1, .1), fr:rng() < .5 ? .7 : 0};
  const cmat = () => irid(""")
rep("""['prism', 'blade', 'barrel', 'scaleno'].includes(habit) ? 1 : 0);
  const kind""", """['prism', 'blade', 'barrel', 'scaleno'].includes(habit) ? 1 : 0, metal ? null : DT);
  const kind""")
# layout choice: most elongated and cubic stones become columns grown out of rock
rep("""    : elongated && ((kind === 'druse' && rng() < .35) || (kind === 'crystal' && rng() < .12)) ? 'radial' : kind === 'druse' ? 'cluster' : 'single';""",
"""    : elongated && ((kind === 'druse' && rng() < .2) || (kind === 'crystal' && rng() < .08)) ? 'radial'
    : (elongated || habit === 'cube') && kind !== 'geode' && rng() < .75 ? 'columnar' : kind === 'druse' ? 'cluster' : 'single';""")
rep("""  const rtype = layout === 'nugget'""", """  const rtype = layout === 'columnar' ? ['basalt', 'basalt', 'ironstone', 'limestone', 'quartzite'][Math.floor(rng() * 5)] : layout === 'nugget'""")
rep("""  const useRock = shape => { const R = makeRock(rng, rtype, shape); add(R.mesh);""",
"""  const useRock = shape => { const R = makeRock(rng, rtype, shape); add(R.mesh); DT.col.copy(R.base);""")
rep("""    main = crystal(1.15 + rng() * .5, 1.2 + rng() * .3, at, lean(up, .35), {scepter:tr.has('scepter')});""",
"""    main = crystal(1.15 + rng() * .5, 1.2 + rng() * .3, at, lean(up, .35), {scepter:tr.has('scepter')}); DT.h = at.y + .1 + rng() * .25; DT.a = .35;""")
rep("""    main = crystal(1.1 + rng() * .5, 1.15 + rng() * .3, new THREE.Vector3(0, .18, 0), lean(up, .3), {scepter:tr.has('scepter')});""",
"""    main = crystal(1.1 + rng() * .5, 1.15 + rng() * .3, new THREE.Vector3(0, .18, 0), lean(up, .3), {scepter:tr.has('scepter')}); DT.h = .14; DT.a = .3;""")
rep("""  } else if (layout === 'radial') {""", """  } else if (layout === 'columnar') {
    // chunky columns pushing out of a crumbling rock that still climbs up their feet
    const R = useRock(rng() < .5 ? 'small' : 'chunk'); R.mesh.scale.multiplyScalar(.8); R.mesh.position.y = -.12;
    const cubic = habit === 'cube', sides = cubic || habit === 'blade' || rng() < .3 ? 4 : 6, axis = lean(up, cubic ? .3 : .55);
    const n = kind === 'druse' ? 4 + Math.floor(rng() * 4) : 1 + Math.floor(rng() * 3);
    for (let k = 0; k < n; k++) {
      const w = (k ? .13 + rng() * .17 : .27 + rng() * .13) * (cubic ? 1.25 : 1), h = cubic ? w * (1.5 + rng() * .8) : k ? .45 + rng() * .9 : 1.45 + rng() * .65;
      const g = prismGeo(rng, {sides, w, d:habit === 'blade' ? w * .42 : w * (.7 + rng() * .45), h, point:!cubic && rng() < .45, slope:rng() < .65 ? .4 + rng() * 1.1 : 0}, zcfg());
      const c = add(new THREE.Mesh(g, mat)); c.renderOrder = 2;
      c.position.set(k ? (rng() - .5) * .55 : 0, -.05, k ? (rng() - .5) * .4 : 0);
      c.quaternion.setFromUnitVectors(up, lean(axis, cubic ? 1.2 : .35)); c.rotateY(rng() * 6.28);
      if (!main) main = c; }
    DT.h = .08 + rng() * .4; DT.a = .45 + rng() * .45;
  } else if (layout === 'radial') {""")

INST = """  const inst = (geo, m, n, place, parent = root) => { if (n <= 0) return; const im = new THREE.InstancedMesh(geo, m, n), mt = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), sc = new THREE.Vector3(), c = new THREE.Color();
    for (let k = 0; k < n; k++) { const r = place(k, e, sc, c); q.setFromEuler(e); mt.compose(r, q, sc); im.setMatrixAt(k, mt); im.setColorAt(k, c); } im.castShadow = true; add(im, true, parent); };
"""
rep(INST, '')
# inclusions, smoky veils, pyrite cubes and rusty fluff
rep("""  // accessory growths, as on real specimens""", INST + """  // the look of a fine specimen: things trapped inside the clear crystal, crusts at the rock line
  const INC = [[0xe8b030, 0xe07020, 0xc02818, 0xf4e0b0], [0x8a4020, 0xb06030, 0x4a2010, 0xd09050], [0x1a1a1a, 0x3a3a3a, 0x6a6a6a, 0xe8e8e8], [0x2a4a2a, 0x4a6a3a, 0x1a2a1a, 0x8aa070]];
  const incI = Math.floor(rng() * INC.length), incP = INC[incI].map(h => new THREE.Color(h).convertSRGBToLinear());
  if (main && mat && layout !== 'geode' && rng() < (o.legend ? 1 : .55 + gi * .1)) {
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
  const cols = []; if (mat) root.children.forEach(m => { if (m.isMesh && m.material === mat) cols.push(m); });
  const nearLine = (p, n) => Math.abs(p.y - DT.h - .05) < .22 && n.y > -.3;
  if (cols.length && DT.h > -50 && (o.sid === 'pyrite' || rng() < .35)) {
    // bright little cubes, pyrite or galena, perched where crystal meets rock
    const pts = cols.flatMap(m => surfPts(m, 14, rng, nearLine)).slice(0, 26), pc = new THREE.Color(rng() < .6 ? 0xd8c890 : 0xc8ccd2).convertSRGBToLinear();
    inst(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({metalness:1, roughness:.18, envMapIntensity:1.6, flatShading:true}), pts.length, (k, e, sc, c) => { const [p, nn] = pts[k], s0 = .03 + Math.pow(rng(), 2) * .08;
      e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(s0); c.copy(pc); return p.clone().addScaledVector(nn, s0 * .15); });
  }
  if (cols.length && (tr.has('coral') || rng() < .35)) {
    // a rusty, scruffy tuft of fine needles clinging to the crystal
    const at = cols.flatMap(m => surfPts(m, 3, rng, p => DT.h < -50 || p.y > DT.h - .05)).slice(0, 1 + Math.floor(rng() * 2));
    const rc = [0x9a3a12, 0xc8601e, 0x5a200a, 0xe08a3a].map(h => new THREE.Color(h).convertSRGBToLinear());
    for (const [p, nn] of at) inst(new THREE.BoxGeometry(1, 1, 1), new THREE.MeshStandardMaterial({roughness:.85}), 700, (k, e, sc, c) => {
      const d = new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize(), r = Math.pow(rng(), .5) * .17, v = p.clone().addScaledVector(d, r).addScaledVector(nn, r * .6);
      e.set(rng() * 6, rng() * 6, rng() * 6); sc.set(.005, .02 + rng() * .045, .005); c.copy(rc[Math.floor(rng() * 4)]).multiplyScalar(.6 + rng() * .7); return v; });
  }
  // accessory growths, as on real specimens""")
# the old coral/needles/crust styles stay for non-columnar stones only
rep("""  const hasBase = !['floater', 'radial'].includes(layout), strong = tr.has('coral');""", """  const hasBase = !['floater', 'radial', 'columnar'].includes(layout), strong = tr.has('coral');""")
# bake the rock-space position for the dirt shader
rep("""  if (o.legend) { const halo""", """  root.updateMatrixWorld(true); const inv = new THREE.Matrix4().copy(root.matrixWorld).invert(), rel = new THREE.Matrix4(), tv = new THREE.Vector3();
  root.traverse(m => { if (!m.isMesh || m.isInstancedMesh || !m.material || !m.material.userData.dirt) return;
    rel.multiplyMatrices(inv, m.matrixWorld); const p = m.geometry.attributes.position, a = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).applyMatrix4(rel); tv.toArray(a, i * 3); } m.geometry.setAttribute('aRP', new THREE.BufferAttribute(a, 3)); });
  if (o.legend) { const halo""")
rep("""  mat.customProgramCacheKey = () => 'xtal'""", """  mat.userData.dirt = !!dt;
  mat.customProgramCacheKey = () => 'xtal'""")
open(p, 'w', encoding='utf-8').write(s)
print('ok')
