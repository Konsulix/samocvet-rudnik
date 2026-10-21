p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("""    const bands = canvasTex(256, 256, x => { for (let r = 128; r > 0; r -= 3) { const t = r / 128; x.fillStyle = `hsl(${210 + Math.sin(r * .7) * 20},${12 + Math.sin(r) * 10}%,${t > .93 ? 30 : 62 + Math.sin(r * 1.3) * 18}%)`; x.beginPath(); x.arc(128, 128, r, 0, 7); x.fill(); } });""",
"""    // agate rind: fine bands from the dark outer crust through grey and milky layers to a hint of the stone's own colour
    const hue = new THREE.Color(sp.c).getHSL({}).h * 360, bands = canvasTex(256, 256, x => { for (let r = 128; r > 80; r -= 1.5) { const t = (128 - r) / 48, j = Math.sin(r * 2.1) * .5 + Math.sin(r * .37) * .5;
      x.fillStyle = t < .12 ? `hsl(25,30%,${14 + j * 6}%)` : `hsl(${t > .75 ? hue : 210 + j * 15},${t > .75 ? 35 : 8 + j * 6}%,${38 + t * 30 + j * 14}%)`; x.beginPath(); x.arc(128, 128, r, 0, 7); x.fill(); } });""")
rep("new THREE.RingGeometry(.9, 1.01, 72, 1), new THREE.MeshStandardMaterial({map:bands, roughness:.35, side:THREE.DoubleSide})", "new THREE.RingGeometry(.84, 1.01, 96, 1), new THREE.MeshStandardMaterial({map:bands, roughness:.75, side:THREE.DoubleSide})")
rep("1200, (k, e, sc, c) => {\n      const d = new THREE.Vector3(rng() - .5, rng() * .98 + .02, rng() - .5).normalize(); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.012 + rng() * .02); sc.y *= 1.7;\n      c.copy(col).lerp(new THREE.Color(1, 1, 1), .2 + rng() * .4);",
    "800, (k, e, sc, c) => {\n      const d = new THREE.Vector3(rng() - .5, rng() * .98 + .02, rng() - .5).normalize(); e.set(rng() * 3, rng() * 3, rng() * 3); sc.setScalar(.008 + rng() * .014); sc.y *= 1.7;\n      c.copy(col).multiplyScalar(.6 + rng() * .5);")
rep("DT.local = true; DT.h = .14 + rng() * .1; DT.a = .25; DT.col.setRGB(.55, .56, .58); DT.fr = 0;", "DT.local = true; DT.h = .06 + rng() * .08; DT.a = .2; DT.col.setRGB(.5, .5, .52); DT.fr = 0;")
rep("const cRoot = new THREE.Color(.92, .93, .95).lerp(col, .15), cTip = col.clone().offsetHSL(0, .12, -.04)", "const cRoot = new THREE.Color(.92, .93, .95).lerp(col, .45), cTip = col.clone().offsetHSL(0, .15, -.08)")
open(p, 'w', encoding='utf-8').write(s); print('ok')
