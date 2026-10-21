"""Самоцветный рудник v12: hand-drawn mine props on the home screen (portal, rubble, timber, lanterns, cart, rails, headframe, shaft), level screen in the shared glass style."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

def rep_line(start, new):
    """replace the single line that begins with `start` (after indentation)"""
    global s
    lines = s.split('\n'); hits = [i for i, l in enumerate(lines) if l.lstrip().startswith(start)]
    assert len(hits) == 1, (len(hits), start[:80])
    lines[hits[0]] = new; s = '\n'.join(lines)

# ---------------- drawing kit ----------------
rep("// the home screen: a cut through the mountain.", r"""/* ---- hand-drawn props for the mine scene (SVG strings) ---- */
const f1 = v => (+v).toFixed(1);
// an angular stone with a lit facet and a crack
function svgStone(cx, cy, r, rng, fill, dark, light){
  const pts = Array.from({length:7}, (_, k) => { const a = k / 7 * 6.283 + rng() * .5, rr = r * (.78 + rng() * .32); return [cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * .8]; });
  return `<path d="M${pts.map(p => p.map(f1).join(' ')).join(' L')}Z" fill="${fill}" stroke="${dark}" stroke-width="1.1" stroke-linejoin="round"/>
    <path d="M${f1(cx - r * .55)} ${f1(cy - r * .1)} L${f1(cx - r * .15)} ${f1(cy - r * .6)} L${f1(cx + r * .45)} ${f1(cy - r * .42)} L${f1(cx + r * .08)} ${f1(cy - r * .02)}Z" fill="${light}" opacity=".5"/>
    <path d="M${f1(cx + r * .08)} ${f1(cy - r * .02)} L${f1(cx + r * .5)} ${f1(cy + r * .38)}" stroke="${dark}" stroke-width=".8" opacity=".55" fill="none"/>`;
}
// a hanging miner's lantern; (x, y) is the hook, s the scale
function svgLantern(x, y, s = 1, glow = true, k = 0){
  return `<g transform="translate(${f1(x)} ${f1(y)}) scale(${s})">${glow ? `<circle cy="9" r="24" fill="url(#scGlow)" opacity=".75"><animate attributeName="opacity" values=".75;.5;.8;.62;.75" dur="${(2 + k * .37).toFixed(2)}s" repeatCount="indefinite"/></circle>` : ''}
    <path d="M-2.6 2 Q0 -3.2 2.6 2" stroke="#1e1a16" stroke-width="1.2" fill="none"/><path d="M-4.5 2 L4.5 2 L5.6 5 L-5.6 5Z" fill="#2e2822"/>
    <rect x="-4.6" y="5" width="9.2" height="11" rx="1.6" fill="#ffe2a0"/><ellipse cy="11" rx="1.9" ry="3.1" fill="#fff8dc"/>
    <path d="M-4.6 5 V16 M0 5 V16 M4.6 5 V16" stroke="#2e2822" stroke-width=".8"/><rect x="-5.6" y="15.6" width="11.2" height="2.6" rx="1" fill="#2e2822"/></g>`;
}
// a riveted ore cart heaped with cut stones; (x, y) is the rail line under its wheels
function svgCart(x, y, s, cols, id){
  const gem = (gx, gy, r, c) => `<path d="M${f1(gx)} ${f1(gy - r)} L${f1(gx + r * .9)} ${f1(gy - r * .2)} L${f1(gx + r * .55)} ${f1(gy + r * .8)} L${f1(gx - r * .55)} ${f1(gy + r * .8)} L${f1(gx - r * .9)} ${f1(gy - r * .2)}Z" fill="${c}" stroke="#1a1a1a" stroke-width=".6"/><path d="M${f1(gx)} ${f1(gy - r)} L${f1(gx + r * .9)} ${f1(gy - r * .2)} L${f1(gx)} ${f1(gy)}Z" fill="#fff" opacity=".45"/>`;
  return `<g transform="translate(${f1(x)} ${f1(y)}) scale(${s})">
    ${gem(-10, -19, 5.5, cols[0])}${gem(0, -21, 6.5, cols[1 % cols.length])}${gem(10, -19, 5.5, cols[2 % cols.length])}${gem(-5, -16, 4.5, cols[3 % cols.length])}${gem(6, -15.5, 4.5, cols[4 % cols.length])}
    <path d="M-22 -16 L22 -16 L18 2 L-18 2Z" fill="url(#scMetal${id})" stroke="#1c1f24" stroke-width="1.2" stroke-linejoin="round"/>
    <rect x="-23.5" y="-18" width="47" height="3.4" rx="1.2" fill="#8a929c" stroke="#1c1f24" stroke-width=".8"/>
    <path d="M-7 -14.6 L-6 1.6 M7 -14.6 L6 1.6" stroke="#2a2e34" stroke-width="1"/>
    ${[-17, -9.5, -2, 5.5, 13].map(rx => `<circle cx="${rx + 2}" cy="-11.5" r=".9" fill="#c8d0d8"/>`).join('')}
    <rect x="-17" y="1" width="34" height="2.4" fill="#22262c"/>
    ${[-11, 11].map(wx => `<g transform="translate(${wx} 5.5)"><circle r="5.4" fill="#22262c" stroke="#0e1012" stroke-width="1"/><circle r="3.6" fill="none" stroke="#5a626c" stroke-width=".9"/><path d="M-3.6 0 H3.6 M0 -3.6 V3.6 M-2.5 -2.5 L2.5 2.5 M-2.5 2.5 L2.5 -2.5" stroke="#5a626c" stroke-width=".6"/><circle r="1.2" fill="#9aa4ae"/></g>`).join('')}</g>`;
}
// timber set in a gallery: a post with a cap block and knee braces
const svgPost = (x, y0, y1) => `<rect x="${f1(x - 1.8)}" y="${f1(y0)}" width="3.6" height="${f1(y1 - y0)}" fill="#7a4e26" stroke="#3a2410" stroke-width=".6"/><rect x="${f1(x - 6)}" y="${f1(y0 - 3)}" width="12" height="3.6" fill="#8e5c2c" stroke="#3a2410" stroke-width=".6"/><path d="M${f1(x - 1.8)} ${f1(y0 + 5)} L${f1(x - 6)} ${f1(y0 + .6)} M${f1(x + 1.8)} ${f1(y0 + 5)} L${f1(x + 6)} ${f1(y0 + .6)}" stroke="#6a4220" stroke-width="1.6"/>`;

// the home screen: a cut through the mountain.""")

# ---------------- surface props ----------------
rep_line("<path d=\"M130 ${G0} L130 146 Q160 112 190 146 L190 ${G0}Z\" fill=\"url(#scDark)\"/>",
"""  <path d="M130 ${G0} L130 146 Q160 112 190 146 L190 ${G0}Z" fill="url(#scDark)"/>
  <path d="M128 ${G0} L128 145 Q160 108 192 145 L192 ${G0}" fill="none" stroke="${fire ? '#2a1a14' : '#3e3832'}" stroke-width="11"/>
  <path d="M128 ${G0} L128 145 Q160 108 192 145 L192 ${G0}" fill="none" stroke="${fire ? '#5a3a2a' : '#7a7064'}" stroke-width="8.5" stroke-dasharray="9 1.8"/>
  <path d="M124 ${G0} L124 145 Q160 102 196 145 L196 ${G0}" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="1"/>""")
rep_line("${has('rubble') ? '' :", r"""  ${has('rubble') ? '' : (() => { const r2 = mulberry(ai * 41 + 7), f = fire ? '#4a2a1e' : cu ? '#5e6a5e' : '#857766', d = fire ? '#1a0c08' : '#2a241e', l = fire ? '#ff8a4a' : '#d8ccb8';
    return `<g>${[[128, 196, 7], [192, 196, 6.5], [139, 191, 12], [180, 192, 11], [159, 190, 14], [149, 177, 10], [171, 176, 10], [160, 164, 8.5], [166, 197, 5]].map(([x, y, r]) => svgStone(x, y, r, r2, f, d, l)).join('')}${fire ? '<circle cx="160" cy="186" r="20" fill="#ff5a1a" opacity=".18"/>' : ''}</g>`; })()}""")
rep_line("${has('timber') ?", r"""  ${has('timber') ? `<g class="b-timber"><g fill="#8a5a2c" stroke="#3a2410" stroke-width="1.2"><rect x="121" y="134" width="12" height="68" rx="1.5"/><rect x="187" y="134" width="12" height="68" rx="1.5"/><rect x="113" y="124" width="94" height="12" rx="2"/></g>
    <g stroke="#5a3818" stroke-width=".8" opacity=".8"><path d="M124 140 Q125 165 124 198 M129 138 Q130 170 129 199 M191 140 Q190 166 191 198 M196 139 Q195 168 196 199 M118 128 Q160 127 202 129 M120 132 Q160 133 200 131"/></g>
    <g stroke="#7a4e26" stroke-width="4" stroke-linecap="round"><path d="M133 148 L145 136 M187 148 L175 136"/></g>
    <g fill="#3a3e44"><rect x="119.5" y="150" width="15" height="4" rx="1"/><rect x="185.5" y="150" width="15" height="4" rx="1"/><rect x="121" y="126" width="9" height="8" rx="1"/><rect x="190" y="126" width="9" height="8" rx="1"/></g>
    <g fill="#9aa4ae">${[[123, 152], [131, 152], [189, 152], [197, 152], [125.5, 130], [194.5, 130]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r=".9"/>`).join('')}</g>
    <circle cx="113" cy="130" r="5.5" fill="#6a4220" stroke="#3a2410"/><circle cx="113" cy="130" r="2.5" fill="none" stroke="#3a2410" stroke-width=".6"/><circle cx="207" cy="130" r="5.5" fill="#6a4220" stroke="#3a2410"/><circle cx="207" cy="130" r="2.5" fill="none" stroke="#3a2410" stroke-width=".6"/></g>` : ''}""")
rep_line("${has('rails') ?", r"""  ${has('rails') ? `<g class="b-rails">${Array.from({length:19}, (_, q) => `<rect x="${142 + q * 8}" y="${G0 - 4.5}" width="4.5" height="8" rx=".8" fill="#4a3018" stroke="#24160a" stroke-width=".5"/>`).join('')}
    <path d="M140 ${G0 - 3} H292" stroke="#3a3e44" stroke-width="2.4"/><path d="M140 ${G0 - 3.6} H292" stroke="#b8c2cc" stroke-width=".9"/><path d="M138 ${G0 + 2} H292" stroke="#3a3e44" stroke-width="2.4"/><path d="M138 ${G0 + 1.4} H292" stroke="#b8c2cc" stroke-width=".9"/>
    <rect x="286" y="${G0 - 8}" width="5" height="12" rx="1" fill="#c8341e" stroke="#4a1208" stroke-width=".7"/></g>` : ''}""")
rep_line("${has('lamps') ?", r"""  ${has('lamps') ? `<g class="b-lamps"><path d="M121 137 H108 V141" stroke="#2e2822" stroke-width="2" fill="none"/><path d="M199 137 H212 V141" stroke="#2e2822" stroke-width="2" fill="none"/>${svgLantern(108, 140, .95, true, 0)}${svgLantern(212, 140, .95, true, 1)}</g>` : ''}""")
rep_line("${has('cart') ?", r"""  ${has('cart') ? `<g class="b-cart">${svgCart(240, G0 - 7, .95, sp, 'S')}</g>` : ''}""")
rep_line("${has('headframe') ? `<g class=\"b-headframe\"", r"""  ${has('headframe') ? (() => { const st = cu ? '#b86a34' : fire ? '#b8502a' : '#a8947a', dk = '#2a2018';
    return `<g class="b-headframe"><g stroke="${dk}" stroke-width="5" stroke-linecap="round"><path d="M286 ${G0} L301 98 M322 ${G0} L307 98"/></g><g stroke="${st}" stroke-width="3.4" stroke-linecap="round"><path d="M286 ${G0} L301 98 M322 ${G0} L307 98"/></g>
      <g stroke="${st}" stroke-width="1.4" opacity=".95">${[[198, 168], [168, 140], [140, 116]].map(([a, b]) => { const xa = 286 + (a - G0) / (98 - G0) * 15, xb = 286 + (b - G0) / (98 - G0) * 15; return `<path d="M${f1(xa)} ${a} L${f1(608 - xb)} ${b} M${f1(608 - xa)} ${a} L${f1(xb)} ${b} M${f1(xb)} ${b} H${f1(608 - xb)}"/>`; }).join('')}</g>
      <rect x="297" y="96" width="14" height="5" fill="${dk}"/>
      <g transform="translate(304 90)"><g><animateTransform attributeName="transform" type="rotate" values="0;360" dur="6s" repeatCount="indefinite"/><circle r="11.5" fill="none" stroke="${dk}" stroke-width="3.6"/><circle r="11.5" fill="none" stroke="${st}" stroke-width="2"/>${Array.from({length:6}, (_, q) => `<path d="M0 0 L${f1(Math.cos(q * 1.047) * 10.5)} ${f1(Math.sin(q * 1.047) * 10.5)}" stroke="${st}" stroke-width="1.2"/>`).join('')}<circle r="2.4" fill="${dk}"/></g></g>
      <path d="M314 92 L336 176" stroke="#1a1a1a" stroke-width=".9"/>
      <path d="M326 ${G0} V178 L340 168 L354 178 V${G0}Z" fill="${fire ? '#3a2420' : '#4a3a2c'}" stroke="#1e1610" stroke-width="1"/><path d="M324 179 L340 166 L356 179" fill="none" stroke="#2a1e14" stroke-width="2.6" stroke-linejoin="round"/>
      <rect x="333" y="184" width="7" height="6" fill="#ffd27a" opacity=".85"/><path d="M336.5 184 V190 M333 187 H340" stroke="#2a1e14" stroke-width=".7"/></g>`; })() : ''}""")
rep_line("${cu ? `<g fill=\"#3fbf8a\" opacity=\".35\">", r"""  ${cu ? (() => { const r3 = mulberry(77); return `<g>${[[58, 196, 6], [76, 197, 4.5], [330, 196, 5.5]].map(([x, y, r]) => svgStone(x, y, r, r3, '#4a6a5a', '#1a2a22', '#7adfb0')).join('')}<g fill="#3fbf8a" opacity=".55"><circle cx="57" cy="194" r="1.6"/><circle cx="61" cy="196" r="1.1"/><circle cx="331" cy="194" r="1.4"/></g></g>`; })() : ''}""")

# ---------------- galleries: timber sets, lanterns, the cart ----------------
rep_line("const posts = Array.from({length:6}, (_, q) => {", "      const posts = Array.from({length:6}, (_, q) => svgPost(gx0 + 14 + q * 44, gy - 12, gy + 14)).join('');")
rep_line("const lamps = Array.from({length:3}, (_, q) => {", "      const lamps = Array.from({length:3}, (_, q) => svgLantern(gx0 + 36 + q * 88, gy - 14, .5, true, q + k)).join('');")
i = s.index("      const cart = sel ? `<g><animateTransform"); j = s.index("\n", s.index("\n", i) + 1)
s = s[:i] + "      const cart = sel ? `<g><animateTransform attributeName=\"transform\" type=\"translate\" values=\"0 0;150 0;150 0;0 0;0 0\" keyTimes=\"0;.4;.5;.9;1\" dur=\"10s\" repeatCount=\"indefinite\"/>${svgCart(gx0 + 34, gy + 9, .5, sp, 'G' + k)}</g>` : '';" + s[j:]

# ---------------- the shaft: boarded walls, a ladder, the cage ----------------
i = s.index("  const shaft = `<rect x=\"296\""); j = s.index("\n  return `<svg", i)
s = s[:i] + r"""  const shaft = `<rect x="295" y="${G0 - 4}" width="18" height="${shaftBot - G0 + 4}" fill="url(#scShaft)"/>
    <rect x="293" y="${G0 - 4}" width="3" height="${shaftBot - G0 + 4}" fill="#6a4220"/><rect x="312" y="${G0 - 4}" width="3" height="${shaftBot - G0 + 4}" fill="#6a4220"/>
    <g stroke="#3a2410" stroke-width=".6">${Array.from({length:Math.floor((shaftBot - G0) / 10)}, (_, q) => `<line x1="293" y1="${G0 + q * 10}" x2="296" y2="${G0 + q * 10}"/><line x1="312" y1="${G0 + 5 + q * 10}" x2="315" y2="${G0 + 5 + q * 10}"/>`).join('')}</g>
    <path d="M298 ${G0 - 2} V${shaftBot} M304 ${G0 - 2} V${shaftBot}" stroke="#8a5a2c" stroke-width="1.4"/>
    <g stroke="#a06a34" stroke-width="1.2">${Array.from({length:Math.floor((shaftBot - G0) / 7)}, (_, q) => `<line x1="298" y1="${G0 + 3 + q * 7}" x2="304" y2="${G0 + 3 + q * 7}"/>`).join('')}</g>
    <rect x="293" y="${shaftBot}" width="22" height="${H - shaftBot}" fill="none" stroke="#fff" stroke-opacity=".08" stroke-dasharray="3 4"/>
    ${has('headframe') ? `<g><animateTransform attributeName="transform" type="translate" values="0 0;0 ${shaftBot - G0 - 22};0 ${shaftBot - G0 - 22};0 0;0 0" keyTimes="0;.42;.5;.92;1" dur="9s" repeatCount="indefinite"/>
      <line x1="309" y1="${G0 - 108}" x2="309" y2="${G0 - 4}" stroke="#9aa6b4" stroke-width=".8"/><rect x="305" y="${G0 - 4}" width="8" height="15" rx="1" fill="#c8a060" stroke="#4a3418" stroke-width=".8"/><path d="M305 ${G0} H313 M305 ${G0 + 5} H313" stroke="#4a3418" stroke-width=".6"/></g>` : ''}`;""" + s[j:]
rep("  <filter id=\"scBlur\"><feGaussianBlur stdDeviation=\"6\"/></filter>",
    """  <filter id="scBlur"><feGaussianBlur stdDeviation="6"/></filter>
  <linearGradient id="scShaft" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#050403"/><stop offset=".5" stop-color="#14100c"/><stop offset="1" stop-color="#050403"/></linearGradient>
  ${['S', 'G0', 'G1', 'G2', 'G3', 'G4'].map(id => `<linearGradient id="scMetal${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a828c"/><stop offset="1" stop-color="#3a3f46"/></linearGradient>`).join('')}""")

# ---------------- level screen in the shared style ----------------
rep(""".goals{position:relative;display:flex;gap:6px;align-items:center;min-width:0;flex-wrap:wrap;padding:7px 16px;border-radius:10px;
  background:repeating-linear-gradient(176deg, rgba(0,0,0,0) 0 7px, rgba(0,0,0,.07) 7px 8px), linear-gradient(#94622f,#6a4220 60%,#5a3618);
  border:2px solid #3a2410;box-shadow:inset 0 2px 0 rgba(255,220,160,.25), inset 0 -3px 0 rgba(0,0,0,.25), 0 5px 0 #24160a, 0 10px 18px rgba(0,0,0,.45)}
.goals::before, .goals::after{content:"";position:absolute;top:50%;width:7px;height:7px;margin-top:-3.5px;border-radius:50%;background:radial-gradient(circle at 35% 30%, #e8e2d4, #7a7468 60%, #3a362e)}
.goals::before{left:5px}.goals::after{right:5px}""",
""".goals{position:relative;display:flex;gap:8px;align-items:center;min-width:0;flex-wrap:wrap;padding:7px 14px;border-radius:16px;
  background:rgba(14,20,32,.66);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.14);box-shadow:0 8px 20px rgba(0,0,0,.4)}""")
rep("""#lvlName{background:rgba(12,10,8,.6);border:1px solid rgba(255,210,122,.25);border-radius:999px;padding:4px 12px;backdrop-filter:blur(4px)}""",
    """#lvlName{font-family:var(--display);font-size:15px;color:#fff;letter-spacing:.02em;text-shadow:0 2px 0 rgba(0,0,0,.4), 0 0 14px rgba(0,0,0,.8)}""")
rep(".lvl-h .x{width:34px;height:34px;border-radius:10px;background:rgba(12,10,8,.6);border:1px solid rgba(255,210,122,.25);font-size:16px}",
    ".lvl-h .x{width:34px;height:34px;border-radius:999px;background:rgba(14,20,32,.66);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.14);font-size:15px}")
rep(""".boosters{position:relative;display:flex;gap:14px;justify-content:center;padding-block:8px 16px}
.boosters::before{content:"";position:absolute;left:50%;bottom:8px;width:min(92%,300px);height:16px;transform:translateX(-50%);border-radius:4px;z-index:-1;
  background:repeating-linear-gradient(90deg, rgba(0,0,0,0) 0 22px, rgba(0,0,0,.08) 22px 23px), linear-gradient(#8a5a2c,#5a3618);border:2px solid #3a2410;box-shadow:0 6px 12px rgba(0,0,0,.5)}""",
""".boosters{position:relative;display:flex;gap:18px;justify-content:center;margin-inline:-12px;padding:10px 12px calc(10px + env(safe-area-inset-bottom,0px));
  background:linear-gradient(#1c2638,#111827);border-top:1px solid rgba(255,255,255,.1);box-shadow:0 -10px 24px rgba(0,0,0,.45)}""")
rep(".boost{position:relative;width:64px;height:64px;border-radius:18px;background:radial-gradient(circle at 40% 30%, #3a4a62, #1a2232 70%);border:2px solid #6a5a3a;display:grid;place-items:center;box-shadow:inset 0 2px 0 rgba(255,255,255,.12), 0 4px 0 #0a0c10}",
    ".boost{position:relative;width:64px;height:64px;border-radius:18px;background:linear-gradient(#2c3c5a,#1e2a42);border:1px solid rgba(255,255,255,.14);display:grid;place-items:center;box-shadow:inset 0 1px 0 rgba(255,255,255,.12), 0 4px 0 #0a0f18}")
rep(".boost .n{position:absolute;right:-4px;bottom:-4px;min-width:22px;height:22px;border-radius:11px;background:var(--ruby);font-size:12px;display:grid;place-items:center;padding:0 4px;border:2px solid var(--bg)}",
    ".boost .n{position:absolute;right:-4px;bottom:-4px;min-width:22px;height:22px;border-radius:11px;background:var(--ruby);font-size:12px;display:grid;place-items:center;padding:0 4px;border:2px solid #111827}")
open(P, 'w', encoding='utf-8').write(s)
print('ok')
