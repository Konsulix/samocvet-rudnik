"""Самоцветный рудник v10: the home screen as one space: the mine cross-section fills the whole screen, the interface floats over it."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- scene sized to the screen ----------------
rep("function sceneSVG(ai, built, dOpen = 0, dSel = 0){\n  const has = id => built.includes(id), cu = ai === 1, fire = ai === 2, rng = mulberry(ai * 977 + 31), W = 360, H = 540, G0 = 200, BH = 64, B0 = 212;",
    "// Hv: the scene height in units for a 360-wide screen, so the picture fills the phone without cropping\n"
    "function sceneSVG(ai, built, dOpen = 0, dSel = 0, Hv = 780){\n"
    "  const has = id => built.includes(id), cu = ai === 1, fire = ai === 2, rng = mulberry(ai * 977 + 31), W = 360, G0 = 200, B0 = 212;\n"
    "  // the surface slides down to leave sky for the title; the horizons share what is left above the buttons\n"
    "  const OFF = Math.round(Math.max(0, Math.min(80, Hv * .34 - 196))), BH = Math.round(Math.max(40, Math.min(62, (Hv - 222 - B0 - OFF) / 5))), H = Hv - OFF;")
rep("const stars = Array.from({length:30}, (_, k) => { const x = rng() * W, y = rng() * 90, r = rng() < .2 ? 1.3 : .7;",
    "const stars = Array.from({length:40}, (_, k) => { const x = rng() * W, y = -OFF + rng() * (90 + OFF), r = rng() < .2 ? 1.3 : .7;")
rep("""  <clipPath id="scClip"><rect width="${W}" height="${H}" rx="22"/></clipPath></defs>
  <g clip-path="url(#scClip)">
  <rect width="${W}" height="${G0 + 10}" fill="url(#scSky)"/>""",
"""  <linearGradient id="scFade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0b0f17" stop-opacity="0"/><stop offset=".55" stop-color="#0b0f17" stop-opacity=".7"/><stop offset="1" stop-color="#0b0f17" stop-opacity=".95"/></linearGradient>
  <linearGradient id="scTopFade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05080e" stop-opacity=".55"/><stop offset="1" stop-color="#05080e" stop-opacity="0"/></linearGradient></defs>
  <g transform="translate(0 ${OFF})">
  <rect y="${-OFF}" width="${W}" height="${G0 + 10 + OFF}" fill="url(#scSky)"/>""")
rep("""  ${bands}
  ${shaft}
  <rect width="${W}" height="${H}" rx="22" fill="none" stroke="#ffffff" stroke-opacity=".06"/>
  </g></svg>`;""",
r"""  <rect y="${B0 + BH * 5 - 2}" width="${W}" height="${H - B0 - BH * 5 + 2}" fill="${mixHex(pal.rock[1], '#000000', .45)}"/>
  <g fill="#fff" opacity=".05">${Array.from({length:40}, () => `<circle cx="${(rng() * W).toFixed(0)}" cy="${(B0 + BH * 5 + rng() * (H - B0 - BH * 5)).toFixed(0)}" r="${(.6 + rng() * 1.6).toFixed(1)}"/>`).join('')}</g>
  ${fire ? `<path d="M0 ${H - 40} Q90 ${H - 70} 180 ${H - 45} T360 ${H - 50} L360 ${H} L0 ${H}Z" fill="#ff5a1a" opacity=".18" filter="url(#scBlur)"><animate attributeName="opacity" values=".12;.24;.12" dur="5s" repeatCount="indefinite"/></path>` : ''}
  ${bands}
  ${shaft}
  </g>
  <rect width="${W}" height="120" fill="url(#scTopFade)"/>
  <rect y="${Hv - 250}" width="${W}" height="250" fill="url(#scFade)"/></svg>`;""")
rep('return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Рудник в разрезе">', 'return `<svg viewBox="0 0 ${W} ${Hv}" preserveAspectRatio="xMidYMid slice" role="img" aria-label="Рудник в разрезе">')

# ---------------- render with the screen's proportions, again on resize ----------------
rep("  $('#scene').innerHTML = sceneSVG(ai, built, save.depth[ai] || 0, Math.min(save.depthSel[ai] || 0, save.depth[ai] || 0));",
    "  const sr = $('#home').getBoundingClientRect(), Hv = Math.round(Math.max(600, Math.min(1000, 360 * sr.height / Math.max(1, sr.width))));\n"
    "  $('#scene').innerHTML = sceneSVG(ai, built, save.depth[ai] || 0, Math.min(save.depthSel[ai] || 0, save.depth[ai] || 0), Hv);")
rep("$('#tasksBtn').onclick = openTasks;", "$('#tasksBtn').onclick = openTasks;\n{ let rt = 0; addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(() => { if (!$('#home').hidden && ov.hidden) goHome(); }, 200); }); }")

# ---------------- floating interface ----------------
rep(".scene{position:relative;flex:1;min-height:0;display:grid;place-items:center}", ".scene{position:absolute;inset:0;z-index:0;overflow:hidden;background:#0b0f17}")
rep(".scene svg{width:100%;height:100%;filter:drop-shadow(0 18px 30px rgba(0,0,0,.5))}", ".scene svg{width:100%;height:100%;display:block}")
rep(".home-actions{display:flex;flex-direction:column;gap:10px;align-items:center;padding-block:8px 6px}",
    "#home > :not(.scene){position:relative;z-index:1}\n#home .title, #home .sub, #home .bar{pointer-events:none}\n#home .bar > *, #home .sub .depthchip{pointer-events:auto}\n"
    "#home .title{text-shadow:0 3px 0 rgba(0,0,0,.35), 0 0 18px rgba(0,0,0,.8)}\n#home .sub{color:#d8e0ee;text-shadow:0 1px 8px rgba(0,0,0,.9)}\n"
    ".home-actions{display:flex;flex-direction:column;gap:10px;align-items:center;padding-block:8px 6px;margin-top:auto}")
rep(".tasks-btn{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:8px 14px;width:min(100%,420px)}",
    ".tasks-btn{display:flex;align-items:center;gap:10px;background:rgba(14,20,32,.72);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);border:1px solid rgba(255,255,255,.12);border-radius:16px;padding:8px 14px;width:min(100%,420px);box-shadow:0 8px 20px rgba(0,0,0,.4)}")
# a game tab bar with icons instead of three web buttons
rep(".nav{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;padding-block:8px 10px}",
    ".nav{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;padding-block:8px 10px}\n"
    "#home .nav{margin-inline:-12px;padding:6px 10px calc(8px + env(safe-area-inset-bottom,0px));gap:4px;background:linear-gradient(#1c2638,#111827);border-top:1px solid rgba(255,255,255,.1);box-shadow:0 -10px 24px rgba(0,0,0,.45)}\n"
    "#home .nav button{display:flex;flex-direction:column;align-items:center;gap:2px;background:none;border:0;border-radius:14px;padding:6px 0 5px;font-size:12px;color:#9fb0c8}\n"
    "#home .nav button svg{width:26px;height:26px}\n"
    "#home .nav button.on{background:linear-gradient(#2c3c5a,#1e2a42);color:#ffd77a;box-shadow:inset 0 1px 0 rgba(255,255,255,.12), 0 -3px 0 #e3a51e inset}")
ICON_MINE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 20h18"/><path d="M5 20V11a7 7 0 0 1 14 0v9"/><path d="M9 20v-6h6v6"/></svg>'
ICON_TECH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 4l6 6-3 1-4-4z"/><path d="M13 7L4 16l4 4 9-9"/><path d="M6 18l-2 2"/></svg>'
ICON_COLL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M6 3h12l3 6-9 12L3 9z"/><path d="M3 9h18M9 3l3 6 3-6M12 21L9 9M12 21l3-12"/></svg>'
rep('<div class="nav"><button class="on" type="button">Рудник</button><button type="button" id="toTech">Техника</button><button type="button" id="toColl">Коллекция</button></div>',
    f'<div class="nav"><button class="on" type="button">{ICON_MINE}Рудник</button><button type="button" id="toTech">{ICON_TECH}Техника</button><button type="button" id="toColl">{ICON_COLL}Коллекция</button></div>')
open(P, 'w', encoding='utf-8').write(s)
print('ok')
