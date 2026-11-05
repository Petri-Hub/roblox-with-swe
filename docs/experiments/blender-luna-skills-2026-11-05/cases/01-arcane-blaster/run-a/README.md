# Arcane Blaster

Prop de fantasia científica low poly, montado proceduralmente em Blender 5.2.3. O corpo usa aethersteel, placas metálicas claras, ferragens de latão, empunhadura escura e elementos de cristal emissivo ciano. A frente da arma aponta para +X no Blender.

## Entregáveis

- `asset.blend`: cena editável, com coleção `ARCANE_BLASTER_ASSET` separada de `STUDIO_NOT_EXPORTED`.
- `asset.glb`: somente objetos e materiais do asset; chão, câmeras e luzes de estúdio foram excluídos.
- `generate.py`: script reprodutível de geração, renderização e exportação.
- `front.png`, `back.png`, `presentation.png`: imagens 768×768 em Cycles CPU.

Para regenerar, use Blender 5.2.3 ou posterior em modo background e execute `generate.py`. O script define Cycles CPU e 4 threads.
