"""Specimen realism pass: striated, chipped crystals with refraction and dispersion; porous rock with cavity shading; branching coral, needle sprays, botryoidal crusts; studio backdrop."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'specimen.js')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:100])
    s = s.replace(a, b)

def between(start, end, new):
    global s
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + s[j:]

# ---- studio: cyclorama gradient behind, grain texture for rock relief ----
rep("  const s = SPEC.scene = new THREE.Scene(); s.background = new THREE.Color(0xe3e2de);",
r"""  const s = SPEC.scene = new THREE.Scene();
  { const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d');
    const g = x.createRadialGradient(256, 210, 30, 256, 260, 380); g.addColorStop(0, '#f3f2ee'); g.addColorStop(.55, '#dedcd6'); g.addColorStop(1, '#b9b6ae');
    x.fillStyle = g; x.fillRect(0, 0, 512, 512); const im = x.getImageData(0, 0, 512, 512);
    for (let i = 0; i < im.data.length; i += 4) { const n = (Math.random() - .5) * 5; im.data[i] += n; im.data[i + 1] += n; im.data[i + 2] += n; }
    x.putImageData(im, 0, 0); const t = new THREE.CanvasTexture(c); t.encoding = THREE.sRGBEncoding; s.background = t; }
  { const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d'), im = x.createImageData(256, 256);
    for (let i = 0; i < im.data.length; i += 4) { const v = 128 + (Math.random() - .5) * 200; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; }
    x.putImageData(im, 0, 0); x.filter = 'blur(1px)'; x.drawImage(c, 0, 0); SPEC.grain = new THREE.CanvasTexture(c); SPEC.grain.wrapS = SPEC.grain.wrapT = THREE.RepeatWrapping; SPEC.grain.repeat.set(3, 3); }""")

# ---- crystal shader: rainbow film + growth striations + refraction with dispersion ----
between("// a thin oily rainbow over the crystal faces\nfunction irid(mat, k){", "function disposeTree(g)", r"""// crystal shading: oily rainbow film, horizontal growth striations, refraction of the studio with slight dispersion
function irid(mat, k, rf = 0, st = 0){
  mat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, {uIr:{value:k}, uRf:{value:rf}, uSt:{value:st}});
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vOP;`).replace('#include <begin_vertex>', `#include <begin_vertex>
      vOP = position;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform float uIr, uRf, uSt; varying vec3 vOP;`).replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
      // growth lines across the prism faces catch the light in thin bands
      normal = normalize(normal + uSt * vec3(0.0, sin(vOP.y * 95.0 + sin(vOP.x * 9.0 + vOP.z * 7.0) * 2.5) * .16, 0.0));`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      float fr = 1.0 - abs(dot(normalize(normal), normalize(vViewPosition)));
      float hue = fr * 2.4 + sin(vOP.x * 9.0 + vOP.y * 5.0) * .35 + sin(vOP.z * 11.0 - vOP.y * 7.0) * .25;
      vec3 ir = .5 + .5 * cos(6.2832 * (hue + vec3(0.0, .33, .67)));
      float msk = smoothstep(.15, .85, sin(vOP.y * 6.0 + vOP.x * 4.0 + vOP.z * 3.0) * .5 + .5);
      totalEmissiveRadiance += ir * uIr * (uIr > 1.5 ? .7 + .6 * fr : .2 + .8 * fr * fr) * (uIr > 1.5 ? 1.0 : .35 + .65 * msk);
      #ifdef ENVMAP_TYPE_CUBE_UV
        if (uRf > 0.0) {
          vec3 nW = inverseTransformDirection(normalize(normal), viewMatrix), iW = inverseTransformDirection(normalize(-vViewPosition), viewMatrix);
          vec3 cr = vec3(textureCubeUV(envMap, refract(iW, nW, .64), .03).r, textureCubeUV(envMap, refract(iW, nW, .61), .03).g, textureCubeUV(envMap, refract(iW, nW, .58), .03).b);
          totalEmissiveRadiance += cr * mix(vec3(1.0), diffuseColor.rgb * 1.4, .7) * uRf;
        }
      #endif`);
  };
  mat.customProgramCacheKey = () => 'xtal' + (mat.flatShading ? 'f' : 's') + (rf > 0 ? 'r' : '') + (st > 0 ? 's' : '');
  return mat;
}
""")

# ---- chipped crystal edges ----
rep("  for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i), z = p.getZ(i), n = Math.sin(x * 37 + y * 13) * Math.sin(z * 29 - y * 7); p.setXYZ(i, x * (1 + n * .05), y, z * (1 + n * .05)); }",
    "  const top = h * .82, hs = (x, y, z) => { const v = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453; return v - Math.floor(v); };\n"
    "  for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i), z = p.getZ(i), n = Math.sin(x * 37 + y * 13) * Math.sin(z * 29 - y * 7);\n"
    "    // a few corners near the termination are knocked off\n"
    "    const chip = y > top && hs(x, y, z) > .72 ? .78 : 1; p.setXYZ(i, x * (1 + n * .05) * chip, y - (chip < 1 ? .03 : 0), z * (1 + n * .05) * chip); }")

# ---- crystal and gem materials use the refraction ----
rep("    : new THREE.MeshPhysicalMaterial({color:col, emissive:col.clone().multiplyScalar(.12), roughness:Math.max(.02, .16 - gi * .035), metalness:.05, clearcoat:1, clearcoatRoughness:.04, flatShading:true, envMapIntensity:2.4,\n"
    "      transparent:true, opacity:habit === 'octa' || habit === 'dodeca' ? .72 : Math.max(.42, .8 - gi * .09), side:THREE.DoubleSide, depthWrite:false}), irk);",
    "    : new THREE.MeshPhysicalMaterial({color:col, emissive:col.clone().multiplyScalar(.08), roughness:Math.max(.02, .16 - gi * .035), metalness:.05, clearcoat:1, clearcoatRoughness:.04, flatShading:true, envMapIntensity:2.2,\n"
    "      transparent:true, opacity:habit === 'octa' || habit === 'dodeca' ? .8 : Math.max(.5, .82 - gi * .07), side:THREE.DoubleSide, depthWrite:false}), irk, .28 + gi * .1, ['prism', 'blade', 'barrel', 'scaleno'].includes(habit) ? 1 : 0);")
rep("    const m = new THREE.MeshPhysicalMaterial({color:col, roughness:.02, transmission:.9, clearcoat:1, flatShading:o.cut !== 'cab', envMapIntensity:2.2});\n    irid(m, o.cut === 'master' ? .45 : .2);",
    "    const m = new THREE.MeshPhysicalMaterial({color:col, emissive:col.clone().multiplyScalar(.06), roughness:.02, metalness:.05, clearcoat:1, flatShading:o.cut !== 'cab', envMapIntensity:2.6, transparent:true, opacity:.86, side:THREE.DoubleSide, depthWrite:false});\n"
    "    irid(m, o.cut === 'master' ? .45 : .2, o.cut === 'cab' ? .35 : .85);")

# ---- porous host rock with cavity shading ----
between("  // host rock: porous, dark, with rusty and pale spots", "  const pos = rock.attributes.position, top = [];", r"""  // host rock: lumpy, pitted with pores, darker inside the pits, gritty to the touch
  const rock = new THREE.IcosahedronGeometry(.62, 4), cav = new Float32Array(rock.attributes.position.count);
  { const p = rock.attributes.position, v = new THREE.Vector3(), u = new THREE.Vector3();
    const ks = Array.from({length:7}, (_, k) => [new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize().multiplyScalar((2 + rng() * 4) * (1 + k * .6)), rng() * 6.3, .14 / (1 + k * .7)]);
    const pores = Array.from({length:55}, () => [new THREE.Vector3(rng() - .5, rng() * .9 - .2, rng() - .5).normalize(), .05 + rng() * .11, .06 + rng() * .14]);
    for (let i = 0; i < p.count; i++) { v.fromBufferAttribute(p, i); u.copy(v).normalize(); let n = 0; for (const [k, ph, a] of ks) n += Math.sin(v.dot(k) + ph) * a;
      let pit = 0; for (const [c, r, d] of pores) { const dd = u.distanceTo(c); if (dd < r) pit = Math.max(pit, d * (1 - (dd / r) * (dd / r))); }
      v.multiplyScalar(1 + n - pit); cav[i] = pit * 5 + Math.max(0, -n) * 2; p.setXYZ(i, v.x, v.y, v.z); }
    rock.scale(1.15, .58, .95); rock.computeVertexNormals(); }
  { const cc = new Float32Array(rock.attributes.position.count * 3), p = rock.attributes.position, c = new THREE.Color();
    const base = new THREE.Color().setHSL(.07 + rng() * .05, .08 + rng() * .1, .12 + rng() * .08).convertSRGBToLinear(), crust = new THREE.Color().setHSL(.1 + rng() * .05, .12, .55).convertSRGBToLinear(), rust = new THREE.Color(0x7a4a2a).convertSRGBToLinear();
    for (let i = 0; i < p.count; i++) { const n = Math.sin(p.getX(i) * 11 + p.getZ(i) * 7) * Math.sin(p.getY(i) * 15 + p.getX(i) * 4); c.copy(base);
      if (n > .62) c.lerp(crust, .28); else if (n < -.72) c.lerp(rust, .3);
      c.multiplyScalar(Math.max(.25, 1 - cav[i] * .9)); c.toArray(cc, i * 3); }
    rock.setAttribute('color', new THREE.BufferAttribute(cc, 3)); }
  const rockMesh = add(new THREE.Mesh(rock, new THREE.MeshStandardMaterial({vertexColors:true, roughness:.96, flatShading:true, bumpMap:SPEC.grain, bumpScale:.03})));
""")
rep("  const pick = () => top[Math.floor(rng() * top.length)] || new THREE.Vector3(0, .3, 0);",
    "  const pick = () => top[Math.floor(rng() * top.length)] || new THREE.Vector3(0, .3, 0);\n"
    "  const nrm = v => new THREE.Vector3(v.x / 1.3, v.y / .34, v.z / .9).normalize(); // outward direction on the squashed rock\n"
    "  const up = new THREE.Vector3(0, 1, 0);")
rep("    for (let k = 0; k < n; k++) { const s = add(new THREE.Mesh(new THREE.SphereGeometry(.07 + rng() * .14, 18, 12), m)); s.position.copy(pick()).multiplyScalar(.98); s.position.y += rng() * .08; }",
    "    // grape-like crust half sunk into the rock, small balls on big ones\n"
    "    const n2 = 34 + Math.floor(rng() * 30);\n"
    "    for (let k = 0; k < n2; k++) { const r = .05 + rng() * .13, at = pick(); const s = add(new THREE.Mesh(new THREE.SphereGeometry(r, 22, 14), m)); s.position.copy(at).addScaledVector(nrm(at), -r * .35); }")

# ---- growths: branching coral, needle sprays, crusts; finer moss; glass bubbles ----
between("  if (tr.has('coral') || rng() < .35) {", "  if (tr.has('moss') || rng() < .2) {", r"""  const segs = (geoUnitY, mat, list) => inst(geoUnitY, mat, list.length, (k, e, sc, c) => { const L = list[k];
    const q = new THREE.Quaternion().setFromUnitVectors(up, L.d); e.setFromQuaternion(q); sc.set(L.r, L.l, L.r); c.copy(L.c); return L.p; });
  const cyl = new THREE.CylinderGeometry(1, 1, 1, 6); cyl.translate(0, .5, 0);
  const cone = new THREE.ConeGeometry(1, 1, 5); cone.translate(0, .5, 0);
  const pal = [[0xff6a2a, 0xffb040, 0xd8302a], [0x3a6aff, 0x7fb4ff, 0x1a2a8a], [0xf4f0e8, 0xd8d0c0, 0xb8b0a0], [0xff4a8a, 0xffb0d0, 0x8a2a5a], [0xd8e04a, 0xf4f0a0, 0x7a8a2a]][Math.floor(rng() * 5)].map(h => new THREE.Color(h).convertSRGBToLinear());
  const strong = tr.has('coral'), style = strong ? Math.floor(rng() * 3) : rng() < .4 ? 1 + Math.floor(rng() * 2) : -1;
  if (style === 0) {
    // coralloid branches, like flos ferri: forking stems with knobbly tips
    const list = [], tips = [];
    const grow = (p, d, l, r, depth) => { list.push({p:p.clone(), d:d.clone(), l, r, c:pal[Math.min(2, 2 - depth % 3)]}); const end = p.clone().addScaledVector(d, l);
      if (depth <= 0 || l < .02) { tips.push(end); return; }
      for (let k = 0, n = 2 + (rng() < .35 ? 1 : 0); k < n; k++) { const nd = d.clone().add(new THREE.Vector3(rng() - .5, rng() * .5, rng() - .5).multiplyScalar(1.3)).normalize(); grow(end, nd, l * (.62 + rng() * .2), r * .72, depth - 1); } };
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
""")
rep("const seeds = Array.from({length:tr.has('moss') ? 7 : 2}, pick), n = tr.has('moss') ? 900 : 180;", "const seeds = Array.from({length:tr.has('moss') ? 8 : 2}, pick), n = tr.has('moss') ? 1400 : 220;")
rep("const l = .04 + rng() * .1; sc.set(.01, l, .01);", "const l = .03 + rng() * .09; sc.set(.006, l, .006);")
rep("inst(new THREE.SphereGeometry(1, 14, 10), new THREE.MeshPhysicalMaterial({roughness:.02, transmission:.9, clearcoat:1, envMapIntensity:2}), 40,",
    "inst(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshPhysicalMaterial({roughness:.02, clearcoat:1, envMapIntensity:2.6, transparent:true, opacity:.4, depthWrite:false}), 40,")

open(P, 'w', encoding='utf-8').write(s)
print('ok')
