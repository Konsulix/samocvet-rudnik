p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
# speed: skip caps that are too far away before any trig
rep("const bumps = (o.bumps || []).flatMap(([n, size, h]) => Array.from({length:n}, () => [rd(), size * (.55 + rng() * .9), h * (.5 + rng() * .9)]));",
    "const bumps = (o.bumps || []).flatMap(([n, size, h]) => Array.from({length:n}, () => { const ar = Math.min(1.5, size * (.55 + rng() * .9)); return [rd(), ar, h * (.5 + rng() * .9), Math.cos(ar)]; }));")
rep("const pits = o.pits ? Array.from({length:o.pits[0]}, () => [rd(), o.pits[1] * (.5 + rng()), o.pits[2] * (.5 + rng())]) : [];",
    "const pits = o.pits ? Array.from({length:o.pits[0]}, () => { const ar = o.pits[1] * (.5 + rng()); return [rd(), ar, o.pits[2] * (.5 + rng()), Math.cos(ar)]; }) : [];")
rep("let b = 0, sum = 0; for (const [d, ar, h] of bumps) { const a = Math.acos(Math.max(-1, Math.min(1, v.dot(d)))); if (a < ar) {",
    "let b = 0, sum = 0; for (const [d, ar, h, ca] of bumps) { const dd = v.dot(d); if (dd <= ca) continue; { const a = Math.acos(Math.min(1, dd));")
rep("const t = a / ar, hh = h * Math.sqrt(1 - t * t); sum += Math.exp(hh * 60); b = Math.max(b, hh); } }",
    "const t = Math.min(1, a / ar), hh = h * Math.sqrt(1 - t * t); sum += Math.exp(hh * o.k); b = Math.max(b, hh); } }")
rep("if (sum > 0) b = Math.log(sum) / 60;", "if (sum > 0) b = Math.log(sum) / o.k;")
rep("let pit = 0; for (const [d, ar, dep] of pits) { const a = Math.acos(Math.max(-1, Math.min(1, v.dot(d)))); if (a < ar)",
    "let pit = 0; for (const [d, ar, dep, ca] of pits) { const dd = v.dot(d); if (dd <= ca) continue; const a = Math.acos(Math.min(1, dd)); if (a < ar)")
rep("function lumpGeo(rng, o){\n", "function lumpGeo(rng, o){\n  o = Object.assign({k:60}, o);\n")
# botryoid: distinct grapes, deeper hollows, darker body with softer bands
rep("const M = lumpGeo(rng, {r:.55, sx:1.2 + rng() * .3, sy:.75 + rng() * .25, sz:1, wave:.12, bumps:[[46, .42, .16], [180, .14, .045]]});",
    "const M = lumpGeo(rng, {r:.5, sx:1.2 + rng() * .3, sy:.75 + rng() * .25, sz:1, wave:.08, k:160, bumps:[[30, .38, .26], [120, .13, .07]], seg:80});")
rep("const L = lumpGeo(rng, {r:.18 + rng() * .14, wave:.1, bumps:[[20, .45, .14], [60, .16, .05]], seg:64});", "const L = lumpGeo(rng, {r:.16 + rng() * .12, wave:.06, k:160, bumps:[[16, .5, .26], [40, .18, .08]], seg:56});")
rep("bumps:[[30, .35, .1], [90, .14, .035]], seg:72});", "k:160, bumps:[[24, .38, .2], [70, .15, .06]], seg:60});")
rep("bumps:[[40, .3, .08], [120, .12, .03]], seg:72}); add(", "k:160, bumps:[[30, .32, .18], [90, .13, .06]], seg:64}); add(")
rep("""    const bm = irid(new THREE.MeshPhysicalMaterial({color:col, vertexColors:true,""", """    const bc = banded ? col.clone().multiplyScalar(.6) : col;
    const bm = irid(new THREE.MeshPhysicalMaterial({color:bc, vertexColors:true,""")
rep("o.sid === 'opal' ? .95 : Math.max(irk, .12), 0, 0, banded ? .5 : o.sid === 'opal' ? 0 : .18,", "o.sid === 'opal' ? .95 : Math.max(irk, .12), 0, 0, banded ? .3 : 0,")
s = s.replace("add(new THREE.Mesh(tintCav(M.g, M.cav, .6), bm))", "add(new THREE.Mesh(tintCav(M.g, M.cav, .8), bm))")
# gold in quartz: gold on top and bigger, quartz a little greyer
rep("new THREE.MeshPhysicalMaterial({color:0xece9e2, vertexColors:true, roughness:.35, clearcoat:.4, flatShading:true})", "new THREE.MeshPhysicalMaterial({color:0xd6d2ca, vertexColors:true, roughness:.35, clearcoat:.4, flatShading:true})")
rep("for (let k = 0, n = 3 + Math.floor(rng() * 4); k < n; k++) { tmp.fromBufferAttribute(qp, Math.floor(rng() * qp.count)); lump(.1 + rng() * .14, tmp.clone().multiplyScalar(.95), {seg:56}); }",
    "for (let k = 0, n = 3 + Math.floor(rng() * 4), tries = 0; k < n && tries < 400; tries++) { tmp.fromBufferAttribute(qp, Math.floor(rng() * qp.count)); if (tmp.y < .1) continue; lump(k ? .1 + rng() * .1 : .2 + rng() * .08, tmp.clone().multiplyScalar(.93), {seg:56}); k++; }")
rep("grow(d.clone().multiplyScalar(.35), d, .16, .03, 4); }", "grow(d.clone().multiplyScalar(.35), d, .22, .035, 4); }")
open(p, 'w', encoding='utf-8').write(s); print('ok')
