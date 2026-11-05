# Vigia do Brejo

Criatura low poly articulável, criada no Blender 5.2.3. A cena usa escala métrica e inclui o rig `RIG_VigiaDoBrejo`, com o clipe cíclico `VigiaDoBrejo_Idle` (48 quadros, 24 fps). O idle anima coluna, cabeça e braços com respiração e deriva sutil. O GLB inclui apenas a coleção `ASSET_VigiaDoBrejo`, seus materiais, armature e animação. O set de estúdio (chão, luzes e câmeras) fica no `.blend` e não é exportado.

## Arquivos

- `asset.blend`: cena editável com o rig, animação, estúdio e renders configurados.
- `asset.glb`: criatura e materiais autossuficientes, com armature e animação.
- `generate.py`: script determinístico de geração, render e exportação.
- `front.png`, `back.png`, `presentation.png`: vistas de avaliação 768×768.
- `pose-01.png`, `pose-24.png`, `pose-48.png`: frames para checar a deformação.

## Regenerar

Use Blender 5.2.3 em background com Cycles CPU. `generate.py` escreve saídas na pasta em que reside. O script limita o render a 4 threads.
