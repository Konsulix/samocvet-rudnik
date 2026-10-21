p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("    const n = kind === 'druse' ? 4 + Math.floor(rng() * 4) : 1 + Math.floor(rng() * 3);\n    for (let k = 0; k < n; k++) {",
    "    const n = kind === 'druse' ? 4 + Math.floor(rng() * 4) : 1 + Math.floor(rng() * 3), cm = mat || cmat();\n    for (let k = 0; k < n; k++) {")
rep("      const c = add(new THREE.Mesh(g, mat)); c.renderOrder = 2;", "      const c = add(new THREE.Mesh(g, cm)); c.renderOrder = 2; c.userData.col = true;")
rep("const cols = []; if (mat) root.children.forEach(m => { if (m.isMesh && m.material === mat) cols.push(m); });",
    "const cols = []; root.children.forEach(m => { if (m.isMesh && (m.userData.col || (mat && m.material === mat))) cols.push(m); });")
open(p, 'w', encoding='utf-8').write(s); print('ok')
