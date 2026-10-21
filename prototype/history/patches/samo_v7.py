"""Самоцветный рудник v7: the equipment screen becomes a depot: a 3D machine on a stage, a strip of machines below."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS ----------------
rep("#coll{background:", r"""#tech{background:radial-gradient(ellipse 120% 45% at 50% 0%, rgba(242,176,30,.14), transparent 60%), repeating-linear-gradient(0deg, rgba(255,255,255,.025) 0 1px, transparent 1px 34px), repeating-linear-gradient(90deg, rgba(255,255,255,.025) 0 1px, transparent 1px 34px), linear-gradient(#1a1e24, #0c0e12 75%)}
#tech .wrap{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;gap:10px;padding-block:4px 12px}
#tech h2{font-family:var(--display);font-size:20px;margin:6px 0 0}
.tsub2{color:#c8b090;font-size:12.5px;margin-top:-6px}
.stage{position:relative;width:min(100%, 40vh);aspect-ratio:1;margin:0 auto;border-radius:20px;overflow:hidden;border:2px solid #3a3a30;box-shadow:0 14px 30px rgba(0,0,0,.6)}
.stage .hazard{position:absolute;left:0;right:0;bottom:0;height:12px;z-index:2;background:repeating-linear-gradient(-45deg, #f2b01e 0 12px, #1a1a1a 12px 24px);opacity:.9}
.stage .owned{position:absolute;top:10px;left:10px;z-index:2;font-size:12px;background:#1f6a2a;color:#d8ffd8;border-radius:999px;padding:3px 10px}
.tinfo{background:rgba(0,0,0,.4);border:1px solid #3a3a30;border-radius:16px;padding:12px;display:flex;flex-direction:column;gap:6px}
.tinfo .tn{display:flex;justify-content:space-between;align-items:baseline;gap:8px}
.tinfo .tn b{font-family:var(--display);font-size:17px;color:#ffe08a}
.tinfo .tn span{color:#c8b090;font-size:12.5px}
.tinfo p{margin:0;font-size:13px;color:#d8d0c0}
.tinfo .fx{display:flex;flex-wrap:wrap;gap:5px}
.tinfo .fx span{font-size:11.5px;border-radius:999px;padding:2px 9px;border:1px solid #4a4a3a;color:#e8d8bc}
.tinfo .fx span.bad{border-color:#7a3a2a;color:#ffb0a0}
.tinfo .fx span.good{border-color:#3a6a3a;color:#b0ffb0}
.pips{display:flex;gap:5px}.pips i{width:22px;height:8px;border-radius:4px;background:#2a2a24;border:1px solid #4a4a3a}.pips i.on{background:linear-gradient(#ffe08a,#e3a51e);border-color:#e3a51e}
.tstrip{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px;scroll-snap-type:x mandatory}
.tcard{flex:none;width:96px;scroll-snap-align:start;display:flex;flex-direction:column;align-items:center;gap:3px;padding:5px 5px 7px;border-radius:14px;background:rgba(0,0,0,.45);border:2px solid #2e2e28;text-align:center}
.tcard img{width:84px;height:84px;border-radius:10px;background:#05070a}
.tcard b{font-size:11px;line-height:1.15;min-height:2.3em;display:grid;place-items:center}
.tcard small{font-size:10.5px;font-weight:800;border-radius:999px;padding:1px 8px}
.tcard small.own{background:#1f5a24;color:#c8ffc8}.tcard small.buy{background:#e3a51e;color:#2a1a04}.tcard small.lock{background:#2a2a24;color:#8a8270}
.tcard.on{border-color:#e3a51e;box-shadow:0 0 0 3px rgba(227,165,30,.25)}
.tcard.lockd img{filter:grayscale(.8) brightness(.6)}
#coll{background:""")

# ---------------- markup and navigation ----------------
rep("<!-- collection -->", """<!-- equipment depot -->
<section class="screen" id="tech" hidden>
  <div class="bar"><div class="pills" id="pills3"></div><span></span></div>
  <div class="wrap" id="techWrap"></div>
  <div class="nav"><button type="button" id="tHome">Рудник</button><button class="on" type="button">Техника</button><button type="button" id="tColl">Коллекция</button></div>
</section>

<!-- collection -->""")
rep("function showScreen(id){ for (const s of ['home', 'game', 'coll']) $('#' + s).hidden = s !== id; }",
    "function showScreen(id){ if (id !== 'tech' && !$('#tech').hidden) specUnmount(); for (const s of ['home', 'game', 'coll', 'tech']) $('#' + s).hidden = s !== id; }")
rep("$('#toTech2').onclick = () => { goHome(); openTech(); };", "$('#toTech2').onclick = () => openTech();\n$('#tHome').onclick = goHome;\n$('#tColl').onclick = renderColl;")

# thumbnails: fill within the screen that asked for them
rep("function fillThumbs(){ const el = document.querySelector('#collWrap img[data-th]:not([data-done])'); if (!el) return; el.dataset.done = 1; const o = THQ[+el.dataset.th]; if (o) { const u = specThumb(o); if (u) el.src = u; } setTimeout(fillThumbs, 16); }",
    "function fillThumbs(scope = '#collWrap'){ const el = document.querySelector(scope + ' img[data-th]:not([data-done])'); if (!el) return; el.dataset.done = 1; const o = THQ[+el.dataset.th]; if (o) { const u = specThumb(o); if (u) el.src = u; } setTimeout(() => fillThumbs(scope), 16); }")

# ---------------- the depot ----------------
i = s.index("function openTech(){"); j = s.index("function openTasks(){")
s = s[:i] + r"""// the depot: depth machines for this mine, kit for every mine; one machine turns on the stage
let techTab = 'depth', techSel = null;
const DMACH = ['', 'hammer', 'rig', 'tbm', 'deep'];
function openTech(){ techTab = 'depth'; techSel = null; renderTech(); }
function techItems(ai){
  const d = save.depth[ai] || 0;
  if (techTab === 'depth') return DEPTHS.slice(1).map((t, i) => { const k = i + 1, cost = depthCost(ai, k);
    return {key:'d' + k, machine:DMACH[k], n:t.tool, sub:`${DEPTHS[k - 1].m} → ${t.m} м`, own:d >= k, next:k === d + 1, cost,
      fx:[...DSHORT.slice(1, k + 1).map(x => ['bad', x]), ['good', `монеты ×${String(depthPay(k)).replace('.', ',')}`], ['good', 'камни дороже']],
      desc:d >= k ? `Открывает выработки до ${t.m} м.` : `Пробьёт породу до ${t.m} м. На новой глубине: ${DMODS[k]}.`,
      buy:() => { save.depth[ai] = k; save.depthSel[ai] = k; return `${t.tool}: открыта глубина ${t.m} м`; }}; });
  return EQUIP.map(e => { const lv = save.eq[e.id], max = e.cost.length;
    return {key:e.id, machine:e.id, n:e.n, sub:`уровень ${lv}/${max}`, own:lv >= max, next:lv < max, cost:e.cost[lv], lv, max, fx:[['good', e.d]],
      desc:lv ? `Работает на всех рудниках. Уровень ${lv} из ${max}.` : 'Работает на всех рудниках сразу.',
      buy:() => { save.eq[e.id]++; return `${e.n}: уровень ${save.eq[e.id]}`; }}; });
}
function renderTech(){
  showScreen('tech'); $('#pills3').innerHTML = pills(); THQ = [];
  const ai = Math.min(save.area, AREAS.length - 1), A = AREAS[ai], items = techItems(ai);
  let it = items.find(x => x.key === techSel) || items.find(x => x.next) || items[items.length - 1]; techSel = it.key;
  const prev = items[items.indexOf(it) - 1];
  const btn = it.own ? `<button class="btn" disabled>${techTab === 'depth' ? '✓ В работе' : '✓ Максимум'}</button>`
    : !it.next ? `<button class="btn" disabled>Сначала: ${prev ? prev.n.toLowerCase() : ''}</button>`
    : save.coins >= it.cost ? `<button class="btn" id="tBuy">${it.lv ? 'Улучшить' : 'Купить'} · ${mon(it.cost)}</button>`
    : `<button class="btn" disabled>Нужно ещё ${mon(it.cost - save.coins)}</button>`;
  $('#techWrap').innerHTML = `<h2>Депо</h2><div class="tsub2">${techTab === 'depth' ? `${A.n}: копаете до ${DEPTHS[save.depth[ai] || 0].m} м` : 'Снаряжение работает во всех рудниках'} · у вас ${mon(save.coins)}</div>
    <div class="ctabs"><button type="button" data-ttab="depth" class="${techTab === 'depth' ? 'on' : ''}">Проходка · ${save.depth[ai] || 0}/4</button><button type="button" data-ttab="eq" class="${techTab === 'eq' ? 'on' : ''}">Снаряжение</button></div>
    <div class="stage"><div class="spec-host" id="techHost"></div>${it.own ? '<span class="owned">✓ в депо</span>' : ''}<div class="hazard"></div></div>
    <div class="tinfo"><div class="tn"><b>${it.n}</b><span>${it.sub}</span></div>${it.max ? `<div class="pips">${Array.from({length:it.max}, (_, q) => `<i class="${q < it.lv ? 'on' : ''}"></i>`).join('')}</div>` : ''}
      <p>${it.desc}</p><div class="fx">${it.fx.map(([c, t]) => `<span class="${c}">${t}</span>`).join('')}</div>${btn}</div>
    <div class="tstrip">${items.map(x => `<button type="button" class="tcard${x.key === it.key ? ' on' : ''}${!x.own && !x.next ? ' lockd' : ''}" data-tk="${x.key}">${thumb({machine:x.machine})}<b>${x.n}</b>
      <small class="${x.own ? 'own' : x.next ? 'buy' : 'lock'}">${x.own ? '✓' : x.next ? fmt(x.cost) : '🔒'}</small></button>`).join('')}</div>`;
  specMount($('#techHost'), {machine:it.machine});
  $('#techWrap').querySelectorAll('[data-ttab]').forEach(b => b.onclick = () => { techTab = b.dataset.ttab; techSel = null; renderTech(); });
  $('#techWrap').querySelectorAll('[data-tk]').forEach(b => b.onclick = () => { techSel = b.dataset.tk; renderTech(); });
  const bb = $('#tBuy'); if (bb) bb.onclick = () => { if (save.coins < it.cost) return; save.coins -= it.cost; const msg = it.buy(); persist(); SFX.build(); confetti(); renderTech(); toast(msg); };
  setTimeout(() => fillThumbs('#techWrap'), 30);
}
""" + s[j:]
open(P, 'w', encoding='utf-8').write(s)
print('ok')
