p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("pe = G(new THREE.SphereGeometry(1, 20, 12), V(Math.cos(a) * .36, Math.sin(a) * .36, -.04), [0, 0, a]); pe.scale.set(.24, .11, .05); }",
    "pe = G(new THREE.SphereGeometry(1, 20, 12), V(Math.cos(a) * .3, Math.sin(a) * .3, -.04), [0, 0, a]); pe.scale.set(.27, .14, .05); }")
rep("stone(col(1), .15, V(Math.cos(.45) * .58, Math.sin(.45) * .58, .02), V(0, 0, 1));\n    stone(col(2), .15, V(Math.cos(3.6) * .58, Math.sin(3.6) * .58, .02), V(0, 0, 1));",
    "stone(col(1), .15, V(Math.cos(.45) * .5, Math.sin(.45) * .5, .04), V(0, 0, 1));\n    stone(col(2), .15, V(Math.cos(3.6) * .5, Math.sin(3.6) * .5, .04), V(0, 0, 1));")
rep("const lf = G(new THREE.SphereGeometry(1, 16, 10), V(Math.cos(a) * .6, Math.sin(a) * .6, -.02), [0, 0, a]); lf.scale.set(.16, .06, .03); }",
    "const lf = G(new THREE.SphereGeometry(1, 16, 10), V(Math.cos(a) * .52, Math.sin(a) * .52, -.06), [0, 0, a]); lf.scale.set(.2, .08, .03); }")
rep("G(new THREE.TorusGeometry(.8, .04, 10, 80, Math.PI * .9), V(0, 0, 0), [Math.PI / 2, 0, Math.PI * .05]);",
    "G(new THREE.TorusGeometry(.8, .045, 10, 80, Math.PI * .9), V(0, 0, 0), [Math.PI / 2, 0, Math.PI * .05]).scale.z = 2;")
rep("h = .18 + Math.sin(k / 8 * Math.PI) * .32, b = at(a);", "h = .2 + Math.sin(k / 8 * Math.PI) * .45, b = at(a);")
rep("stone(col(0), .3, V(cb.x, .36, cb.z + .02), V(0, 0, 1), 'master');", "stone(col(0), .38, V(cb.x, .42, cb.z + .04), V(0, 0, 1), 'master');")
rep("stone(col(k), .14, V(b.x * 1.03, .02, b.z * 1.03), b.clone().setY(0)); });", "stone(col(k), .2, V(b.x * 1.04, .05, b.z * 1.04), b.clone().setY(0)); });")
open(p, 'w', encoding='utf-8').write(s); print('ok')
