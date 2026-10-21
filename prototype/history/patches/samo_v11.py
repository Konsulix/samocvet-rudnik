"""Самоцветный рудник v11: depot and museum join the home screen's look: one tab bar, big titles, glass panels over a full-bleed scene."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'samocvet_src.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- one tab bar for every screen ----------------
for a in ["#home .nav{", "#home .nav button{", "#home .nav button svg{", "#home .nav button.on{"]:
    rep(a, a.replace("#home .nav", ".screen > .nav"))
i = s.index('<div class="nav"><button class="on" type="button"><svg'); j = s.index('</div>', i)
home_nav = s[i:j + 6]
import re
icons = re.findall(r'<svg.*?</svg>', home_nav)
mine, tech, coll = icons
rep('<div class="nav"><button type="button" id="tHome">Рудник</button><button class="on" type="button">Техника</button><button type="button" id="tColl">Коллекция</button></div>',
    f'<div class="nav"><button type="button" id="tHome">{mine}Рудник</button><button class="on" type="button">{tech}Техника</button><button type="button" id="tColl">{coll}Коллекция</button></div>')
rep('<div class="nav"><button type="button" id="toHome">Рудник</button><button type="button" id="toTech2">Техника</button><button class="on" type="button">Коллекция</button></div>',
    f'<div class="nav"><button type="button" id="toHome">{mine}Рудник</button><button type="button" id="toTech2">{tech}Техника</button><button class="on" type="button">{coll}Коллекция</button></div>')

# ---------------- big titles and glass panels ----------------
rep("#tech h2{font-family:var(--display);font-size:20px;margin:6px 0 0}\n.tsub2{color:#c8b090;font-size:12.5px;margin-top:-6px}",
r""".stitle{font-family:var(--display);font-weight:900;font-size:clamp(17px, 5.6vw, 22px);letter-spacing:.02em;text-align:center;margin:2px 0 0;text-shadow:0 3px 0 rgba(0,0,0,.35), 0 0 18px rgba(0,0,0,.8)}
.ssub{text-align:center;color:#d8e0ee;font-size:13px;margin-top:-6px;text-shadow:0 1px 8px rgba(0,0,0,.9)}
.glass{background:rgba(14,20,32,.62);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.12);box-shadow:0 8px 20px rgba(0,0,0,.35)}
#tech .wrap, #coll .wrap{-webkit-mask-image:linear-gradient(transparent, #000 10px, #000 calc(100% - 18px), transparent);mask-image:linear-gradient(transparent, #000 10px, #000 calc(100% - 18px), transparent)}
#tech .ctabs, #coll .ctabs{background:rgba(14,20,32,.62);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.12)}""")
# the depot stage: no frame, the machine stands in the hangar on a lit pad
rep(".stage{position:relative;width:min(100%, 40vh);aspect-ratio:1;margin:0 auto;border-radius:20px;overflow:hidden;border:2px solid #3a3a30;box-shadow:0 14px 30px rgba(0,0,0,.6)}",
    ".stage{position:relative;width:min(100%, 46vh);aspect-ratio:1;margin:-6px auto -10px;-webkit-mask-image:radial-gradient(circle at 50% 48%, #000 52%, transparent 71%);mask-image:radial-gradient(circle at 50% 48%, #000 52%, transparent 71%)}\n"
    ".stage .spec-host, .stage .spec-host canvas{border-radius:0}\n"
    ".pad{position:relative;height:30px;margin:-46px auto 8px;width:min(80%, 34vh);border-radius:50%;background:radial-gradient(ellipse at center, rgba(242,176,30,.42), rgba(242,176,30,.08) 55%, transparent 72%);pointer-events:none}\n"
    ".pad::before{content:\"\";position:absolute;left:12%;right:12%;top:40%;height:6px;border-radius:3px;background:repeating-linear-gradient(-45deg, #f2b01e 0 8px, #1a1a1a 8px 16px);opacity:.75}")
rep(".stage .hazard{position:absolute;left:0;right:0;bottom:0;height:12px;z-index:2;background:repeating-linear-gradient(-45deg, #f2b01e 0 12px, #1a1a1a 12px 24px);opacity:.9}\n", "")
rep(".stage .owned{position:absolute;top:10px;left:10px;z-index:2;", ".stage .owned{position:absolute;top:18%;left:14%;z-index:2;")
rep(".tinfo{background:rgba(0,0,0,.4);border:1px solid #3a3a30;border-radius:16px;padding:12px;display:flex;flex-direction:column;gap:6px}",
    ".tinfo{background:rgba(14,20,32,.62);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,.12);box-shadow:0 8px 20px rgba(0,0,0,.35);border-radius:16px;padding:12px;display:flex;flex-direction:column;gap:6px}")
rep(".mstats div{background:rgba(0,0,0,.35);border:1px solid rgba(227,165,30,.3);", ".mstats div{background:rgba(14,10,6,.55);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);border:1px solid rgba(227,165,30,.3);")
rep("#coll h2{font-family:var(--display);font-size:20px;margin:6px 0 0}", "")
rep("""  $('#techWrap').innerHTML = `<h2>Депо</h2><div class="tsub2">""", """  $('#techWrap').innerHTML = `<div class="stitle">Депо</div><div class="ssub">""")
rep("""<div class="stage"><div class="spec-host" id="techHost"></div>${it.own ? '<span class="owned">✓ в депо</span>' : ''}<div class="hazard"></div></div>""",
    """<div class="stage"><div class="spec-host" id="techHost"></div>${it.own ? '<span class="owned">✓ в депо</span>' : ''}</div><div class="pad"></div>""")
rep("return `<h2>Минералогический музей</h2><div class=\"mstats\">", "return `<div class=\"stitle\">Коллекция</div><div class=\"ssub\">Минералогический музей</div><div class=\"mstats\">")

# the depot hangar and the museum hall get a little more depth behind the glass
rep("#tech{background:radial-gradient(ellipse 120% 45% at 50% 0%, rgba(242,176,30,.14), transparent 60%),",
    "#tech{background:radial-gradient(ellipse 70% 32% at 50% 34%, rgba(242,176,30,.16), transparent 70%), radial-gradient(ellipse 120% 45% at 50% 0%, rgba(242,176,30,.14), transparent 60%),")
rep("#coll{background:radial-gradient(ellipse 120% 50% at 50% -8%, rgba(255,200,120,.16), transparent 60%),",
    "#coll{background:radial-gradient(ellipse 30% 22% at 18% 0%, rgba(255,210,140,.18), transparent 70%), radial-gradient(ellipse 30% 22% at 82% 0%, rgba(255,210,140,.18), transparent 70%), radial-gradient(ellipse 120% 50% at 50% -8%, rgba(255,200,120,.16), transparent 60%),")
open(P, 'w', encoding='utf-8').write(s)
print('ok')
