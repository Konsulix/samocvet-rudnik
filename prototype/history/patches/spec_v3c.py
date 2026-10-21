p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("new THREE.MeshBasicMaterial({color:0xbdbdbb, side:THREE.BackSide})", "new THREE.MeshBasicMaterial({color:0x3c3c3b, side:THREE.BackSide})")
rep("[[0, 4.9, 0, 7, 7, 0xffffff], [-4.9, 1, 1, 4, 5, 0xffffff], [4.9, 1.5, -1, 4, 5, 0xf4f4f4], [0, 1, 4.9, 6, 3, 0xffffff], [3, 0, 4.9, 1.2, 6, 0x202020], [-4.9, 0, -2.5, 1.5, 7, 0x161616], [0, -4.9, 0, 10, 10, 0x8a8a88]]",
    "[[0, 4.9, 0, 5, 5, 0xffffff], [-4.9, 1.5, 1.5, 3, 4, 0xffffff], [4.9, 1.5, -1.5, 2, 4.5, 0xe8e8e8], [-1.5, .5, 4.9, 3, 2.2, 0xffffff], [2.5, 0, 4.9, 1.6, 7, 0x080808], [-4.9, 0, -2.5, 2, 7, 0x080808], [0, 1, -4.9, 4, 3, 0xd8d8d8], [0, -4.9, 0, 10, 10, 0x9a9a98]]")
rep("transparent:true, opacity:habit === 'octa' || habit === 'dodeca' ? .8 :", "transparent:true, opacity:layout === 'columnar' ? .34 + (gi < 2 ? .14 : 0) : habit === 'octa' || habit === 'dodeca' ? .8 :")
rep("    DT.h = .08 + rng() * .4; DT.a = .45 + rng() * .45;", "    DT.h = .3 + rng() * .45; DT.a = .5 + rng() * .5;")
rep("const rtype = layout === 'columnar' ? ['basalt', 'basalt', 'ironstone', 'limestone', 'quartzite']", "const rtype = layout === 'columnar' ? ['basalt', 'basalt', 'ironstone', 'ironstone', 'limestone']")
rep("""      for (let k = 0; k < 22; k++) { const n = new THREE.Mesh(new THREE.CylinderGeometry(.004, .004, .3 + rng() * .6, 4), gm); n.position.set((rng() - .5) * .3, .15 + rng() * h * .7, (rng() - .5) * .3); n.rotation.set((rng() - .5) * 1.6, rng() * 3, (rng() - .5) * 1.6); main.add(n); } }""",
"""      const g = main.geometry; if (!g.boundingBox) g.computeBoundingBox(); const bb = g.boundingBox, w = Math.min(bb.max.x - bb.min.x, bb.max.z - bb.min.z), hh = bb.max.y - Math.max(0, bb.min.y);
      for (let k = 0; k < 22; k++) { const len = Math.min(hh * .7, w * 1.6) * (.4 + rng() * .6), n = new THREE.Mesh(new THREE.CylinderGeometry(.004, .004, len, 4), gm);
        n.position.set((bb.min.x + bb.max.x) / 2 + (rng() - .5) * w * .4, Math.max(0, bb.min.y) + hh * (.25 + rng() * .45), (bb.min.z + bb.max.z) / 2 + (rng() - .5) * w * .4); n.rotation.set((rng() - .5) * .8, rng() * 3, (rng() - .5) * .8); main.add(n); } }""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
