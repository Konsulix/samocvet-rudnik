"""Top-down sprites and tileable textures for «Забой» via OpenRouter (GPT Image 2)."""
import os, sys, concurrent.futures as cf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_images as g

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets', 'raw')
TOP = ('Top-down orthographic view, seen from directly above, sprite for a dark atmospheric mobile game, painterly realistic style, '
       'soft light from above, centered, the subject fills about 80% of the frame, isolated on a perfectly flat solid magenta background '
       '(#FF00FF) with no gradient and no cast shadow. No text, no border.')
TEX = ('Seamless tileable square texture, seen from directly above, even flat lighting with no shadows and no vignette, '
       'photorealistic, no objects, no text. ')
JOBS = [
    ('miner_top', TOP + ' Subject: a miner in a worn brown canvas jacket and a brass helmet with a small carbide lamp on the front, '
                  'carrying a pickaxe over one shoulder, seen from directly above; the head and lamp point to the top edge of the image.'),
    ('crawler_top', TOP + ' Subject: a pale, eyeless cave crawler creature with a flat segmented chitin body and eight long thin jointed legs '
                    'spread out like a spider, seen from directly above; the head points to the top edge of the image.'),
    ('golem_top', TOP + ' Subject: a hunched rock golem made of dark grey boulders, with pale blue crystals growing out of its back and shoulders, '
                  'seen from directly above; the head points to the top edge of the image.'),
    ('moss_top', TOP + ' Subject: an irregular round patch of damp cave moss with tiny pale ferns, lichen and a few small blue mushrooms, seen from directly above.'),
    ('floor_tex', TEX + 'Dark cave floor: packed damp dirt, fine gravel and scattered small stones, muted brown-grey tones.'),
    ('rock_tex', TEX + 'Dark rough rock surface with cracks and subtle layered mineral strata, muted grey-brown tones.'),
]


def run(job):
    name, prompt = job
    path = os.path.join(OUT, name + '.png')
    if os.path.exists(path):
        return name, 'exists'
    png, usage = g.call(prompt, None, '1:1')
    open(path, 'wb').write(png)
    return name, round(usage.get('cost', 0), 3)


if __name__ == '__main__':
    with cf.ThreadPoolExecutor(3) as ex:
        for f in cf.as_completed([ex.submit(run, j) for j in JOBS]):
            try:
                print(f.result(), flush=True)
            except Exception as e:
                print('ERROR', e, flush=True)
