p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b, n=1):
    global s
    assert s.count(a) == n, (s.count(a), a[:80]); s = s.replace(a, b)
# frost band above the rock line is optional (crystals only)
rep("uIs:{value:dt.is || 0}});", "uIs:{value:dt.is || 0}, uFb:{value:dt.fb ?? 1}});")
rep("uniform float uDH, uDA, uFr, uIs;", "uniform float uDH, uDA, uFr, uIs, uFb;")
rep("frost = (1.0 - smoothstep(0.0, .3, edge)) * (1.0 - dirt) * .85;", "frost = (1.0 - smoothstep(0.0, .3, edge)) * (1.0 - dirt) * .85 * uFb;")
rep("{h:-.3, a:.35, col:crust, fr:0, is:.08}", "{h:-.3, a:.35, col:crust, fr:0, is:.08, fb:0}")
rep("{h:-99, a:.3, col:crust, fr:0, is:copper ? .45 : .22}", "{h:-99, a:.3, col:crust, fr:0, is:copper ? .45 : .22, fb:0}")
rep("new THREE.MeshPhysicalMaterial({color:0xd6d2ca, vertexColors:true, roughness:.35, clearcoat:.4, flatShading:true}), 0, 0, 0, 0, {h:-99, a:.3, col:new THREE.Color(0x6a3a1a).convertSRGBToLinear(), fr:.9, is:.18}",
    "new THREE.MeshPhysicalMaterial({color:0xbdb8ae, vertexColors:true, roughness:.3, clearcoat:.5, flatShading:true}), 0, 0, 0, 0, {h:-99, a:.3, col:new THREE.Color(0x7a4018).convertSRGBToLinear(), fr:0, is:.32, fb:0}")
rep("grow(d.clone().multiplyScalar(.35), d, .22, .035, 4); }", "grow(d.clone().multiplyScalar(.35), d, .26, .035, 3); }")
open(p, 'w', encoding='utf-8').write(s); print('ok')
