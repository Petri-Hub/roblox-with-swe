# Estudo exploratório: Blender, Luna e skills

Comparações pareadas com `gpt-6-luna` (medium), com e sem o pacote `EL4CTEO/blender-skills`, usando Blender 5.2.3 headless. Um par por categoria; execução dos casos adicionais em sequência.

## Relatório concluído

- [Torre medieval — PDF](report.pdf)
- [Análise em Markdown](REPORT.md)
- [Galeria lado a lado](comparison.html)
- [Dados medidos](metrics.json)
- [Pedido literal](request.txt)

## Expansão autorizada em andamento

1. [Blaster arcano fictício — PDF concluído](cases/01-arcane-blaster/report.pdf).
2. [Criatura de terror com rig e idle — PDF concluído](cases/02-horror-creature/report.pdf).
3. [Pátio de capela abandonada — PDF concluído](cases/03-haunted-courtyard/report.pdf).
4. [Moinho com animação de cenário — PDF concluído](cases/04-windmill-motion/report.pdf).
5. Kit modular para uso posterior no Roblox — em execução.

Cada caso terá pedido, arquivos dos dois agentes, métricas, imagens e seu próprio PDF. O relatório global será produzido após a conclusão dos cinco casos adicionais.

## Reprodução dos relatórios

Python 3 com `matplotlib`, `reportlab` e `Pillow`; fonte DejaVu Sans em `/usr/share/fonts/truetype/dejavu`.

```sh
python build_reports.py tower-report.json
```

Os scripts e cenas originais foram preservados. O runtime Blender e o pacote completo de skills não são versionados aqui; o commit das skills está no manifesto. Tokens reais não estão disponíveis. A avaliação é exploratória e não cega; duração e quantidade de skills não equivalem a consumo de tokens.
