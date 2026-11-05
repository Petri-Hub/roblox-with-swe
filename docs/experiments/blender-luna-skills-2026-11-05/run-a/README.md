# Torre de vigia medieval

Torre de fantasia low poly com quatro pilares ligeiramente inclinados, travessas diagonais e plataforma elevada. A escada frontal chega ao piso; guarda-corpo, telhado de duas águas e bandeirola completam a silhueta. Madeira quente, ardósia azul-esverdeada, ferragens escuras e sapatas de pedra foram separados em materiais para facilitar ajustes no jogo.

## Arquivos

- `tower.blend`: cena completa, com câmeras, luzes e fundo de apresentação.
- `tower.glb`: geometria e materiais da torre, sem o cenário de estúdio.
- `front.png`, `back.png`, `presentation.png`: renders quadrados de 768 × 768.
- `create_tower.py`: script fonte que gera a cena.
- `refine_render.py`: ajuste final de nomes, fundo e exportação/renders.

## Reproduzir

Com Blender 5.2.3 ou compatível, execute da pasta do projeto:

```sh
blender -b --threads 4 --python create_tower.py
```

O script escreve o `.blend`, `.glb` e os três PNGs na pasta atual. `refine_render.py` reaplica o ajuste de apresentação final sobre o `.blend` gerado.
