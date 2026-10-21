"""v9 of «Забой»: procedural one-off mineral specimens with rare traits, shown in the lab and the museum."""
import os
D = os.path.dirname(os.path.abspath(__file__))
P = os.path.join(D, 'zaboy.html')
s = open(P, encoding='utf-8').read()
spec = open(os.path.join(D, 'specimen.js'), encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

rep(".fxc{position:fixed;", """.gem.live{inset:0}
.gem canvas.specv{width:100%;height:100%;display:block;border-radius:18px;box-shadow:0 18px 40px rgba(0,0,0,.6), 0 0 0 1px rgba(255,255,255,.08)}
.fc img.spec{width:86px;height:86px;object-fit:cover;border-radius:10px;box-shadow:0 4px 10px rgba(0,0,0,.4)}
.specbig{width:min(72vw,280px);aspect-ratio:1;object-fit:cover;border-radius:16px;box-shadow:0 14px 30px rgba(0,0,0,.55)}
.traits{display:flex;flex-wrap:wrap;gap:4px;margin-top:6px}
.traits span{font-size:11.5px;font-family:var(--body);font-weight:600;border-radius:999px;padding:2px 8px;background:rgba(42,34,24,.12);color:var(--ink)}
.traits span.rare{background:linear-gradient(90deg,#ffd27a,#ff9ad8,#9ad0ff);color:#2a1606}
.fxc{position:fixed;""")
rep("/* ===================== lab: the reveal ===================== */", spec + "/* ===================== lab: the reveal ===================== */")

# value now carries the traits
rep("  return {sid, gi, value:Math.round(SP[sid].v * sizeM * GR[gi].m * (it.kind === 'geode' ? 1.8 : 1) * Math.pow(wf, .8) * [1, .75, .5, .15][dm] * .3 * (1 + (it.tier || 0) * .2) * (it.legend ? 2 : 1) * (1 + save.perks.val))};",
    "  const traits = dm >= 3 ? [] : rollTraits(it, gi), tm = traits.reduce((m, id) => m * TR[id].m, 1);\n"
    "  return {sid, gi, traits, value:Math.round(SP[sid].v * sizeM * GR[gi].m * (it.kind === 'geode' ? 1.8 : 1) * Math.pow(wf, .8) * [1, .75, .5, .15][dm] * .3 * (1 + (it.tier || 0) * .2) * (it.legend ? 2 : 1) * (1 + save.perks.val) * tm)};")
rep("function openFind(id){\n", "function openFind(id){\n  specUnmount();\n")
# the reveal shows the specimen itself
rep("a.innerHTML = `<div class=\"rays\"></div><div class=\"wheel\"></div><div class=\"gem\">${imgTag(res.sid)}</div>`;",
    "a.innerHTML = `<div class=\"rays\"></div><div class=\"wheel\"></div><div class=\"gem\" id=\"gemView\">${imgTag(res.sid)}</div>`;\n"
    "  specMount($('#gemView'), specOf(it, res));")
rep("  if (!save.coll.some(c => c.sid === res.sid)) ST.news.push('Новый вид для музея');",
    "  if (!save.coll.some(c => c.sid === res.sid)) ST.news.push('Новый вид для музея');\n"
    "  for (const id of res.traits || []) if (TR[id].p < .06) ST.news.push(`Редкость: ${TR[id].n}`);")
rep("res.cut = c.id; gem.classList.add('faceted');", "res.cut = c.id; gem.classList.add('faceted'); specMount(gem, specOf(it, res));")
rep("res.cut = 'broken'; gem.classList.add('cracked');", "res.cut = 'broken'; gem.classList.add('cracked'); specMount(gem, specOf(it, res));")
rep("${res.cut ? `<dt>Огранка</dt><dd>${CUTN[res.cut]}</dd>` : ''}</dl>",
    "${res.cut ? `<dt>Огранка</dt><dd>${CUTN[res.cut]}</dd>` : ''}</dl>\n"
    "      ${res.traits && res.traits.length ? `<div class=\"traits\">${res.traits.map(id => `<span class=\"${TR[id].p < .06 ? 'rare' : ''}\">${TR[id].n} ×${String(TR[id].m).replace('.', ',')}</span>`).join('')}</div>` : ''}")
rep("if (next) openFind(next.id); else { stage.hidden = true; ST = null; renderCamp(); }",
    "if (next) openFind(next.id); else { specUnmount(); stage.hidden = true; ST = null; renderCamp(); }", 2)
rep("cut:res.cut});", "cut:res.cut, traits:res.traits, kind:it.kind, legend:!!it.legend});")
# museum: photos of the actual specimens
rep("data-coll=\"${s.id}\" style=\"--rc:${RC[SP[s.sid].r]}\">${imgTag(s.sid)}<span class=\"n\">",
    "data-coll=\"${s.id}\" style=\"--rc:${RC[SP[s.sid].r]}\">${imgTag(s.sid).replace('<img ', `<img data-spec=\"${s.id}\" `)}<span class=\"n\">")
rep("  if (lastTab !== tab) { lastTab = tab;", "  setTimeout(fillSpecs, 60);\n  if (lastTab !== tab) { lastTab = tab;")
rep("${imgTag(s.sid, 'width:min(50vw,180px);aspect-ratio:1;object-fit:contain')}</div>",
    "${(u => u ? `<img class=\"specbig\" src=\"${u}\" alt=\"\">` : imgTag(s.sid, 'width:min(50vw,180px);aspect-ratio:1;object-fit:contain'))(specThumb({seed:s.id, sid:s.sid, kind:s.kind, gi:s.gi, traits:s.traits, cut:s.cut, legend:s.legend}))}</div>\n"
    "      ${s.traits && s.traits.length ? `<div class=\"tags\" style=\"justify-content:center\">${s.traits.map(id => `<span style=\"--tc:#ffd27a\">${TR[id].n}</span>`).join('')}</div>` : ''}")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
