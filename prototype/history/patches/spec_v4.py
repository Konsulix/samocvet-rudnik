"""specimen.js v4: back to the dark floating studio; druses and geodes in the new style; crumbly rock material everywhere."""
import os
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)

def cut(a, b):
    """remove everything from marker a up to (not including) marker b"""
    global s
    i = s.index(a); j = s.index(b, i)
    s = s[:i] + s[j:]

# ---------- studio: dark void only ----------
cut("  // the gallery: pale grey studio", "  // turn it with a finger")
cut("// 'light': gallery plinth;", "const specOf =")
rep("o.cut || '', o.legend ? 1 : 0, SPEC.mode || ''].join('|');", "o.cut || '', o.legend ? 1 : 0].join('|');")
rep("g.rotation.set(SPEC.mode === 'light' ? 0 : .12, .6, 0); fitRod(g);", "g.rotation.set(.12, .6, 0);")
rep("if (SPEC.live) { SPEC.live.visible = true; fitRod(SPEC.live); }", "if (SPEC.live) SPEC.live.visible = true;")
rep("host.classList.add('live'); fitRod(SPEC.live);", "host.classList.add('live');")
cut("  // switch between the gallery plinth and the dark void", "  let last = performance.now(), t = 0;")
rep("L.rotation.x += (SPEC.tilt + (SPEC.mode === 'light' ? 0 : Math.sin(t * .7) * .06) - L.rotation.x) * Math.min(1, dt * 6); L.position.y = SPEC.mode === 'light' ? 0 : Math.sin(t * 1.1) * .06; }",
    "L.rotation.x += (SPEC.tilt + Math.sin(t * .7) * .06 - L.rotation.x) * Math.min(1, dt * 6); L.position.y = Math.sin(t * 1.1) * .06; }")

# ---------- prisms can start at any depth ----------
rep("tp = o.taper ?? (.9 + rng() * .12), y0 = -.3;", "tp = o.taper ?? (.9 + rng() * .12), y0 = o.y0 ?? -.3;")

# ---------- layout choice: druses get their own look ----------
rep("""    : (elongated || habit === 'cube') && kind !== 'geode' && rng() < .75 ? 'columnar' : kind === 'druse' ? 'cluster' : 'single';""",
    """    : kind === 'druse' ? 'cluster' : (elongated || habit === 'cube') && rng() < .75 ? 'columnar' : 'single';""")
rep("opacity:layout === 'columnar' ? .34 + (gi < 2 ? .14 : 0) :", "opacity:layout === 'columnar' || layout === 'cluster' ? .36 + (gi < 2 ? .14 : 0) :")
rep("  if (layout === 'columnar') irk = Math.max(irk, dark ? .75 : .3);", "  if (layout === 'columnar' || layout === 'cluster') irk = Math.max(irk, dark ? .75 : .3);")

# ---------- crumbly rock: the crust shader over the whole surface ----------
rep("""  const useRock = shape => { const R = makeRock(rng, rtype, shape); add(R.mesh); DT.col.copy(R.base);""",
    """  const rockMat = c => irid(new THREE.MeshPhysicalMaterial({color:0xffffff, roughness:.95, flatShading:true}), 0, 0, 0, 0, {h:99, a:.3, col:c.clone(), fr:0});
  const useRock = shape => { const R = makeRock(rng, rtype, shape); R.mesh.material.dispose(); R.mesh.material = rockMat(R.base); add(R.mesh); DT.col.copy(R.base);""")
rep("""    if (rng() < .45) { add(R.mesh); R.mesh.scale.multiplyScalar(.7); R.mesh.position.y = -.2; } else disposeTree(R.mesh);""",
    """    if (rng() < .45) { R.mesh.material.dispose(); R.mesh.material = rockMat(R.base); add(R.mesh); R.mesh.scale.multiplyScalar(.7); R.mesh.position.y = -.2; } else disposeTree(R.mesh);""")

# ---------- druse ----------
rep("""  } else if (layout === 'cluster') {
    useRock(rng() < .6 ? 'slab' : 'long');
    main = crystal(1.1 + rng() * .5, 1.15 + rng() * .3, new THREE.Vector3(0, .18, 0), lean(up, .3), {scepter:tr.has('scepter')}); DT.h = .14; DT.a = .3;
    for (let k = 0, n = 6 + Math.floor(rng() * 8); k < n; k++) { const p = pick(); crystal(.35 + rng() * .7, .45 + rng() * .55, p, lean(nrm(p).lerp(up, .6), .7)); }""",
"""  } else if (layout === 'cluster') {
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
      c.userData.local = true; if (!main) main = c; }""")

# ---------- geode ----------
rep("""    const R = ROCKS[rtype === 'quartzite' ? 'basalt' : rtype];
    const outer = warp(new THREE.SphereGeometry(1, 48, 24, 0, Math.PI * 2, 0, Math.PI / 2), rng, .25, 1.5);
    const ocol = new THREE.Color().setHSL(R.h[0], R.s[0], R.l[0] + .05).convertSRGBToLinear();
    add(new THREE.Mesh(outer, new THREE.MeshStandardMaterial({color:ocol, roughness:.95, flatShading:true, bumpMap:SPEC.grain, bumpScale:.04})), true, shell);
    const inner = new THREE.Mesh(new THREE.SphereGeometry(.9, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({color:new THREE.Color(0x6a7080).convertSRGBToLinear(), roughness:.55, side:THREE.BackSide}));
    add(inner, true, shell);""",
"""    const R = ROCKS[rtype === 'quartzite' ? 'basalt' : rtype];
    const outer = warp(new THREE.SphereGeometry(1, 64, 32, 0, Math.PI * 2, 0, Math.PI / 2), rng, .3, 1.6);
    const ocol = new THREE.Color().setHSL(R.h[0], R.s[0] + .05, R.l[0] + .06).convertSRGBToLinear();
    add(new THREE.Mesh(outer, rockMat(ocol)), true, shell);
    const inner = new THREE.Mesh(new THREE.SphereGeometry(.9, 40, 20, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshStandardMaterial({color:col.clone().lerp(new THREE.Color(.25, .27, .3), .6).multiplyScalar(.5), roughness:.45, side:THREE.BackSide}));
    add(inner, true, shell);
    // a glittering carpet of tiny crystals over the cave wall
    inst(new THREE.OctahedronGeometry(1, 0), new THREE.MeshPhysicalMaterial({roughness:.08, clearcoat:1, flatShading:true, envMapIntensity:2.4}), 1200, (k, e, sc, c) => {
      const d = new THREE.Vector3(rng() - .5, rng() * .98 + .02, rng() - .5).normalize(); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.012 + rng() * .02); sc.y *= 1.7;
      c.copy(col).lerp(new THREE.Color(1, 1, 1), .2 + rng() * .4); return d.multiplyScalar(.885); }, shell);""")
rep("""    const gm = mat ? cmat() : null; if (gm) { gm.opacity = .93; gm.emissive.copy(col).multiplyScalar(.22); }
    for (let k = 0, n = 46 + Math.floor(rng() * 30); k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng() * .95 + .05, rng() - .5).normalize();
      const c = crystal(.3 + rng() * .35, .35 + rng() * .3, d.clone().multiplyScalar(.86), d.clone().negate(), {cA:col, cB:col.clone().offsetHSL(0, .1, .12), zk:1}, gm); shell.attach(c); if (!main) main = c; }""",
"""    // pointed crystals crowding the cave: milky at their roots, deep colour at the tips
    const gm = cmat(); if (!metal) { gm.opacity = .8; gm.emissive.copy(col).multiplyScalar(.18); }
    DT.local = true; DT.h = .14 + rng() * .1; DT.a = .25; DT.col.setRGB(.55, .56, .58); DT.fr = 0;
    const cRoot = new THREE.Color(.92, .93, .95).lerp(col, .15), cTip = col.clone().offsetHSL(0, .12, -.04), prismy = elongated || habit === 'cube';
    for (let k = 0, n = 55 + Math.floor(rng() * 35); k < n; k++) { const d = new THREE.Vector3(rng() - .5, rng() * .95 + .05, rng() - .5).normalize(), f = Math.pow(rng(), 2.2);
      const dir = d.clone().negate().lerp(new THREE.Vector3(0, -1, 0), .25).add(new THREE.Vector3((rng() - .5) * .5, 0, (rng() - .5) * .5)).normalize();
      let c;
      if (prismy) { const w = .035 + f * .1, h = habit === 'cube' ? w * 1.4 : w * (2.4 + rng() * 2.4);
        c = new THREE.Mesh(prismGeo(rng, {sides:habit === 'cube' ? 4 : 6, w, d:w * (.8 + rng() * .3), h, point:habit !== 'cube', y0:-w}, {cA:cRoot, cB:cTip, zk:1}), gm);
        c.position.copy(d).multiplyScalar(.9); c.quaternion.setFromUnitVectors(up, dir); c.rotateY(rng() * 6.28); c.renderOrder = 2; shell.add(c); }
      else { c = crystal(.3 + f * .4, .3 + f * .35, d.clone().multiplyScalar(.86), dir, {cA:cRoot, cB:cTip, zk:1}, gm); shell.attach(c); }
      c.userData.local = true; if (!main) main = c; }""")
rep("    // dense, deeply coloured crystals lining the cave\n", "")
# the inst helper must exist before the geode uses it
INST_START = "  const inst = (geo, m, n, place, parent = root) =>"
i = s.index(INST_START); j = s.index("\n", s.index("\n", i) + 1) + 1
inst_code = s[i:j]; s = s[:i] + s[j:]
rep("  const lean = (d, a) =>", inst_code + "  const lean = (d, a) =>")

# ---------- pyrite on druse plates sits on the rock ----------
rep("    const pts = cols.flatMap(m => surfPts(m, 14, rng, nearLine)).slice(0, 26),",
    "    const pts = DT.local ? Array.from({length:22}, () => { const q = pick(); return [q, nrm(q)]; }) : cols.flatMap(m => surfPts(m, 14, rng, nearLine)).slice(0, 26),")
rep("  if (cols.length && DT.h > -50 && (o.sid === 'pyrite' || rng() < .35)) {", "  if (cols.length && DT.h > -50 && layout !== 'geode' && (o.sid === 'pyrite' || rng() < .35)) {")
rep("const at = cols.flatMap(m => surfPts(m, 3, rng, p => DT.h < -50 || p.y > DT.h - .05))", "const at = cols.flatMap(m => surfPts(m, 3, rng, p => DT.local || DT.h < -50 || p.y > DT.h - .05))")

# ---------- rock-line coordinates: whole specimen, or each crystal from root (0) to tip (1) ----------
rep("""    rel.multiplyMatrices(inv, m.matrixWorld); const p = m.geometry.attributes.position, a = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).applyMatrix4(rel); tv.toArray(a, i * 3); }""",
"""    const p = m.geometry.attributes.position, a = new Float32Array(p.count * 3);
    if (m.userData.local) { const g = m.geometry; if (!g.boundingBox) g.computeBoundingBox(); const bb = g.boundingBox, hgt = Math.max(.001, bb.max.y - bb.min.y);
      for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).sub(bb.min).multiplyScalar(1 / hgt); tv.toArray(a, i * 3); } }
    else { rel.multiplyMatrices(inv, m.matrixWorld); for (let i = 0; i < p.count; i++) { tv.fromBufferAttribute(p, i).applyMatrix4(rel); tv.toArray(a, i * 3); } }""")

open(p, 'w', encoding='utf-8').write(s)
print('ok')
