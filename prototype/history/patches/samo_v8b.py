p = 'samocvet_src.html'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("rock:['#2a221e', '#0e0a09']", "rock:['#3a2e28', '#161010']")
rep("rock:['#1e2824', '#0a0e0c']", "rock:['#2a3632', '#101614']")
rep("rock:['#262a2a', '#0b0d0e']", "rock:['#343a3a', '#121516']")
rep("""      ${open ? '' : `<rect x="0" y="${y}" width="${W}" height="${BH}" fill="#000" opacity="${(.35 + t * .35).toFixed(2)}"/>`}""",
"""      <g stroke="#000" stroke-opacity=".28" fill="none">${[.3, .62].map(f => { let d = `M0 ${(y + BH * f).toFixed(0)}`; for (let x = 0; x <= W; x += 24) d += ` L${x} ${(y + BH * f + Math.sin(x * .05 + k * 3 + f * 9) * 3).toFixed(1)}`; return `<path d="${d}"/>`; }).join('')}</g>
      ${open ? '' : `<rect x="0" y="${y}" width="${W}" height="${BH}" fill="#000" opacity="${(.22 + t * .32).toFixed(2)}"/>`}""")
# roots hanging from the soil into the first horizon
rep("""  ${fogBank(196, 180, 10, .2, 38, 50)}
  ${bands}""", """  ${fogBank(196, 180, 10, .2, 38, 50)}
  ${bands}
  <g stroke="#0c0a08" fill="none" stroke-linecap="round" opacity=".85">${Array.from({length:9}, () => { let x = 10 + rng() * 280, yy = B0 - 2, d = `M${x.toFixed(0)} ${yy}`, w = 1.6 + rng() * 1.4; const n = 3 + Math.floor(rng() * 4);
    for (let q = 0; q < n; q++) { x += (rng() - .5) * 10; yy += 4 + rng() * 6; d += ` Q${(x + (rng() - .5) * 8).toFixed(0)} ${(yy - 3).toFixed(0)} ${x.toFixed(0)} ${yy.toFixed(0)}`; } return `<path d="${d}" stroke-width="${w.toFixed(1)}"/>`; }).join('')}</g>""")
# a more visible pond with the moon in it
rep("""  <path d="M6 ${G0 + 1} Q50 ${G0 - 9} 104 ${G0 + 1}Z" fill="${pal.water}"/>""",
    """  <path d="M4 ${G0 + 1} Q52 ${G0 - 12} 108 ${G0 + 1}Z" fill="${pal.water}"/><path d="M4 ${G0 + 1} Q52 ${G0 - 12} 108 ${G0 + 1}" stroke="${pal.fog}" stroke-opacity=".35" stroke-width=".8" fill="none"/><ellipse cx="55" cy="${G0 - 4}" rx="7" ry="1.6" fill="#d8d6c4" opacity=".35"/>""")
open(p, 'w', encoding='utf-8').write(s); print('ok')
