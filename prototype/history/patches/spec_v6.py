"""specimen.js v6: 3D jewellery (ring, earrings, pendant, brooch, diadem, crown) built from the stones that went into it."""
import os
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)

rep("// o: {seed, sid, kind, gi, traits, cut, legend}\nfunction buildSpecimen(o){", r"""// jewellery: gold work set with faceted stones; j = {rid, cols:['#rrggbb', ...]}
function buildJewel(seed, j){
  const root = new THREE.Group(), rng = mulberry((seed || 1) * 7 + 11), cols = (j.cols && j.cols.length ? j.cols : ['#9fb4d0']);
  const gold = new THREE.MeshPhysicalMaterial({color:new THREE.Color(0xf2c35a).convertSRGBToLinear(), metalness:1, roughness:.16, clearcoat:.7, clearcoatRoughness:.08, envMapIntensity:1.9});
  const mats = new Map(), gemMat = hex => { if (mats.has(hex)) return mats.get(hex); const c = new THREE.Color(hex).convertSRGBToLinear();
    const m = irid(new THREE.MeshPhysicalMaterial({color:c, emissive:c.clone().multiplyScalar(.1), roughness:.02, metalness:.05, clearcoat:1, flatShading:true, envMapIntensity:2.8, transparent:true, opacity:.88, side:THREE.DoubleSide, depthWrite:false}), .3, .9);
    mats.set(hex, m); return m; };
  const col = k => cols[k % cols.length];
  const add = (m, parent = root) => { m.castShadow = true; m.receiveShadow = true; parent.add(m); return m; };
  const G = (geo, at, rot, parent) => { const m = add(new THREE.Mesh(geo, gold), parent); if (at) m.position.copy(at); if (rot) m.rotation.set(...rot); return m; };
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  // a faceted stone, table pointing along `dir`, sitting in a little gold collet
  const stone = (hex, size, at, dir = V(0, 0, 1), cut = 'facet', parent = root) => {
    const g = new THREE.Group(); parent.add(g); g.position.copy(at); g.quaternion.setFromUnitVectors(V(0, 1, 0), dir.clone().normalize());
    const geo = gemGeo(cut); geo.translate(0, -.5, 0);
    const m = new THREE.Mesh(geo, gemMat(hex)); m.scale.setScalar(size); m.renderOrder = 2; g.add(m);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(size * .6, size * .06, 8, 32), gold); ring.rotation.x = Math.PI / 2; g.add(ring);
    for (let k = 0; k < 4; k++) { const a = k / 4 * 6.283 + .4, pr = new THREE.Mesh(new THREE.CylinderGeometry(size * .035, size * .05, size * .32, 6), gold); pr.position.set(Math.cos(a) * size * .6, size * .1, Math.sin(a) * size * .6); pr.rotation.set(Math.sin(a) * .5, 0, -Math.cos(a) * .5); g.add(pr); }
    return g; };
  const bead = (r, at, parent) => G(new THREE.SphereGeometry(r, 16, 12), at, null, parent);
  // a pear-shaped drop, faceted
  const dropGeo = () => { const pts = []; for (let k = 0; k <= 8; k++) { const t = k / 8; pts.push(new THREE.Vector2(Math.sin(t * Math.PI) * (.5 - t * .22) * .9, -t * 1.4)); } return new THREE.LatheGeometry(pts, 10); };
  if (j.rid === 'ring') {
    const sh = G(new THREE.TorusGeometry(.5, .07, 20, 72)); sh.scale.set(1, 1, 1.6);
    G(new THREE.CylinderGeometry(.16, .1, .14, 24), V(0, .55, 0));
    stone(col(0), .42, V(0, .7, 0), V(0, 1, 0), 'master');
    for (const sx of [-1, 1]) { bead(.035, V(sx * .2, .52, .06)); bead(.035, V(sx * .2, .52, -.06)); }
  } else if (j.rid === 'ear') {
    for (const [k, sx] of [[0, -1], [1, 1]]) { const e = new THREE.Group(); e.position.x = sx * .38; root.add(e);
      const hook = G(new THREE.TorusGeometry(.13, .016, 8, 40, Math.PI * 1.4), V(0, .66, 0), [0, 0, -.3], e);
      bead(.045, V(0, .5, 0), e); G(new THREE.CylinderGeometry(.012, .012, .14, 6), V(0, .4, 0), null, e);
      const d = new THREE.Mesh(dropGeo(), gemMat(col(k))); d.scale.setScalar(.36); d.position.y = .32; d.renderOrder = 2; e.add(d);
      const cap = G(new THREE.SphereGeometry(.07, 16, 8, 0, 6.283, 0, 1.2), V(0, .34, 0), null, e); cap.scale.y = .7; }
  } else if (j.rid === 'pend') {
    // a fine chain hanging in a curve
    const link = new THREE.TorusGeometry(.028, .007, 6, 12);
    for (let k = 0; k <= 40; k++) { const t = k / 40 * 2 - 1, x = t * .78, y = .95 - (1 - t * t) * .62; const m = G(link, V(x, y, 0), [0, k % 2 ? Math.PI / 2 : 0, Math.atan2(-.62 * 2 * t * -1, 1)]); }
    G(new THREE.TorusGeometry(.06, .014, 8, 24), V(0, .28, 0), [0, Math.PI / 2, 0]);
    stone(col(0), .5, V(0, -.06, 0), V(0, 0, 1), 'master');
    G(new THREE.TorusGeometry(.34, .03, 10, 48), V(0, -.06, -.02));
    stone(col(1), .16, V(0, -.5, 0), V(0, 0, 1));
    bead(.03, V(0, -.38, 0));
  } else if (j.rid === 'brooch') {
    // a gold flower: petals, a ring of beads, the stones set face-up
    for (let k = 0; k < 7; k++) { const a = k / 7 * 6.283, pe = G(new THREE.SphereGeometry(1, 20, 12), V(Math.cos(a) * .36, Math.sin(a) * .36, -.04), [0, 0, a]); pe.scale.set(.24, .11, .05); }
    for (let k = 0; k < 14; k++) { const a = k / 14 * 6.283; bead(.028, V(Math.cos(a) * .22, Math.sin(a) * .22, .03)); }
    stone(col(0), .34, V(0, 0, .06), V(0, 0, 1), 'master');
    stone(col(1), .15, V(Math.cos(.45) * .58, Math.sin(.45) * .58, .02), V(0, 0, 1));
    stone(col(2), .15, V(Math.cos(3.6) * .58, Math.sin(3.6) * .58, .02), V(0, 0, 1));
    for (const a of [1.6, 5]) { const lf = G(new THREE.SphereGeometry(1, 16, 10), V(Math.cos(a) * .6, Math.sin(a) * .6, -.02), [0, 0, a]); lf.scale.set(.16, .06, .03); }
  } else if (j.rid === 'diadem') {
    // a curved band with rising scrolls, tallest in the middle
    G(new THREE.TorusGeometry(.8, .04, 10, 80, Math.PI * .9), V(0, 0, 0), [Math.PI / 2, 0, Math.PI * .05]);
    const at = a => V(Math.cos(a) * .8, 0, Math.sin(a) * .8);
    for (let k = 0; k < 9; k++) { const a = Math.PI * (.12 + k * .085), h = .18 + Math.sin(k / 8 * Math.PI) * .32, b = at(a);
      const sp = G(new THREE.ConeGeometry(.035, h, 6), V(b.x, h / 2, b.z)); bead(.03, V(b.x, h + .02, b.z));
      if (k % 2 === 0) G(new THREE.TorusGeometry(.07, .012, 6, 20), V(b.x, h * .55, b.z), [0, -a + Math.PI / 2, 0]); }
    const ca = Math.PI / 2, cb = at(ca);
    stone(col(0), .3, V(cb.x, .36, cb.z + .02), V(0, 0, 1), 'master');
    [[.3, 1], [.7, 2], [.38, 3]].forEach(([f, k], q) => { const a = Math.PI * (q === 2 ? .62 : f), b = at(a); stone(col(k), .14, V(b.x * 1.03, .02, b.z * 1.03), b.clone().setY(0)); });
  } else {
    // the crown: band, rims, pointed fleurons with pearls, arches, an orb, a velvet cap, stones all round
    const band = new THREE.Mesh(new THREE.CylinderGeometry(.56, .5, .34, 64, 1, true), gold.clone()); band.material.side = THREE.DoubleSide; add(band);
    G(new THREE.TorusGeometry(.5, .035, 10, 64), V(0, -.17, 0), [Math.PI / 2, 0, 0]); G(new THREE.TorusGeometry(.56, .035, 10, 64), V(0, .17, 0), [Math.PI / 2, 0, 0]);
    for (let k = 0; k < 8; k++) { const a = k / 8 * 6.283, x = Math.cos(a) * .56, z = Math.sin(a) * .56;
      G(new THREE.ConeGeometry(.09, .32, 4), V(x, .33, z), [0, -a, 0]); const pearl = add(new THREE.Mesh(new THREE.SphereGeometry(.045, 16, 10), new THREE.MeshPhysicalMaterial({color:0xf4efe6, roughness:.25, clearcoat:1, envMapIntensity:1.4}))); pearl.position.set(x, .52, z); }
    for (const r of [0, Math.PI / 2]) { const ar = G(new THREE.TorusGeometry(.54, .03, 8, 48, Math.PI), V(0, .17, 0), [0, r, 0]); ar.scale.y = .9; }
    bead(.08, V(0, .7, 0)); G(new THREE.BoxGeometry(.03, .16, .03), V(0, .83, 0)); G(new THREE.BoxGeometry(.1, .03, .03), V(0, .85, 0));
    const cap = add(new THREE.Mesh(new THREE.SphereGeometry(.52, 32, 16, 0, 6.283, 0, Math.PI / 2), new THREE.MeshStandardMaterial({color:new THREE.Color(0x8a1020).convertSRGBToLinear(), roughness:.9}))); cap.position.y = .12; cap.scale.y = .8;
    for (let k = 0; k < 10; k++) { const a = k / 10 * 6.283, d = V(Math.cos(a), 0, Math.sin(a)); stone(col(k % 2 ? 4 : Math.floor(k / 2) % 4), k % 2 ? .1 : .16, d.clone().multiplyScalar(.56).setY(0), d); }
  }
  root.rotation.x = j.rid === 'ring' ? .25 : j.rid === 'crown' || j.rid === 'diadem' ? .3 : 0;
  root.userData.glow = new THREE.Color(0xe4ae39);
  return root;
}
// o: {seed, sid, kind, gi, traits, cut, legend} or {seed, jewel:{rid, cols}}
function buildSpecimen(o){
  if (o.jewel) return buildJewel(o.seed, o.jewel);""")
rep("o.cut || '', o.legend ? 1 : 0].join('|');", "o.cut || '', o.legend ? 1 : 0, o.jewel ? o.jewel.rid + (o.jewel.cols || []).join('') : ''].join('|');")
open(p, 'w', encoding='utf-8').write(s)
print('ok')
