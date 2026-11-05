# Kit modular low poly de corredor de masmorra

Kit de módulos de pedra e metal para montagem posterior no Roblox Studio. A cena editável está em `asset.blend`; `asset.glb` contém somente a montagem demonstrativa e seus materiais. O piso de estúdio, as câmeras e as luzes ficam fora dos exports. Os GLBs em `modules/` trazem uma peça por tipo.

## Escala e encaixe

O projeto usa unidades métricas com **1 unidade Blender = 1 metro**. Como referência, 1 stud Roblox ≈ 0,28 m; portanto, cada módulo de 4 m equivale a aproximadamente **14,29 studs**. Use o mesmo fator ao importar e mantenha a escala uniforme.

Piso, parede, canto e arco usam um passo de **4 m**. Os pisos ocupam 4 × 4 m; paredes e arcos cobrem um vão de 4 m de comprimento e 4 m de altura. A abertura do arco tem 2,24 m de largura e 3,57 m de altura, livre até o piso. Posicione os módulos pelo incremento de 4 m e gire paredes/arcos 90° em Z para os trechos perpendiculares. As faces de extremidade e as juntas de canto coincidem; o piso fica a Z=0.

Origens: piso no canto inicial da superfície de caminhada em Z=0 (a laje desce até Z=-0,36 m); parede e arco no canto inicial inferior; canto no vértice inferior do L; coluna no centro da base; tocha no ponto de fixação, com o suporte apontando para +Y. A coluna tem 0,84 × 0,84 × 4 m. A tocha foi pensada como acessório de parede e pode ser girada em Z para apontar para dentro do corredor.

## Arquivos

- `asset.blend` — cena editável, biblioteca dos seis módulos, demonstração e coleção `STUDIO` separada.
- `asset.glb` — demonstração em L com passagem de entrada e saída em arco.
- `modules/SM_Floor_4m.glb`
- `modules/SM_Wall_4m.glb`
- `modules/SM_Corner_4m.glb`
- `modules/SM_DoorArch_4m.glb`
- `modules/SM_Column_4m.glb`
- `modules/SM_Torch.glb`
- `front.png`, `back.png`, `presentation.png` — renders de 768 × 768 px.
- `generate.py` — gerador da cena, materiais, montagem, renders e exports.

Os materiais são cores PBR sólidas Principled, sem imagens ou caminhos externos. Os nomes dos objetos e materiais seguem prefixos `SM_` e `M_`. O GLB principal tem malhas low poly e não inclui animações, câmera ou iluminação.

## Revisão

O kit foi gerado e renderizado com Blender 5.2.3, Cycles CPU e 4 threads. A QA Roblox das seis peças passa: cada módulo é fechado, tem uma UV em 0–1 e permanece abaixo de 3 mil triângulos. A montagem usa peças separadas que se sobrepõem nas juntas de 90°; a QA sinaliza seis pares de faces coplanares nesses cantos. Não se veem frestas nos renders, mas essas juntas podem precisar de união/limpeza adicional se aparecer cintilação de profundidade após importação em tempo real. As uniões do suporte da tocha e as pedras/capas do canto também retêm faces internas sobrepostas, sem peças flutuantes.

Veja `execution-log.txt` e `logs/` para comandos, resultados de geometria e exportação. Abra `asset.blend` para inspecionar a passagem por dentro e as faces inferiores.
