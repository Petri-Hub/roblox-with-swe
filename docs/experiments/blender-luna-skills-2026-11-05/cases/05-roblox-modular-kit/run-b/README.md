# Kit modular — Corredor da masmorra

Kit low poly para composição de corredores e entradas no Roblox Studio. Os módulos-fonte estão nas coleções `MODULE | ...`; a montagem de demonstração está em `DEMO | curved corridor and traversable entrance`. Os objetos de iluminação, câmera e chão do estúdio ficam em `STUDIO | render only` e não entram nos GLBs.

## Escala e encaixe

A escala de trabalho é 1 unidade Blender = 1 stud (unidade de referência do Roblox). A grade horizontal é de 4 unidades. Pisos medem 4 × 4 unidades; paredes e o arco medem 4 unidades de largura e altura, com 0,4 unidade de espessura. O arco deixa passagem livre de cerca de 1,4 unidade de largura por 3,1 de altura. Mantenha centros dos pisos e paredes em múltiplos de 4, com a superfície superior do piso em Z=0. Gire os módulos em passos de 90° em torno de Z para virar esquinas. O módulo de canto fornece dois braços de 4 unidades em ângulo reto. Coluna e tocha são acentos de colocação livre; a origem do módulo da tocha é o plano de montagem na parede.

Para repetir um trecho reto, duplique o piso e as paredes laterais em deslocamentos de (4,0,0) e mantenha as paredes a y=±2 em relação à linha central do corredor. Para virar, continue a fileira de piso no eixo perpendicular e gire os trechos de parede; alinhe os centros à mesma grade. O GLB consolidado contém os módulos-fonte e a montagem demonstrativa; `modules/` contém um GLB por tipo de módulo.

## Arquivos

- `asset.blend`: cena editável, módulos, montagem, câmeras e estúdio.
- `asset.glb`: módulos e montagem demonstrativa, com materiais embutidos.
- `modules/floor.glb`, `wall.glb`, `corner.glb`, `doorarch.glb`, `column.glb`, `torch.glb`: arquivos separados por tipo.
- `front.png`, `back.png`, `presentation.png`: renders 768 × 768.
- `generate.py`: script de geração e exportação usado no Blender 5.2.3.

## Observações

As peças usam malhas low poly e cores de material embutidas; não há texturas externas. Os módulos repetidos têm alívio geométrico de pedra e arestas chanfradas para leitura visual. A montagem é uma demonstração compacta e aberta no topo para permitir avaliar a circulação. Inspecione a colisão final dentro do Roblox Studio antes de publicar, pois a exportação fornece geometria visual e não configura colisores do jogo.
