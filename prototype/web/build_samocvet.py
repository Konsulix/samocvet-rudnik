import os
D = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(D, 'samocvet_src.html'), encoding='utf-8').read()
spec = open(os.path.join(D, 'specimen.js'), encoding='utf-8').read()
assert src.count('/*SPECIMEN*/') == 1
open(os.path.join(D, 'samocvet.html'), 'w', encoding='utf-8').write(src.replace('/*SPECIMEN*/', spec))
print('built')
v = open(os.path.join(D, 'vitrina_src.html'), encoding='utf-8').read()
assert v.count('/*SPECIMEN*/') == 1
open(os.path.join(D, 'vitrina.html'), 'w', encoding='utf-8').write(v.replace('/*SPECIMEN*/', spec))
print('built vitrina')
