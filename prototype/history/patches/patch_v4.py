"""v4 of «Забой»: noise ring + sound marks, a game-like camp hub, a richer underground, no screen grain."""
import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()

def rep(a, b, n=1):
    global s
    c = s.count(a)
    assert c == n, (c, a[:100])
    s = s.replace(a, b)

def between(start, end, new):
    global s
    i = s.index(start); j = s.index(end, i)
    s = s[:i] + new + s[j:]

# ---------------- fonts, grain bug ----------------
rep("family=Golos+Text:wght@400;500;600&", "family=Golos+Text:wght@400;500;600&family=Russo+One&")
rep("  --mono:'JetBrains Mono', ui-monospace, Consolas, monospace;", "  --mono:'JetBrains Mono', ui-monospace, Consolas, monospace;\n  --game:'Russo One', 'Golos Text', system-ui, sans-serif;")
# the moving film grain read as a glitch: gone
rep('.film::after{content:"";position:absolute;inset:-50%;background-image:var(--grain);opacity:.07;animation:grain .6s steps(4) infinite;mix-blend-mode:screen}\n', '')
rep('@keyframes grain{25%{transform:translate(-3%,2%)}50%{transform:translate(2%,-3%)}75%{transform:translate(-1%,3%)}}\n', '')
between("(function grain(){", "renderCamp();\nif (!save.help)", "")

# ---------------- CSS: hub + run additions ----------------
rep(".fxc{position:fixed;", r""".app{position:fixed;inset:0;max-width:none;margin:0;padding:0;gap:0;display:flex;flex-direction:column;overflow:hidden;background:#04080a}
.app::before{content:"";position:absolute;inset:-5%;background:url(img/mine_bg.webp) center/cover;filter:brightness(.7) saturate(1.05);animation:kb 40s ease-in-out infinite alternate;transition:filter .4s;z-index:0}
.app.sub::before{filter:brightness(.25) saturate(.7) blur(3px)}
@keyframes kb{to{transform:scale(1.09) translateY(-2%)}}
.app::after{content:"";position:absolute;inset:0;z-index:0;pointer-events:none;background:radial-gradient(ellipse at 50% 22%, rgba(255,190,100,.16), transparent 50%), linear-gradient(rgba(3,6,8,.55), rgba(3,6,8,.05) 28%, rgba(3,6,8,.55) 62%, rgba(3,6,8,.96));animation:lampfl 5s infinite}
@keyframes lampfl{0%,100%{opacity:1}47%{opacity:1}48%{opacity:.82}50%{opacity:1}73%{opacity:.9}74%{opacity:1}}
.app .top{position:relative;z-index:2;justify-content:flex-end;padding:calc(10px + env(safe-area-inset-top, 0px)) 12px 4px}
.app .brand{display:none}
.wallet .chipr{background:linear-gradient(rgba(20,34,40,.9), rgba(8,16,20,.9));border:1px solid rgba(227,168,87,.4);font-size:13px;padding:4px 10px;box-shadow:inset 0 1px 0 rgba(255,255,255,.08), 0 2px 0 rgba(0,0,0,.5)}
.wallet .chipr i{width:10px;height:10px;border-radius:3px;transform:rotate(45deg)}
.icon-btn{background:rgba(8,16,20,.8);border-color:rgba(255,255,255,.15)}
#camp{position:relative;z-index:1;flex:1;min-height:0;display:flex;flex-direction:column;gap:0!important}
.hub{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;align-items:center;gap:12px;padding:0 14px 10px}
.logo{text-align:center;margin-top:3vh}
.logo b{display:block;font-family:var(--game);font-weight:400;font-size:clamp(46px, 15vw, 64px);line-height:1;letter-spacing:.05em;color:#f6cd84;text-shadow:0 0 26px rgba(227,168,87,.6), 0 3px 0 #6a3a10, 0 8px 22px rgba(0,0,0,.9)}
.logo span{display:block;margin-top:6px;font-size:11px;letter-spacing:.32em;text-transform:uppercase;color:#e2d4b6;opacity:.85;text-shadow:0 1px 4px #000}
.hub .spacer{flex:1;min-height:8px}
.hz{display:flex;align-items:center;gap:6px;width:100%;max-width:440px}
.arr{flex:none;width:34px;height:70px;border-radius:12px;background:rgba(8,16,20,.75);border:1px solid rgba(255,255,255,.14);font-size:26px;line-height:1;color:var(--fg);box-shadow:0 3px 0 rgba(0,0,0,.5)}
.arr:disabled{opacity:.2;cursor:default}
.hz-card{flex:1;min-width:0;position:relative;border-radius:18px;overflow:hidden;border:2px solid var(--hc);background:#0b1418;box-shadow:0 0 34px color-mix(in srgb, var(--hc) 32%, transparent), 0 14px 30px rgba(0,0,0,.65);animation:hzin .4s cubic-bezier(.2,1.25,.4,1)}
@keyframes hzin{from{transform:scale(.92);opacity:0}}
.hz-art{height:118px;background:url(img/key_art.webp) center 42%/cover;filter:var(--hf);-webkit-mask:linear-gradient(#000 50%, transparent);mask:linear-gradient(#000 50%, transparent)}
.hz-body{position:relative;margin-top:-38px;padding:0 13px 12px;display:flex;flex-direction:column;gap:6px}
.hz-no{font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;color:var(--hc);font-weight:600;text-shadow:0 1px 3px #000}
.hz-body h2{font-family:var(--game);font-weight:400;font-size:23px;line-height:1.05;margin:0;text-shadow:0 2px 6px #000}
.hz-body p{margin:0;font-size:12.5px;color:#b9c4c2;line-height:1.35}
.hz-card.locked .hz-art, .hz-card.locked .hz-body{filter:grayscale(.85) brightness(.5)}
.hz-lock{position:absolute;top:10px;right:10px;background:rgba(0,0,0,.75);border:1px solid rgba(255,255,255,.2);border-radius:999px;padding:4px 10px;font-size:12px;font-weight:600}
.dots{display:flex;gap:7px}
.dots i{width:8px;height:8px;border-radius:50%;background:rgba(255,255,255,.22)}
.dots i.on{background:var(--lamp);box-shadow:0 0 8px var(--lamp)}
.play{width:100%;max-width:440px;border:0;border-radius:18px;padding:13px 12px 11px;background:linear-gradient(#ffd488, #e39d3e 55%, #b9691d);color:#2a1606;font-family:var(--game);font-size:25px;letter-spacing:.07em;text-transform:uppercase;position:relative;overflow:hidden;box-shadow:inset 0 2px 0 rgba(255,255,255,.55), inset 0 -4px 0 rgba(0,0,0,.22), 0 6px 0 #6a3a10, 0 14px 30px rgba(227,140,40,.35);transition:transform .08s, box-shadow .08s}
.play:active{transform:translateY(4px);box-shadow:inset 0 2px 0 rgba(255,255,255,.55), 0 2px 0 #6a3a10}
.play small{display:block;font-family:var(--body);font-size:12px;letter-spacing:0;text-transform:none;font-weight:600;opacity:.72}
.play::after{content:"";position:absolute;top:0;bottom:0;width:38%;left:-60%;background:linear-gradient(100deg, transparent, rgba(255,255,255,.5), transparent);animation:shine 3.4s ease-in-out infinite}
@keyframes shine{55%,100%{left:135%}}
.play.off{background:linear-gradient(#3c4c54, #26333a);color:#d6dfe1;box-shadow:inset 0 2px 0 rgba(255,255,255,.14), 0 6px 0 #0e171b}
.play.off::after{display:none}
.hub-mini{display:flex;gap:8px;flex-wrap:wrap;justify-content:center;align-items:center}
.chip-btn{background:rgba(8,16,20,.8);border:1px solid rgba(255,255,255,.16);border-radius:999px;padding:6px 13px;font-size:12.5px;font-weight:600}
.chip-btn.hot{border-color:var(--anom);color:var(--anom);box-shadow:0 0 14px rgba(127,224,200,.3)}
.nav{position:relative;z-index:2;display:grid;grid-template-columns:repeat(4, 1fr);gap:6px;padding:8px 10px calc(10px + env(safe-area-inset-bottom, 0px));background:linear-gradient(rgba(3,7,9,0), rgba(3,7,9,.94) 32%)}
.nav button{position:relative;display:flex;flex-direction:column;align-items:center;gap:3px;border-radius:14px;padding:8px 0 6px;font-size:11px;font-weight:600;color:#9fb2b6;background:linear-gradient(#1b2f39, #0e1c23);border:1px solid #2d4a58;box-shadow:inset 0 1px 0 rgba(255,255,255,.08), 0 3px 0 #050c0f}
.nav button.on{color:#ffd488;border-color:#c98a3a;background:linear-gradient(#3e2c14, #22180c);box-shadow:inset 0 1px 0 rgba(255,220,150,.2), 0 3px 0 #120b04, 0 0 16px rgba(227,168,87,.25)}
.nav svg{width:24px;height:24px}
.nav .dot{position:absolute;top:-5px;right:8px;min-width:18px;height:18px;border-radius:9px;background:var(--danger);color:#fff;font-size:10.5px;font-weight:700;display:grid;place-items:center;padding:0 4px;box-shadow:0 2px 0 #5a1a10}
.view{flex:1;min-height:0;overflow:auto;padding:2px 14px 16px;display:flex;flex-direction:column;gap:10px}
.vh{display:flex;align-items:baseline;justify-content:space-between;gap:8px;padding:4px 2px 0}
.vh h2{font-family:var(--game);font-weight:400;font-size:27px;color:#f6cd84;text-shadow:0 2px 0 #4a2a0c, 0 0 18px rgba(227,168,87,.35)}
.vh span{font-size:12px;color:var(--muted)}
.app .bld, .app .biome{background:linear-gradient(160deg, rgba(30,50,60,.94), rgba(12,24,30,.96));border:1px solid #3c5c6a;border-radius:16px;box-shadow:inset 0 1px 0 rgba(255,255,255,.07), 0 10px 24px rgba(0,0,0,.5)}
.app .bld-h b{font-family:var(--game);font-weight:400;font-size:20px;color:#f6cd84}
.app .buy{background:linear-gradient(#ffd488, #d48a30);color:#2a1606;border:0;border-radius:11px;box-shadow:inset 0 1px 0 rgba(255,255,255,.5), 0 3px 0 #6a3a10;font-weight:700}
.app .buy:active{transform:translateY(2px);box-shadow:0 1px 0 #6a3a10}
.app .buy:disabled{background:#1d2a30;color:#8fa3a8;box-shadow:0 3px 0 #0b1216;opacity:1}
.app .buy .cost .no{color:#ff8a78}
.app .fc{background:linear-gradient(160deg, rgba(30,50,60,.92), rgba(12,24,30,.94));border-radius:14px;box-shadow:0 6px 14px rgba(0,0,0,.4)}
.app .rows{background:rgba(8,16,20,.78);border:1px solid #2a4250;border-radius:14px;padding:2px 12px}
.app .row:last-child{border-bottom:0}
.app .sec-h h2{color:#e3c48c}
.app .empty{background:rgba(8,16,20,.75)}
.btn{font-family:var(--game);font-weight:400;letter-spacing:.04em;background:linear-gradient(#ffd488, #d48a30);box-shadow:inset 0 1px 0 rgba(255,255,255,.5), 0 4px 0 #6a3a10;border-radius:12px}
.btn:active{transform:translateY(3px);box-shadow:0 1px 0 #6a3a10}
.btn small{font-family:var(--body)}
#marks{position:fixed;inset:0;z-index:9;pointer-events:none}
.smark{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:2px;--mc:#e8f0a0;animation:smk 1.4s ease-out forwards}
.smark.golem{--mc:#8fd8ff}
.smark i{width:22px;height:22px;border-radius:50%;border:2px solid var(--mc);box-shadow:0 0 10px var(--mc), inset 0 0 6px var(--mc);animation:ping 1.4s ease-out}
.smark.edge i{width:0;height:0;border-radius:0;border:0;box-shadow:none;border-left:15px solid var(--mc);border-top:9px solid transparent;border-bottom:9px solid transparent;transform:rotate(var(--rot));filter:drop-shadow(0 0 6px var(--mc));animation:none}
.smark span{font-size:10.5px;font-weight:700;letter-spacing:.04em;color:var(--mc);text-shadow:0 1px 3px #000}
@keyframes smk{0%{opacity:0}12%{opacity:1}70%{opacity:1}100%{opacity:0}}
@keyframes ping{from{transform:scale(.4)}to{transform:scale(1.35)}}
.joy.sneak{border-color:rgba(127,224,200,.5)}
.joy.sneak i{background:rgba(127,224,200,.55);box-shadow:0 0 14px rgba(127,224,200,.5)}
.joy.sneak::after{content:"тихо";position:absolute;left:50%;top:-20px;transform:translateX(-50%);font-size:11px;font-weight:700;color:var(--anom);text-shadow:0 1px 3px #000}
.fxc{position:fixed;""")
rep('<div class="toastbox" id="toasts"></div>', '<div id="marks"></div>\n<div class="toastbox" id="toasts"></div>')

# ---------------- renderer: less pixel load, cleaner shadows ----------------
rep("R3.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));", "R3.setPixelRatio(Math.min(1.75, window.devicePixelRatio || 1));")
rep("spot.shadow.bias = -.002;", "spot.shadow.bias = -.0015; spot.shadow.normalBias = .03;")

# ---------------- biome looks ----------------
rep("const SHARED = {t:{value:0}}, WALLCUT = {value:null};", r"""const SHARED = {t:{value:0}}, WALLCUT = {value:null};
// per-horizon look: floor tints, puddles, wall specks, mist, life
const LOOK = {
  adit:{a:0x9a6a40, b:0x6a6a68, wet:.2, spk:0xd8c070, mist:0xffe2b0, mistOp:1, glow:0xb8ff9a, spores:0x9fffb0, nSp:40, timber:true, hot:0},
  flood:{a:0x3e6a58, b:0x56687a, wet:1, spk:0xb8d8f0, mist:0xbfe6ff, mistOp:1.5, glow:0x6ff0ff, spores:0x8fe8ff, nSp:70, timber:true, hot:0},
  fire:{a:0x2a2424, b:0x7a4232, wet:0, spk:0xff5a40, mist:0xffb080, mistOp:1.2, glow:null, spores:0xff7a30, nSp:150, timber:false, hot:1},
};
const ZN = NOISE_GLSL_Z();
function NOISE_GLSL_Z(){ return `
  float zh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
  float zn(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(zh(i), zh(i + vec2(1.0, 0.0)), u.x), mix(zh(i + vec2(0.0, 1.0)), zh(i + vec2(1.0, 1.0)), u.x), u.y); }
  float zf(vec2 p){ float v = 0.0, a = 0.5; for (int k = 0; k < 4; k++){ v += a * zn(p); p *= 2.03; a *= 0.5; } return v; }`; }
let gridTex = null, mist = null, noiseRing = null, spores = null;
function makeGridTex(){
  const d = new Uint8Array(W * H * 4); for (let i = 0; i < W * H; i++) d[i * 4] = L.g[i] ? 0 : 255;
  const t = new THREE.DataTexture(d, W, H, THREE.RGBAFormat); t.magFilter = t.minFilter = THREE.NearestFilter; t.needsUpdate = true; return t;
}
function mistMaterial(look){
  return new THREE.ShaderMaterial({uniforms:{t:SHARED.t, uP:{value:new THREE.Vector3()}, uDir:{value:new THREE.Vector2(0, -1)}, uAng:{value:.5}, uDist:{value:10}, uOp:{value:look.mistOp}, uCol:{value:new THREE.Color(look.mist)}, uGrid:{value:gridTex}},
    transparent:true, depthWrite:false, blending:THREE.AdditiveBlending,
    vertexShader:`varying vec3 wp; void main(){ vec4 w = modelMatrix * vec4(position, 1.0); wp = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader:`uniform float t, uAng, uDist, uOp; uniform vec3 uP, uCol; uniform vec2 uDir; uniform sampler2D uGrid; varying vec3 wp; ${ZN}
      void main(){
        vec2 d = wp.xz - uP.xz; float r = length(d); if (r < .1 || r > uDist) discard;
        float ang = acos(clamp(dot(d / r, uDir), -1.0, 1.0));
        float cone = 1.0 - smoothstep(uAng * .7, uAng * 1.05, ang); if (cone <= 0.0) discard;
        for (int k = 1; k < 14; k++) { vec2 p = uP.xz + d * (float(k) / 14.0); if (texture2D(uGrid, (p + vec2(${W / 2}.0, ${H / 2}.0)) / vec2(${W}.0, ${H}.0)).r < .5) discard; }
        float fall = smoothstep(.3, 1.4, r) * (1.0 - smoothstep(uDist * .4, uDist * .95, r));
        float n = zf(wp.xz * .5 + vec2(t * .07, -t * .045)) * zf(wp.xz * 1.4 - vec2(t * .1, t * .06) + 3.0);
        float a = cone * fall * smoothstep(.1, .5, n) * .26 * uOp;
        gl_FragColor = vec4(uCol * a, a); }`});
}""")

# ---------------- floor: tints, puddles that catch the lamp, glowing cracks on the fire horizon ----------------
rep("  const floor = new THREE.Mesh(new THREE.PlaneGeometry(W, H), new THREE.MeshStandardMaterial({map:floorTex, bumpMap:floorTex, bumpScale:.035, color:0x8a7a6a, roughness:.92}));",
r"""  const look = LOOK[L.b.id]; gridTex = makeGridTex();
  const floorMat = new THREE.MeshStandardMaterial({map:floorTex, bumpMap:floorTex, bumpScale:.035, color:0x8a7a6a, roughness:.92});
  floorMat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, {uT:SHARED.t, uA:{value:new THREE.Color(look.a)}, uB:{value:new THREE.Color(look.b)}, uWet:{value:look.wet}, uHot:{value:look.hot}});
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vWP;`).replace('#include <project_vertex>', `#include <project_vertex>
      vWP = (modelMatrix * vec4(transformed, 1.0)).xyz;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform float uT, uWet, uHot; uniform vec3 uA, uB; varying vec3 vWP; ${ZN}`).replace('#include <map_fragment>', `#include <map_fragment>
      float fn1 = zf(vWP.xz * .16), fn2 = zf(vWP.xz * .45 + 7.0);
      diffuseColor.rgb *= mix(vec3(1.0), mix(uA, uB, smoothstep(.35, .65, fn1)) * 1.7, .5);
      float wet = smoothstep(.66 - uWet * .14, .72 - uWet * .14, fn2);
      diffuseColor.rgb *= 1.0 - wet * .6;`).replace('#include <roughnessmap_fragment>', `#include <roughnessmap_fragment>
      roughnessFactor = mix(roughnessFactor, .05, wet);`).replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      if (uHot > .5) { float cr = abs(zf(vWP.xz * .32) - .5); float v = 1.0 - smoothstep(.0, .022, cr); v *= smoothstep(.45, .62, zf(vWP.xz * .07 + 3.0));
        totalEmissiveRadiance += vec3(1.0, .3, .05) * v * (.7 + .3 * sin(uT * 1.4 + vWP.x * .6)); }`);
  };
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(W, H), floorMat);""")

# ---------------- walls: strata, glittering specks, smooth cut-away instead of the dither ----------------
between("  wallMat.onBeforeCompile = sh => {", "  walls = new THREE.InstancedMesh(", r"""  wallMat.onBeforeCompile = sh => {
    Object.assign(sh.uniforms, {uP:WALLCUT, uSpk:{value:new THREE.Color(look.spk)}, uWetW:{value:look.wet}});
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      uniform vec3 uP; varying vec3 vWP;`).replace('#include <begin_vertex>', `#include <begin_vertex>
      #ifdef USE_INSTANCING
        // rock between the camera and the miner sinks down, so the tilted camera never loses him
        vec2 cd = instanceMatrix[3].xz - uP.xz; float hh = length(instanceMatrix[1].xyz);
        float cut = (1.0 - smoothstep(1.0, 1.7 + cd.y * .3, abs(cd.x))) * smoothstep(.2, .7, cd.y) * (1.0 - smoothstep(2.3, 3.1, cd.y));
        if (transformed.y > 0.0) transformed.y = mix(transformed.y, .28 / hh - .5, cut);
      #endif`).replace('#include <project_vertex>', `#include <project_vertex>
      #ifdef USE_INSTANCING
        vWP = (modelMatrix * instanceMatrix * vec4(transformed, 1.0)).xyz;
      #else
        vWP = (modelMatrix * vec4(transformed, 1.0)).xyz;
      #endif`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform vec3 uSpk; uniform float uWetW; varying vec3 vWP; ${ZN}`).replace('#include <map_fragment>', `#include <map_fragment>
      float band = sin(vWP.y * 10.0 + zf(vWP.xz * .6) * 7.0);
      diffuseColor.rgb *= .84 + .16 * band;
      vec3 sc = floor(vWP * 20.0); float spk = step(.986, zh(sc.xz + sc.y * 17.13));
      diffuseColor.rgb = mix(diffuseColor.rgb, uSpk, spk);`).replace('#include <roughnessmap_fragment>', `#include <roughnessmap_fragment>
      roughnessFactor = mix(mix(roughnessFactor, .42, uWetW * .6), .12, spk);`).replace('#include <metalnessmap_fragment>', `#include <metalnessmap_fragment>
      metalnessFactor = mix(metalnessFactor, .9, spk);`);
  };
""")

# ---------------- decor: stalagmites, timber, glowing fungi, spores/embers, mist, noise ring ----------------
rep("  // ore veins: metallic streaks on the rock face, visible only when lit", r"""  // stalagmites by the walls: they throw long shadows in the lamp
  const stal = L.decor.rocks.filter(() => Math.random() < .3);
  if (stal.length) { const sm = new THREE.InstancedMesh(new THREE.ConeGeometry(.13, 1, 7), new THREE.MeshStandardMaterial({color:L.b.id === 'fire' ? 0x2e2826 : 0x857565, roughness:L.b.id === 'flood' ? .35 : .85, flatShading:true}), stal.length * 3);
    let k = 0; for (const i of stal) { const ws = N4.filter(([dx, dy]) => !L.g[i + dx + dy * W]), [sx, sy] = ws[0] || [0, 0];
      for (let n = ri(1, 3); n > 0; n--) { const h = rnd(.35, 1.1); e.set(rnd(-.08, .08), rnd(0, 3), rnd(-.08, .08)); q.setFromEuler(e); mt.compose(new THREE.Vector3(wx(i % W) + sx * .3 + rnd(-.25, .25), h / 2, wz(Math.floor(i / W)) + sy * .3 + rnd(-.25, .25)), q, new THREE.Vector3(rnd(.7, 1.3), h, rnd(.7, 1.3))); sm.setMatrixAt(k++, mt); } }
    sm.count = k; sm.castShadow = true; scene.add(sm); }
  // old mine timbering across the drifts
  if (look.timber) {
    const sup = []; for (let i = 0; i < W * H; i++) { if (!L.g[i] || L.dist[i] < 3 || L.block.has(i) || L.water.has(i)) continue;
      const ns = !L.g[i - W] && !L.g[i + W] && L.g[i - 1] && L.g[i + 1], ew = !L.g[i - 1] && !L.g[i + 1] && L.g[i - W] && L.g[i + W];
      if ((ns || ew) && sup.every(([j]) => Math.abs(j % W - i % W) + Math.abs(Math.floor(j / W) - Math.floor(i / W)) > 4) && Math.random() < .5) sup.push([i, ns]); }
    const wood = new THREE.MeshStandardMaterial({color:0x5a4128, roughness:.9});
    const posts = new THREE.InstancedMesh(new THREE.BoxGeometry(.13, 1.25, .13), wood, sup.length * 2), beams = new THREE.InstancedMesh(new THREE.BoxGeometry(1.05, .13, .15), wood, sup.length);
    sup.forEach(([i, ns], k) => { const x = wx(i % W), z = wz(Math.floor(i / W)); e.set(0, ns ? 0 : Math.PI / 2, rnd(-.04, .04)); q.setFromEuler(e);
      for (const s of [-1, 1]) { mt.compose(new THREE.Vector3(x + (ns ? 0 : s * .44), .62, z + (ns ? s * .44 : 0)), q, one3); posts.setMatrixAt(k * 2 + (s > 0 ? 1 : 0), mt); }
      e.set(0, ns ? Math.PI / 2 : 0, rnd(-.05, .05)); q.setFromEuler(e); mt.compose(new THREE.Vector3(x, 1.22, z), q, one3); beams.setMatrixAt(k, mt); });
    posts.castShadow = beams.castShadow = true; scene.add(posts, beams); }
  // glowing fungi: tiny lights you can see in the dark
  if (look.glow) {
    const spots = L.decor.moss.filter(() => Math.random() < .35).slice(0, 16);
    const caps = new THREE.InstancedMesh(new THREE.SphereGeometry(1, 8, 6, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({color:look.glow}), spots.length * 6);
    const stems = new THREE.InstancedMesh(new THREE.CylinderGeometry(.012, .016, 1, 5), new THREE.MeshStandardMaterial({color:0xd8d2c0, roughness:.8}), spots.length * 6);
    let k = 0; for (const i of spots) { const cx = wx(i % W) + rnd(-.3, .3), cz = wz(Math.floor(i / W)) + rnd(-.3, .3);
      for (let n = 0; n < 6; n++) { const h = rnd(.05, .16), r = rnd(.025, .06), x = cx + rnd(-.18, .18), z = cz + rnd(-.18, .18);
        mt.compose(new THREE.Vector3(x, h, z), q.identity(), new THREE.Vector3(r, r * .55, r)); caps.setMatrixAt(k, mt);
        mt.compose(new THREE.Vector3(x, h / 2, z), q, new THREE.Vector3(1, h, 1)); stems.setMatrixAt(k++, mt); }
      const hs = new THREE.Sprite(new THREE.SpriteMaterial({map:haloTex, color:look.glow, blending:THREE.AdditiveBlending, depthWrite:false, transparent:true, opacity:.35})); hs.scale.setScalar(1.1); hs.position.set(cx, .12, cz); scene.add(hs); }
    caps.count = stems.count = k; scene.add(caps, stems); }
  // spores drifting in the dark, or embers rising on the fire horizon
  { const N = look.nSp, g2 = new THREE.BufferGeometry(); g2.setAttribute('position', new THREE.BufferAttribute(new Float32Array(N * 3), 3));
    spores = new THREE.Points(g2, new THREE.PointsMaterial({map:haloTex, color:look.spores, size:look.hot ? .1 : .07, transparent:true, opacity:look.hot ? .9 : .55, depthWrite:false, blending:THREE.AdditiveBlending}));
    spores.frustumCulled = false; spores.userData.v = Array.from({length:N}, () => ({life:0})); scene.add(spores); }
  // mist that only shows inside the beam
  mist = new THREE.Mesh(new THREE.PlaneGeometry(W, H), mistMaterial(look)); mist.rotation.x = -Math.PI / 2; mist.position.y = .45; mist.renderOrder = 4; scene.add(mist);
  // how far your noise carries
  noiseRing = new THREE.Mesh(new THREE.RingGeometry(.965, 1, 72), new THREE.MeshBasicMaterial({color:0xdfe8f0, transparent:true, opacity:.3, depthWrite:false}));
  noiseRing.rotation.x = -Math.PI / 2; noiseRing.renderOrder = 5; scene.add(noiseRing);
  // ore veins: metallic streaks on the rock face, visible only when lit""")
rep("  const mt = m4(), col = new THREE.Color(), q = new THREE.Quaternion(), e = new THREE.Euler();",
    "  const mt = m4(), col = new THREE.Color(), q = new THREE.Quaternion(), e = new THREE.Euler(), one3 = new THREE.Vector3(1, 1, 1);")
rep("  L.g[i] = 1; hideWork(); SFX.collapse(); S.shake = .6;", "  L.g[i] = 1; hideWork(); SFX.collapse(); S.shake = .6; gridTex.image.data[i * 4] = 255; gridTex.needsUpdate = true;")

# ---------------- draw: mist, spores, ring ----------------
rep("  dust.geometry.attributes.position.needsUpdate = true;", r"""  dust.geometry.attributes.position.needsUpdate = true;
  const mu = mist.material.uniforms; mu.uP.value.set(S.pos.x, 0, S.pos.z); mu.uDir.value.set(fx, fz); mu.uAng.value = spot.angle; mu.uDist.value = spot.distance * .9; mist.visible = on;
  const hot = LOOK[L.b.id].hot, sv = spores.userData.v, sa = spores.geometry.attributes.position.array;
  for (let k = 0; k < sv.length; k++) { const p = sv[k]; p.life -= dt;
    if (p.life <= 0 || Math.abs(p.x - S.pos.x) > 11 || Math.abs(p.z - S.pos.z) > 13) { p.x = S.pos.x + rnd(-10, 10); p.z = S.pos.z + rnd(-12, 9); p.y = hot ? rnd(0, .4) : rnd(.2, 1.4); p.vx = rnd(-.08, .08); p.vy = hot ? rnd(.25, .6) : rnd(-.03, .05); p.vz = rnd(-.08, .08); p.life = rnd(3, 7); }
    p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt; sa[k * 3] = p.x; sa[k * 3 + 1] = p.y; sa[k * 3 + 2] = p.z; }
  spores.geometry.attributes.position.needsUpdate = true; spores.material.opacity = (hot ? .75 : .45) + Math.sin(t * 2) * .1;
  S.noiseVis += (S.noise - S.noiseVis) * Math.min(1, dt * 10);
  noiseRing.position.set(S.pos.x, .04, S.pos.z); noiseRing.scale.setScalar(Math.max(.35, S.noiseVis)); noiseRing.material.opacity = .34 - Math.min(.22, S.noiseVis * .025);""")

# ---------------- noise: walking, sneaking, working ----------------
rep("hurtFlash:0, kills:0, dread:0,", "hurtFlash:0, kills:0, noise:.6, noiseVis:.6, sneak:false, dread:0,")
rep("function noiseAt(r){ for (", "function noiseAt(r){ S.noise = Math.max(S.noise, r); for (")
rep("  const speed = 3.2 * (inWater ? .55 : 1);", "  const sneak = !!S.joy && Math.hypot(kx, kz) < .62, speed = 3.2 * (inWater ? .55 : 1) * (sneak ? .48 : 1);")
rep("  if (moving) { S.walkT += dt; if (S.walkT > .36) { S.walkT = 0; SFX.step(); } S.act = null; S.idle = 0; }",
    "  if (moving) { S.walkT += dt; if (S.walkT > (sneak ? .55 : .36)) { S.walkT = 0; SFX.step(sneak ? .35 : 1); } S.act = null; S.idle = 0; }\n"
    "  // footsteps carry: a full run is loud, a slow sneak barely heard, standing still is silence\n"
    "  S.sneak = sneak; S.noise = Math.max(moving ? (sneak ? 1.1 : inWater ? 3.4 : 2.7) : .6, S.noise - dt * 5);")
rep("  step(){ noise(.05, 380, .05); },", "  step(v = 1){ noise(.05, 380, .05 * v); },")
rep("      if (d < (S.lamp > 0 ? 3 : 6) || (mo.lit && mo.type === 'crawler')) {", "      if (d < S.noise + (S.lamp > 0 ? 0 : 2) || (mo.lit && mo.type === 'crawler')) {")
rep("    if (!mo.lit && d < 9 && mo.sound <= 0) { mo.sound = rnd(1.2, 2.4); mo.type === 'crawler' ? SFX.skitter(1 - d / 9, pan) : SFX.growl(pan); }",
    "    if (!mo.lit && d < 9 && mo.sound <= 0) { mo.sound = rnd(1.2, 2.4); mo.type === 'crawler' ? SFX.skitter(1 - d / 9, pan) : SFX.growl(pan); soundMark(mo.x, mo.z, mo.type); }")
rep("function stepPath(mo, spd, dt){", r"""// what you hear, drawn where it comes from; pinned to the screen edge when it is off-screen
function soundMark(x, z, kind){
  const v = new THREE.Vector3(x, .4, z).project(camera), w0 = innerWidth, h0 = innerHeight, m = 30, top = 120, bot = 150;
  let sx = (v.x * .5 + .5) * w0, sy = (-v.y * .5 + .5) * h0;
  const inside = sx > m && sx < w0 - m && sy > top && sy < h0 - bot;
  const el = document.createElement('div'); el.className = `smark ${kind}${inside ? '' : ' edge'}`;
  if (!inside) { const cx = w0 / 2, cy = (top + h0 - bot) / 2, a = Math.atan2(sy - cy, sx - cx);
    const k = Math.min((w0 / 2 - m) / Math.max(1e-4, Math.abs(Math.cos(a))), ((h0 - bot - top) / 2) / Math.max(1e-4, Math.abs(Math.sin(a))));
    sx = cx + Math.cos(a) * k; sy = cy + Math.sin(a) * k; el.style.setProperty('--rot', a + 'rad'); }
  el.style.left = sx + 'px'; el.style.top = sy + 'px';
  el.innerHTML = `<i></i><span>${kind === 'golem' ? 'рык' : 'шорох'}</span>`;
  $('#marks').appendChild(el); setTimeout(() => el.remove(), 1400);
}
function stepPath(mo, spd, dt){""")
rep("  if (down.joy) { const k = Math.min(1, d / 45);", "  if (down.joy) { const k = Math.min(1, d / 45); joyEl.classList.toggle('sneak', k < .62);")
rep("  ambStop(); $('#dread').style.opacity = 0;", "  ambStop(); $('#dread').style.opacity = 0; $('#marks').innerHTML = '';")

# ---------------- the camp: a game hub instead of a web page ----------------
rep("let tab = 'go', lastTab = null;", "let tab = 'go', lastTab = null, hz = Math.min(2, save.up.lift);")
ICONS = r"""const ICO = {
  go:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><g transform="rotate(-35 12 12)"><path d="M4 9Q12 1.5 20 9"/><path d="M12 5.2V22"/></g></svg>',
  shop:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10h13l2-3h3v3l-4 3H9l-2 3h8v3H5v-3l2-3z"/></svg>',
  lab:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 3h6"/><path d="M10 3v6L4.6 18.6A1.6 1.6 0 0 0 6 21h12a1.6 1.6 0 0 0 1.4-2.4L14 9V3"/><path d="M7.5 15h9"/></svg>',
  museum:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12l4 6-10 12L2 9z"/><path d="M2 9h20"/><path d="M12 21 8.5 9 12 3l3.5 6z"/></svg>'};
const HZC = {adit:'#e3a857', flood:'#4fc3e8', fire:'#ff6a3a'}, HZF = {adit:'none', flood:'hue-rotate(-75deg) saturate(1.2)', fire:'hue-rotate(95deg) saturate(1.6) brightness(.95)'};
"""
between("function renderCamp(){", "function bldHTML(id){", ICONS + r"""function renderCamp(){
  $('#wallet').innerHTML = `<span class="chipr">${fmt(save.money)} ₽</span>` + Object.keys(RES).map(r => `<span class="chipr" style="--rc:${RES[r].c}"><i></i>${save.res[r]}</span>`).join('');
  $('#mute').textContent = save.mute ? '🔇' : '🔊';
  $('#campApp').classList.toggle('sub', tab !== 'go');
  const nav = [['go', 'Шахта', 0], ['shop', 'Мастерская', 0], ['lab', 'Лаборатория', save.finds.length], ['museum', 'Музей', 0]];
  let body = '';
  if (tab === 'go') {
    const b = BIOMES[hz], open = save.up.lift >= b.lift;
    body = `<div class="hub">
      <div class="logo"><b>ЗАБОЙ</b><span>войти · найти · вернуться</span></div>
      <div class="spacer"></div>
      <div class="hz" style="--hc:${HZC[b.id]}">
        <button type="button" class="arr" data-hz="-1" aria-label="Выше"${hz === 0 ? ' disabled' : ''}>‹</button>
        <div class="hz-card${open ? '' : ' locked'}" style="--hf:${HZF[b.id]}">
          <div class="hz-art"></div>
          <div class="hz-body"><div class="hz-no">Горизонт ${['I', 'II', 'III'][hz]} · ${b.place}</div><h2>${b.name}</h2><p>${b.hint}</p>
            <div class="tags">${b.events.map(e => `<span style="--tc:${{collapse:'#d9c39a', flood:'var(--water)', lava:'var(--lava)'}[e]}">${{collapse:'обвалы', flood:'подтопление', lava:'лава'}[e]}</span>`).join('')}<span style="--tc:var(--gas)">газ</span><span style="--tc:var(--anom)">ползуны${b.golems ? ', големы' : ''}</span></div>
            <div class="minis">${Object.keys(b.pool).map(id => imgTag(id)).join('')}</div></div>
          ${open ? '' : `<div class="hz-lock">закрыто · лебёдка ${b.lift}</div>`}
        </div>
        <button type="button" class="arr" data-hz="1" aria-label="Глубже"${hz === BIOMES.length - 1 ? ' disabled' : ''}>›</button>
      </div>
      <div class="dots">${BIOMES.map((_, k) => `<i class="${k === hz ? 'on' : ''}"></i>`).join('')}</div>
      ${open ? `<button type="button" class="play" data-run="${b.id}">Спуститься<small>фонарь ${LAMP_T[save.up.lamp]} с · рюкзак ${BAGS[save.up.bag].join('×')} · заряды ${1 + save.up.charge}</small></button>`
        : `<button type="button" class="play off" data-tab="shop">В мастерскую<small>нужна лебёдка уровня ${b.lift}</small></button>`}
      <div class="hub-mini">${save.finds.length ? `<button type="button" class="chip-btn hot" data-tab="lab">Неразобрано: ${save.finds.length}</button>` : ''}<button type="button" class="chip-btn" data-help>Как играть</button>${save.st.best ? `<span class="chip-btn" style="color:var(--lamp)">★ ${save.st.best.name}, ${fmt(save.st.best.value)} ₽</span>` : ''}</div>
    </div>`;
  } else {
    let inner = '', sub = '';
    if (tab === 'shop') { sub = 'снаряжение и лебёдка'; inner = ['workshop', 'lift'].map(id => bldHTML(id)).join(''); }
    else if (tab === 'lab') { sub = `неразобрано: ${save.finds.length}`;
      inner = `${bldHTML('lab')}<div class="sec-h"><h2>Не обработано · ${save.finds.length}</h2></div>
      ${save.finds.length ? `<div class="grid3">${save.finds.map(it => `<button type="button" class="fc dirty" data-find="${it.id}">${itemImg(it)}<span class="n">${itemName(it)}</span><span class="m">${it.g ? fmtW(it.g) : `${it.w}×${it.h}`} · ${it.depth} м</span></button>`).join('')}</div>
        <button type="button" class="btn" data-findall>Обрабатывать по очереди</button>` : '<p class="empty">Трофеев нет. Принесите из шахты друзы, кристаллы и жеоды.</p>'}`; }
    else { const c = save.coll.slice().sort((a, b) => b.value - a.value), sids = Object.keys(SP), got = new Set(save.coll.map(s => s.sid)); sub = `видов: ${got.size} из ${sids.length}`;
      inner = `<div class="sec-h"><h2>Витрина · ${c.length}</h2></div>
      ${c.length ? `<div class="grid3">${c.slice(0, 12).map(s => `<button type="button" class="fc" data-coll="${s.id}" style="--rc:${RC[SP[s.sid].r]}">${imgTag(s.sid)}<span class="n">${SP[s.sid].n}</span><span class="m">${s.g ? fmtW(s.g) : GR[s.gi].n} · ${fmt(s.value)} ₽</span></button>`).join('')}</div>` : '<p class="empty">Пусто. Обработанный трофей можно оставить в музее.</p>'}
      <div class="sec-h"><h2>Коллекция видов · ${got.size} из ${sids.length}</h2></div>
      <div class="grid3">${sids.map(id => `<div class="fc${got.has(id) ? '' : ' lock'}" style="--rc:${got.has(id) ? RC[SP[id].r] : 'var(--line)'}">${imgTag(id)}<span class="n">${got.has(id) ? SP[id].n : '???'}</span><span class="m">${RAR[SP[id].r].toLowerCase()}</span></div>`).join('')}</div>
      ${Object.keys(save.rec).length ? `<div class="sec-h"><h2>Рекорды веса</h2></div><div class="rows">${Object.entries(save.rec).sort((a, b) => (b[0] === 'geode' ? 2 : SP[b[0]].r) - (a[0] === 'geode' ? 2 : SP[a[0]].r) || b[1] - a[1]).map(([k, g]) => `<div class="row"><span>${k === 'geode' ? 'Жеода' : SP[k].n}</span><span>${fmtW(g)}</span></div>`).join('')}</div>` : ''}
      <div class="sec-h"><h2>Журнал</h2></div>
      <div class="rows"><div class="row"><span>Спусков</span><span>${save.st.runs}</span></div><div class="row"><span>Подъёмов</span><span>${save.st.ups}</span></div><div class="row"><span>Выносили спасатели</span><span>${save.st.rescues}</span></div>
        <div class="row"><span>Глубже всего</span><span>${save.st.deepest} м</span></div><div class="row"><span>Монстров одолели</span><span>${save.st.monsters}</span></div><div class="row"><span>Лучшая находка</span><span>${save.st.best ? `${save.st.best.name}, ${fmt(save.st.best.value)} ₽` : '—'}</span></div></div>
      <button type="button" class="ghost" data-reset>Сбросить прогресс</button>`; }
    body = `<div class="view"><div class="vh"><h2>${nav.find(n => n[0] === tab)[1]}</h2><span>${sub}</span></div>${inner}</div>`;
  }
  $('#camp').innerHTML = body + `<nav class="nav">${nav.map(([id, n, c]) => `<button type="button" data-tab="${id}" class="${tab === id ? 'on' : ''}">${ICO[id]}<span>${n}</span>${c ? `<span class="dot">${c}</span>` : ''}</button>`).join('')}</nav>`;
  if (lastTab !== tab) { lastTab = tab; let i = 0; $('#camp').querySelectorAll('.logo, .bld, .fc, .sec-h, .vh, .play').forEach(el => { el.classList.add('fx-in'); el.style.setProperty('--i', Math.min(i++, 14)); }); }
}
""")
rep("  const t = e.target.closest('[data-tab]'); if (t) { tab = t.dataset.tab; return renderCamp(); }",
    "  const t = e.target.closest('[data-tab]'); if (t) { tab = t.dataset.tab; return renderCamp(); }\n"
    "  const h = e.target.closest('[data-hz]'); if (h) { hz = Math.max(0, Math.min(BIOMES.length - 1, hz + +h.dataset.hz)); SFX.step(); return renderCamp(); }")
rep('<section id="camp" style="display:flex;flex-direction:column;gap:10px"></section>', '<section id="camp"></section>')

# help: sneaking and noise
rep("    <li>Ведите пальцем — шахтёр идёт, фонарь светит по ходу.", "    <li>Белый круг вокруг шахтёра показывает, как далеко слышно его шаги. Если вести пальцем недалеко, он крадётся тихо, а удары кайла слышно далеко. Метки «шорох» и «рык» показывают, откуда идёт звук.</li>\n    <li>Ведите пальцем — шахтёр идёт, фонарь светит по ходу.")

open(P, 'w', encoding='utf-8').write(s)
print('ok', len(s))
