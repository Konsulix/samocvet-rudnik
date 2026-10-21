p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("""        float edge = vRP.y - (uDH + (fbm(vRP * 4.0) - .47) * uDA);
        dirt = 1.0 - smoothstep(-.012, .012, edge);""", """        float edge = vRP.y - (uDH + (fbm(vRP * 4.0) - .47) * uDA + (fbm(vRP * 1.7 + 3.0) - .5) * uDA * .9);
        dirt = 1.0 - smoothstep(-.012, .012, edge);
        // islands of crust above the line, and windows where the crystal shows through below it
        dirt = max(dirt, smoothstep(.64, .67, fbm(vRP * 5.5 + 11.0)) * (1.0 - smoothstep(.0, .8, edge)));
        dirt *= 1.0 - smoothstep(.68, .71, fbm(vRP * 6.0 + 21.0)) * smoothstep(-.7, -.08, edge);
        float rim = 1.0 - smoothstep(.0, .05, abs(edge));""")
rep("""        vec3 rk = uRC * (.35 + 1.1 * fbm(vRP * 26.0)) * (.7 + .5 * vn(vRP * 3.0));""",
"""        vec3 rk = uRC * (.2 + 1.4 * fbm(vRP * 26.0)) * (.65 + .6 * vn(vRP * 3.0));
        rk = mix(rk, vec3(.3, .11, .035) * (.6 + .8 * vn(vRP * 30.0)), smoothstep(.5, .75, vn(vRP * 6.0 + 5.0)) * .7);
        rk = mix(rk, rk * 1.7 + .04, rim * .6);""")
rep("new THREE.MeshBasicMaterial({color:0x3c3c3b, side:THREE.BackSide})", "new THREE.MeshBasicMaterial({color:0x1c1c1c, side:THREE.BackSide})")
rep("[0, -4.9, 0, 10, 10, 0x9a9a98]]", "[0, -4.9, 0, 10, 10, 0x6a6a68]]")
rep("if (main && mat && layout !== 'geode' && rng() < (o.legend ? 1 : .55 + gi * .1)) {", "if (main && mat && layout !== 'geode' && rng() < (o.legend ? 1 : layout === 'columnar' ? .85 : .5 + gi * .1)) {")
# tufts hug the surface instead of forming balls
rep("""      const d = new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize(), r = Math.pow(rng(), .5) * .17, v = p.clone().addScaledVector(d, r).addScaledVector(nn, r * .6);""",
"""      const d = new THREE.Vector3(rng() - .5, rng() - .5, rng() - .5).normalize(); d.addScaledVector(nn, -d.dot(nn)).normalize();
      const r = Math.pow(rng(), .7) * .2, v = p.clone().addScaledVector(d, r).addScaledVector(nn, (.2 - r) * .25 * rng());""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
