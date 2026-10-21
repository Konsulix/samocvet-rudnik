import os
p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("o.cut || '', o.legend ? 1 : 0].join('|');", "o.cut || '', o.legend ? 1 : 0, SPEC.mode || ''].join('|');")
rep("  if (!specInit()) return null;\n  const g = seat(buildSpecimen(o)); g.rotation.set(.12, .6, 0);", "  if (!specInit()) return null;\n  const g = seat(buildSpecimen(o)); g.rotation.set(SPEC.mode === 'light' ? 0 : .12, .6, 0); fitRod(g);")
rep("SPEC.glow.material.color.copy(prevGlow); if (SPEC.live) SPEC.live.visible = true;", "SPEC.glow.material.color.copy(prevGlow); if (SPEC.live) { SPEC.live.visible = true; fitRod(SPEC.live); }")
rep("  host.innerHTML = ''; host.appendChild(SPEC.r.domElement); host.classList.add('live');",
"""  host.innerHTML = ''; host.appendChild(SPEC.r.domElement); host.classList.add('live'); fitRod(SPEC.live);
  // switch between the gallery plinth and the dark void
  const sw = document.createElement('button'); sw.type = 'button'; sw.setAttribute('aria-label', 'Сменить студию');
  sw.style.cssText = 'position:absolute;right:10px;bottom:10px;width:36px;height:36px;border-radius:50%;border:1px solid rgba(128,128,128,.4);background:rgba(20,24,30,.55);color:#fff;font-size:16px;line-height:1;cursor:pointer;z-index:2';
  const lbl = () => { sw.textContent = SPEC.mode === 'light' ? '☾' : '☀'; }; lbl();
  sw.onclick = e => { e.stopPropagation(); specStudio(SPEC.mode === 'light' ? 'dark' : 'light'); lbl(); };
  host.appendChild(sw);""")
rep("L.position.y = Math.sin(t * 1.1) * .06; }", "L.position.y = SPEC.mode === 'light' ? 0 : Math.sin(t * 1.1) * .06; }")
rep("L.rotation.x += (SPEC.tilt + Math.sin(t * .7) * .06 - L.rotation.x)", "L.rotation.x += (SPEC.tilt + (SPEC.mode === 'light' ? 0 : Math.sin(t * .7) * .06) - L.rotation.x)")
open(p, 'w', encoding='utf-8').write(s); print('ok')
