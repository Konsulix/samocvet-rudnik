p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("if (prismy) { const w = .05 + f * .13, h = habit === 'cube' ? w * 1.4 : w * (2.6 + rng() * 2.6);", "if (prismy) { const w = .05 + f * .13, h = habit === 'cube' ? w * 1.4 : Math.min(.55, w * (2.6 + rng() * 2.6));")
rep("h, point:habit !== 'cube', y0:-w}, {cA:cRoot, cB:cTip, zk:1}), gm);\n        c.position.copy(d).multiplyScalar(.9);", "h, point:habit !== 'cube', y0:-w * .4}, {cA:cRoot, cB:cTip, zk:1}), gm);\n        c.position.copy(d).multiplyScalar(.86);")
rep("shell.rotation.set(-Math.PI / 2 + .75, .35, 0);", "shell.rotation.set(-Math.PI / 2 - .55, .35, 0);")
open(p, 'w', encoding='utf-8').write(s); print('ok')
