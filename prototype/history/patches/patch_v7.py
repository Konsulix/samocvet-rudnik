"""v7 of «Забой»: long-term goals — orders & reputation, museum sets, endless tiers, descent modifiers, legendary finds, saner economy."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- CSS ----------------
rep(".fxc{position:fixed;", r""".tierrow{display:flex;align-items:center;gap:8px;flex-wrap:wrap;background:rgba(0,0,0,.3);border-radius:10px;padding:5px 8px}
.tierrow button{width:30px;height:30px;border-radius:8px;border:1px solid rgba(255,255,255,.18);background:rgba(255,255,255,.06);font-size:18px;line-height:1;font-weight:700}
.tierrow button:disabled{opacity:.25}
.tierrow b{font-family:var(--game);font-weight:400;font-size:16px;color:var(--hc)}
.tierrow small{flex-basis:100%;font-size:11.5px;color:var(--muted)}
.modchip{width:100%;max-width:440px;background:rgba(8,16,20,.84);border:1px dashed rgba(227,168,87,.45);border-radius:14px;padding:8px 12px;font-size:12.5px;color:#cfd6d4}
.modchip b{color:var(--lamp);font-weight:700}
.modchip .rumor{display:block;margin-top:4px;color:#e4ae39;font-weight:600}
.orders{display:flex;flex-direction:column;gap:8px}
.order{background:linear-gradient(160deg, rgba(30,50,60,.95), rgba(12,24,30,.97));border:1px solid #3c5c6a;border-radius:14px;padding:10px 12px;display:flex;flex-direction:column;gap:5px}
.order.ok{border-color:var(--anom);box-shadow:0 0 14px rgba(127,224,200,.2)}
.order-h{display:flex;justify-content:space-between;gap:8px;align-items:baseline}
.order-h b{font-size:14.5px}
.order-h span{font-family:var(--mono);font-size:12.5px;color:var(--lamp);white-space:nowrap}
.order p{margin:0;font-size:12px;color:var(--muted)}
.order .two{grid-template-columns:1fr auto}
.order .ghost{padding:7px 10px;font-size:12.5px}
.ordbtn{width:100%;max-width:420px;background:linear-gradient(#9ff0d8, #3fb895);color:#06231b;box-shadow:inset 0 1px 0 rgba(255,255,255,.5), 0 4px 0 #14523f}
.sets{display:flex;flex-direction:column;gap:8px}
.set{background:linear-gradient(160deg, rgba(30,50,60,.94), rgba(12,24,30,.96));border:1px solid #3c5c6a;border-radius:14px;padding:10px 12px;display:flex;flex-direction:column;gap:6px}
.set.done{border-color:#e4ae39;box-shadow:0 0 16px rgba(228,174,57,.25)}
.set-h{display:flex;justify-content:space-between;gap:8px;align-items:baseline}
.set-h b{font-family:var(--game);font-weight:400;font-size:16px;color:#f6cd84}
.set-h span{font-size:12px;color:var(--muted);font-family:var(--mono)}
.set-i{display:flex;gap:5px;flex-wrap:wrap}
.set-i span{width:34px;height:34px;border-radius:8px;background:rgba(0,0,0,.35);border:1px solid rgba(255,255,255,.08);display:grid;place-items:center;font-size:12px;font-weight:700;color:var(--muted)}
.set-i span.on{border-color:#e4ae39;color:#e4ae39}
.set-i img{width:28px;height:28px;object-fit:contain}
.set-i span:not(.on) img{filter:brightness(0) opacity(.45)!important}
.set p{margin:0;font-size:12px;color:#cfd6d4}
.set .btn{padding:8px 12px}
.fr.legend{color:#e4ae39!important;text-shadow:0 0 10px rgba(228,174,57,.7)}
.fxc{position:fixed;""")

# ---------------- data ----------------
rep("const LAMP_T = [110, 140, 170, 200, 240]", r"""// what makes each descent different
const MODS = {
  calm:{n:'Тихий спуск', d:'Ничего необычного.', w:3},
  gas:{n:'Газовая неделя', d:'Газа вдвое больше, но и самородков тоже.', w:1},
  dark:{n:'Обесточено', d:'Старые фонари не горят. Зато находки богаче.', w:1},
  vein:{n:'Богатая жила', d:'Жилы толще: руды в полтора раза больше.', w:1},
  restless:{n:'Беспокойные', d:'Ползунов больше, и они далеко бродят.', w:1},
  quake:{n:'Подвижки', d:'Обвалы и прорывы вдвое чаще.', w:1},
};
const DEPTH0 = {adit:0, flood:150, fire:300}, TIER_M = 150;
// museum sets: long goals with rewards and permanent perks
const SETS = [
  {id:'quartz', n:'Кварцевая линия', need:['quartz', 'amethyst', 'calcite', 'gypsum'], reward:{money:400, rep:2}, perk:null},
  {id:'copper', n:'Медная зелень', need:['malachite', 'azurite', 'fluorite'], reward:{money:600, rep:3}, perk:null},
  {id:'ural', n:'Уральские самоцветы', need:['amethyst', 'beryl', 'aquamarine', 'garnet', 'malachite'], reward:{money:1500, rep:5}, perk:{lamp:10}, pd:'+10 с фонаря навсегда'},
  {id:'heavy', n:'Тяжеловесы', heavy:3, reward:{money:1000, rep:4}, perk:null, pd:'3 находки от 1 кг'},
  {id:'cut', n:'Ювелирная витрина', cut:4, reward:{money:1200, rep:4}, perk:null, pd:'4 удачно огранённых камня'},
  {id:'fire', n:'Огненное сердце', need:['ruby', 'sapphire', 'opal', 'garnet'], reward:{money:3000, rep:8}, perk:{hp:1}, pd:'+1 здоровье навсегда'},
  {id:'crown', n:'Корона коллекции', need:['emerald', 'ruby', 'sapphire', 'diamond'], reward:{money:8000, rep:20}, perk:{val:.15}, pd:'находки дороже на 15%'},
];
const LAMP_T = [110, 140, 170, 200, 240]""")
rep("finds:[], coll:[], rec:{}, crew:['miner'], hero:'miner', uid:0,",
    "finds:[], coll:[], rec:{}, crew:['miner'], hero:'miner', orders:[], rep:0, tiers:{}, tierSel:{}, mod:'calm', rumor:false, sets:[], perks:{lamp:0, hp:0, val:0}, uid:0,")
rep("rec:Object.assign(b.rec, s.rec)}); }", "rec:Object.assign(b.rec, s.rec), perks:Object.assign(b.perks, s.perks)}); }")

# ---------------- generation: tiers, modifiers, legend ----------------
rep("function genCave(b){", "function genCave(b, opt = {}){\n  const tier = opt.tier || 0, mod = opt.mod || 'calm', DB = tier * .1 + (mod === 'dark' ? .12 : 0);")
rep("lv.veins.push({i:w.i, x:w.x, y:w.y, face:w.face, type, left:ri(2, 4), mesh:null}); }", "lv.veins.push({i:w.i, x:w.x, y:w.y, face:w.face, type, left:mod === 'vein' ? ri(3, 6) : ri(2, 4), mesh:null}); }")
rep("w => .2 + Math.pow(lv.dist[w.face] / lv.maxD, 1.4) * 3); if (!w) break; const d = lv.dist[w.face] / lv.maxD;",
    "w => .2 + Math.pow(lv.dist[w.face] / lv.maxD, 1.4) * 3); if (!w) break; const d = Math.min(1, lv.dist[w.face] / lv.maxD + DB);")
rep("['nugget', b.pool.gold ? 10 : 0]]);", "['nugget', b.pool.gold ? (mod === 'gas' ? 24 : 10) : 0]]);")
rep("const floorDep = (i, boost) => { const d = Math.min(1, lv.dist[i] / lv.maxD + boost);", "const floorDep = (i, boost) => { const d = Math.min(1, lv.dist[i] / lv.maxD + boost + DB);")
rep("lv.lamps.push({i:c, wall, on:Math.random() < .72});", "lv.lamps.push({i:c, wall, on:mod !== 'dark' && Math.random() < .72});")
rep("for (let k = 0; k < b.gas && gasCells.length; k++)", "for (let k = 0; k < b.gas * (mod === 'gas' ? 2 : 1) && gasCells.length; k++)")
rep("k < b.crawlers && lairs.length; k++)", "k < b.crawlers + tier + (mod === 'restless' ? 2 : 0) && lairs.length; k++)")
rep("k < b.golems && rich[k]; k++)", "k < b.golems + Math.floor(tier / 2) && rich[k]; k++)")
rep("  // crawlers make their lairs in the dark", r"""  // a rumour come true: a legendary cluster in the deepest dark, guarded by an elder golem
  if (opt.rumor) {
    const c = floors.filter(i => openAt(i) && lv.dist[i] > lv.maxD * .5 && lv.lumAt(i) < .03 && free(i));
    if (c.length) { const i = c[ri(0, c.length - 1)]; floorDep(i, 1); const dep = lv.deps[lv.deps.length - 1];
      const top = Math.max(...Object.keys(b.pool).filter(s => s !== 'gold').map(s => SP[s].r)), best = Object.keys(b.pool).filter(s => s !== 'gold' && SP[s].r === top);
      Object.assign(dep, {kind:'druse', sid:best[ri(0, best.length - 1)], d:1, legend:true, dark:1});
      const gm = newMon('golem', dep.face); gm.hp = 16; gm.elite = true; lv.mons.push(gm); lv.legend = dep; } }
  // crawlers make their lairs in the dark""")

# ---------------- scene: elder golem, legendary cluster ----------------
rep("  const g = new THREE.Group(), size = mo.type === 'golem' ? 1.9 : 1.35;", "  const g = new THREE.Group(), size = mo.elite ? 2.5 : mo.type === 'golem' ? 1.9 : 1.35;")
rep("  const eyes = new THREE.Group(), col = mo.type === 'golem' ? 0x8fd8ff : 0xe8f0a0;", "  const eyes = new THREE.Group(), col = mo.elite ? 0xff4a30 : mo.type === 'golem' ? 0x8fd8ff : 0xe8f0a0;")
rep("    g.userData.glint = gl; g.userData.halo = halo; g.userData.phase = Math.random() * 6; dep.mesh = g; scene.add(g);",
    "    if (dep.legend) { g.scale.setScalar(1.8); halo.material.color.set(0xe4ae39); gl.material.color.set(0xe4ae39); }\n"
    "    g.userData.glint = gl; g.userData.halo = halo; g.userData.phase = Math.random() * 6; dep.mesh = g; scene.add(g);")

# ---------------- run: tier, modifier, depth ----------------
rep("  L = genCave(b); buildScene();", "  const tier = Math.min(save.tierSel[bid] || 0, save.tiers[bid] || 0);\n  L = genCave(b, {tier, mod:save.mod, rumor:save.rumor}); buildScene();")
rep("lampT = Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1)), hpX = save.hero === 'miner' ? 2 : 0;",
    "lampT = Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1)) + save.perks.lamp, hpX = (save.hero === 'miner' ? 2 : 0) + save.perks.hp;")
rep("hero:save.hero, abCd:0,", "tier, mod:save.mod, drain:b.drain * (1 + tier * .1), evK:Math.max(.4, (save.mod === 'quake' ? .5 : 1) * (1 - tier * .06)), depthBase:DEPTH0[b.id] + tier * TIER_M, hero:save.hero, abCd:0,")
rep("  toast('Спуск', `${b.place}. Фонарь горит ${S.lampMax} с — вернитесь к лифту до того, как он погаснет.`, '', 'var(--lamp)');",
    "  toast(tier ? `Спуск · ярус ${tier + 1}` : 'Спуск', `${b.place}. Фонарь горит ${S.lampMax} с — вернитесь к лифту до того, как он погаснет.`, '', 'var(--lamp)');\n"
    "  if (S.mod !== 'calm') toast(MODS[S.mod].n, MODS[S.mod].d, '', 'var(--lamp)');\n"
    "  if (L.legend) toast('Слух подтвердился', 'Где-то в глухой тьме — легендарная друза. Её стережёт старший голем.', '', '#e4ae39');")
rep("dt * S.b.drain * (inWater ? 1.5 : 1)", "dt * S.drain * (inWater ? 1.5 : 1)")
rep("  S.deepest = Math.max(S.deepest, Math.round(Math.max(0, L.dist[S.cell]) * 4));", "  S.deepest = Math.max(S.deepest, S.depthBase + Math.round(Math.max(0, L.dist[S.cell]) * 4));")
rep("const n = ri(2, 4); if (addRes(tg.o.type, n))", "const n = Math.round(ri(2, 4) * (S.mod === 'vein' ? 1.5 : 1)); if (addRes(tg.o.type, n))")
rep("const t = mo.home + ri(-4, 4) + ri(-4, 4) * W;", "const rr = S.mod === 'restless' ? 7 : 4, t = mo.home + ri(-rr, rr) + ri(-rr, rr) * W;")
rep("    S.evAt = S.t + rnd(22, 34);", "    S.evAt = S.t + rnd(22, 34) * S.evK;")
rep("depth:Math.round(Math.max(0, L.dist[dep.face]) * 4), biome:S.b.id,", "depth:S.depthBase + Math.round(Math.max(0, L.dist[dep.face]) * 4), biome:S.b.id, tier:S.tier, legend:!!dep.legend,")
rep("  dep.g = dep.g || rollW(dep.kind, dep.d);", "  dep.g = dep.g || rollW(dep.kind, dep.d) * (dep.legend ? 3 : 1);")
rep("<div class=\"fr\">${shard ? 'раскололся' : geo ? 'жеода · что внутри — загадка' : RAR[r]}</div>",
    "<div class=\"fr${item.legend && !shard ? ' legend' : ''}\">${shard ? 'раскололся' : item.legend ? 'легендарная находка' : geo ? 'жеода · что внутри — загадка' : RAR[r]}</div>")

# ---------------- lab: value (economy ÷3, tiers, legend, perks) and orders ----------------
rep("  const dm = Math.min(3, it.dmg || 0), gi = Math.max(0, pickW(GR.map((g, k) => [k, g.w * Math.pow(luck, k * .55)])) - Math.min(dm, 2));",
    "  const dm = Math.min(3, it.dmg || 0); let gi = Math.max(0, pickW(GR.map((g, k) => [k, g.w * Math.pow(luck, k * .55)])) - Math.min(dm, 2)); if (it.legend) gi = Math.max(gi, 3);")
rep("* Math.pow(wf, .8) * [1, .75, .5, .15][dm])};",
    "* Math.pow(wf, .8) * [1, .75, .5, .15][dm] * .3 * (1 + (it.tier || 0) * .2) * (it.legend ? 2 : 1) * (1 + save.perks.val))};")
rep("    ${canCut ? '<button type=\"button\" class=\"btn cutbtn\" data-cut>Огранить<small>рискнуть ради цены</small></button>' : ''}",
    "    ${save.orders.filter(o => orderFits(o, it)).map(o => `<button type=\"button\" class=\"btn ordbtn\" data-order=\"${o.id}\">Сдать по заказу<small>${o.text} · ${rewardText(o.reward)}</small></button>`).join('')}\n"
    "    ${canCut ? '<button type=\"button\" class=\"btn cutbtn\" data-cut>Огранить<small>рискнуть ради цены</small></button>' : ''}")
rep("function decideFind(keep){", r"""function deliverFind(oid){
  if (ST.busy) return;
  const it = ST.it, o = save.orders.find(x => x.id === oid); if (!o || !orderFits(o, it)) return;
  save.finds = save.finds.filter(x => x.id !== it.id); completeOrder(o);
  const next = save.finds[0];
  if (next) openFind(next.id); else { stage.hidden = true; ST = null; renderCamp(); }
}
function decideFind(keep){""")
rep("stage.addEventListener('click', e => {", "stage.addEventListener('click', e => { const od = e.target.closest('[data-order]'); if (od) return deliverFind(+od.dataset.order);")

# ---------------- orders, reputation, sets, the daily roll ----------------
rep("/* ===================== camp ===================== */", r"""/* ===================== orders, sets, modifiers ===================== */
const rewardText = r => [r.money ? `${fmt(r.money)} ₽` : '', r.rep ? `★${r.rep}` : ''].filter(Boolean).join(' · ');
function give(r){ save.money += r.money || 0; save.rep += r.rep || 0; for (const k in (r.res || {})) save.res[k] += r.res[k]; SFX.coin(); }
const maxDepthAvail = () => Math.max(150, ...BIOMES.filter(b => save.up.lift >= b.lift).map(b => DEPTH0[b.id] + (save.tiers[b.id] || 0) * TIER_M + 140));
function genOrder(){
  const open = BIOMES.filter(b => save.up.lift >= b.lift), b = open[ri(0, open.length - 1)], boost = 1 + save.rep / 60, id = nid();
  const pool = Object.keys(b.pool).filter(sid => sid !== 'gold' && sid !== 'pyrite' && SP[sid].r <= 2 + Math.floor(save.rep / 15));
  const type = pickW([['spec', 5], ['heavy', 2], ['grade', 2], ['cut', save.up.lab >= 1 ? 1.5 : .4], ['ore', 2], ['deep', 1.5]]);
  if (type === 'spec') { const sid = pool[ri(0, pool.length - 1)], sp = SP[sid], wMin = Math.round(WMED.crystal * rnd(.4, 1.1) / 10) * 10;
    return {id, type, sid, wMin, text:`${sp.n} от ${fmtW(wMin)}`, hint:`водится: ${b.name}`, reward:{money:Math.round(sp.v * 3 * (1 + sp.r) * boost), rep:1 + sp.r}}; }
  if (type === 'heavy') { const wMin = pickW([[500, 3], [1000, 2], [2000, 1]]);
    return {id, type, wMin, text:`Кристалл или друза от ${fmtW(wMin)}`, hint:'ищите в глухой тьме и на ярусах поглубже', reward:{money:Math.round(wMin * .9 * boost), rep:2 + (wMin >= 1000) + (wMin >= 2000)}}; }
  if (type === 'grade') { const sid = pool[ri(0, pool.length - 1)], sp = SP[sid], gi = pickW([[2, 3], [3, 1]]);
    return {id, type, sid, gi, text:`${sp.n}, качество от ${GR[gi].n}`, hint:`водится: ${b.name}`, reward:{money:Math.round(sp.v * 5 * (1 + sp.r) * (gi - 1) * boost), rep:gi}}; }
  if (type === 'cut') { const r = pickW([[0, 2], [1, 2], [2, 1]]);
    return {id, type, r, text:`Огранённый камень: ${RAR[r].toLowerCase()} или реже`, hint:'огранка — в лаборатории после вскрытия', reward:{money:Math.round((300 + r * 500) * boost), rep:2 + r}}; }
  if (type === 'ore') { const res = pickW([['iron', 2], ['copper', 2], ['carbide', 1]]), n = ri(3, 6) * 10;
    return {id, type, res, n, text:`${RES[res].n}: ${n} ед.`, hint:'сдаётся со склада', reward:{money:Math.round(n * 12 * boost), rep:1}}; }
  const depth = pickW([[150, 2], [250, 2], [400, 1], [600, .6], [900, .3], [1300, .2]].filter(([d]) => d <= maxDepthAvail())) || 150;
  return {id, type:'deep', depth, text:`Спуститься глубже ${depth} м`, hint:'засчитается при подъёме на лифте', reward:{money:Math.round(depth * 2 * boost), rep:1 + Math.floor(depth / 300)}};
}
function ensureOrders(){ while (save.orders.length < 3) save.orders.push(genOrder()); }
function orderFits(o, it){
  const res = it.res; if (!res || it.dmg >= 3) return false;
  if (o.type === 'spec') return res.sid === o.sid && (it.g || 0) >= o.wMin;
  if (o.type === 'heavy') return (it.kind === 'crystal' || it.kind === 'druse') && (it.g || 0) >= o.wMin;
  if (o.type === 'grade') return res.sid === o.sid && res.gi >= o.gi;
  if (o.type === 'cut') return res.cut && res.cut !== 'broken' && SP[res.sid].r >= o.r;
  return false;
}
function completeOrder(o){
  give(o.reward); save.orders = save.orders.filter(x => x !== o); ensureOrders(); persist();
  toast('Заказ выполнен', `${o.text} · ${rewardText(o.reward)}`, '', 'var(--anom)');
}
function openOrders(){
  ensureOrders();
  openPanel(`${head(`Репутация ★${save.rep}`, 'Заказы')}<div class="orders">${save.orders.map(o => { const ore = o.type === 'ore', ok = ore && save.res[o.res] >= o.n;
      return `<div class="order${ok ? ' ok' : ''}"><div class="order-h"><b>${o.text}</b><span>${rewardText(o.reward)}</span></div><p>${o.hint}${ore ? ` · на складе ${save.res[o.res]}` : ''}</p>
        <div class="two">${ore ? `<button type="button" class="btn" data-ordres="${o.id}"${ok ? '' : ' disabled'}>Сдать</button>` : '<span></span>'}<button type="button" class="ghost" data-reroll="${o.id}"${save.money >= 100 ? '' : ' disabled'}>Другой · 100 ₽</button></div></div>`; }).join('')}</div>
    <p class="muted" style="margin:0;font-size:12.5px">Находки сдаются в лаборатории после вскрытия: под этикеткой появится кнопка «Сдать по заказу». Чем выше репутация, тем дороже и реже заказы.</p>
    <button type="button" class="btn" data-close>Понятно</button>`);
}
function setProg(st){
  const c = save.coll;
  if (st.need) return st.need.map(sid => c.some(x => x.sid === sid));
  const n = st.cut ? c.filter(x => x.cut && x.cut !== 'broken').length : c.filter(x => (x.g || 0) >= 1000).length;
  return Array.from({length:st.cut || st.heavy}, (_, k) => n > k);
}
function claimSet(id){
  const st = SETS.find(x => x.id === id); if (!st || save.sets.includes(id) || !setProg(st).every(Boolean)) return;
  save.sets.push(id); give(st.reward); if (st.perk) for (const k in st.perk) save.perks[k] += st.perk[k];
  SFX.build(); persist(); renderCamp(); toast(st.n, `Коллекция собрана · ${rewardText(st.reward)}${st.pd && st.perk ? ` · ${st.pd}` : ''}`, '', '#e4ae39');
}
// every trip up rolls the next descent's modifier and maybe a rumour
function rollDay(){ save.mod = pickW(Object.entries(MODS).map(([k, m]) => [k, m.w])); save.rumor = Math.random() < .22; }

/* ===================== camp ===================== */""")

# ascend: tier unlocks, depth orders, next day
rep("  save.st.ups++; save.st.deepest = Math.max(save.st.deepest, depth); persist();\n  endRun(); showCamp('lab');",
    r"""  save.st.ups++; save.st.deepest = Math.max(save.st.deepest, depth);
  let unlocked = 0; if (items.length >= 2 && S.tier >= (save.tiers[b.id] || 0) && S.tier < 9) { save.tiers[b.id] = S.tier + 1; save.tierSel[b.id] = S.tier + 1; unlocked = S.tier + 2; }
  const done = save.orders.filter(o => o.type === 'deep' && depth >= o.depth); done.forEach(completeOrder);
  rollDay(); persist();
  endRun(); showCamp('lab');""")
rep("${recs ? `<div class=\"row\"><span>Рекорды веса</span><span>★ ${recs}</span></div>` : ''}</div>",
    "${recs ? `<div class=\"row\"><span>Рекорды веса</span><span>★ ${recs}</span></div>` : ''}${unlocked ? `<div class=\"row\"><span>Открыт</span><span>ярус ${unlocked}</span></div>` : ''}${done.map(o => `<div class=\"row\"><span>Заказ</span><span>${o.text}</span></div>`).join('')}</div>")
rep("  save.st.rescues++; save.st.deepest = Math.max(save.st.deepest, S.deepest); persist();", "  save.st.rescues++; save.st.deepest = Math.max(save.st.deepest, S.deepest); rollDay(); persist();")

# ---------------- hub: reputation, tiers, today's modifier, orders ----------------
rep("  $('#wallet').innerHTML = `<span class=\"chipr\">${fmt(save.money)} ₽</span>`",
    "  ensureOrders();\n  $('#wallet').innerHTML = `<span class=\"chipr\" style=\"color:#e4ae39\">★${save.rep}</span><span class=\"chipr\">${fmt(save.money)} ₽</span>`")
rep("<div class=\"hz-body\"><div class=\"hz-no\">Горизонт ${['I', 'II', 'III'][hz]} · ${b.place}</div><h2>${b.name}</h2><p>${b.hint}</p>",
    "<div class=\"hz-body\"><div class=\"hz-no\">Горизонт ${['I', 'II', 'III'][hz]} · ${b.place}</div><h2>${b.name}</h2><p>${b.hint}</p>\n"
    "            ${open ? (() => { const mt = save.tiers[b.id] || 0, t = Math.min(save.tierSel[b.id] || 0, mt); return `<div class=\"tierrow\"><button type=\"button\" data-tier=\"-1\"${t <= 0 ? ' disabled' : ''}>−</button><b>Ярус ${t + 1}</b><button type=\"button\" data-tier=\"1\"${t >= mt ? ' disabled' : ''}>+</button><span class=\"muted\" style=\"font-size:12px\">${DEPTH0[b.id] + t * TIER_M} м и ниже</span><small>${t ? `монстров +${t}, фонарь садится быстрее, находки дороже на ${t * 20}%` : ''}${t >= mt ? `${t ? '. ' : ''}Вынесите 2+ трофея, чтобы открыть ярус ${mt + 2}` : ''}</small></div>`; })() : ''}")
rep("      <div class=\"dots\">${BIOMES.map((_, k) => `<i class=\"${k === hz ? 'on' : ''}\"></i>`).join('')}</div>",
    "      <div class=\"dots\">${BIOMES.map((_, k) => `<i class=\"${k === hz ? 'on' : ''}\"></i>`).join('')}</div>\n"
    "      <div class=\"modchip\"><b>${MODS[save.mod].n}.</b> ${MODS[save.mod].d}${save.rumor ? '<span class=\"rumor\">★ Слух: в глухой тьме лежит легендарная находка под охраной</span>' : ''}</div>")
rep("<button type=\"button\" class=\"chip-btn\" data-help>Как играть</button>",
    "<button type=\"button\" class=\"chip-btn hot\" data-orders>Заказы · ${save.orders.length}</button><button type=\"button\" class=\"chip-btn\" data-help>Как играть</button>")
rep("      <div class=\"sec-h\"><h2>Коллекция видов · ${got.size} из ${sids.length}</h2></div>",
    "      <div class=\"sec-h\"><h2>Коллекции</h2><span class=\"muted\" style=\"font-size:12px\">${save.sets.length} из ${SETS.length}</span></div>\n"
    "      <div class=\"sets\">${SETS.map(st => { const p = setProg(st), n = p.filter(Boolean).length, done = save.sets.includes(st.id);\n"
    "        return `<div class=\"set${done ? ' done' : ''}\"><div class=\"set-h\"><b>${st.n}</b><span>${n}/${p.length}</span></div>\n"
    "          <div class=\"set-i\">${st.need ? st.need.map((sid, k) => `<span class=\"${p[k] ? 'on' : ''}\">${imgTag(sid)}</span>`).join('') : p.map(x => `<span class=\"${x ? 'on' : ''}\">${st.cut ? '◆' : 'кг'}</span>`).join('')}</div>\n"
    "          <p>Награда: ${rewardText(st.reward)}${st.perk ? ` · ${st.pd}` : st.pd ? ` · ${st.pd}` : ''}</p>\n"
    "          ${done ? '<span class=\"crew-on\" style=\"--cc:#e4ae39\">✓ Собрана</span>' : n === p.length ? `<button type=\"button\" class=\"btn\" data-set=\"${st.id}\">Забрать награду</button>` : ''}</div>`; }).join('')}</div>\n"
    "      <p class=\"muted\" style=\"margin:0;font-size:12px\">В коллекции считаются только экспонаты музея — проданное не в счёт.</p>\n"
    "      <div class=\"sec-h\"><h2>Коллекция видов · ${got.size} из ${sids.length}</h2></div>")
rep("  const hr = e.target.closest('[data-hero]');",
    "  if (e.target.closest('[data-orders]')) return openOrders();\n"
    "  const sb = e.target.closest('[data-set]'); if (sb) return claimSet(sb.dataset.set);\n"
    "  const tr = e.target.closest('[data-tier]'); if (tr) { const b = BIOMES[hz]; save.tierSel[b.id] = Math.max(0, Math.min(save.tiers[b.id] || 0, (save.tierSel[b.id] || 0) + +tr.dataset.tier)); persist(); SFX.step(); return renderCamp(); }\n"
    "  const hr = e.target.closest('[data-hero]');")
rep("sheet.addEventListener('click', e => {",
    "sheet.addEventListener('click', e => {\n"
    "  const orr = e.target.closest('[data-ordres]'); if (orr) { const o = save.orders.find(x => x.id === +orr.dataset.ordres); if (o && save.res[o.res] >= o.n) { save.res[o.res] -= o.n; completeOrder(o); renderCamp(); openOrders(); } return; }\n"
    "  const rr = e.target.closest('[data-reroll]'); if (rr) { const k = save.orders.findIndex(x => x.id === +rr.dataset.reroll); if (k >= 0 && save.money >= 100) { save.money -= 100; save.orders[k] = genOrder(); persist(); renderCamp(); openOrders(); } return; }")
rep("fonar ${Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1))} с", "x", 0)
rep("фонарь ${Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1))} с", "фонарь ${Math.round(LAMP_T[save.up.lamp] * (save.hero === 'spel' ? 1.25 : 1)) + save.perks.lamp} с")

# help
rep("    <li>В бригаде четыре специалиста:", "    <li>Цели: заказы за деньги и репутацию (на главном экране), коллекции-наборы в музее с постоянными бонусами, ярусы — у каждого горизонта бесконечная глубина. Вынесите 2+ трофея, и откроется ярус ниже.</li>\n"
    "    <li>Каждый спуск особенный: «газовая неделя», «обесточено», «богатая жила»… А иногда ходит слух о легендарной находке в глухой тьме — её стережёт старший голем.</li>\n"
    "    <li>В бригаде четыре специалиста:")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
