p = 'samocvet_src.html'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("""    <line x1="${x}" y1="66" x2="${x}" y2="104" stroke="#2a2420" stroke-width="2" stroke-dasharray="3 2"/>
    <circle cx="${x}" cy="118" r="150" fill="url(#gbGlow)">""", """    <line x1="${x}" y1="66" x2="${x}" y2="164" stroke="#2a2420" stroke-width="2" stroke-dasharray="3 2"/>
    <circle cx="${x}" cy="178" r="170" fill="url(#gbGlow)">""")
rep("""<path d="M${x - 8} 104 L${x + 8} 104 L${x + 10} 128 L${x - 10} 128Z" fill="#3a3028"/><rect x="${x - 6}" y="108" width="12" height="16" rx="2" fill="#ffe7a0"/><path d="M${x - 10} 128 L${x + 10} 128 L${x + 6} 134 L${x - 6} 134Z" fill="#2a221c"/></g>`;""",
"""<path d="M${x - 8} 164 L${x + 8} 164 L${x + 10} 188 L${x - 10} 188Z" fill="#3a3028"/><rect x="${x - 6}" y="168" width="12" height="16" rx="2" fill="#ffe7a0"/><path d="M${x - 10} 188 L${x + 10} 188 L${x + 6} 194 L${x - 6} 194Z" fill="#2a221c"/></g>`;""")
rep("const side = k % 2, x = side ? W - 18 - rng() * 40 : 18 + rng() * 40, y = 130 + rng() * (H - 300),",
    "const side = k % 2, low = k % 4 > 1, x = low ? 40 + rng() * (W - 80) : side ? W - 50 - rng() * 110 : 50 + rng() * 110, y = low ? 650 + rng() * 70 : 150 + rng() * 60,")
open(p, 'w', encoding='utf-8').write(s); print('ok')
