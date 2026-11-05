# Moinho low-poly animado

Cena de moinho estilizado sobre uma ilhota, com pás em rotação e três tufos de folhas oscilando num ciclo de 48 quadros a 24 fps. O rotor fica à frente da torre, apoiado por eixo e cubo de latão.

## Arquivos

- `asset.blend`: cena editável, incluindo câmeras e iluminação de estúdio.
- `asset.glb`: exportação GLB do asset e seus materiais; chão, câmeras e luzes de estúdio ficam de fora.
- `front.png`, `back.png`, `presentation.png`: renders quadrados de 768 × 768.
- `motion-01.png`, `motion-16.png`, `motion-32.png`: amostras para inspecionar a animação.
- `generate.py`: script de construção e render.

Para regenerar com Blender 5.2.3, defina `BLENDER_EXE` e execute `"$BLENDER_EXE" -b --python generate.py`.
