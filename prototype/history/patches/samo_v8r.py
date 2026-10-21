"""Back to the v7 home screen, keeping two touches from the DREDGE try: crows in the sky, eyes blinking in the deepest dark."""
p = 'samocvet_src.html'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
# crows crossing the sky
rep("""  const sky = fire""", """  const crows = Array.from({length:2}, (_, k) => { const y = 64 + rng() * 40, d = 38 + rng() * 20;
    return `<g><animateTransform attributeName="transform" type="translate" values="-30 ${y.toFixed(0)};${W + 30} ${(y - 20).toFixed(0)}" dur="${d.toFixed(0)}s" begin="${-k * 17}s" repeatCount="indefinite"/><path d="M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0" stroke="#0a0c10" stroke-width="1.4" fill="none"><animate attributeName="d" values="M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0;M-5 -1 Q-2.5 1 0 0 Q2.5 1 5 -1;M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0" dur=".9s" repeatCount="indefinite"/></path></g>`; }).join('');
  const sky = fire""")
rep("""  ${sky}
  <path d="${ridgePath(128, 14, 7, 2.2)}" fill="${pal.mid}"/>""", """  ${sky}${crows}
  <path d="${ridgePath(128, 14, 7, 2.2)}" fill="${pal.mid}"/>""")
# something lives at the very bottom
rep("""      body = `<rect x="${gx0}" y="${gy - 15}" width="${gx1 - gx0}" height="30" rx="12" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-dasharray="4 5"/>""",
"""      const eyes = k === DEPTHS.length - 1 ? Array.from({length:2}, (_, q) => { const ex = 70 + q * 170 + rng() * 40, ey = gy + (rng() - .5) * 20, d = (7 + rng() * 6).toFixed(1);
        return `<g opacity="0"><animate attributeName="opacity" values="0;0;.9;.9;0;0" keyTimes="0;.55;.6;.7;.75;1" dur="${d}s" begin="${(q * 3.1).toFixed(1)}s" repeatCount="indefinite"/><ellipse cx="${ex.toFixed(0)}" cy="${ey.toFixed(0)}" rx="2.2" ry="1.3" fill="#e8d86a"/><ellipse cx="${(ex + 9).toFixed(0)}" cy="${ey.toFixed(0)}" rx="2.2" ry="1.3" fill="#e8d86a"/></g>`; }).join('') : '';
      body = `${eyes}<rect x="${gx0}" y="${gy - 15}" width="${gx1 - gx0}" height="30" rx="12" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-dasharray="4 5"/>""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
