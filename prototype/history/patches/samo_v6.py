"""Самоцветный рудник v6: the collection becomes a museum hall: lit display cases, 3D jewellery, an atlas of species with sets."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

def cut_between(a, b):
    """replace everything from a (inclusive) up to b (exclusive) with nothing, returning the removed text"""
    global s
    i = s.index(a); j = s.index(b, i)
    t = s[i:j]; s = s[:i] + s[j:]; return t

# ---------------- CSS ----------------
rep("#coll .wrap{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;gap:12px;padding-block:4px 12px}",
r"""#coll{background:radial-gradient(ellipse 120% 50% at 50% -8%, rgba(255,200,120,.16), transparent 60%), repeating-linear-gradient(90deg, rgba(0,0,0,0) 0 46px, rgba(0,0,0,.18) 46px 48px), linear-gradient(#24170e, #120c08 70%)}
#coll .wrap{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;gap:12px;padding-block:4px 12px}
.mstats{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.mstats div{background:rgba(0,0,0,.35);border:1px solid rgba(227,165,30,.3);border-radius:12px;padding:6px 4px;text-align:center}
.mstats b{display:block;font-family:var(--display);font-size:15px;color:#ffd77a}
.mstats small{font-size:10.5px;color:#c8b090;text-transform:uppercase;letter-spacing:.06em}
.ctabs.three{grid-template-columns:1fr 1fr 1fr}
.sortrow{display:flex;gap:6px}
.sortrow button{font-size:12px;border-radius:999px;padding:4px 10px;border:1px solid rgba(227,165,30,.3);color:#c8b090;background:rgba(0,0,0,.3)}
.sortrow button.on{background:#e3a51e;color:#2a1a04;border-color:#e3a51e}
.cases{display:grid;grid-template-columns:repeat(auto-fill,minmax(104px,1fr));gap:10px}
.cases.big{grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
.case{position:relative;display:flex;flex-direction:column;padding:6px 6px 0;border-radius:14px;overflow:hidden;text-align:center;
  background:linear-gradient(#0b0d12,#06070a);border:1px solid #4a3a22;box-shadow:inset 0 0 0 1px rgba(255,255,255,.04), 0 8px 18px rgba(0,0,0,.55)}
.case::after{content:"";position:absolute;inset:0;pointer-events:none;border-radius:14px;background:linear-gradient(115deg, rgba(255,255,255,.1) 0 18%, transparent 30% 100%)}
.case img{width:100%;aspect-ratio:1;border-radius:9px;background:#05070a;display:block}
.case .plate{margin:6px -6px 0;padding:5px 6px 6px;background:linear-gradient(#d8b060,#9a7024);color:#2a1a04;border-top:1px solid #f8e0a0}
.case .plate b{display:block;font-size:12px;line-height:1.15}
.case .plate small{font-size:10.5px;color:#4a3008;font-weight:800}
.case .dot{position:absolute;top:10px;left:10px;width:9px;height:9px;border-radius:50%;background:var(--rc);box-shadow:0 0 8px var(--rc);z-index:1}
.case .cutm{position:absolute;top:7px;right:9px;color:#ffe8a8;font-size:13px;z-index:1;text-shadow:0 0 6px #ffb020}
.case.legend{border-color:#e4ae39;animation:legend 2.4s ease-in-out infinite}
@keyframes legend{50%{box-shadow:inset 0 0 0 1px rgba(255,255,255,.04), 0 0 22px rgba(228,174,57,.55)}}
.case .perk{color:#1f5a20}
.atlas{display:grid;grid-template-columns:repeat(auto-fill,minmax(72px,1fr));gap:8px}
.atlas div{display:flex;flex-direction:column;align-items:center;gap:3px;text-align:center;font-size:10.5px;line-height:1.15;color:#e8d8bc}
.atlas img, .atlas i{width:100%;aspect-ratio:1;border-radius:50%;border:2px solid #6a5028;background:#05070a;display:block}
.atlas i{display:grid;place-items:center;font-style:normal;font-family:var(--display);font-size:22px;color:#4a3a28;background:radial-gradient(circle at 50% 40%, #1a1410, #08060a)}
.atlas .no{color:#7a6a58}
.atlas small{color:#8a7a62;font-size:9.5px}
.prog{height:6px;border-radius:3px;background:rgba(0,0,0,.4);overflow:hidden}
.prog i{display:block;height:100%;background:linear-gradient(90deg,#e3a51e,#ffe08a)}
.wshop{display:grid;grid-template-columns:72px 1fr;gap:10px;align-items:center;text-align:left;background:rgba(0,0,0,.35);border:1px solid #4a3a22;border-radius:14px;padding:8px 10px}
.wshop img{width:72px;height:72px;border-radius:10px;background:#05070a}
.wshop b{font-family:var(--display);font-size:14px;color:#ffe8c0}
.wshop p{margin:2px 0 0;font-size:12px;color:#c8b090}
.wshop .perk{color:#7ad87a}
.wshop .go{margin-top:6px;border-radius:12px;padding:7px 12px;background:linear-gradient(#ffd77a,#e3a51e);color:#3a2200;font-family:var(--display);font-size:12px;box-shadow:0 3px 0 #7a4c08}
.wshop .go:disabled{background:#2a2a2a;color:#7a6a58;box-shadow:none}
#coll .set{background:rgba(0,0,0,.35);border-color:#4a3a22}""")

# ---------------- seen species ----------------
rep("depth:[0, 0, 0], depthSel:[0, 0, 0], jewels:[], coll:[], sets:[],", "depth:[0, 0, 0], depthSel:[0, 0, 0], jewels:[], seen:[], coll:[], sets:[],")
rep("  SFX.reveal(s.tier); buzz(s.tier >= 3 ? [60, 40, 140] : 40);", "  SFX.reveal(s.tier); buzz(s.tier >= 3 ? [60, 40, 140] : 40); if (!save.seen.includes(s.sid)) { save.seen.push(s.sid); persist(); }")

# ---------------- the museum ----------------
old_coll = cut_between("let collTab = 'spc';\nfunction renderColl(){", "\n$('#playBtn').onclick")
old_jw = cut_between("const collTabs = () =>", "function cutPanel(s){")

new = r"""let collTab = 'spc', collSort = 'value';
// thumbnails are rendered one per tick so the screen never stalls
let THQ = [];
const thumb = (o, cls = '') => { THQ.push(o); return `<img data-th="${THQ.length - 1}" class="${cls}" alt="" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">`; };
function fillThumbs(){ const el = document.querySelector('#collWrap img[data-th]:not([data-done])'); if (!el) return; el.dataset.done = 1; const o = THQ[+el.dataset.th]; if (o) { const u = specThumb(o); if (u) el.src = u; } setTimeout(fillThumbs, 16); }
const specO = s => ({seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, legend:s.legend, cut:s.cut});
const collTabs = () => `<div class="ctabs three">${[['spc', `Витрина · ${save.coll.length}`], ['jw', `Украшения · ${save.jewels.length}`], ['atlas', 'Атлас']].map(([id, n]) => `<button type="button" data-ctab="${id}" class="${collTab === id ? 'on' : ''}">${n}</button>`).join('')}</div>`;
function bindTabs(){ $('#collWrap').querySelectorAll('[data-ctab]').forEach(b => b.onclick = () => { collTab = b.dataset.ctab; renderColl(); }); }
function museumHead(){
  for (const s of save.coll) if (!save.seen.includes(s.sid)) save.seen.push(s.sid);
  const worth = save.coll.reduce((a, s) => a + s.value, 0) + save.jewels.reduce((a, j) => a + j.value, 0);
  return `<h2>Минералогический музей</h2><div class="mstats"><div><b>${save.seen.length}/${Object.keys(SP).length}</b><small>видов</small></div><div><b>${fmt(worth)}</b><small>ценность</small></div><div><b>${save.sets.length}/${SETS.length}</b><small>наборов</small></div></div>${collTabs()}`;
}
function renderColl(){
  showScreen('coll'); $('#pills2').innerHTML = pills(); THQ = [];
  if (collTab === 'jw') renderJewels(); else if (collTab === 'atlas') renderAtlas(); else renderCases();
  bindTabs(); setTimeout(fillThumbs, 30);
}
function renderCases(){
  const sorters = {value:(a, b) => b.value - a.value, rare:(a, b) => b.tier - a.tier || b.value - a.value, new:(a, b) => b.id - a.id};
  const list = save.coll.slice().sort(sorters[collSort]);
  $('#collWrap').innerHTML = `${museumHead()}
    ${list.length ? `<div class="sortrow">${[['value', 'Ценные'], ['rare', 'Редкие'], ['new', 'Новые']].map(([id, n]) => `<button type="button" data-sort="${id}" class="${collSort === id ? 'on' : ''}">${n}</button>`).join('')}</div>
    <div class="cases">${list.map(s => `<button type="button" class="case${s.legend ? ' legend' : ''}" style="--rc:${RC[s.tier]}" data-spc="${s.id}"><span class="dot"></span>${cutOK(s) ? '<span class="cutm">✦</span>' : ''}${thumb(specO(s))}
      <div class="plate"><b>${SP[s.sid].n}</b><small>${fmtW(s.g)} · ${fmt(s.value)}</small></div></button>`).join('')}</div>`
    : '<p class="h3" style="text-transform:none;letter-spacing:0">Витрины пока пусты. Камни выпадают на уровнях-жилах.</p>'}`;
  $('#collWrap').querySelectorAll('[data-sort]').forEach(b => b.onclick = () => { collSort = b.dataset.sort; renderColl(); });
  $('#collWrap').querySelectorAll('[data-spc]').forEach(b => b.onclick = () => { const s = save.coll.find(x => x.id === +b.dataset.spc); if (!s) return;
    openOv(`<div class="reveal"><div class="spec-host" id="specHost"></div></div><div class="label"><div class="rar" style="color:${RC[s.tier]}">${s.legend ? 'легендарная находка' : RAR[s.tier]}</div><h3>${SP[s.sid].n}</h3><div class="row"><span>Вес</span><b>${fmtW(s.g)}</b></div><div class="row"><span>Качество</span><b>${GR[s.gi].n}</b></div>${s.traits.length ? `<div class="tr">${s.traits.map(id => `<span>${TR[id].n}</span>`).join('')}</div>` : ''}</div>
      ${s.cut ? `<p>Огранка: ${CUTN[s.cut]}</p>` : '<button class="btn" style="background:linear-gradient(#d2b0ff,#8a4ff0);color:#1a0b33;box-shadow:0 5px 0 #3e1f78" id="cutC">Огранить<small>рискнуть ради цены</small></button>'}
      <button class="btn" id="sellC">Продать · ${mon(s.value)}</button><button class="btn ghost" id="closeC">Закрыть</button>`, () => {
      specMount($('#specHost'), specO(s));
      const cb = $('#cutC'); if (cb) cb.onclick = () => cutPanel(s);
      $('#closeC').onclick = () => { specUnmount(); closeOv(); };
      $('#sellC').onclick = () => { save.coll = save.coll.filter(x => x !== s); save.coins += Math.round(s.value * coinMul()); persist(); SFX.coin(); specUnmount(); closeOv(); renderColl(); };
    }); });
}
// every species there is: found ones show your best piece, the rest are a mystery with a hint where to dig
function renderAtlas(){
  const ids = Object.keys(SP), best = {}; for (const s of save.coll) if (!best[s.sid] || s.value > best[s.sid].value) best[s.sid] = s;
  const where = id => { const a = AREAS.find(A => A.pool[id]); return a ? a.n : ''; };
  const got = new Set(save.coll.map(s => s.sid));
  ids.sort((a, b) => SP[a].r - SP[b].r || SP[a].v - SP[b].v);
  $('#collWrap').innerHTML = `${museumHead()}
    <div class="h3">Виды · найдено ${save.seen.length} из ${ids.length}</div>
    <div class="atlas">${ids.map(id => { const seen = save.seen.includes(id), b = best[id];
      return `<div>${b ? thumb(specO(b)) : seen ? `<i style="color:${hexC(SP[id].c)}">◆</i>` : '<i>?</i>'}<span class="${seen ? '' : 'no'}">${seen ? SP[id].n : '???'}</span>${seen ? '' : `<small>${where(id)}</small>`}</div>`; }).join('')}</div>
    <div class="h3">Наборы</div>
    ${SETS.map(st => { const n = st.need.filter(x => got.has(x)).length, full = n === st.need.length, claimed = save.sets.includes(st.id);
      return `<div class="set${full ? ' full' : ''}"><div class="set-h"><b>${st.n}</b><span class="h3">${n}/${st.need.length}</span></div><div class="prog"><i style="width:${n / st.need.length * 100}%"></i></div><div class="chips">${st.need.map(x => `<span class="${got.has(x) ? 'on' : ''}">${SP[x].n}</span>`).join('')}</div>
        <div class="h3" style="text-transform:none;letter-spacing:0">Награда: ${st.reward.coins} монет${st.reward.pick ? `, кирка ×${st.reward.pick}` : ''}${st.reward.dyn ? `, динамит ×${st.reward.dyn}` : ''}</div>
        ${claimed ? '<b style="color:var(--good)">✓ Получено</b>' : full ? `<button class="btn" data-set="${st.id}">Забрать награду</button>` : ''}</div>`; }).join('')}`;
  $('#collWrap').querySelectorAll('[data-set]').forEach(b => b.onclick = () => { const st = SETS.find(x => x.id === b.dataset.set); if (save.sets.includes(st.id)) return; save.sets.push(st.id); save.coins += st.reward.coins; save.boost.pick += st.reward.pick || 0; save.boost.dyn += st.reward.dyn || 0; persist(); SFX.coin(); renderColl(); toast(`${st.n}: награда получена`); });
}
const jewelO = j => ({seed:j.id, jewel:{rid:j.rid, cols:j.cols}});
function renderJewels(){
  const cut = save.coll.filter(cutOK).length;
  $('#collWrap').innerHTML = `${museumHead()}
    ${save.jewels.length ? `<div class="cases big">${save.jewels.map(j => { const R0 = JEWELS.find(x => x.id === j.rid);
      return `<button type="button" class="case" data-jw="${j.id}">${thumb(jewelO(j))}<div class="plate"><b>${R0.n}</b><small>${fmt(j.value)} монет${R0.perk ? ` · <span class="perk">${R0.perk}</span>` : ''}</small></div></button>`; }).join('')}</div>`
      : '<p class="h3" style="text-transform:none;letter-spacing:0">Украшений пока нет. Соберите первое в мастерской.</p>'}
    <div class="h3">Мастерская · огранённых камней: ${cut}</div>
    <p class="h3" style="text-transform:none;letter-spacing:0;margin-top:-6px">Мастер берёт самые дешёвые подходящие камни, ценные остаются в витрине.</p>
    ${JEWELS.map(j => { const st = pickFor(j), val = st ? Math.round(st.reduce((a, x) => a + x.value, 0) * j.m) : 0, cols = st ? st.map(x => hexC(SP[x.sid].c)) : ['#6a7080'];
      return `<div class="wshop">${thumb({seed:7, jewel:{rid:j.id, cols}})}<div><b>${j.n}</b><p>${j.d}</p>${j.perk ? `<p class="perk">${j.perk}</p>` : ''}${st ? `<p>Из: ${st.map(x => SP[x.sid].n).join(', ')} → ${mon(val)}</p>` : ''}
        <button class="go" data-craft="${j.id}" type="button" ${st ? '' : 'disabled'}>${st ? 'Собрать' : 'Нет камней'}</button></div></div>`; }).join('')}`;
  $('#collWrap').querySelectorAll('[data-craft]').forEach(b => b.onclick = () => { const j = JEWELS.find(x => x.id === b.dataset.craft), st = pickFor(j); if (!st) return;
    const ids = new Set(st.map(x => x.id)); save.coll = save.coll.filter(x => !ids.has(x.id));
    const value = Math.round(st.reduce((a, x) => a + x.value, 0) * j.m), jw = {id:++save.uid, rid:j.id, cols:st.map(x => hexC(SP[x.sid].c)), names:st.map(x => SP[x.sid].n), value};
    save.jewels.push(jw); persist(); SFX.build(); confetti(); renderColl(); showJewel(jw, true); });
  $('#collWrap').querySelectorAll('[data-jw]').forEach(b => b.onclick = () => { const j = save.jewels.find(x => x.id === +b.dataset.jw); if (j) showJewel(j); });
}
// a jewel in the hand: turn it in 3D, read what it is made of, sell it if you must
function showJewel(j, fresh = false){
  const R0 = JEWELS.find(x => x.id === j.rid);
  openOv(`<div class="reveal"><div class="spec-host" id="specHost"></div></div><div class="label"><div class="rar" style="color:#e4ae39">${fresh ? 'новое украшение' : 'украшение'}</div><h3>${R0.n}</h3>
    <div class="row"><span>Камни</span><b style="text-align:right">${j.names.join(', ')}</b></div><div class="row"><span>Стоимость</span><b>${mon(j.value)}</b></div>${R0.perk ? `<div class="tr"><span>${R0.perk}</span></div>` : ''}</div>
    <button class="btn" id="sellJ">Продать · ${mon(Math.round(j.value * coinMul()))}</button><button class="btn ghost" id="closeJ">Закрыть</button>`, () => {
    specMount($('#specHost'), jewelO(j));
    $('#closeJ').onclick = () => { specUnmount(); closeOv(); };
    $('#sellJ').onclick = e => { const b = e.currentTarget; if (b.dataset.armed !== '1') { b.dataset.armed = '1'; b.innerHTML = `Точно продать?<small>${R0.perk ? 'бонус украшения пропадёт' : 'его не вернуть'}</small>`; return; }
      save.jewels = save.jewels.filter(x => x !== j); save.coins += Math.round(j.value * coinMul()); persist(); SFX.coin(); specUnmount(); closeOv(); renderColl(); };
  });
}
"""
i = s.index("function cutPanel(s){")
s = s[:i] + new + s[i:]
open(P, 'w', encoding='utf-8').write(s)
print('ok')
