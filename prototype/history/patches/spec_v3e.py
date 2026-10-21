p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("""    const R = useRock(rng() < .5 ? 'small' : 'chunk'); R.mesh.scale.multiplyScalar(.8); R.mesh.position.y = -.12;""",
"""    // often there is no separate rock at all: the columns themselves crumble into it
    const R = makeRock(rng, rtype, rng() < .5 ? 'small' : 'chunk'); DT.col.copy(R.base);
    if (rng() < .45) { add(R.mesh); R.mesh.scale.multiplyScalar(.7); R.mesh.position.y = -.2; } else disposeTree(R.mesh);""")
rep("""  if (L) { SPEC.cam.position.set(0, .05, 7.6); SPEC.cam.lookAt(0, -.38, 0); }""", """  if (L) { SPEC.cam.position.set(0, -.1, 6.9); SPEC.cam.lookAt(0, -.45, 0); }""")
rep("""  const plinth = new THREE.Mesh(new THREE.BoxGeometry(2.4, .5, 1.5), white); plinth.position.y = -2.1;""", """  const plinth = new THREE.Mesh(new THREE.BoxGeometry(2.4, .8, 1.5), white); plinth.position.y = -2.02;""")
rep("""disc.position.y = -1.84;""", """disc.position.y = -1.605;""")
rep("""bot = -1.83;""", """bot = -1.6;""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
