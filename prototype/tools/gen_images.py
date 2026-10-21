"""Generate the game's image set through OpenRouter.

Usage: python gen_images.py [name ...]   (no names = everything missing)
The first specimen (quartz) is used as a PNG style reference for the others.
"""
import base64, json, os, sys, concurrent.futures as cf, urllib.request

MODEL = 'openai/gpt-5.4-image-2'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets', 'raw')
os.makedirs(OUT, exist_ok=True)

STYLE = ('Museum-quality macro photograph of a single natural mineral specimen, centered, isolated on a pure black (#000000) '
         'seamless background, soft studio key light from the top left and a subtle rim light, sharp focus, true-to-life colors, '
         'square 1:1 composition with the specimen filling about 75% of the frame. No text, no labels, no stand, no hands.')
REF_NOTE = ('Match the reference image exactly in lighting, pure black background, camera distance, framing and photographic '
            'style, but show the new subject described here.')

JOBS = [
    ('quartz', 'Subject: a cluster of clear rock crystal quartz points with glassy hexagonal terminations.', None),
    ('malachite', 'Subject: natural botryoidal malachite with rounded bubbly surface and concentric green banding.', '1:1'),
    ('selenite', 'Subject: a fan of long transparent selenite gypsum blades with satin luster.', '1:1'),
    ('fluorite', 'Subject: a cluster of green cubic fluorite crystals with purple colour zoning at the edges.', '1:1'),
    ('garnet', 'Subject: a group of deep red garnet rhombic dodecahedron crystals on a small grey matrix.', '1:1'),
    ('beryl', 'Subject: a hexagonal pale green-yellow beryl crystal column standing on white feldspar matrix.', '1:1'),
    ('gold', 'Subject: a natural gold nugget, irregular rounded shape, rich metallic yellow, small quartz inclusions.', '1:1'),
    ('opal', 'Subject: a rough precious opal nodule broken open, vivid play-of-color flashes of blue, green and red in the cut face.', '1:1'),
    ('corundum', 'Subject: a rough blue sapphire corundum crystal, barrel-shaped hexagonal bipyramid, natural unpolished.', '1:1'),
    ('diamond', 'Subject: a rough natural octahedral diamond crystal with adamantine luster, sitting in dark blue-grey kimberlite.', '1:1'),
    ('nodule', 'Subject: a closed, unopened rock nodule: roundish weathered brown-grey stone with rough pitted crust. No crystals visible.', '1:1'),
    ('geode', 'Subject: a geode broken into two halves that rest slightly apart, the cavity lined with sparkling purple amethyst crystals.', '1:1'),
    ('ammonite', 'Subject: a fossil ammonite shell in a piece of grey limestone, clear spiral ribs, natural not polished.', '1:1'),
    ('mine_bg', 'Moody vertical background illustration for a mobile game: a dark underground mine shaft going deep down, timber supports, '
                'a few warm lantern lights near the top fading to cold darkness at the bottom, faint glints of crystals in the rock walls. '
                'Painterly but realistic, low contrast, lots of empty dark space in the middle for UI. No text.', '9:16'),
    ('key_art', 'Key art for a mobile game about mining minerals: a miner\'s brass lantern lighting up a large open amethyst geode '
                'in a dark rock face, warm and violet light, cinematic, realistic. No text, no people.', '1:1'),
]


def call(prompt, ref_png=None, aspect='1:1'):
    content = [{'type': 'text', 'text': prompt}]
    if ref_png:
        content.append({'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,' + base64.b64encode(ref_png).decode()}})
    body = {'model': MODEL, 'modalities': ['image', 'text'], 'messages': [{'role': 'user', 'content': content}],
            'image_config': {'aspect_ratio': aspect}}
    req = urllib.request.Request('https://openrouter.ai/api/v1/chat/completions', data=json.dumps(body).encode(),
                                 headers={'Authorization': 'Bearer ' + os.environ['OPENROUTER_API_KEY'], 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.load(r)
    msg = data['choices'][0]['message']
    imgs = msg.get('images') or []
    if not imgs:
        raise RuntimeError('no image returned: ' + str(msg.get('content'))[:300])
    url = imgs[0]['image_url']['url']
    return base64.b64decode(url.split(',', 1)[1]), data.get('usage', {})


def run(job, ref):
    name, subject, aspect = job
    path = os.path.join(OUT, name + '.png')
    if os.path.exists(path):
        return name, 'exists', {}
    is_specimen = aspect == '1:1' and name not in ('key_art',)
    prompt = (STYLE + ' ' + subject + ' ' + REF_NOTE) if is_specimen and ref else (STYLE + ' ' + subject if name not in ('mine_bg', 'key_art') else subject)
    png, usage = call(prompt, ref if is_specimen else None, aspect or '1:1')
    with open(path, 'wb') as f:
        f.write(png)
    return name, 'ok', usage


if __name__ == '__main__':
    want = set(sys.argv[1:])
    jobs = [j for j in JOBS if not want or j[0] in want]
    ref_path = os.path.join(OUT, 'quartz.png')
    if not os.path.exists(ref_path):
        print(run(JOBS[0], None), flush=True)
    ref = open(ref_path, 'rb').read()
    with cf.ThreadPoolExecutor(4) as ex:
        for fut in cf.as_completed([ex.submit(run, j, ref) for j in jobs if j[0] != 'quartz']):
            try:
                print(fut.result(), flush=True)
            except Exception as e:
                print('ERROR', e, flush=True)
