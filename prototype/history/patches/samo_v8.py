"""Самоцветный рудник v8: the home screen redrawn in a DREDGE mood: fog, muted slate palette, one warm lantern, the dark below."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- serif type ----------------
rep("family=Unbounded:wght@500;700;900&family=Nunito:wght@600;700;800&display=swap",
    "family=Unbounded:wght@500;700;900&family=Nunito:wght@600;700;800&family=Alegreya+SC:wght@500;700&family=Alegreya:ital,wght@0,500;0,700;1,500&display=swap")

# ---------------- the home screen skin ----------------
rep("@media (prefers-reduced-motion:reduce)", r"""/* home, DREDGE mood: slate and fog, cream ink, one warm light */
#home{--ink:#e6dcc4;--ink2:#a8a08c;--slate:rgba(16,20,22,.82);--edge:rgba(230,220,196,.32);--warm:#e8a456;
  background:radial-gradient(ellipse 90% 40% at 50% 0%, rgba(140,160,160,.16), transparent 70%), linear-gradient(#141b1e, #0a0e10 70%);font-family:'Alegreya', Georgia, serif;color:var(--ink)}
#home::after{content:"";position:absolute;inset:0;pointer-events:none;background-image:var(--grain);opacity:.14;mix-blend-mode:overlay;z-index:5}
#home .pill{background:var(--slate);border:1px solid var(--edge);border-radius:6px;color:var(--ink);font-family:'Alegreya SC', serif}
#home .pill .ic{filter:saturate(.45) brightness(.9)}
#home #mute{border-radius:6px}
#home .title{font-family:'Alegreya SC', serif;font-weight:700;font-size:clamp(22px, 7vw, 30px);letter-spacing:.06em;color:var(--ink);text-shadow:0 2px 12px rgba(0,0,0,.8)}
#home .sub{font-style:italic;color:var(--ink2);font-size:14px}
#home .depthchip{font-style:normal;font-family:'Alegreya SC', serif;color:var(--ink);background:var(--slate);border:1px solid var(--edge);border-radius:4px;letter-spacing:.03em}
#home .scene svg{filter:drop-shadow(0 20px 40px rgba(0,0,0,.7))}
#home .tasks-btn{background:var(--slate);border:1px solid var(--edge);border-radius:6px;box-shadow:inset 0 0 0 3px rgba(0,0,0,.35)}
#home .tasks-btn b{font-family:'Alegreya', serif;font-weight:700;font-size:15px;color:var(--ink)}
#home .tasks-btn span{font-family:'Alegreya SC', serif;color:var(--warm)}
#home .tasks-bar{height:5px;border-radius:0;background:rgba(0,0,0,.6);border:1px solid rgba(230,220,196,.15)}
#home .tasks-bar i{background:linear-gradient(90deg,#8a6a3a,var(--warm))}
#home .play{border-radius:6px;background:linear-gradient(rgba(40,34,26,.92), rgba(20,17,13,.95));color:var(--ink);font-family:'Alegreya SC', serif;font-weight:700;font-size:26px;letter-spacing:.08em;
  border:1px solid rgba(232,164,86,.7);box-shadow:inset 0 0 0 3px rgba(0,0,0,.5), inset 0 0 26px rgba(232,164,86,.18), 0 0 30px rgba(232,164,86,.2), 0 10px 26px rgba(0,0,0,.6);text-shadow:0 0 14px rgba(232,164,86,.45)}
#home .play:active{transform:translateY(2px)}
#home .play::after{display:none}
#home .play small{font-family:'Alegreya', serif;font-style:italic;font-weight:500;color:var(--ink2);font-size:14px;letter-spacing:.02em;text-shadow:none}
#home .play .vein{font-family:'Alegreya SC', serif;background:transparent;border:1px solid rgba(200,170,255,.45);color:#cdb8f0;border-radius:3px}
#home .nav button{border-radius:4px;background:var(--slate);border:1px solid rgba(230,220,196,.18);font-family:'Alegreya SC', serif;font-size:15px;color:var(--ink2);letter-spacing:.04em}
#home .nav button.on{border-color:var(--edge);color:var(--ink);box-shadow:inset 0 -2px 0 var(--warm)}
@media (prefers-reduced-motion:reduce)""")

# grain texture, made once
rep("$('#tasksBtn').onclick = openTasks;", r"""$('#tasksBtn').onclick = openTasks;
{ const c = document.createElement('canvas'); c.width = c.height = 160; const x = c.getContext('2d'), im = x.createImageData(160, 160);
  for (let i = 0; i < im.data.length; i += 4) { const v = Math.random() * 255; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = 255; }
  x.putImageData(im, 0, 0); $('#home').style.setProperty('--grain', `url(${c.toDataURL()})`); }""")

# ---------------- the scene ----------------
i = s.index("// the home screen: a cut through the mountain."); j = s.index("/* ================= stones:", i)
s = s[:i] + r"""// the home screen: a cut through the mountain in fog. Surface works on top, depth horizons below; lit ones are yours, the rest is dark.
const mixHex = (a, b, t) => '#' + [1, 3, 5].map(i => Math.round(parseInt(a.substr(i, 2), 16) * (1 - t) + parseInt(b.substr(i, 2), 16) * t).toString(16).padStart(2, '0')).join('');
function sceneSVG(ai, built, dOpen = 0, dSel = 0){
  const has = id => built.includes(id), cu = ai === 1, fire = ai === 2, rng = mulberry(ai * 977 + 31), W = 360, H = 540, G0 = 200, BH = 64, B0 = 212;
  const pal = fire ? {sky:['#2e2420', '#120d0c'], fog:'#7a6a60', far:'#2a201c', mid:'#1e1714', near:['#2c221e', '#14100e'], soil:'#1c1512', rock:['#2a221e', '#0e0a09'], tree:'#0e0b0a', water:'#140f0e'}
    : cu ? {sky:['#22343a', '#0e1618'], fog:'#7f9a96', far:'#22322f', mid:'#18241f', near:['#1f2e28', '#0f1714'], soil:'#141c18', rock:['#1e2824', '#0a0e0c'], tree:'#0b1210', water:'#0c1416'}
    : {sky:['#28343c', '#10161a'], fog:'#8a9a9e', far:'#25303a', mid:'#1a2228', near:['#2a2e2e', '#121516'], soil:'#16191a', rock:['#262a2a', '#0b0d0e'], tree:'#0c1114', water:'#0c1216'};
  const ink = '#e6dcc4', ink2 = '#a8a08c', warm = '#e8a456', serif = "'Alegreya SC', Georgia, serif";
  const sp = Object.entries(AREAS[ai].pool).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k]) => mixHex('#' + SP[k].c.toString(16).padStart(6, '0'), '#8a9090', .45));
  const ridge = (x, base, a1, a2, ph) => base + Math.sin(x * .021 + ph) * a1 + Math.sin(x * .057 + ph * 2) * a2;
  const ridgePath = (base, a1, a2, ph) => { let d = `M0 ${G0 + 4}`; for (let x = 0; x <= W; x += 12) d += ` L${x} ${ridge(x, base, a1, a2, ph).toFixed(1)}`; return d + ` L${W} ${G0 + 4}Z`; };
  const pines = (n, base, a1, a2, ph, hmin, hvar) => Array.from({length:n}, () => { const x = rng() * W, y = ridge(x, base, a1, a2, ph) + 3 + rng() * 8, h = hmin + rng() * hvar, w = h * .3;
    return `<path d="M${x.toFixed(1)} ${(y - h).toFixed(1)} L${(x + w * .7).toFixed(1)} ${(y - h * .45).toFixed(1)} L${(x + w * .35).toFixed(1)} ${(y - h * .47).toFixed(1)} L${(x + w * 1.1).toFixed(1)} ${y.toFixed(1)} L${(x - w * 1.1).toFixed(1)} ${y.toFixed(1)} L${(x - w * .35).toFixed(1)} ${(y - h * .47).toFixed(1)} L${(x - w * .7).toFixed(1)} ${(y - h * .45).toFixed(1)}Z"/>`; }).join('');
  // drifting fog banks
  const fogBank = (y, rx, ry, op, dur, dx) => `<ellipse cx="${(rng() * W).toFixed(0)}" cy="${y}" rx="${rx}" ry="${ry}" fill="${pal.fog}" opacity="${op}" filter="url(#scFog)"><animateTransform attributeName="transform" type="translate" values="${-dx} 0;${dx} 0;${-dx} 0" dur="${dur}s" repeatCount="indefinite"/></ellipse>`;
  const stars = Array.from({length:16}, () => `<circle cx="${(rng() * W).toFixed(1)}" cy="${(rng() * 80).toFixed(1)}" r="${rng() < .2 ? .9 : .5}"><animate attributeName="opacity" values=".7;.15;.7" dur="${(3 + rng() * 4).toFixed(1)}s" begin="${(rng() * 3).toFixed(1)}s" repeatCount="indefinite"/></circle>`).join('');
  const crows = Array.from({length:2}, (_, k) => { const y = 60 + rng() * 40, d = 38 + rng() * 20;
    return `<g><animateTransform attributeName="transform" type="translate" values="-30 ${y};${W + 30} ${y - 20}" dur="${d.toFixed(0)}s" begin="${-k * 17}s" repeatCount="indefinite"/><path d="M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0" stroke="#0a0c0e" stroke-width="1.3" fill="none"><animate attributeName="d" values="M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0;M-5 -1 Q-2.5 1 0 0 Q2.5 1 5 -1;M-5 0 Q-2.5 -3 0 0 Q2.5 -3 5 0" dur=".9s" repeatCount="indefinite"/></path></g>`; }).join('');
  const sky = `<circle cx="276" cy="58" r="70" fill="url(#scHalo)"/><circle cx="276" cy="58" r="15" fill="#d6d4c2" opacity=".9"/><circle cx="271" cy="54" r="3.4" fill="#b8b6a4" opacity=".5"/><circle cx="281" cy="62" r="2.2" fill="#b8b6a4" opacity=".45"/>
    ${cu ? `<path d="M-10 74 Q70 40 150 66 T380 58" stroke="#6fa89a" stroke-width="18" fill="none" opacity=".1" filter="url(#scFog)"><animate attributeName="opacity" values=".05;.14;.05" dur="11s" repeatCount="indefinite"/></path>` : ''}
    ${fire ? `<path d="M120 160 L170 66 L190 66 L242 160Z" fill="${pal.far}"/><ellipse cx="180" cy="66" rx="12" ry="3" fill="#c86a3a" opacity=".7"/><circle cx="180" cy="62" r="40" fill="#c86a3a" opacity=".12"><animate attributeName="opacity" values=".08;.18;.08" dur="4s" repeatCount="indefinite"/></circle>
      ${[0, 1, 2].map(k => `<circle cx="${178 + k * 5}" cy="56" r="${9 + k * 4}" fill="#4a4240" opacity=".35"><animate attributeName="cy" values="56;${-6 - k * 8}" dur="${9 + k * 3}s" begin="${k * 3}s" repeatCount="indefinite"/><animate attributeName="opacity" values=".4;0" dur="${9 + k * 3}s" begin="${k * 3}s" repeatCount="indefinite"/></circle>`).join('')}` : ''}
    <path d="${ridgePath(112, 20, 9, .9)}" fill="${pal.far}"/>
    <g fill="${pal.far}" opacity=".9">${fire ? '' : pines(14, 112, 20, 9, .9, 6, 6)}</g>`;
  // the horizons below
  const bands = DEPTHS.map((D, k) => {
    const y = B0 + k * BH, open = k <= dOpen, sel = k === dSel, next = k === dOpen + 1, t = k / (DEPTHS.length - 1);
    const top = k ? `M0 ${y} ${Array.from({length:13}, (_, q) => `L${q * 30} ${(y + Math.sin(q * 1.7 + k * 2.3) * 3).toFixed(1)}`).join(' ')} L${W} ${y}` : `M0 ${y} L${W} ${y}`;
    const fill = mixHex(pal.rock[0], pal.rock[1], t * .8);
    const specks = Array.from({length:18}, () => `<circle cx="${(rng() * W).toFixed(0)}" cy="${(y + 4 + rng() * (BH - 8)).toFixed(0)}" r="${(.5 + rng() * 1.4).toFixed(1)}"/>`).join('');
    const gy = y + BH / 2, gx0 = 46, gx1 = 296;
    let body;
    if (open) {
      const posts = Array.from({length:6}, (_, q) => { const x = gx0 + 12 + q * 44; return `<rect x="${x}" y="${gy - 13}" width="3" height="26" fill="#2e2318"/><rect x="${x - 4}" y="${gy - 14}" width="11" height="3" fill="#3a2c1e"/>`; }).join('');
      const lx = gx0 + 70 + (k * 53) % 120;
      const lamp = `<circle cx="${lx}" cy="${gy - 4}" r="34" fill="url(#scWarm)"><animate attributeName="opacity" values="1;.75;.95;.85;1" dur="${(2.2 + k * .3).toFixed(1)}s" repeatCount="indefinite"/></circle><line x1="${lx}" y1="${gy - 14}" x2="${lx}" y2="${gy - 9}" stroke="#1a1410"/><rect x="${lx - 2.5}" y="${gy - 9}" width="5" height="7" rx="1" fill="#f0c080"/>`;
      const gems = Array.from({length:5}, () => { const x = 20 + rng() * 320, yy = y + 6 + rng() * (BH - 12), c = sp[Math.floor(rng() * sp.length)], r = 2 + rng() * 2;
        return `<g transform="translate(${x.toFixed(0)} ${yy.toFixed(0)}) rotate(${(rng() * 60 - 30).toFixed(0)})"><path d="M0 ${-r * 1.6} L${r} 0 L0 ${r * .9} L${-r} 0Z" fill="${c}" opacity=".8"/><path d="M0 ${-r * 1.6} L${r} 0 L0 0Z" fill="#fff" opacity=".18"><animate attributeName="opacity" values=".1;.5;.1" dur="${(3 + rng() * 3).toFixed(1)}s" begin="${(rng() * 4).toFixed(1)}s" repeatCount="indefinite"/></path></g>`; }).join('');
      const cart = sel ? `<g><animateTransform attributeName="transform" type="translate" values="0 0;150 0;150 0;0 0;0 0" keyTimes="0;.4;.5;.9;1" dur="12s" repeatCount="indefinite"/>
        <path d="M${gx0 + 20} ${gy + 2} L${gx0 + 46} ${gy + 2} L${gx0 + 42} ${gy + 11} L${gx0 + 24} ${gy + 11}Z" fill="#3a3e42" stroke="#121416" stroke-width="1"/>${[0, 1, 2].map(q => `<circle cx="${gx0 + 26 + q * 7}" cy="${gy + 1}" r="3" fill="${sp[q % sp.length]}"/>`).join('')}<circle cx="${gx0 + 27}" cy="${gy + 12}" r="2.2" fill="#121416"/><circle cx="${gx0 + 39}" cy="${gy + 12}" r="2.2" fill="#121416"/></g>` : '';
      body = `<rect x="${gx0}" y="${gy - 15}" width="${gx1 - gx0}" height="30" rx="10" fill="url(#scTunnel)"/>${gems}${posts}
        <line x1="${gx0 + 6}" y1="${gy + 13}" x2="${gx1}" y2="${gy + 13}" stroke="#5a5e60" stroke-width="1"/>${lamp}${cart}
        ${sel ? `<rect x="${gx0 - 3}" y="${gy - 18}" width="${gx1 - gx0 + 6}" height="36" rx="12" fill="none" stroke="${ink}" stroke-opacity=".55" stroke-width="1" stroke-dasharray="2 4"/>
          <text x="${gx1 - 4}" y="${gy - 21}" font-size="10" text-anchor="end" fill="${ink}" font-family="${serif}" opacity=".85">здесь копаем</text>` : ''}`;
    } else {
      const lbl = next ? `${D.tool} · ${fmt(depthCost(ai, k))}` : D.tool, wch = lbl.length * 5.8 + 30;
      const fogs = Array.from({length:3}, (_, q) => `<ellipse cx="${(60 + q * 120 + rng() * 40).toFixed(0)}" cy="${gy}" rx="90" ry="26" fill="#000" opacity="${(.35 + t * .3).toFixed(2)}" filter="url(#scFog)"><animateTransform attributeName="transform" type="translate" values="-14 0;14 0;-14 0" dur="${(14 + q * 5)}s" repeatCount="indefinite"/></ellipse>`).join('');
      // something lives at the very bottom
      const eyes = k === DEPTHS.length - 1 ? Array.from({length:2}, (_, q) => { const ex = 70 + q * 170 + rng() * 40, ey = gy + (rng() - .5) * 20, d = (7 + rng() * 6).toFixed(1);
        return `<g opacity="0"><animate attributeName="opacity" values="0;0;.9;.9;0;0" keyTimes="0;.55;.6;.7;.75;1" dur="${d}s" begin="${(q * 3.1).toFixed(1)}s" repeatCount="indefinite"/><ellipse cx="${ex}" cy="${ey}" rx="2.2" ry="1.3" fill="#d8c86a"/><ellipse cx="${ex + 9}" cy="${ey}" rx="2.2" ry="1.3" fill="#d8c86a"/></g>`; }).join('') : '';
      body = `${fogs}${eyes}<g transform="translate(${(gx0 + gx1) / 2} ${gy})"><rect x="${-wch / 2}" y="-11" width="${wch}" height="22" rx="2" fill="rgba(14,16,18,.9)" stroke="${next ? warm : ink}" stroke-opacity="${next ? .7 : .25}"/>
        <text x="0" y="4" font-size="11" text-anchor="middle" fill="${next ? ink : ink2}" font-family="${serif}" letter-spacing=".5">${lbl}</text></g>`;
    }
    return `<g data-band="${k}" role="button" aria-label="${open ? `Глубина ${D.m} м` : `${D.tool}: открыть ${D.m} м`}">
      <path d="${top} L${W} ${y + BH + 4} L0 ${y + BH + 4}Z" fill="${fill}"/><g fill="#000" opacity=".3">${specks}</g>
      ${open ? '' : `<rect x="0" y="${y}" width="${W}" height="${BH}" fill="#000" opacity="${(.35 + t * .35).toFixed(2)}"/>`}
      <rect class="bandHi" x="0" y="${y}" width="${W}" height="${BH}" fill="${ink}" opacity="0" style="transition:opacity .2s"/>
      ${body}
      <text x="10" y="${y + 15}" font-size="11" fill="${open ? ink : '#5e5a50'}" font-family="${serif}">${D.m} м</text></g>`;
  }).join('');
  const shaftBot = B0 + dOpen * BH + BH / 2 + 12;
  const shaft = `<rect x="296" y="${G0 - 4}" width="16" height="${shaftBot - G0 + 4}" fill="#07090a"/><g stroke="#2e2318" stroke-width="2">${Array.from({length:Math.floor((shaftBot - G0) / 16)}, (_, q) => `<line x1="296" y1="${G0 + 8 + q * 16}" x2="312" y2="${G0 + 8 + q * 16}"/>`).join('')}</g>
    ${has('headframe') ? `<g><animateTransform attributeName="transform" type="translate" values="0 0;0 ${shaftBot - G0 - 22};0 ${shaftBot - G0 - 22};0 0;0 0" keyTimes="0;.42;.5;.92;1" dur="11s" repeatCount="indefinite"/><line x1="304" y1="${G0 - 100}" x2="304" y2="${G0 - 2}" stroke="#5a5e60" stroke-width="1"/><rect x="298" y="${G0 - 2}" width="12" height="14" rx="1" fill="#4a3a28" stroke="#1a140e"/></g>` : ''}`;
  return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Рудник в разрезе">
  <defs><linearGradient id="scSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.sky[0]}"/><stop offset="1" stop-color="${pal.sky[1]}"/></linearGradient>
  <linearGradient id="scNear" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.near[0]}"/><stop offset="1" stop-color="${pal.near[1]}"/></linearGradient>
  <linearGradient id="scMist" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pal.fog}" stop-opacity="0"/><stop offset="1" stop-color="${pal.fog}" stop-opacity=".32"/></linearGradient>
  <linearGradient id="scTunnel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0a0807"/><stop offset="1" stop-color="#1a140f"/></linearGradient>
  <radialGradient id="scWarm"><stop offset="0" stop-color="${warm}" stop-opacity=".55"/><stop offset=".45" stop-color="${warm}" stop-opacity=".14"/><stop offset="1" stop-color="${warm}" stop-opacity="0"/></radialGradient>
  <radialGradient id="scHalo"><stop offset="0" stop-color="#d8d6c4" stop-opacity=".28"/><stop offset=".4" stop-color="#b0b8b4" stop-opacity=".08"/><stop offset="1" stop-color="#b0b8b4" stop-opacity="0"/></radialGradient>
  <radialGradient id="scDark" cx=".5" cy=".7"><stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#121010"/></radialGradient>
  <radialGradient id="scVig" cx=".5" cy=".4" r=".75"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient>
  <filter id="scFog" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
  <clipPath id="scClip"><rect width="${W}" height="${H}" rx="8"/></clipPath></defs>
  <g clip-path="url(#scClip)">
  <rect width="${W}" height="${G0 + 10}" fill="url(#scSky)"/>
  <g fill="#d8d6c4">${stars}</g>${sky}${crows}
  ${fogBank(118, 160, 18, .22, 60, 30)}
  <path d="${ridgePath(132, 13, 7, 2.2)}" fill="${pal.mid}"/>
  <g fill="${pal.tree}">${fire ? '' : pines(30, 132, 13, 7, 2.2, 10, 10)}</g>
  <rect y="118" width="${W}" height="${G0 - 114}" fill="url(#scMist)"/>
  ${fogBank(150, 140, 14, .28, 45, 40)}
  <path d="M28 ${G0 + 2} Q60 160 104 124 L140 96 Q172 78 208 100 L246 128 Q272 150 286 ${G0 + 2}Z" fill="url(#scNear)"/>
  <rect y="${G0}" width="${W}" height="${B0 - G0 + 2}" fill="${pal.soil}"/>
  <path d="M6 ${G0 + 1} Q50 ${G0 - 9} 104 ${G0 + 1}Z" fill="${pal.water}"/>
  <g stroke="#d8d6c4" stroke-linecap="round">${[0, 1, 2, 3].map(q => `<line x1="${48 + q * 3 - q * q}" y1="${G0 - 5 + q * 1.6}" x2="${60 - q * 2 + q * q}" y2="${G0 - 5 + q * 1.6}" stroke-width=".9" opacity=".5"><animate attributeName="opacity" values=".15;.6;.15" dur="${(2.5 + q * .7).toFixed(1)}s" repeatCount="indefinite"/></line>`).join('')}</g>
  <path d="M0 ${G0} ${Array.from({length:19}, (_, q) => `L${q * 20} ${(G0 - 1 - (q % 3) * .7).toFixed(1)}`).join(' ')} L${W} ${G0}" stroke="${mixHex(pal.near[0], '#5a6a50', .35)}" stroke-width="2" fill="none"/>
  <path d="M130 ${G0} L130 146 Q160 112 190 146 L190 ${G0}Z" fill="url(#scDark)"/>
  <circle cx="122" cy="146" r="46" fill="url(#scWarm)"><animate attributeName="opacity" values="1;.78;.95;.85;1" dur="2.6s" repeatCount="indefinite"/></circle>
  <line x1="122" y1="128" x2="122" y2="140" stroke="#121010" stroke-width="1"/><path d="M118 140 L126 140 L127 152 L117 152Z" fill="#1a1612"/><rect x="119.5" y="142" width="5" height="8" fill="#f0c080"/>
  ${has('rubble') ? '' : `<g fill="#3a3632" stroke="#151312" stroke-width="1.2"><circle cx="140" cy="194" r="12"/><circle cx="160" cy="190" r="15"/><circle cx="180" cy="195" r="11"/><circle cx="152" cy="180" r="9"/><circle cx="170" cy="176" r="8"/></g>`}
  ${has('timber') ? `<g class="b-timber" fill="#3a2c1e" stroke="#120d08" stroke-width="1.2"><rect x="124" y="134" width="9" height="68"/><rect x="187" y="134" width="9" height="68"/><rect x="118" y="127" width="84" height="10"/></g>` : ''}
  ${has('rails') ? `<g class="b-rails" stroke="#5a5e60" stroke-width="1.6"><line x1="150" y1="${G0}" x2="138" y2="${B0}"/><line x1="170" y1="${G0}" x2="182" y2="${B0}"/><g stroke="#2a2018" stroke-width="2.5"><line x1="146" y1="${G0 + 4}" x2="174" y2="${G0 + 4}"/><line x1="142" y1="${G0 + 9}" x2="178" y2="${G0 + 9}"/></g></g>` : ''}
  ${has('lamps') ? `<g class="b-lamps"><circle cx="208" cy="140" r="34" fill="url(#scWarm)"><animate attributeName="opacity" values=".85;1;.8" dur="2.1s" repeatCount="indefinite"/></circle><line x1="208" y1="128" x2="208" y2="134" stroke="#121010"/><path d="M204 134 L212 134 L213 146 L203 146Z" fill="#1a1612"/><rect x="205.5" y="136" width="5" height="8" fill="#f0c080"/></g>` : ''}
  ${has('cart') ? `<g class="b-cart"><path d="M218 182 L258 182 L253 198 L223 198Z" fill="#33373a" stroke="#101214" stroke-width="1.5"/>${[0, 1, 2].map(q => `<circle cx="${228 + q * 10}" cy="179" r="5" fill="${sp[q % sp.length]}"/>`).join('')}<circle cx="228" cy="200" r="4" fill="#101214"/><circle cx="248" cy="200" r="4" fill="#101214"/></g>` : ''}
  ${has('headframe') ? `<g class="b-headframe" stroke="#2a2420" stroke-width="3" fill="none"><path d="M288 ${G0} L304 96 L320 ${G0}"/><path d="M294 164 L314 164 M297 132 L311 132 M290 188 L318 188"/><circle cx="304" cy="92" r="11"/><line x1="304" y1="92" x2="276" y2="154"/></g>` : ''}
  ${fogBank(196, 180, 10, .2, 38, 50)}
  ${bands}
  ${shaft}
  <rect width="${W}" height="${H}" fill="url(#scVig)"/>
  <rect x=".5" y=".5" width="${W - 1}" height="${H - 1}" rx="8" fill="none" stroke="${ink}" stroke-opacity=".28"/>
  <rect x="4.5" y="4.5" width="${W - 9}" height="${H - 9}" rx="5" fill="none" stroke="${ink}" stroke-opacity=".1"/>
  </g></svg>`;
}

""" + s[j:]
open(P, 'w', encoding='utf-8').write(s)
print('ok')
