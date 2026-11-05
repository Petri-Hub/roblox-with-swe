# Pátio da capela assombrada

Diorama low poly de um pátio abandonado, com entrada de capela, caminho de pedras, portão de ferro quebrado, poço e vegetação seca esparsa. A composição e a iluminação fria de luar conduzem ao portal; uma lanterna quente marca a entrada. Não há sangue nem dependências externas.

## Entregas

- `asset.blend` — cena editável, com asset, câmeras e iluminação de apresentação em coleções separadas.
- `asset.glb` — somente a coleção do asset, com malhas e materiais; chão de estúdio, luzes e câmeras ficam fora.
- `generate.py` — script reprodutível de geração e renderização.
- `front.png`, `back.png`, `presentation.png` — imagens finais de 768 × 768 px.

## Escala e conteúdo

A base mede aproximadamente 10,2 × 8,4 m; o conjunto tem cerca de 4,3 m de altura. A cena contém 151 objetos de malha e 4.108 triângulos, com materiais Principled de cor sólida e sem imagens externas. O render usa Blender 5.2.3, Cycles CPU, quatro threads e denoise.

## Regenerar

Execute na pasta deste projeto:

```bash
BLENDER_EXE=/caminho/para/blender-5.2.3-linux-x64/blender
BLENDER_USER_CONFIG="$PWD/config" BLENDER_USER_CACHE="$PWD/cache" HOME="$PWD/cache/home" \
  "$BLENDER_EXE" -b --factory-startup --threads 4 --python-exit-code 1 -P generate.py
```

`asset.glb` é exportado da coleção `ASSET_HauntedCourtyard`; a iluminação de cena e os elementos de apresentação não entram na seleção.

## Revisão

O QA final do Blender passou sem erros. Permanecem avisos de n-gons nas tampas planas de alguns cilindros/barras e de faces coincidentes em junções internas de ferragens, intencionais para este diorama renderizado. As três vistas foram abertas e inspecionadas após as correções; o GLB foi reimportado em cena vazia para conferir o conteúdo.
