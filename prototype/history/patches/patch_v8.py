"""v8 of «Забой»: four new horizons (copper mountain, salt mines, ice cave, kimberlite pipe), per-horizon looks, more copper."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:110])
    s = s.replace(a, b)

# ---------------- species ----------------
rep("  diamond:{n:'Алмаз', img:'diamond', c:0xeaf6ff, v:2000, r:4},", r"""  diamond:{n:'Алмаз', img:'diamond', c:0xeaf6ff, v:2000, r:4},
  nativecu:{n:'Самородная медь', img:'gold', fl:'sepia(.6) saturate(2.4) hue-rotate(-28deg) brightness(.85)', c:0xd07040, v:70, r:1},
  cuprite:{n:'Куприт', img:'garnet', fl:'hue-rotate(-12deg) saturate(1.5) brightness(.75)', c:0xb02020, v:110, r:2},
  chrysocolla:{n:'Хризоколла', img:'malachite', fl:'hue-rotate(38deg) saturate(1.4)', c:0x3fc0c0, v:45, r:1},
  halite:{n:'Галит', img:'quartz', fl:'sepia(.35) saturate(2.2) hue-rotate(290deg) brightness(1.08)', c:0xf4c0d0, v:12, r:0},
  sylvite:{n:'Сильвин', img:'quartz', fl:'sepia(.7) saturate(3.5) hue-rotate(-20deg) brightness(.95)', c:0xe86a40, v:30, r:1},
  celestine:{n:'Целестин', img:'quartz', fl:'sepia(.3) saturate(2) hue-rotate(170deg) brightness(1.05)', c:0x9fd0ff, v:50, r:1},
  anhydrite:{n:'Ангидрит', img:'gypsum', fl:'sepia(.3) hue-rotate(220deg) saturate(1.5)', c:0xc0b0e8, v:25, r:0},
  pyrope:{n:'Пироп', img:'garnet', fl:'saturate(1.6) brightness(1.1)', c:0xff2a4a, v:140, r:2},
  chrysolite:{n:'Хризолит', img:'beryl', fl:'hue-rotate(40deg) saturate(2.2) brightness(.95)', c:0x9ee04a, v:120, r:2},""")

# ---------------- horizons ----------------
rep("""    events:['collapse'], gas:4, crawlers:3, golems:0, drain:1, pool:{quartz:30, calcite:18, pyrite:16, fluorite:12, amethyst:8, malachite:8, gold:4}, geo:{quartz:5, amethyst:3, calcite:3, fluorite:1}, ore:{iron:5, copper:2, carbide:3}},""",
"""    events:['collapse'], gas:4, crawlers:3, golems:0, drain:1, pool:{quartz:30, calcite:18, pyrite:16, fluorite:12, amethyst:8, malachite:8, gold:4}, geo:{quartz:5, amethyst:3, calcite:3, fluorite:1}, ore:{iron:5, copper:4, carbide:3}},
  {id:'copper', name:'Медная гора', place:'Нижний Тагил, Урал', lift:0, hint:'Старый медный рудник: медные жилы на каждом шагу, малахит и азурит. Вода в штреках кислая — обходите лужи.',
    events:['collapse', 'flood'], gas:3, crawlers:3, golems:0, drain:1, acid:true, pool:{malachite:22, azurite:12, chrysocolla:14, cuprite:5, quartz:10, calcite:8}, nug:[['nativecu', 3], ['pyrite', 1]], geo:{quartz:4, calcite:3, malachite:2}, ore:{copper:9, iron:2, carbide:2}},""")
rep("""ore:{iron:3, copper:5, carbide:3}},""", """ore:{iron:3, copper:5, carbide:3}},
  {id:'salt', name:'Соляные копи', place:'Соликамск, Пермский край', lift:1, hint:'Полосатые стены из красной и белой соли, кубические кристаллы. Рассол съедает карбид, а соль слепит в луче.',
    events:['collapse', 'flood'], gas:2, crawlers:4, golems:1, drain:1.1, pool:{halite:30, sylvite:18, anhydrite:12, gypsum:10, celestine:7, fluorite:6}, geo:{celestine:3, gypsum:3, calcite:2}, ore:{iron:2, copper:3, carbide:6}},""")
rep("""ore:{iron:4, copper:3, carbide:5}},
];""", """ore:{iron:4, copper:4, carbide:5}},
  {id:'ice', name:'Ледяная пещера', place:'Кунгур, Пермский край', lift:2, hint:'Гипсовый карст в вечном льду. Пол скользкий, мороз съедает фонарь, зато целестин и селенит чистые, как стекло.',
    events:['collapse'], gas:2, crawlers:4, golems:2, drain:1.25, ice:true, pool:{gypsum:20, anhydrite:12, celestine:14, calcite:12, fluorite:10, quartz:8, aquamarine:3, sapphire:1.5}, geo:{celestine:4, quartz:3, amethyst:2}, ore:{iron:3, copper:3, carbide:4}},
  {id:'kimber', name:'Кимберлитовая трубка', place:'Мирный, Якутия', lift:3, hint:'Самый глубокий горизонт: синяя порода, мерзлота и алмазы. Света почти нет, големов много.',
    events:['collapse', 'flood'], gas:4, crawlers:5, golems:3, drain:1.35, pool:{pyrope:16, chrysolite:12, diamond:3, garnet:10, quartz:8, calcite:6}, geo:{quartz:3, amethyst:2, opal:1}, ore:{iron:4, copper:3, carbide:5}},
];""")
rep("{id:'lift', n:'Лебёдка', d:lv => lv >= 2 ? 'Открыты все горизонты' : `Открыт горизонт: ${BIOMES[lv].name}`, cost:[{iron:30, copper:15, money:500}, {iron:60, copper:40, carbide:20, money:2500}]},",
    "{id:'lift', n:'Лебёдка', d:lv => `Доступно горизонтов: ${BIOMES.filter(b => b.lift <= lv).length} из ${BIOMES.length}`, cost:[{iron:30, copper:15, money:500}, {iron:60, copper:40, carbide:20, money:2000}, {iron:90, copper:70, carbide:40, money:4000}]},")
rep("const GROT_C = {adit:0xb47cff, flood:0x7fd8ff, fire:0xff3a5a};", "const GROT_C = {adit:0xb47cff, copper:0x3fe0b0, flood:0x7fd8ff, salt:0xff8ab0, fire:0xff3a5a, ice:0x9fd8ff, kimber:0xf4f8ff};")
rep("const DEPTH0 = {adit:0, flood:150, fire:300}, TIER_M = 150;", "const DEPTH0 = {adit:0, copper:60, flood:150, salt:200, fire:300, ice:350, kimber:550}, TIER_M = 150;")
rep("  {id:'crown', n:'Корона коллекции',",
    "  {id:'cuhill', n:'Медная гора', need:['nativecu', 'cuprite', 'chrysocolla', 'malachite', 'azurite'], reward:{money:1200, rep:5}, perk:{lamp:5}, pd:'+5 с фонаря навсегда'},\n"
    "  {id:'salt', n:'Соль земли', need:['halite', 'sylvite', 'anhydrite', 'celestine'], reward:{money:900, rep:4}, perk:null},\n"
    "  {id:'yakut', n:'Якутский клад', need:['diamond', 'pyrope', 'chrysolite'], reward:{money:6000, rep:12}, perk:{hp:1}, pd:'+1 здоровье навсегда'},\n"
    "  {id:'crown', n:'Корона коллекции',")

# ---------------- generation ----------------
rep("r === 'copper' ? .5 + d * 1.5 :", "r === 'copper' ? .9 + d * 1.1 :")
rep("['nugget', b.pool.gold ? (mod === 'gas' ? 24 : 10) : 0]]);", "['nugget', b.pool.gold || b.nug ? (mod === 'gas' ? 24 : 10) : 0]]);")
rep("    if (kind === 'nugget') sid = Math.random() < .55 ? 'pyrite' : 'gold';", "    if (kind === 'nugget') sid = b.nug ? pickW(b.nug) : Math.random() < .55 ? 'pyrite' : 'gold';")
rep("    if (Math.random() < (b.id === 'flood' ? .1 : .055)) lv.decor.moss.push(i);\n    if (nearWall && Math.random() < .045) lv.decor.crys.push(i);",
    "    if (Math.random() < LOOK[b.id].moss) lv.decor.moss.push(i);\n    if (nearWall && Math.random() < LOOK[b.id].crysP) lv.decor.crys.push(i);")
rep("  if (b.id !== 'fire') for (const i of lv.decor.moss.slice().sort(() => Math.random() - .5)) {",
    "  const gk = LOOK[b.id].glowKind, gcand = gk === 'fungi' ? lv.decor.moss : gk === 'crystal' ? floors.filter(i => lv.dist[i] > 6 && !shut(i) && N4.some(([dx, dy]) => !g[i + dx + dy * W])) : [];\n"
    "  for (const i of gcand.slice().sort(() => Math.random() - .5)) {")
rep("srcs.push({i:l.i, col:[1, .7, .4], r:4.6, k:.7});", "srcs.push({i:l.i, col:LOOK[b.id].lampCol, r:4.6, k:.7});")

# ---------------- looks ----------------
rep("""  adit:{a:0x9a6a40, b:0x6a6a68, wet:.2, spk:0xd8c070, mist:0xffe2b0, mistOp:1, glow:0xb8ff9a, spores:0x9fffb0, nSp:40, timber:true, hot:0},
  flood:{a:0x3e6a58, b:0x56687a, wet:1, spk:0xb8d8f0, mist:0xbfe6ff, mistOp:1.5, glow:0x6ff0ff, spores:0x8fe8ff, nSp:70, timber:true, hot:0},
  fire:{a:0x2a2424, b:0x7a4232, wet:0, spk:0xff5a40, mist:0xffb080, mistOp:1.2, glow:null, spores:0xff7a30, nSp:150, timber:false, hot:1},""",
"""  adit:{a:0x9a6a40, b:0x6a6a68, wet:.2, spk:0xd8c070, mist:0xffe2b0, mistOp:1, glow:0xb8ff9a, glowKind:'fungi', spores:0x9fffb0, nSp:40, timber:true, hot:0,
    wall:[.07, .14, .5], band:0xa07040, bandK:.12, floor:0x8a7a6a, water:0x0e3a52, crys:0xb8c8ff, cube:false, moss:.055, crysP:.045, stal:0x857565, glass:false, snow:false, lampCol:[1, .7, .4], mon:0xffffff},
  copper:{a:0x3a6a4a, b:0x6a5a48, wet:.5, spk:0x4fe0a0, mist:0xc8ffd8, mistOp:1.2, glow:0x6fffb0, glowKind:'fungi', spores:0x9fffc0, nSp:50, timber:true, hot:0,
    wall:[.36, .22, .36], band:0x1fa060, bandK:.55, floor:0x6a7a62, water:0x0e6a50, crys:0x5fe0c0, cube:false, moss:.04, crysP:.06, stal:0x5a6a58, glass:false, snow:false, lampCol:[1, .75, .45], mon:0xb8ffd0},
  flood:{a:0x3e6a58, b:0x56687a, wet:1, spk:0xb8d8f0, mist:0xbfe6ff, mistOp:1.5, glow:0x6ff0ff, glowKind:'fungi', spores:0x8fe8ff, nSp:70, timber:true, hot:0,
    wall:[.55, .1, .42], band:0x5a7a8a, bandK:.15, floor:0x7a8a8a, water:0x0e3a52, crys:0x9fe8ff, cube:false, moss:.1, crysP:.05, stal:0x758085, glass:false, snow:false, lampCol:[1, .7, .4], mon:0xd8f0ff},
  salt:{a:0xf0c8c8, b:0xd89090, wet:.4, spk:0xffffff, mist:0xffd8e0, mistOp:1, glow:0xffb0c8, glowKind:'crystal', spores:0xfff0f4, nSp:70, timber:true, hot:0,
    wall:[.99, .38, .64], band:0xb83a2a, bandK:.6, floor:0xc8a8a8, water:0x6a4048, crys:0xffe4ec, cube:true, moss:0, crysP:.16, stal:0xf0e0e0, glass:false, snow:false, lampCol:[1, .96, .88], mon:0xffd0d8},
  fire:{a:0x2a2424, b:0x7a4232, wet:0, spk:0xff5a40, mist:0xffb080, mistOp:1.2, glow:null, glowKind:null, spores:0xff7a30, nSp:150, timber:false, hot:1,
    wall:[.03, .2, .28], band:0x401010, bandK:.3, floor:0x6a5a54, water:0x0e3a52, crys:0xff8a6a, cube:false, moss:.015, crysP:.03, stal:0x2e2826, glass:false, snow:false, lampCol:[1, .6, .3], mon:0xffc0a0},
  ice:{a:0xc8e0f0, b:0x8ab0d0, wet:1, spk:0xffffff, mist:0xe0f4ff, mistOp:1.8, glow:0x9fe0ff, glowKind:'crystal', spores:0xffffff, nSp:110, timber:false, hot:0,
    wall:[.57, .38, .74], band:0xffffff, bandK:.3, floor:0xb8d0e0, water:0x9ac8e8, crys:0xd8f0ff, cube:false, moss:0, crysP:.12, stal:0xcfe8ff, glass:true, snow:true, lampCol:[.85, .95, 1], mon:0xc8e8ff},
  kimber:{a:0x3a4450, b:0x2a3038, wet:.3, spk:0xe8f4ff, mist:0xc8d0dc, mistOp:1.3, glow:0xffffff, glowKind:'crystal', spores:0xaab4c0, nSp:30, timber:true, hot:0,
    wall:[.6, .14, .28], band:0x202830, bandK:.25, floor:0x5a6068, water:0x1a3a52, crys:0xffffff, cube:false, moss:.015, crysP:.05, stal:0x3a4048, glass:false, snow:false, lampCol:[1, .85, .6], mon:0xd0d8ff},""")

# ---------------- scene ----------------
rep("bumpScale:.035, color:0x8a7a6a, roughness:.92});", "bumpScale:.035, color:look.floor, roughness:.92});")
rep("Object.assign(sh.uniforms, {uP:WALLCUT, uSpk:{value:new THREE.Color(look.spk)}, uWetW:{value:look.wet}});",
    "Object.assign(sh.uniforms, {uP:WALLCUT, uSpk:{value:new THREE.Color(look.spk)}, uWetW:{value:look.wet}, uBand:{value:new THREE.Color(look.band)}, uBandK:{value:look.bandK}});")
rep("uniform vec3 uSpk; uniform float uWetW; varying vec3 vWP;", "uniform vec3 uSpk, uBand; uniform float uWetW, uBandK; varying vec3 vWP;")
rep("      diffuseColor.rgb *= .84 + .16 * band;", "      diffuseColor.rgb *= .84 + .16 * band;\n      diffuseColor.rgb = mix(diffuseColor.rgb, uBand, smoothstep(.2, .9, band) * uBandK);")
rep("    col.setHSL(.07 - dd * .04 + rnd(-.01, .01), .14 + dd * .08, .5 - dd * .14 + rnd(-.04, .04)); walls.setColorAt(k, col);",
    "    col.setHSL((look.wall[0] - dd * .03 + rnd(-.01, .01) + 1) % 1, look.wall[1] + dd * .06, look.wall[2] - dd * .14 + rnd(-.04, .04)); walls.setColorAt(k, col);")
rep("  if (dc.length) { const cm = new THREE.InstancedMesh(new THREE.OctahedronGeometry(.07, 0), new THREE.MeshStandardMaterial({color:0xb8c8ff, roughness:.12, metalness:.1}), dc.length * 4);",
    "  if (dc.length) { const cm = new THREE.InstancedMesh(look.cube ? new THREE.BoxGeometry(.1, .1, .1) : new THREE.OctahedronGeometry(.07, 0), new THREE.MeshStandardMaterial({color:look.crys, roughness:.12, metalness:.1, transparent:look.glass, opacity:look.glass ? .8 : 1}), dc.length * 4);")
rep("mt.compose(new THREE.Vector3(cx + rnd(-.12, .12), .1 * s, cz + rnd(-.12, .12)), q, new THREE.Vector3(s * .8, s * 3, s * .8)); cm.setMatrixAt(k++, mt); } }",
    "mt.compose(new THREE.Vector3(cx + rnd(-.12, .12), (look.cube ? .05 : .1) * s, cz + rnd(-.12, .12)), q, look.cube ? new THREE.Vector3(s * 1.3, s * 1.3, s * 1.3) : new THREE.Vector3(s * .8, s * 3, s * .8)); cm.setMatrixAt(k++, mt); } }")
rep("new THREE.MeshStandardMaterial({color:L.b.id === 'fire' ? 0x2e2826 : 0x857565, roughness:L.b.id === 'flood' ? .35 : .85, flatShading:true}), stal.length * 3);",
    "new THREE.MeshStandardMaterial({color:look.stal, roughness:look.glass ? .05 : L.b.id === 'flood' ? .35 : .85, metalness:look.glass ? .1 : 0, transparent:look.glass, opacity:look.glass ? .72 : 1, flatShading:true}), stal.length * 3);")
# glowing crystals instead of fungi where the horizon has no moss
rep("""    caps.count = stems.count = k; scene.add(caps, stems); }""", """    caps.count = stems.count = k; scene.add(caps, stems); }
  if (look.glowKind === 'crystal' && L.fungi.length) {
    const gm = new THREE.InstancedMesh(look.cube ? new THREE.BoxGeometry(1, 1, 1) : new THREE.OctahedronGeometry(1, 0), new THREE.MeshBasicMaterial({color:look.glow, transparent:true, opacity:.9}), L.fungi.length * 7);
    let k = 0; for (const i of L.fungi) { const ws = N4.filter(([dx, dy]) => !L.g[i + dx + dy * W]), [sx, sy] = ws[0] || [0, 0], cx = wx(i % W) + sx * .3, cz = wz(Math.floor(i / W)) + sy * .3;
      for (let n = 0; n < 7; n++) { const s = rnd(.04, .1); e.set(rnd(-.5, .5), rnd(0, 3), rnd(-.5, .5)); q.setFromEuler(e);
        mt.compose(new THREE.Vector3(cx + rnd(-.22, .22), s * (look.cube ? 1 : 2.4), cz + rnd(-.22, .22)), q, look.cube ? new THREE.Vector3(s * 1.4, s * 1.4, s * 1.4) : new THREE.Vector3(s, s * 3, s)); gm.setMatrixAt(k++, mt); }
      const hs = new THREE.Sprite(new THREE.SpriteMaterial({map:haloTex, color:look.glow, blending:THREE.AdditiveBlending, depthWrite:false, transparent:true, opacity:.4})); hs.scale.setScalar(1.3); hs.position.set(cx, .2, cz); scene.add(hs); }
    gm.count = k; scene.add(gm); }""")
rep("  if (look.glow) {\n    const spots = L.fungi", "  if (look.glow && look.glowKind === 'fungi') {\n    const spots = L.fungi")
rep("size:look.hot ? .14 : .08,", "size:look.hot ? .14 : look.snow ? .1 : .08,")
rep("p.y = hot ? rnd(0, .4) : rnd(.2, 1.4); p.vx = rnd(-.08, .08); p.vy = hot ? rnd(.25, .6) : rnd(-.03, .05);",
    "const sn = LOOK[L.b.id].snow; p.y = hot ? rnd(0, .4) : sn ? rnd(1, 2.6) : rnd(.2, 1.4); p.vx = rnd(-.08, .08); p.vy = hot ? rnd(.25, .6) : sn ? rnd(-.4, -.18) : rnd(-.03, .05);")
rep("new THREE.MeshStandardMaterial({color:0x0e3a52, normalMap:wn,", "new THREE.MeshStandardMaterial({color:look.water, normalMap:wn,")
rep("new THREE.MeshBasicMaterial({color:lp.on ? 0xffcf88 : 0x2a2420}));", "new THREE.MeshBasicMaterial({color:lp.on ? new THREE.Color(...LOOK[L.b.id].lampCol) : 0x2a2420}));")
rep("map:loadTex(mo.type === 'golem' ? 'golem_top' : 'crawler_top'), transparent:true, alphaTest:.35, roughness:.9}));",
    "map:loadTex(mo.type === 'golem' ? 'golem_top' : 'crawler_top'), color:LOOK[L.b.id].mon, transparent:true, alphaTest:.35, roughness:.9}));")

# ---------------- mechanics: slippery ice, acid water ----------------
rep("""    const l = Math.max(1, Math.hypot(kx, kz)), nx = S.pos.x + kx / l * speed * dt, nz = S.pos.z + kz / l * speed * dt;
    if (canStand(nx, S.pos.z)) S.pos.x = nx; if (canStand(S.pos.x, nz)) S.pos.z = nz;
    S.face = Math.atan2(kx, kz);
  } else if (S.path.length) {""", """    const l = Math.max(1, Math.hypot(kx, kz)); let vx = kx / l * speed, vz = kz / l * speed;
    // on ice the miner keeps sliding the way he was going
    if (S.b.ice) { const k = Math.min(1, dt * 2.2); S.vx += (vx - S.vx) * k; S.vz += (vz - S.vz) * k; vx = S.vx; vz = S.vz; }
    const nx = S.pos.x + vx * dt, nz = S.pos.z + vz * dt;
    if (canStand(nx, S.pos.z)) S.pos.x = nx; else S.vx = 0; if (canStand(S.pos.x, nz)) S.pos.z = nz; else S.vz = 0;
    S.face = Math.atan2(kx, kz);
  } else if (S.b.ice && Math.hypot(S.vx, S.vz) > .25 && !S.path.length) {
    moving = true; const k = Math.max(0, 1 - dt * 1.6); S.vx *= k; S.vz *= k;
    const nx = S.pos.x + S.vx * dt, nz = S.pos.z + S.vz * dt;
    if (canStand(nx, S.pos.z)) S.pos.x = nx; else S.vx = 0; if (canStand(S.pos.x, nz)) S.pos.z = nz; else S.vz = 0;
  } else if (S.path.length) {""")
rep("hero:save.hero, abCd:0,", "vx:0, vz:0, hero:save.hero, abCd:0,")
rep("  if ((inGas || nearLava) && S.hurtT > 1.8) { S.hurtT = 0; hurt(1, inGas ? 'Вы надышались газом' : 'Жар от лавы'); }",
    "  const inAcid = S.b.acid && L.water.has(S.cell);\n"
    "  if ((inGas || nearLava || inAcid) && S.hurtT > 1.8) { S.hurtT = 0; hurt(1, inGas ? 'Вы надышались газом' : nearLava ? 'Жар от лавы' : 'Кислая вода разъедает сапоги'); }")
rep("  if (L.water.has(S.cell)) w.push('Вы в воде');", "  if (L.water.has(S.cell)) w.push(S.b.acid ? 'Кислая вода!' : 'Вы в воде');")

# ---------------- hub ----------------
rep("let tab = 'go', lastTab = null, hz = Math.min(2, save.up.lift);", "let tab = 'go', lastTab = null, hz = BIOMES.reduce((m, b, k) => save.up.lift >= b.lift ? k : m, 0);")
rep("const HZC = {adit:'#e3a857', flood:'#4fc3e8', fire:'#ff6a3a'}, HZF = {adit:'none', flood:'sepia(.75) hue-rotate(160deg) saturate(2.2) brightness(.9)', fire:'sepia(.85) hue-rotate(-28deg) saturate(3) brightness(.85)'};",
    "const HZC = {adit:'#e3a857', copper:'#3fcf8a', flood:'#4fc3e8', salt:'#ff9ab8', fire:'#ff6a3a', ice:'#9fd8ff', kimber:'#c8d4e8'}, HZF = {adit:'none', copper:'sepia(.7) hue-rotate(80deg) saturate(2)', flood:'sepia(.75) hue-rotate(160deg) saturate(2.2) brightness(.9)', salt:'sepia(.6) hue-rotate(295deg) saturate(1.7) brightness(1.05)', fire:'sepia(.85) hue-rotate(-28deg) saturate(3) brightness(.85)', ice:'sepia(.5) hue-rotate(170deg) saturate(1.3) brightness(1.2)', kimber:'grayscale(.7) brightness(.8) contrast(1.15)'};")
rep("Горизонт ${['I', 'II', 'III'][hz]} · ${b.place}", "Горизонт ${['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][hz]} · ${b.place}")
rep("[e]}</span>`).join('')}<span style=\"--tc:var(--gas)\">газ</span>",
    "[e]}</span>`).join('')}${b.acid ? '<span style=\"--tc:#7fe0a0\">кислая вода</span>' : ''}${b.ice ? '<span style=\"--tc:#9fd8ff\">скользкий лёд</span>' : ''}<span style=\"--tc:var(--gas)\">газ</span>")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
