# Vigia do Brejo

Criatura low poly articulada, construída proceduralmente no Blender. O asset usa um esqueleto simples, placas ósseas, pele de brejo e abertura luminosa. A animação idle percorre 48 quadros a 24 fps, com respiração e oscilações sutis.

## Arquivos
- `asset.blend`: cena editável, incluindo rig, animação e estúdio de render.
- `asset.glb`: somente criatura, rig, materiais e animação; chão, câmeras e luzes ficam de fora.
- `front.png`, `back.png`, `presentation.png`: renders 768×768.
- `pose-01.png`, `pose-24.png`, `pose-48.png`: poses para revisão da animação.
- `generate.py`: script para recriar a cena e as entregas.

## Recriar
Execute `blender --background --python generate.py`. O script configura Cycles CPU, quatro threads e renderiza os arquivos na pasta atual.
