import os
P = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zaboy.html')
s = open(P, encoding='utf-8').read()
i = s.index('  wallMat.onBeforeCompile = sh => {')
j = s.index('  walls = new THREE.InstancedMesh(', i)
new = r'''  wallMat.onBeforeCompile = sh => {
    sh.uniforms.uP = WALLCUT;
    sh.vertexShader = sh.vertexShader.replace('#include <common>', `#include <common>
      varying vec3 vWP;`).replace('#include <project_vertex>', `#include <project_vertex>
      #ifdef USE_INSTANCING
        vWP = (modelMatrix * instanceMatrix * vec4(transformed, 1.0)).xyz;
      #else
        vWP = (modelMatrix * vec4(transformed, 1.0)).xyz;
      #endif`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', `#include <common>
      uniform vec3 uP; varying vec3 vWP;`).replace('#include <clipping_planes_fragment>', `#include <clipping_planes_fragment>
      vec2 cd = vWP.xz - uP.xz;
      if (vWP.y > .3 && cd.y > .4 && cd.y < 2.8 && abs(cd.x) < 1.1 + cd.y * .3 && mod(floor(gl_FragCoord.x) + floor(gl_FragCoord.y), 2.0) < 1.0) discard;`);
  };
'''
s = s[:i] + new + s[j:]
open(P, 'w', encoding='utf-8').write(s)
print('ok')
