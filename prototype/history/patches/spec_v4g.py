p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
i = s.index("    // agate rind: fine bands"); j = s.index("    bands.encoding = THREE.sRGBEncoding;\n", i) + len("    bands.encoding = THREE.sRGBEncoding;\n")
s = s[:i] + """    // agate rind: fine bands from the dark outer crust through grey and milky layers to a hint of the stone's own colour
    const hue = new THREE.Color(sp.c).getHSL({}).h, band = (t, c) => { const r = t * 40, j = Math.sin(r * 2.1) * .5 + Math.sin(r * .37) * .5;
      return t < .25 ? c.setHSL((20 + j * 8) / 360, .35 + j * .15, .12 + t * .4 + j * .06) : c.setHSL(t > .8 ? hue : (30 + j * 180) / 360, t > .8 ? .3 : .06 + j * .08, .18 + t * .28 + j * .12); };
""" + s[j:]
rep("const rg = new THREE.RingGeometry(.84, 1.01, 120, 3)", "const rg = new THREE.RingGeometry(.84, 1.01, 120, 16)")
rep("    rg.computeVertexNormals();\n", """    const rc = new Float32Array(rp.count * 3), bc = new THREE.Color();
    for (let i = 0; i < rp.count; i++) { const t = 1 - (Math.hypot(rp.getX(i), rp.getY(i)) - .84) / .2; band(Math.max(0, Math.min(1, t)), bc).convertSRGBToLinear().toArray(rc, i * 3); }
    rg.setAttribute('color', new THREE.BufferAttribute(rc, 3)); rg.computeVertexNormals();
""")
rep("new THREE.MeshStandardMaterial({map:bands, roughness:.8, flatShading:true})", "new THREE.MeshStandardMaterial({vertexColors:true, roughness:.8, flatShading:true})")
open(p, 'w', encoding='utf-8').write(s); print('ok')
