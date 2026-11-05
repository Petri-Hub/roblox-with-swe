# Blender headless com Luna: seis comparações

[**Abrir PDF global — 22 páginas**](global-report.pdf) · [Dados CSV](comparison.csv) · [Dados JSON](comparison-data.json) · [Síntese Markdown](GLOBAL-REPORT.md)

Estudo exploratório com dois `gpt-6-luna` (medium) por pedido, um com acesso ao pacote fixo de skills e outro sem consulta autorizada. Foram seis pares em contextos separados: a torre inicial e cinco categorias adicionais, executadas uma de cada vez.

## PDFs individuais

| Caso | Triângulos no GLB: A com skills | B sem skills | Relatório |
|---|---:|---:|---|
| Torre medieval: Blender com e sem skills | 4,929 | 7,708 | [PDF](report.pdf) · [MD](REPORT.md) |
| Blaster arcano: prop de jogo com e sem skills | 868 | 5,216 | [PDF](cases/01-arcane-blaster/report.pdf) · [MD](cases/01-arcane-blaster/REPORT.md) |
| Vigia do Brejo: criatura com rig e idle | 1,428 | 5,556 | [PDF](cases/02-horror-creature/report.pdf) · [MD](cases/02-horror-creature/REPORT.md) |
| Capela abandonada: cenário estático e composição | 4,108 | 7,404 | [PDF](cases/03-haunted-courtyard/report.pdf) · [MD](cases/03-haunted-courtyard/REPORT.md) |
| Moinho: cenário animado, exportação e interseções | 1,680 | 2,002 | [PDF](cases/04-windmill-motion/report.pdf) · [MD](cases/04-windmill-motion/REPORT.md) |
| Kit modular: peças, encaixes e circulação | 19,516 | 9,212 | [PDF](cases/05-roblox-modular-kit/report.pdf) · [MD](cases/05-roblox-modular-kit/REPORT.md) |

## O que está medido

Cada PDF traz polígonos e triângulos-base, triângulos avaliados com modificadores, triângulos efetivamente exportados, vértices de posição no GLB, definições de malha, instâncias, materiais, clipes, dimensões, tamanhos de arquivos, tempo registrado e skills consultadas. As contagens finais foram confrontadas diretamente com o glTF. Há 48 PNGs de entrega dos agentes, além de 12 renders neutros dos módulos produzidos pelo avaliador.

[Galeria HTML — abrir localmente após baixar](comparison.html) · [Protocolo e limitações](PROTOCOL.md) · [Verificações](validation.json) · [Hashes dos arquivos](SHA256SUMS.txt)

### Correções e limites importantes

- A primeira auditoria da criatura contou uma Icosphere auxiliar do importador (80 triângulos). Os números finais corrigidos são 1.428 em A e 5.556 em B; os JSONs anteriores foram preservados.
- O kit A declarou 5.548 triângulos-base, mas o GLB final contém 19.516. Não se confundem base, resultado avaliado e exportação.
- Alguns GLBs omitiram modificadores presentes no render. A tabela mostra essas diferenças.
- Tokens reais e custo monetário não foram expostos: não há estimativa disfarçada de medição. Tempo inclui ferramentas, render, correções e retomadas do ambiente.
- Uma execução por condição, avaliação não cega, recursos/filesystem compartilhados. Não houve Roblox Studio, teste de avatar, colisões de engine, FPS ou draw calls. A análise registra também falhas dos assets e do próprio método de auditoria.

## Reprodução dos relatórios

Python 3 com as dependências de [requirements-report.txt](requirements-report.txt) e fonte DejaVu Sans. Os relatórios podem ser reconstruídos com os dados preservados:

```sh
python build_reports.py tower-report.json cases/01-arcane-blaster/report-config.json cases/02-horror-creature/report-config.json cases/03-haunted-courtyard/report-config.json cases/04-windmill-motion/report-config.json cases/05-roblox-modular-kit/report-config.json
python build_global.py
python build_gallery.py
python validate_reports.py
```

O runtime usado foi Blender 5.2.3 LTS. As skills foram consultadas no commit `fb92cfb4cc5a238c22113a6a230b09f535bd0656` de [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills), sem instalação global e sem alterações rastreadas no pacote. Runtime e pacote completo não foram adicionados ao repositório.

Os scripts dos agentes e de coleta podem conter caminhos absolutos da sessão; consulte os READMEs antes de regenerar modelos. Os arquivos originais foram preservados, sem correção de modelagem pelo avaliador. O código do jogo não foi alterado.