p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("x.fillStyle = t < .12 ? `hsl(25,30%,${14 + j * 6}%)` : `hsl(${t > .75 ? hue : 210 + j * 15},${t > .75 ? 35 : 8 + j * 6}%,${38 + t * 30 + j * 14}%)`;",
    "x.fillStyle = t < .25 ? `hsl(${20 + j * 8},${35 + j * 15}%,${12 + t * 40 + j * 6}%)` : `hsl(${t > .8 ? hue : 30 + j * 180},${t > .8 ? 30 : 6 + j * 8}%,${18 + t * 28 + j * 12}%)`;")
rep("""    const rim = add(new THREE.Mesh(new THREE.RingGeometry(.84, 1.01, 96, 1), new THREE.MeshStandardMaterial({map:bands, roughness:.75, side:THREE.DoubleSide})), true, shell);""",
"""    // a broken, uneven lip instead of a clean ring
    const rg = new THREE.RingGeometry(.84, 1.01, 120, 3), rp = rg.attributes.position, wob = Array.from({length:4}, () => [1 + Math.floor(rng() * 9), rng() * 6.3]);
    for (let i = 0; i < rp.count; i++) { const x = rp.getX(i), y = rp.getY(i), a = Math.atan2(y, x), r = Math.hypot(x, y), t = (r - .84) / .17;
      let n = 0; for (const [f, ph] of wob) n += Math.sin(a * f + ph) * .25; n += Math.sin(a * 37 + r * 9) * .12;
      const rr = r + (t > .5 ? n * .03 : 0); rp.setXYZ(i, Math.cos(a) * rr, Math.sin(a) * rr, (n * .05 + Math.sin(a * 53) * .012) * (1 - Math.abs(t - .5))); }
    rg.computeVertexNormals();
    const rim = add(new THREE.Mesh(rg, new THREE.MeshStandardMaterial({map:bands, roughness:.8, side:THREE.DoubleSide, flatShading:true})), true, shell);""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
