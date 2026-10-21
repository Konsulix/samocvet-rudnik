p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("const dir = d.clone().negate().lerp(new THREE.Vector3(0, -1, 0), .25).add(new THREE.Vector3((rng() - .5) * .5, 0, (rng() - .5) * .5)).normalize();",
    "const dir = d.clone().negate().lerp(new THREE.Vector3(0, 1, 0), .15).add(new THREE.Vector3((rng() - .5) * .45, (rng() - .5) * .2, (rng() - .5) * .45)).normalize();")
rep("h = habit === 'cube' ? w * 1.4 : Math.min(.55, w * (2.6 + rng() * 2.6));", "h = habit === 'cube' ? w * 1.4 : Math.min(.42, w * (2.4 + rng() * 2.2));")
open(p, 'w', encoding='utf-8').write(s); print('ok')
