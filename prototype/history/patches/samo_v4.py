"""Самоцветный рудник v4: the home screen becomes a living cross-section of the mine: surface works on top, depth horizons below."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS ----------------
rep(".scene svg{width:100%;height:100%;max-height:52vh;filter:drop-shadow(0 18px 30px rgba(0,0,0,.5))}",
    ".scene svg{width:100%;height:100%;filter:drop-shadow(0 18px 30px rgba(0,0,0,.5))}\n.scene [data-band]{cursor:pointer}\n.scene [data-band]:hover .bandHi{opacity:.5}")

# ---------------- the scene ----------------
i = s.index("function sceneSVG(ai, built){"); j = s.index("/* ================= stones:", i)
s = s[:i] + r"""// the home screen: a cut through the mountain. Surface works on top, depth horizons below; lit ones are yours.
const mixHex = (a, b, t) => '#' + [1, 3, 5].map(i => Math.round(parseInt(a.substr(i, 2), 16) * (1 - t) + parseInt(b.substr(i, 2), 16) * t).toString(16).padStart(2, '0')).join('');
function sceneSVG(ai, built, dOpen = 0, dSel = 0){
  const has = id => built.includes(id), cu = ai === 1, fire = ai === 2, rng = mulberry(ai * 977 + 31), W = 360, H = 540, G0 = 200, BH = 64, B0 = 212;
  const pal = fire ? {sky:['#3a120c', '#160806'], far:'#3a1d18', mid:'#2a1512', near:['#3a2420', '#1c100e'], soil:'#2a1814', rock:['#3a2420', '#24120e'], tree:'#000'}
    : cu ? {sky:['#0f2a33', '#0b1820'], far:'#2a4a52', mid:'#1c3a34', near:['#2f5a46', '#173126'], soil:'#24402f', rock:['#2c3a34', '#141c1a'], tree:'#0f241c'}
    : {sky:['#1d2a46', '#0e1626'], far:'#3a4660', mid:'#2a2a34', near:['#5a4a3e', '#2c241e'], soil:'#3a2e24', rock:['#4a3c32', '#1c1612'], tree:'#151c22'};
  const sp = Object.entries(AREAS[ai].pool).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k]) => '#' + SP[k].c.toString(16).padStart(6, '0'));
  const ridge = (x, base, a1, a2, ph) => base + Math.sin(x * .021 + ph) * a1 + Math.sin(x * .057 + ph * 2) * a2;
  const ridgePath = (base, a1, a2, ph) => { let d = `M0 ${G0 + 4}`; for (let x = 0; x <= W; x += 12) d += ` L${x} ${ridge(x, base, a1, a2, ph).toFixed(1)}`; return d + ` L${W} ${G0 + 4}Z`; };
  // pines along the middle ridge
  const pines = fire ? '' : Array.from({length:34}, () => { const x = rng() * W, y = ridge(x, 128, 14, 7, 2.2) + 4 + rng() * 10, h = 9 + rng() * 9, w = h * .36;
    return `<path d="M${x.toFixed(1)} ${(y - h).toFixed(1)} L${(x + w).toFixed(1)} ${(y - h * .35).toFixed(1)} L${(x + w * .55).toFixed(1)} ${(y - h * .38).toFixed(1)} L${(x + w * 1.25).toFixed(1)} ${y.toFixed(1)} L${(x - w * 1.25).toFixed(1)} ${y.toFixed(1)} L${(x - w * .55).toFixed(1)} ${(y - h * .38).toFixed(1)} L${(x - w).toFixed(1)} ${(y - h * .35).toFixed(1)}Z"/>`; }).join('');
  const stars = Array.from({length:30}, (_, k) => { const x = rng() * W, y = rng() * 90, r = rng() < .2 ? 1.3 : .7;
    return `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${r}">${k % 3 === 0 ? `<animate attributeName="opacity" values="1;.2;1" dur="${(2 + rng() * 3).toFixed(1)}s" begin="${(rng() * 3).toFixed(1)}s" repeatCount="indefinite"/>` : ''}</circle>`; }).join('');
  const sky = fire
    ? `<path d="${ridgePath(150, 6, 4, .4)}" fill="${pal.far}"/><path d="M118 156 L168 52 L192 52 L246 156Z" fill="#2a1410"/><ellipse cx="180" cy="52" rx="14" ry="4" fill="#ff8a2a"/>
      <circle cx="180" cy="44" r="46" fill="url(#scGlow)" opacity=".55"><animate attributeName="opacity" values=".45;.7;.45" dur="3s" repeatCount="indefinite"/></circle>
      <path d="M176 56 Q168 90 182 112 Q192 132 178 156" stroke="#ff6a1a" stroke-width="3.5" fill="none" opacity=".9"/><path d="M188 58 Q200 84 194 108" stroke="#ffb03a" stroke-width="2" fill="none" opacity=".8"/>
      <g fill="#6a5a58" opacity=".5">${[0, 1, 2].map(k => `<circle cx="${178 + k * 6}" cy="40" r="${10 + k * 4}"><animate attributeName="cy" values="40;${-10 - k * 8}" dur="${6 + k * 2}s" begin="${k * 2}s" repeatCount="indefinite"/><animate attributeName="opacity" values=".7;0" dur="${6 + k * 2}s" begin="${k * 2}s" repeatCount="indefinite"/></circle>`).join('')}</g>
      <g fill="#ffb03a">${Array.from({length:14}, () => { const x = rng() * W; return `<circle cx="${x.toFixed(0)}" cy="0" r="${(.6 + rng()).toFixed(1)}"><animate attributeName="cy" values="${(rng() * 60).toFixed(0)};210" dur="${(5 + rng() * 6).toFixed(1)}s" begin="${(rng() * 6).toFixed(1)}s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;1;0" dur="${(5 + rng() * 6).toFixed(1)}s" repeatCount="indefinite"/></circle>`; }).join('')}</g>`
    : `<circle cx="292" cy="48" r="38" fill="url(#scMoon)"/><circle cx="292" cy="48" r="13" fill="#f4ecd8"/><circle cx="287" cy="44" r="3" fill="#d8cfb8" opacity=".6"/><circle cx="296" cy="52" r="2" fill="#d8cfb8" opacity=".5"/>
      ${cu ? `<path d="M-10 70 Q60 30 130 62 T260 50 T380 60" stroke="#3fe0a0" stroke-width="16" fill="none" opacity=".18" filter="url(#scBlur)"><animate attributeName="opacity" values=".1;.28;.1" dur="7s" repeatCount="indefinite"/></path>
        <path d="M-10 92 Q80 58 160 84 T380 76" stroke="#5fc0ff" stroke-width="10" fill="none" opacity=".12" filter="url(#scBlur)"><animate attributeName="opacity" values=".2;.06;.2" dur="9s" repeatCount="indefinite"/></path>` : ''}
      <path d="${ridgePath(108, 22, 10, .9)}" fill="${pal.far}"/>
      <path d="${(() => { let d = ''; for (let x = 0; x <= W; x += 12) { const y = ridge(x, 108, 22, 10, .9); if (y < 96) d += `M${x - 7} ${(y + 7).toFixed(1)} L${x} ${y.toFixed(1)} L${x + 7} ${(y + 7).toFixed(1)}Z `; } return d; })()}" fill="#dfe6f0" opacity=".55"/>`;
  // underground horizons
  const bands = DEPTHS.map((D, k) => {
    const y = B0 + k * BH, open = k <= dOpen, sel = k === dSel, next = k === dOpen + 1, t = k / (DEPTHS.length - 1);
    const top = k ? `M0 ${y} ${Array.from({length:13}, (_, q) => `L${q * 30} ${(y + Math.sin(q * 1.7 + k * 2.3) * 3).toFixed(1)}`).join(' ')} L${W} ${y}` : `M0 ${y} L${W} ${y}`;
    const fill = mixHex(pal.rock[0], fire ? '#3a0c06' : pal.rock[1], t * .75);
    const specks = Array.from({length:22}, () => `<circle cx="${(rng() * W).toFixed(0)}" cy="${(y + 4 + rng() * (BH - 8)).toFixed(0)}" r="${(.6 + rng() * 1.6).toFixed(1)}"/>`).join('');
    const gy = y + BH / 2, gx0 = 46, gx1 = 296;
    let body;
    if (open) {
      const posts = Array.from({length:6}, (_, q) => { const x = gx0 + 12 + q * 44; return `<rect x="${x}" y="${gy - 13}" width="4" height="26" fill="#7a4e26"/><rect x="${x - 4}" y="${gy - 15}" width="12" height="4" fill="#8a5a2c"/>`; }).join('');
      const lamps = Array.from({length:3}, (_, q) => { const x = gx0 + 36 + q * 88; return `<circle cx="${x}" cy="${gy - 6}" r="16" fill="url(#scGlow)" opacity=".55"><animate attributeName="opacity" values=".55;.35;.6;.5" dur="${(1.6 + q * .4).toFixed(1)}s" repeatCount="indefinite"/></circle><circle cx="${x}" cy="${gy - 8}" r="2.4" fill="#ffe08a"/>`; }).join('');
      const gems = Array.from({length:7}, (_, q) => { const x = 20 + rng() * 320, yy = y + 6 + rng() * (BH - 12), c = sp[Math.floor(rng() * sp.length)], r = 2.4 + rng() * 2.4;
        return `<g transform="translate(${x.toFixed(0)} ${yy.toFixed(0)}) rotate(${(rng() * 60 - 30).toFixed(0)})"><path d="M0 ${-r * 1.6} L${r} 0 L0 ${r * .9} L${-r} 0Z" fill="${c}" stroke="#fff" stroke-opacity=".35" stroke-width=".5"/><circle r="${r * 1.8}" fill="${c}" opacity=".0"><animate attributeName="opacity" values="0;.45;0" dur="${(2.4 + rng() * 3).toFixed(1)}s" begin="${(rng() * 4).toFixed(1)}s" repeatCount="indefinite"/></circle></g>`; }).join('');
      const cart = sel ? `<g><animateTransform attributeName="transform" type="translate" values="0 0;150 0;150 0;0 0;0 0" keyTimes="0;.4;.5;.9;1" dur="10s" repeatCount="indefinite"/>
        <path d="M${gx0 + 20} ${gy + 2} L${gx0 + 46} ${gy + 2} L${gx0 + 42} ${gy + 11} L${gx0 + 24} ${gy + 11}Z" fill="#6a6f7a" stroke="#2a2e36" stroke-width="1.2"/>${[0, 1, 2].map(q => `<circle cx="${gx0 + 26 + q * 7}" cy="${gy + 1}" r="3" fill="${sp[q % sp.length]}" stroke="#1a1a1a" stroke-width=".6"/>`).join('')}<circle cx="${gx0 + 27}" cy="${gy + 12}" r="2.4" fill="#22262c"/><circle cx="${gx0 + 39}" cy="${gy + 12}" r="2.4" fill="#22262c"/></g>` : '';
      body = `<rect x="${gx0}" y="${gy - 15}" width="${gx1 - gx0}" height="30" rx="12" fill="url(#scTunnel)"/>${gems}${posts}
        <line x1="${gx0 + 6}" y1="${gy + 13}" x2="${gx1}" y2="${gy + 13}" stroke="#8a96a4" stroke-width="1.2"/>${lamps}${cart}
        ${sel ? `<rect x="${gx0 - 3}" y="${gy - 18}" width="${gx1 - gx0 + 6}" height="36" rx="14" fill="none" stroke="#ffd27a" stroke-width="1.6" stroke-dasharray="5 4"><animate attributeName="stroke-dashoffset" values="0;-18" dur="1.2s" repeatCount="indefinite"/></rect>` : ''}`;
    } else {
      const lbl = next ? `${D.tool} · ${fmt(depthCost(ai, k))}` : D.tool;
      const wch = lbl.length * 5.4 + 30;
      body = `<rect x="${gx0}" y="${gy - 15}" width="${gx1 - gx0}" height="30" rx="12" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-dasharray="4 5"/>
        <g transform="translate(${(gx0 + gx1) / 2} ${gy})"><rect x="${-wch / 2}" y="-11" width="${wch}" height="22" rx="11" fill="${next ? '#3a2a0e' : '#0c1018'}" stroke="${next ? '#e3a51e' : '#2a3442'}"/>
        <text x="${-wch / 2 + 14}" y="4" font-size="11" text-anchor="middle">🔒</text><text x="${-wch / 2 + 24}" y="4" font-size="10.5" font-weight="800" fill="${next ? '#ffd27a' : '#8d97a6'}" font-family="Nunito, sans-serif">${lbl}</text></g>`;
    }
    return `<g data-band="${k}" role="button" aria-label="${open ? `Глубина ${D.m} м` : `${D.tool}: открыть ${D.m} м`}">
      <path d="${top} L${W} ${y + BH + 4} L0 ${y + BH + 4}Z" fill="${fill}"/><g fill="#000" opacity=".25">${specks}</g>
      ${open ? '' : `<rect x="0" y="${y}" width="${W}" height="${BH}" fill="#000" opacity="${(.25 + t * .3).toFixed(2)}"/>`}
      <rect class="bandHi" x="0" y="${y}" width="${W}" height="${BH}" fill="#ffd27a" opacity="0" style="transition:opacity .2s"/>
      ${body}
      <text x="10" y="${y + 15}" font-size="10" font-weight="800" fill="${open ? '#ffd27a' : '#6a7484'}" font-family="Nunito, sans-serif">${D.m} м</text></g>`;
  }).join('');
  const shaftBot = B0 + dOpen * BH + BH / 2 + 12;
  const shaft = `<rect x="296" y="${G0 - 4}" width="16" height="${shaftBot - G0 + 4}" fill="#0a0806"/><g stroke="#5a3a1c" stroke-width="2">${Array.from({length:Math.floor((shaftBot - G0) / 16)}, (_, q) => `<line x1="296" y1="${G0 + 8 + q * 16}" x2="312" y2="${G0 + 8 + q * 16}"/>`).join('')}</g>
    <rect x="296" y="${shaftBot}" width="16" height="${H - shaftBot}" fill="none" stroke="#fff" stroke-opacity=".1" stroke-dasharray="3 4"/>
    ${has('headframe') ? `<g><animateTransform attributeName="transform" type="translate" values="0 0;0 ${shaftBot - G0 - 22};0 ${shaftBot - G0 - 22};0 0;0 0" keyTimes="0;.42;.5;.92;1" dur="9s" repeatCount="indefinite"/><line x1="304" y1="${G0 - 100}" x2="304" y2="${G0 - 2}" stroke="#9aa6b4" stroke-width="1"/><rect x="298" y="${G0 - 2}" width="12" height="14" rx="1.5" fill="#c8a060" stroke="#4a3418"/></g>` : ''}`;
  return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Рудник в разрезе">
  <defs><linearGradient id="scSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.sky[0]}"/><stop offset="1" stop-color="${pal.sky[1]}"/></linearGradient>
  <linearGradient id="scNear" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.near[0]}"/><stop offset="1" stop-color="${pal.near[1]}"/></linearGradient>
  <linearGradient id="scMist" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.sky[1]}" stop-opacity="0"/><stop offset="1" stop-color="${pal.sky[0]}" stop-opacity=".7"/></linearGradient>
  <linearGradient id="scTunnel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a120c"/><stop offset=".6" stop-color="#2e2014"/><stop offset="1" stop-color="#3a2a1a"/></linearGradient>
  <radialGradient id="scGlow"><stop offset="0" stop-color="#ffd27a" stop-opacity=".9"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient>
  <radialGradient id="scMoon"><stop offset="0" stop-color="#fff4d8" stop-opacity=".35"/><stop offset="1" stop-color="#fff4d8" stop-opacity="0"/></radialGradient>
  <radialGradient id="scDark" cx=".5" cy=".7"><stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#1a1410"/></radialGradient>
  <filter id="scBlur"><feGaussianBlur stdDeviation="6"/></filter>
  <clipPath id="scClip"><rect width="${W}" height="${H}" rx="22"/></clipPath></defs>
  <g clip-path="url(#scClip)">
  <rect width="${W}" height="${G0 + 10}" fill="url(#scSky)"/>
  <g fill="#fff" opacity=".6">${stars}</g>
  ${sky}
  <path d="${ridgePath(128, 14, 7, 2.2)}" fill="${pal.mid}"/>
  <g fill="${pal.tree}">${pines}</g>
  <rect y="120" width="${W}" height="${G0 - 116}" fill="url(#scMist)"/>
  <path d="M28 ${G0 + 2} Q60 160 104 124 L140 96 Q172 78 208 100 L246 128 Q272 150 286 ${G0 + 2}Z" fill="url(#scNear)"/>
  <path d="M104 124 L140 96 Q172 78 208 100" stroke="#fff" stroke-opacity=".08" stroke-width="2" fill="none"/>
  <rect y="${G0}" width="${W}" height="${B0 - G0 + 2}" fill="${pal.soil}"/>
  <path d="M0 ${G0} ${Array.from({length:19}, (_, q) => `L${q * 20} ${(G0 - 1 - (q % 3)).toFixed(0)}`).join(' ')} L${W} ${G0}" stroke="${fire ? '#4a2a1a' : cu ? '#3f7a4a' : '#5a6a3a'}" stroke-width="3" fill="none"/>
  <path d="M130 ${G0} L130 146 Q160 112 190 146 L190 ${G0}Z" fill="url(#scDark)"/>
  ${has('rubble') ? '' : `<g fill="${fire ? '#3a1a10' : '#7a6a58'}" stroke="${fire ? '#ff6a1a' : '#3a3028'}" stroke-width="1.5"><circle cx="140" cy="194" r="12"/><circle cx="160" cy="190" r="15"/><circle cx="180" cy="195" r="11"/><circle cx="152" cy="180" r="9"/><circle cx="170" cy="176" r="8"/></g>`}
  ${has('timber') ? `<g class="b-timber" fill="#8a5a2c" stroke="#4a2c12" stroke-width="1.5"><rect x="122" y="134" width="11" height="68" rx="2"/><rect x="187" y="134" width="11" height="68" rx="2"/><rect x="116" y="126" width="88" height="12" rx="2"/></g>` : ''}
  ${has('rails') ? `<g class="b-rails" stroke="#9aa6b4" stroke-width="2"><line x1="150" y1="${G0}" x2="138" y2="${B0}"/><line x1="170" y1="${G0}" x2="182" y2="${B0}"/><g stroke="#6a4a2a" stroke-width="3"><line x1="146" y1="${G0 + 4}" x2="174" y2="${G0 + 4}"/><line x1="142" y1="${G0 + 9}" x2="178" y2="${G0 + 9}"/></g></g>` : ''}
  ${has('lamps') ? `<g class="b-lamps"><circle cx="112" cy="138" r="22" fill="url(#scGlow)"><animate attributeName="opacity" values="1;.7;1" dur="2.2s" repeatCount="indefinite"/></circle><circle cx="208" cy="138" r="22" fill="url(#scGlow)"><animate attributeName="opacity" values=".8;1;.8" dur="1.8s" repeatCount="indefinite"/></circle><rect x="108" y="132" width="8" height="12" rx="2" fill="#ffe08a" stroke="#6a4a1a"/><rect x="204" y="132" width="8" height="12" rx="2" fill="#ffe08a" stroke="#6a4a1a"/></g>` : ''}
  ${has('cart') ? `<g class="b-cart"><path d="M218 180 L262 180 L256 198 L224 198Z" fill="#6a6f7a" stroke="#2a2e36" stroke-width="2"/>${[0, 1, 2].map(q => `<circle cx="${228 + q * 12}" cy="177" r="6" fill="${sp[q % sp.length]}" stroke="#1a1a1a"/>`).join('')}<circle cx="230" cy="200" r="4.5" fill="#2a2e36"/><circle cx="250" cy="200" r="4.5" fill="#2a2e36"/></g>` : ''}
  ${has('headframe') ? `<g class="b-headframe" stroke="${cu ? '#c8783a' : fire ? '#c85a2a' : '#b8a48a'}" stroke-width="3" fill="none"><path d="M288 ${G0} L304 96 L320 ${G0}"/><path d="M294 164 L314 164 M297 132 L311 132 M290 188 L318 188"/><circle cx="304" cy="92" r="11"/><line x1="304" y1="92" x2="276" y2="154"/></g>` : ''}
  ${cu ? `<g fill="#3fbf8a" opacity=".35"><circle cx="60" cy="190" r="5"/><circle cx="80" cy="194" r="4"/><circle cx="330" cy="190" r="5"/></g>` : ''}
  ${bands}
  ${shaft}
  <rect width="${W}" height="${H}" rx="22" fill="none" stroke="#ffffff" stroke-opacity=".06"/>
  </g></svg>`;
}

""" + s[j:]

# ---------------- wiring: depth info, taps on horizons ----------------
rep("  $('#scene').innerHTML = sceneSVG(ai, built);",
    """  $('#scene').innerHTML = sceneSVG(ai, built, save.depth[ai] || 0, Math.min(save.depthSel[ai] || 0, save.depth[ai] || 0));
  { const svg = $('#scene svg'); if (svg && matchMedia('(prefers-reduced-motion: reduce)').matches) svg.pauseAnimations();
    $('#scene').querySelectorAll('[data-band]').forEach(g => g.onclick = () => { const k = +g.dataset.band;
      if (k <= (save.depth[ai] || 0)) { if (save.depthSel[ai] !== k) { save.depthSel[ai] = k; persist(); SFX.swap(); goHome(); toast(`Копаем на ${DEPTHS[k].m} м`); } }
      else openTech(); }); }""")
rep("""`${A.sub}<br><span class="depthchip">⛏ копаете до ${DEPTHS[save.depth[ai] || 0].m} м</span>`""",
    """`${A.sub}<br><span class="depthchip">⛏ копаете на ${DEPTHS[Math.min(save.depthSel[ai] || 0, save.depth[ai] || 0)].m} м · открыто до ${DEPTHS[save.depth[ai] || 0].m} м</span>`""")
open(P, 'w', encoding='utf-8').write(s)
print('ok')
