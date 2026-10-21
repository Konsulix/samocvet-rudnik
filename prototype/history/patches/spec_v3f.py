p = 'specimen.js'; s = open(p, encoding='utf-8').read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:80]); s = s.replace(a, b)
rep("  const irk = tr.has('aurora')", "  let irk = tr.has('aurora')")
rep("  const mat = metal || ['nugget', 'botryoid'].includes(layout) ? null : cmat();",
"""  // some columns are dark and oily with a rainbow sheen, like hematite-coated quartz
  const dark = layout === 'columnar' && !metal && rng() < .22;
  if (layout === 'columnar') irk = Math.max(irk, dark ? 1.05 : .3);
  const mat = metal || ['nugget', 'botryoid'].includes(layout) ? null : cmat();
  if (dark && mat) { mat.color.setRGB(.09, .09, .1); mat.opacity = .93; mat.metalness = .45; mat.roughness = .1; mat.emissive.multiplyScalar(.3); }""")
rep("  if (cols.length && (tr.has('coral') || rng() < .35)) {", "  if (cols.length && (tr.has('coral') || rng() < .2)) {")
rep("const r = Math.pow(rng(), .7) * .2, v = p.clone().addScaledVector(d, r).addScaledVector(nn, (.2 - r) * .25 * rng());", "const r = Math.pow(rng(), .7) * .12, v = p.clone().addScaledVector(d, r).addScaledVector(nn, (.12 - r) * .3 * rng());")
rep("sc.set(.005, .02 + rng() * .045, .005);", "sc.set(.004, .015 + rng() * .03, .004);")
open(p, 'w', encoding='utf-8').write(s); print('ok')
