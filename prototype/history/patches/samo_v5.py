"""Самоцветный рудник v5: the level screen becomes a mine gallery: living background per mine and depth, timber-framed stone tray, plank sign, brass moves token, booster shelf."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS ----------------
rep("#game .hud{display:grid;grid-template-columns:1fr auto;gap:10px;align-items:stretch;padding-block:8px 8px}",
"""#gameBg{position:absolute;inset:0;z-index:0;pointer-events:none;overflow:hidden}
#gameBg svg{width:100%;height:100%;display:block}
#game > :not(#gameBg){position:relative;z-index:1}
#game .hud{display:grid;grid-template-columns:1fr auto;gap:10px;align-items:center;padding-block:6px 8px}""")
rep(".goals{display:flex;gap:6px;align-items:center;background:linear-gradient(#22324e,#172235);border:1px solid var(--line);border-radius:16px;padding:6px 8px;min-width:0;flex-wrap:wrap}",
""".goals{position:relative;display:flex;gap:6px;align-items:center;min-width:0;flex-wrap:wrap;padding:7px 16px;border-radius:10px;
  background:repeating-linear-gradient(176deg, rgba(0,0,0,0) 0 7px, rgba(0,0,0,.07) 7px 8px), linear-gradient(#94622f,#6a4220 60%,#5a3618);
  border:2px solid #3a2410;box-shadow:inset 0 2px 0 rgba(255,220,160,.25), inset 0 -3px 0 rgba(0,0,0,.25), 0 5px 0 #24160a, 0 10px 18px rgba(0,0,0,.45)}
.goals::before, .goals::after{content:"";position:absolute;top:50%;width:7px;height:7px;margin-top:-3.5px;border-radius:50%;background:radial-gradient(circle at 35% 30%, #e8e2d4, #7a7468 60%, #3a362e)}
.goals::before{left:5px}.goals::after{right:5px}
.goals .goal b{color:#fff4dc;text-shadow:0 2px 0 rgba(0,0,0,.45)}""")
rep(".moves{display:flex;flex-direction:column;align-items:center;justify-content:center;background:linear-gradient(#3a2a12,#22180c);border:1px solid #6a4a1c;border-radius:16px;padding:4px 12px;min-width:64px}",
""".moves{display:flex;flex-direction:column;align-items:center;justify-content:center;width:72px;height:72px;border-radius:50%;padding:0;
  background:radial-gradient(circle at 50% 50%, transparent 58%, rgba(0,0,0,.25) 59%, transparent 62%), radial-gradient(circle at 35% 28%, #fff0b0, #e0aa30 45%, #9a6810 80%, #5a3a06);
  border:3px solid #4a3006;box-shadow:inset 0 3px 2px rgba(255,255,255,.45), inset 0 -4px 4px rgba(0,0,0,.35), 0 5px 0 #2a1a04, 0 10px 20px rgba(0,0,0,.45), 0 0 26px rgba(255,200,90,.25)}""")
rep(".moves small{font-size:10px;color:#d8b278;text-transform:uppercase;letter-spacing:.08em}", ".moves small{font-size:9px;color:#5a3604;text-transform:uppercase;letter-spacing:.1em;margin-top:2px}")
rep(".moves b{font-family:var(--display);font-size:26px;line-height:1;color:var(--gold);font-variant-numeric:tabular-nums}", ".moves b{font-family:var(--display);font-size:27px;line-height:1;color:#3a2200;text-shadow:0 1px 0 rgba(255,240,190,.7);font-variant-numeric:tabular-nums}")
rep(".moves.low b{color:#ff6a6a;animation:bump .6s infinite}", ".moves.low{box-shadow:inset 0 3px 2px rgba(255,255,255,.45), inset 0 -4px 4px rgba(0,0,0,.35), 0 5px 0 #2a1a04, 0 0 30px rgba(255,70,70,.7)}\n.moves.low b{color:#a80e1c;animation:bump .6s infinite}")
rep(".lvl-h{display:flex;justify-content:space-between;align-items:center;font-size:12px;color:var(--muted)}",
""".lvl-h{display:flex;justify-content:space-between;align-items:center;font-size:12px;color:#e8d8bc;padding-top:6px}
#lvlName{background:rgba(12,10,8,.6);border:1px solid rgba(255,210,122,.25);border-radius:999px;padding:4px 12px;backdrop-filter:blur(4px)}""")
rep(".lvl-h .x{width:34px;height:34px;border-radius:10px;background:var(--panel);border:1px solid var(--line);font-size:16px}", ".lvl-h .x{width:34px;height:34px;border-radius:10px;background:rgba(12,10,8,.6);border:1px solid rgba(255,210,122,.25);font-size:16px}")
rep("#board{display:block;touch-action:none;border-radius:18px}", "#board{display:block;touch-action:none;border-radius:18px;filter:drop-shadow(0 16px 24px rgba(0,0,0,.65))}")
rep(".boosters{display:flex;gap:10px;justify-content:center;padding-block:8px 12px}",
""".boosters{position:relative;display:flex;gap:14px;justify-content:center;padding-block:8px 16px}
.boosters::before{content:"";position:absolute;left:50%;bottom:8px;width:min(92%,300px);height:16px;transform:translateX(-50%);border-radius:4px;z-index:-1;
  background:repeating-linear-gradient(90deg, rgba(0,0,0,0) 0 22px, rgba(0,0,0,.08) 22px 23px), linear-gradient(#8a5a2c,#5a3618);border:2px solid #3a2410;box-shadow:0 6px 12px rgba(0,0,0,.5)}""")
rep(".boost{position:relative;width:64px;height:64px;border-radius:18px;background:linear-gradient(#2a3b5a,#1a263b);border:1px solid var(--line);display:grid;place-items:center;box-shadow:0 4px 0 #0a1019}",
    ".boost{position:relative;width:64px;height:64px;border-radius:18px;background:radial-gradient(circle at 40% 30%, #3a4a62, #1a2232 70%);border:2px solid #6a5a3a;display:grid;place-items:center;box-shadow:inset 0 2px 0 rgba(255,255,255,.12), 0 4px 0 #0a0c10}")

# ---------------- markup ----------------
rep('<section class="screen" id="game" hidden>\n', '<section class="screen" id="game" hidden>\n  <div id="gameBg" aria-hidden="true"></div>\n')

# ---------------- background ----------------
rep("/* ================= stones:", r"""// the level backdrop: the face of the gallery you are working, by mine and depth
function gameBgSVG(ai, dl){
  const rng = mulberry(ai * 131 + dl * 17 + 5), W = 400, H = 860, fire = ai === 2, cu = ai === 1, t = dl / 4;
  const wall = fire ? ['#4a2a22', '#24100c'] : cu ? ['#2e4038', '#121a18'] : ['#4e4034', '#1a1410'];
  const top = mixHex(wall[0], '#000000', .25 + t * .3), mid = mixHex(wall[0], fire ? '#5a1a08' : '#000000', t * .35), bot = mixHex(wall[1], '#000000', t * .3);
  const sp = Object.entries(AREAS[ai].pool).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k]) => '#' + SP[k].c.toString(16).padStart(6, '0'));
  const strata = Array.from({length:7}, (_, k) => { const y = 90 + k * 105 + rng() * 30, a = 8 + rng() * 14, ph = rng() * 6;
    let d = `M-10 ${y}`; for (let x = 0; x <= W + 20; x += 20) d += ` L${x} ${(y + Math.sin(x * .015 + ph) * a + x * .06).toFixed(1)}`;
    return `<path d="${d} L${W + 20} ${y + 40 + W * .06} L-10 ${y + 40}Z" fill="${k % 2 ? '#000' : '#fff'}" opacity="${(.03 + rng() * .04).toFixed(3)}"/>`; }).join('');
  const specks = Array.from({length:240}, () => `<circle cx="${(rng() * W).toFixed(0)}" cy="${(rng() * H).toFixed(0)}" r="${(.6 + rng() * 2.2).toFixed(1)}" fill="${rng() < .5 ? '#000' : '#fff'}" opacity="${(.06 + rng() * .14).toFixed(2)}"/>`).join('');
  // crystal pockets in the walls; deeper means more and bigger
  const pockets = Array.from({length:4 + dl * 2}, (_, k) => { const side = k % 2, x = side ? W - 18 - rng() * 40 : 18 + rng() * 40, y = 130 + rng() * (H - 300), c = sp[Math.floor(rng() * sp.length)], n = 3 + Math.floor(rng() * 4);
    const shards = Array.from({length:n}, () => { const a = (side ? 200 : -20) + rng() * 140, l = 10 + rng() * (12 + dl * 4), w = 3 + rng() * 3;
      return `<g transform="rotate(${a.toFixed(0)})"><path d="M0 ${-w} L${l} ${-w * .6} L${l + w * 1.4} 0 L${l} ${w * .6} L0 ${w}Z" fill="${c}"/><path d="M0 ${-w} L${l} ${-w * .6} L${l + w * 1.4} 0Z" fill="#fff" opacity=".35"/></g>`; }).join('');
    return `<g transform="translate(${x.toFixed(0)} ${y.toFixed(0)})"><ellipse rx="${14 + n * 3}" ry="${9 + n * 2}" fill="#000" opacity=".45"/>${shards}
      <circle r="${18 + n * 3}" fill="${c}" opacity="0"><animate attributeName="opacity" values="0;.22;0" dur="${(3 + rng() * 3).toFixed(1)}s" begin="${(rng() * 4).toFixed(1)}s" repeatCount="indefinite"/></circle></g>`; }).join('');
  const post = x => `<g><rect x="${x}" y="0" width="26" height="${H}" fill="url(#gbWood)"/>${Array.from({length:22}, (_, k) => `<line x1="${x + 4 + (k % 4) * 5}" y1="${k * 40}" x2="${x + 6 + (k % 4) * 5}" y2="${k * 40 + 34}" stroke="#2a1808" stroke-opacity=".35" stroke-width="1"/>`).join('')}
    <rect x="${x}" y="0" width="26" height="${H}" fill="none" stroke="#2a1808" stroke-width="2"/></g>`;
  const lamp = (x, k) => `<g><animateTransform attributeName="transform" type="rotate" values="-5 ${x} 66;5 ${x} 66;-5 ${x} 66" dur="${(3.2 + k * .7).toFixed(1)}s" repeatCount="indefinite" calcMode="spline" keySplines=".45 0 .55 1;.45 0 .55 1"/>
    <line x1="${x}" y1="66" x2="${x}" y2="104" stroke="#2a2420" stroke-width="2" stroke-dasharray="3 2"/>
    <circle cx="${x}" cy="118" r="150" fill="url(#gbGlow)"><animate attributeName="opacity" values=".85;.65;.9;.75;.85" dur="${(2.3 + k * .5).toFixed(1)}s" repeatCount="indefinite"/></circle>
    <path d="M${x - 8} 104 L${x + 8} 104 L${x + 10} 128 L${x - 10} 128Z" fill="#3a3028"/><rect x="${x - 6}" y="108" width="12" height="16" rx="2" fill="#ffe7a0"/><path d="M${x - 10} 128 L${x + 10} 128 L${x + 6} 134 L${x - 6} 134Z" fill="#2a221c"/></g>`;
  const dust = Array.from({length:16}, () => { const x = 40 + rng() * 320, y = 120 + rng() * 600, d = 8 + rng() * 10;
    return `<circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="${(.8 + rng() * 1.2).toFixed(1)}" fill="#ffe7b8" opacity=".0"><animate attributeName="cy" values="${y.toFixed(0)};${(y + 60 + rng() * 60).toFixed(0)}" dur="${d.toFixed(1)}s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;.5;0" dur="${d.toFixed(1)}s" repeatCount="indefinite"/></circle>`; }).join('');
  const gasHaze = dl >= 2 ? Array.from({length:4}, (_, k) => `<ellipse cx="${60 + k * 95}" cy="${560 + (k % 2) * 90}" rx="120" ry="50" fill="#7adf6a" opacity=".07" filter="url(#gbBlur)"><animate attributeName="cx" values="${60 + k * 95};${90 + k * 95};${60 + k * 95}" dur="${9 + k * 2}s" repeatCount="indefinite"/></ellipse>`).join('') : '';
  const lava = fire ? Array.from({length:5}, () => { let x = rng() * W, y = 200 + rng() * 500, d = `M${x.toFixed(0)} ${y.toFixed(0)}`; for (let q = 0; q < 6; q++) { x += (rng() - .5) * 50; y += 15 + rng() * 25; d += ` L${x.toFixed(0)} ${y.toFixed(0)}`; }
    return `<path d="${d}" stroke="#ff6a1a" stroke-width="2.5" fill="none" opacity=".7" filter="url(#gbSoft)"><animate attributeName="opacity" values=".4;.85;.4" dur="${(2 + rng() * 2).toFixed(1)}s" repeatCount="indefinite"/></path>`; }).join('') : '';
  const sleepers = Array.from({length:6}, (_, k) => { const y = H - 110 + k * 20, w = 70 + k * 26; return `<rect x="${W / 2 - w / 2}" y="${y}" width="${w}" height="${6 + k}" rx="2" fill="#4a2e14" opacity=".9"/>`; }).join('');
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice">
  <defs><linearGradient id="gbWall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset=".35" stop-color="${mid}"/><stop offset="1" stop-color="${bot}"/></linearGradient>
  <linearGradient id="gbWood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4a2c12"/><stop offset=".4" stop-color="#8a5a2c"/><stop offset="1" stop-color="#3a2210"/></linearGradient>
  <linearGradient id="gbBeam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9a6a34"/><stop offset="1" stop-color="#4a2c12"/></linearGradient>
  <radialGradient id="gbGlow"><stop offset="0" stop-color="${fire ? '#ffb070' : '#ffd890'}" stop-opacity=".42"/><stop offset=".5" stop-color="${fire ? '#ff8040' : '#ffc870'}" stop-opacity=".1"/><stop offset="1" stop-color="#ffc870" stop-opacity="0"/></radialGradient>
  <radialGradient id="gbVig" cx=".5" cy=".45" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="${(.55 + t * .25).toFixed(2)}"/></radialGradient>
  <filter id="gbBlur"><feGaussianBlur stdDeviation="18"/></filter><filter id="gbSoft"><feGaussianBlur stdDeviation="1.5"/></filter></defs>
  <rect width="${W}" height="${H}" fill="url(#gbWall)"/>${strata}${specks}${lava}${pockets}
  <path d="M0 ${H - 120} Q${W / 2} ${H - 140} ${W} ${H - 120} L${W} ${H} L0 ${H}Z" fill="#000" opacity=".35"/>${sleepers}
  <path d="M${W / 2 - 30} ${H - 112} L${W / 2 - 110} ${H}" stroke="#9aa6b4" stroke-width="3" opacity=".7"/><path d="M${W / 2 + 30} ${H - 112} L${W / 2 + 110} ${H}" stroke="#9aa6b4" stroke-width="3" opacity=".7"/>
  ${post(-4)}${post(W - 22)}
  <rect x="-4" y="48" width="${W + 8}" height="22" fill="url(#gbBeam)" stroke="#2a1808" stroke-width="2"/>
  ${[30, W - 30].map(x => `<circle cx="${x}" cy="59" r="3.5" fill="#8a8478"/>`).join('')}
  ${lamp(110, 0)}${lamp(W - 110, 1)}
  ${gasHaze}${dust}
  <rect width="${W}" height="${H}" fill="url(#gbVig)"/></svg>`;
}

/* ================= stones:""")

# ---------------- mount it ----------------
rep("  showScreen('game'); sizeBoard(); renderHud(); renderBoosters();",
    "  $('#gameBg').innerHTML = gameBgSVG(Math.min(save.area, AREAS.length - 1), dl); { const svg = $('#gameBg svg'); if (svg && matchMedia('(prefers-reduced-motion: reduce)').matches) svg.pauseAnimations(); }\n  showScreen('game'); sizeBoard(); renderHud(); renderBoosters();")

# ---------------- the tray: timber rim and stone tiles ----------------
rep("""    x.fillStyle = '#5a3a1e'; x.beginPath(); x.roundRect(px - PAD * .7, py - PAD * .7, S + PAD * 1.4, S + PAD * 1.4, S * .22); x.fill(); }
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c)) {
    const px = PAD + c * S, py = PAD + r * S; x.fillStyle = (r + c) % 2 ? '#1f2c42' : '#24334c'; x.fillRect(px, py, S, S); }""",
"""    x.fillStyle = '#24160a'; x.beginPath(); x.roundRect(px - PAD * .7, py - PAD * .7 + 3, S + PAD * 1.4, S + PAD * 1.4, S * .22); x.fill(); }
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c)) {
    const px = PAD + c * S, py = PAD + r * S; x.fillStyle = trayWood(x, H); x.beginPath(); x.roundRect(px - PAD * .7, py - PAD * .7, S + PAD * 1.4, S + PAD * 1.4, S * .22); x.fill(); }
  for (let r = 0; r < R; r++) for (let c = 0; c < C; c++) if (playable(r, c)) x.drawImage(tileSpr(S * DPR, (r * 7 + c * 13) % 4), PAD + c * S, PAD + r * S, S, S);""")
rep("function drawBoard(t){", r"""// stone tiles for the tray: dark slate, a little worn, four variants so the grid does not look printed
const TILES = new Map();
function tileSpr(S, v){
  S = Math.round(S); const key = S + ':' + v; if (TILES.has(key)) return TILES.get(key);
  const c = document.createElement('canvas'); c.width = c.height = S; const x = c.getContext('2d'), rng = mulberry(v * 97 + 3);
  const g = x.createLinearGradient(0, 0, 0, S); g.addColorStop(0, v % 2 ? '#2a3448' : '#26304a'); g.addColorStop(1, v % 2 ? '#1c2434' : '#1a2132'); x.fillStyle = g; x.fillRect(0, 0, S, S);
  for (let k = 0; k < 40; k++) { x.fillStyle = `rgba(${rng() < .5 ? '0,0,0' : '255,255,255'},${(.03 + rng() * .05).toFixed(3)})`; x.beginPath(); x.arc(rng() * S, rng() * S, S * (.01 + rng() * .05), 0, 6.3); x.fill(); }
  x.strokeStyle = 'rgba(255,255,255,.06)'; x.lineWidth = Math.max(1, S * .02); x.strokeRect(x.lineWidth / 2, x.lineWidth / 2, S - x.lineWidth, S - x.lineWidth);
  x.strokeStyle = 'rgba(0,0,0,.35)'; x.beginPath(); x.moveTo(0, S - x.lineWidth / 2); x.lineTo(S, S - x.lineWidth / 2); x.stroke();
  TILES.set(key, c); return c;
}
let WOOD = null;
const trayWood = (x, H) => { if (!WOOD || WOOD.h !== H) { const g = x.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#9a6a34'); g.addColorStop(.5, '#7a4e24'); g.addColorStop(1, '#5a3618'); WOOD = {g, h:H}; } return WOOD.g; };
function drawBoard(t){""")
open(P, 'w', encoding='utf-8').write(s)
print('ok')
