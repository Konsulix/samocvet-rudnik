p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("for (let k = 0, n = 55 + Math.floor(rng() * 35); k < n; k++) {", "for (let k = 0, n = 80 + Math.floor(rng() * 40); k < n; k++) {")
rep("f = Math.pow(rng(), 2.2);", "f = Math.pow(rng(), 1.6);")
rep("if (prismy) { const w = .035 + f * .1, h = habit === 'cube' ? w * 1.4 : w * (2.4 + rng() * 2.4);", "if (prismy) { const w = .05 + f * .13, h = habit === 'cube' ? w * 1.4 : w * (2.6 + rng() * 2.6);")
rep("else { c = crystal(.3 + f * .4, .3 + f * .35,", "else { c = crystal(.3 + f * .5, .4 + f * .5,")
rep("shell.rotation.set(-Math.PI / 2 + .25, .35, 0);", "shell.rotation.set(-Math.PI / 2 + .75, .35, 0);")
rep("if (hasBase && (tr.has('moss') || rng() < .18)) {", "if (hasBase && tr.has('moss')) {")
open(p, 'w', encoding='utf-8').write(s); print('ok')
