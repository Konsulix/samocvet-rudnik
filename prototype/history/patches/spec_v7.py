"""specimen.js v7: 3D mining machines for the equipment depot, with moving parts."""
import os
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:90])
    s = s.replace(a, b)

rep("// o: {seed, sid, kind, gi, traits, cut, legend} or {seed, jewel:{rid, cols}}\nfunction buildSpecimen(o){\n  if (o.jewel) return buildJewel(o.seed, o.jewel);",
r"""// machines for the depot: painted steel, rubber, a little wood; root.userData.anim lists parts that keep moving
function buildMachine(id){
  const root = new THREE.Group(), anim = [], lin = h => new THREE.Color(h).convertSRGBToLinear();
  const M = {
    paint:new THREE.MeshPhysicalMaterial({color:lin(0xf2b01e), metalness:.25, roughness:.42, clearcoat:.5, clearcoatRoughness:.3}),
    red:new THREE.MeshPhysicalMaterial({color:lin(0xc8341e), metalness:.2, roughness:.45, clearcoat:.4}),
    steel:new THREE.MeshStandardMaterial({color:lin(0xa8b0b8), metalness:.9, roughness:.3, envMapIntensity:1.4}),
    dark:new THREE.MeshStandardMaterial({color:lin(0x2a2e34), metalness:.6, roughness:.5}),
    rubber:new THREE.MeshStandardMaterial({color:lin(0x151515), roughness:.92}),
    wood:new THREE.MeshStandardMaterial({color:lin(0x8a5a2c), roughness:.8}),
    glass:new THREE.MeshPhysicalMaterial({color:lin(0x6a9ac8), metalness:.1, roughness:.05, clearcoat:1, transparent:true, opacity:.6}),
    hot:new THREE.MeshStandardMaterial({color:lin(0xff7a20), emissive:lin(0xff5a10), emissiveIntensity:1.4, roughness:.4}),
    lamp:new THREE.MeshStandardMaterial({color:lin(0xffe7a0), emissive:lin(0xffd070), emissiveIntensity:1.2}),
  };
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  const put = (geo, m, at, rot, parent = root) => { const o = new THREE.Mesh(geo, m); o.castShadow = o.receiveShadow = true; if (at) o.position.copy(at); if (rot) o.rotation.set(...rot); parent.add(o); return o; };
  const box = (w, h, d, m, at, rot, par) => put(new THREE.BoxGeometry(w, h, d), m, at, rot, par);
  const cyl = (rt, rb, h, m, at, rot, par, seg = 24) => put(new THREE.CylinderGeometry(rt, rb, h, seg), m, at, rot, par);
  // a straight member between two points
  const beam = (a, b, r, m, par) => { const d = b.clone().sub(a), o = cyl(r, r, d.length(), m, a.clone().add(b).multiplyScalar(.5), null, par, 8); o.quaternion.setFromUnitVectors(V(0, 1, 0), d.normalize()); return o; };
  const track = (len, z, y) => { box(len, .2, .26, M.rubber, V(0, y, z)); for (let k = 0; k < 5; k++) cyl(.09, .09, .28, M.dark, V(-len / 2 + .12 + k * (len - .24) / 4, y, z), [Math.PI / 2, 0, 0]); };
  const spinner = (o, ax, v) => { anim.push({o, ax, v}); return o; };
  if (id === 'hammer') {
    // jackhammer: body, T-handle with grips, chisel, hose
    cyl(.16, .16, .7, M.paint, V(0, .1, 0)); cyl(.19, .19, .08, M.dark, V(0, .48, 0));
    for (let k = 0; k < 4; k++) put(new THREE.TorusGeometry(.165, .015, 8, 32), M.dark, V(0, -.12 + k * .1, 0), [Math.PI / 2, 0, 0]);
    cyl(.035, .035, .8, M.steel, V(0, .64, 0), [0, 0, Math.PI / 2]); for (const x of [-.32, .32]) cyl(.05, .05, .2, M.rubber, V(x, .64, 0), [0, 0, Math.PI / 2]);
    for (const x of [-.11, .11]) cyl(.03, .03, .16, M.steel, V(x, .56, 0));
    cyl(.1, .13, .16, M.steel, V(0, -.33, 0)); const ch = cyl(.04, .04, .5, M.steel, V(0, -.64, 0)); put(new THREE.ConeGeometry(.045, .14, 12), M.steel, V(0, -.95, 0), [Math.PI, 0, 0]);
    const hose = new THREE.CatmullRomCurve3([V(.16, .3, 0), V(.42, .2, .1), V(.5, -.4, .2), V(.25, -.95, .25), V(-.3, -.98, .2), V(-.45, -.9, -.2), V(.1, -.95, -.35)]);
    put(new THREE.TubeGeometry(hose, 60, .035, 8), M.rubber);
    put(new THREE.CylinderGeometry(.6, .6, .04, 40), M.dark, V(0, -1.02, 0)).material = new THREE.MeshStandardMaterial({color:lin(0x3a3228), roughness:.95});
    spinner(ch, 'y', 3);
  } else if (id === 'rig') {
    // crawler drill rig: tracks, chassis, cab, lattice mast, turning drill rod
    track(1.3, .36, -.62); track(1.3, -.36, -.62);
    box(1.2, .24, .8, M.paint, V(0, -.42, 0)); box(.5, .44, .62, M.paint, V(-.32, -.08, 0)); box(.3, .22, .64, M.glass, V(-.32, .02, 0));
    box(.08, .1, .66, M.red, V(-.06, -.26, 0));
    for (const z of [-.12, .12]) box(.06, 1.7, .06, M.paint, V(.38, .55, z));
    for (let k = 0; k < 7; k++) { const y = -.2 + k * .24; beam(V(.38, y, -.12), V(.38, y + .24, .12), .015, M.paint); box(.06, .03, .3, M.paint, V(.38, y, 0)); }
    box(.18, .14, .3, M.red, V(.38, 1.38, 0)); const rod = cyl(.035, .035, 1.6, M.steel, V(.38, .45, 0)); put(new THREE.ConeGeometry(.07, .18, 10), M.dark, V(.38, -.42, 0), [Math.PI, 0, 0]);
    beam(V(.05, -.28, 0), V(.36, .4, 0), .03, M.steel); spinner(rod, 'y', 6);
  } else if (id === 'tbm') {
    // tunnel boring machine: shield, rotating cutter head with discs, trailing gantry, tracks
    cyl(.46, .46, 1.3, M.paint, V(0, 0, 0), [0, 0, Math.PI / 2], null, 40);
    for (const x of [-.4, .2]) put(new THREE.TorusGeometry(.465, .03, 8, 40), M.red, V(x, 0, 0), [0, Math.PI / 2, 0]);
    const head = new THREE.Group(); head.position.x = .72; root.add(head);
    cyl(.5, .5, .12, M.steel, V(0, 0, 0), [0, 0, Math.PI / 2], head, 40);
    for (let k = 0; k < 6; k++) { const a = k / 6 * 6.283; box(.06, .9, .08, M.dark, V(.07, 0, 0), [a, 0, 0], head); }
    for (let r = 0; r < 3; r++) for (let k = 0, n = 4 + r * 4; k < n; k++) { const a = k / n * 6.283 + r, rr = .12 + r * .14; put(new THREE.ConeGeometry(.035, .1, 8), M.steel, V(.11, Math.cos(a) * rr, Math.sin(a) * rr), [0, 0, -Math.PI / 2], head); }
    put(new THREE.ConeGeometry(.06, .14, 10), M.red, V(.13, 0, 0), [0, 0, -Math.PI / 2], head); spinner(head, 'x', 1.6);
    box(.6, .34, .5, M.dark, V(-.95, -.12, 0)); for (const z of [-.18, .18]) beam(V(-1.2, -.3, z), V(-1.2, .25, z), .025, M.paint); beam(V(-1.2, .25, -.18), V(-.6, .25, -.18), .025, M.paint); beam(V(-1.2, .25, .18), V(-.6, .25, .18), .025, M.paint);
    cyl(.05, .05, .9, M.steel, V(-.8, .32, .1), [0, 0, Math.PI / 2]); track(1.4, .3, -.52); track(1.4, -.3, -.52);
  } else if (id === 'deep') {
    // deep drill: a lattice derrick over a platform, drill string glowing hot below
    box(1.1, .12, 1.1, M.dark, V(0, -.85, 0)); for (const [x, z] of [[-.5, -.5], [.5, -.5], [-.5, .5], [.5, .5]]) cyl(.04, .05, .35, M.steel, V(x, -1.06, z));
    const legs = [[-.42, -.42], [.42, -.42], [.42, .42], [-.42, .42]].map(([x, z]) => [V(x, -.79, z), V(x * .2, 1.05, z * .2)]);
    for (const [a, b] of legs) beam(a, b, .03, M.red);
    for (let k = 1; k < 6; k++) { const t = k / 6, pts = legs.map(([a, b]) => a.clone().lerp(b, t)); for (let q = 0; q < 4; q++) { beam(pts[q], pts[(q + 1) % 4], .014, M.steel); if (k < 5) beam(pts[q], legs[(q + 1) % 4][0].clone().lerp(legs[(q + 1) % 4][1], (k + 1) / 6), .01, M.steel); } }
    box(.24, .14, .24, M.paint, V(0, 1.1, 0)); const str = cyl(.03, .03, 1.95, M.steel, V(0, .02, 0)); box(.3, .1, .3, M.paint, V(0, -.74, 0));
    cyl(.06, .03, .2, M.hot, V(0, -1.08, 0)); box(.34, .26, .3, M.paint, V(.62, -.66, .2)); box(.2, .14, .02, M.glass, V(.62, -.62, .36)); spinner(str, 'y', 5);
    const glow = put(new THREE.SphereGeometry(.12, 16, 12), new THREE.MeshBasicMaterial({color:0xff8a30, transparent:true, opacity:.35, depthWrite:false}), V(0, -1.12, 0)); glow.castShadow = false;
  } else if (id === 'lift') {
    // winch: skid, side frames, a drum wound with cable, motor, a sheave above
    box(1.1, .1, .7, M.dark, V(0, -.5, 0)); for (const z of [-.3, .3]) box(.7, .7, .06, M.paint, V(0, -.1, z));
    const drum = new THREE.Group(); drum.position.y = -.05; root.add(drum);
    cyl(.24, .24, .54, M.steel, V(0, 0, 0), [Math.PI / 2, 0, 0], drum); for (let k = 0; k < 9; k++) put(new THREE.TorusGeometry(.25, .018, 6, 32), M.dark, V(0, 0, -.24 + k * .06), null, drum);
    for (const z of [-.28, .28]) cyl(.32, .32, .03, M.red, V(0, 0, z), [Math.PI / 2, 0, 0], drum);
    cyl(.14, .14, .4, M.paint, V(.48, -.24, 0), [Math.PI / 2, 0, 0]); box(.12, .12, .5, M.dark, V(.48, -.38, 0));
    beam(V(-.2, .1, 0), V(-.35, 1, 0), .012, M.dark); for (const z of [-.06, .06]) beam(V(-.5, -.45, z), V(-.35, 1.05, z), .025, M.paint);
    cyl(.1, .1, .05, M.steel, V(-.35, 1.05, 0), [Math.PI / 2, 0, 0]); spinner(drum, 'z', 1.4);
  } else if (id === 'crush') {
    // jaw crusher: square hopper, body, flywheels, a conveyor carrying crushed stone
    const hop = put(new THREE.CylinderGeometry(.5, .26, .45, 4, 1, true), M.paint, V(0, .55, 0), [0, Math.PI / 4, 0]); hop.material = M.paint.clone(); hop.material.side = THREE.DoubleSide;
    box(.6, .55, .5, M.paint, V(0, .05, 0)); box(.62, .08, .52, M.red, V(0, .32, 0));
    for (const z of [-.33, .33]) { const fw = new THREE.Group(); fw.position.set(0, .05, z); root.add(fw); cyl(.32, .32, .06, M.dark, V(0, 0, 0), [Math.PI / 2, 0, 0], fw);
      for (let k = 0; k < 4; k++) box(.6, .05, .07, M.steel, V(0, 0, 0), [0, 0, k * Math.PI / 4], fw); spinner(fw, 'z', 2.2); }
    const belt = new THREE.Group(); belt.position.set(.75, -.35, 0); belt.rotation.z = .35; root.add(belt);
    box(1.1, .05, .3, M.rubber, V(0, 0, 0), null, belt); for (let k = 0; k < 6; k++) cyl(.035, .035, .34, M.steel, V(-.5 + k * .2, -.04, 0), [Math.PI / 2, 0, 0], belt);
    for (let k = 0; k < 9; k++) put(new THREE.DodecahedronGeometry(.04 + (k % 3) * .015, 0), M.dark, V(-.45 + k * .11, .06, (k % 3 - 1) * .07), [k, k * 2, 0], belt);
    for (const x of [-.25, .25]) for (const z of [-.2, .2]) box(.06, .3, .06, M.dark, V(x, -.38, z));
    for (let k = 0; k < 5; k++) put(new THREE.DodecahedronGeometry(.07 + k * .01, 0), new THREE.MeshStandardMaterial({color:lin(0x6a6258), roughness:.9, flatShading:true}), V((k - 2) * .09, .62, (k % 2 - .5) * .12), [k, k, 0]);
  } else if (id === 'food') {
    // provisions: a wooden crate with a lantern and a canteen on top, a barrel and a sack beside
    box(.7, .45, .5, M.wood, V(0, -.3, 0)); for (const y of [-.42, -.27, -.12]) box(.72, .03, .52, new THREE.MeshStandardMaterial({color:lin(0x6a4220), roughness:.85}), V(0, y, 0));
    for (const x of [-.33, .33]) box(.05, .47, .53, new THREE.MeshStandardMaterial({color:lin(0x5a3618), roughness:.85}), V(x, -.3, 0));
    box(.74, .05, .54, M.wood, V(.04, -.05, .02), [0, .08, -.06]);
    cyl(.07, .08, .04, M.dark, V(-.15, .0, 0)); cyl(.06, .06, .16, M.glass, V(-.15, .1, 0)); cyl(.035, .035, .1, M.lamp, V(-.15, .1, 0)); cyl(.07, .05, .04, M.dark, V(-.15, .2, 0));
    put(new THREE.TorusGeometry(.04, .008, 6, 16, Math.PI), M.dark, V(-.15, .22, 0));
    const ct = cyl(.1, .1, .05, new THREE.MeshStandardMaterial({color:lin(0x4a6a3a), roughness:.6}), V(.15, .05, 0), [Math.PI / 2, 0, 0]); cyl(.015, .015, .05, M.steel, V(.15, .17, 0));
    const pts = []; for (let k = 0; k <= 10; k++) { const t = k / 10; pts.push(new THREE.Vector2(.2 + Math.sin(t * Math.PI) * .05, -.25 + t * .5)); }
    put(new THREE.LatheGeometry(pts, 24), M.wood, V(.62, -.27, .1)); for (const y of [-.4, -.14]) put(new THREE.TorusGeometry(.23, .012, 6, 32), M.dark, V(.62, y, .1), [Math.PI / 2, 0, 0]);
    const sack = put(new THREE.SphereGeometry(.22, 24, 16), new THREE.MeshStandardMaterial({color:lin(0xc8b088), roughness:.95}), V(-.55, -.38, .15)); sack.scale.set(1, 1.15, .9);
    cyl(.06, .03, .1, new THREE.MeshStandardMaterial({color:lin(0xa88860), roughness:.95}), V(-.55, -.1, .15));
    const bread = put(new THREE.SphereGeometry(.12, 20, 12), new THREE.MeshStandardMaterial({color:lin(0xb87a3a), roughness:.7}), V(.05, -.47, .38)); bread.scale.set(1.4, .6, .8);
  } else {
    // ventilation fan: shroud, guard ring, spinning blades, stand and a duct behind
    const sh = put(new THREE.CylinderGeometry(.56, .56, .32, 48, 1, true), M.paint.clone(), V(0, .1, 0), [Math.PI / 2, 0, 0]); sh.material.side = THREE.DoubleSide;
    for (const z of [-.16, .16]) put(new THREE.TorusGeometry(.57, .035, 10, 48), M.dark, V(0, .1, z));
    const fan = new THREE.Group(); fan.position.set(0, .1, .02); root.add(fan);
    cyl(.1, .1, .14, M.red, V(0, 0, 0), [Math.PI / 2, 0, 0], fan);
    for (let k = 0; k < 6; k++) { const bl = box(.42, .13, .02, M.steel, V(0, 0, 0), null, fan); bl.geometry.translate(.26, 0, 0); bl.rotation.set(.45, 0, k / 6 * 6.283, 'ZXY'); }
    for (let k = 0; k < 8; k++) { const a = k / 8 * 6.283; beam(V(0, .1, .18), V(Math.cos(a) * .55, .1 + Math.sin(a) * .55, .18), .008, M.dark); }
    put(new THREE.TorusGeometry(.3, .008, 6, 40), M.dark, V(0, .1, .18));
    for (const x of [-.35, .35]) beam(V(x * 1.4, -.72, 0), V(x * .9, -.3, 0), .035, M.dark); box(1.1, .06, .4, M.dark, V(0, -.74, 0));
    cyl(.5, .5, .7, new THREE.MeshStandardMaterial({color:lin(0x5a6068), metalness:.6, roughness:.5}), V(0, .1, -.6), [Math.PI / 2, 0, 0], null, 40);
    for (let k = 0; k < 3; k++) put(new THREE.TorusGeometry(.51, .02, 6, 40), M.dark, V(0, .1, -.4 - k * .2));
    spinner(fan, 'z', 9);
  }
  root.userData.anim = anim; root.userData.glow = new THREE.Color(0xf2b01e);
  root.rotation.y = -.5;
  return root;
}
// o: {seed, sid, kind, gi, traits, cut, legend}, {seed, jewel:{rid, cols}} or {machine:id}
function buildSpecimen(o){
  if (o.machine) return buildMachine(o.machine);
  if (o.jewel) return buildJewel(o.seed, o.jewel);""")
rep("o.jewel ? o.jewel.rid + (o.jewel.cols || []).join('') : ''].join('|');", "o.jewel ? o.jewel.rid + (o.jewel.cols || []).join('') : '', o.machine || ''].join('|');")
# moving parts keep moving in the live viewer
rep("      L.rotation.x += (SPEC.tilt + Math.sin(t * .7) * .06 - L.rotation.x) * Math.min(1, dt * 6); L.position.y = Math.sin(t * 1.1) * .06; }",
    "      L.rotation.x += (SPEC.tilt + Math.sin(t * .7) * .06 - L.rotation.x) * Math.min(1, dt * 6); L.position.y = Math.sin(t * 1.1) * .06;\n      const an = L.children[0] && L.children[0].userData.anim; if (an) for (const q of an) q.o.rotation[q.ax] += q.v * dt; }")
open(p, 'w', encoding='utf-8').write(s)
print('ok')
