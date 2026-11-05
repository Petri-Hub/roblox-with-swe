# Comparação das torres medievais

Nesta execução, prefiro a versão B (sem skills) como ponto de partida visual. A versão A (com skills) é mais leve e demonstrou uma revisão técnica mais sistemática, mas não resolveu a passagem da escada nem tornou todos os apoios convincentes. Nenhuma entrega está pronta para produção sem ajustes.

## Condições

Dois subagentes gpt-6-luna, reasoning medium, sem histórico da conversa. Mesmo pedido natural, sem mencionar comparação ou benchmark e sem Roblox: torre medieval low poly com madeira, escada acessível, plataforma, guarda-corpo, cobertura e materiais. Entregas: .blend, GLB, três PNGs 768², gerador e README. Ambos autorizados a revisar e corrigir suas próprias cenas, CPU e quatro threads. Blender 5.2.3 LTS portátil, download oficial com SHA256 verificado. Skills EL4CTEO/blender-skills fixadas em fb92cfb4cc5a238c22113a6a230b09f535bd0656, sem instalação global.

A diferença nas instruções foi o acesso e uso do pacote. A usou /run-a, B /run-b. A separação foi por pasta e instrução; não houve isolamento de segurança entre sistemas de arquivos. Os agentes não receberam os resultados um do outro, e eu não forneci dicas de modelagem durante as execuções. Enviei a mesma solicitação de andamento/finalização a ambos. Não houve prazo rígido nem orçamento idêntico de tokens.

## Medidas

| Medida | A: com skills | B: sem skills |
|---|---:|---:|
| Tempo decorrido registrado | 9 min 10 s | 5 min 44 s |
| SKILL.md consultados, conforme log | 7 | 0 |
| Triângulos no GLB reimportado | 4.929 | 7.708 |
| Objetos de malha no GLB | 113 | 146 |
| Materiais no GLB | 8 | 7 |
| tower.blend | 156.927 bytes | 177.713 bytes |
| tower.glb | 320.452 bytes | 476.400 bytes |
| Renders | 3 × 768 × 768 | 3 × 768 × 768 |
| Tokens reais | não disponíveis | não disponíveis |

A usou aproximadamente 36% menos triângulos e seu GLB ocupa 33% menos bytes. Seu tempo foi cerca de 60% maior. Tempo é duração total registrada pelos agentes, incluindo renderização, revisão e chamadas, em máquina compartilhada; não é medição de custo computacional ou de tokens. Quantidade de objetos não equivale a draw calls medidas.

As sete skills registradas por A foram core, scene-setup, pbr-materials, export-pipelines, rendering, lighting-lookdev e asset-qa. Também leu o AGENTS.md do pacote. B declarou nenhuma consulta. O registro de leitura não é auditoria independente do acesso a arquivos. Não há telemetria de tokens por agente exposta pelas ferramentas desta sessão; tamanho do código e duração não substituem esse dado.

## Avaliação visual e funcional

**B, sem skills:** a cobertura de quatro águas, as diagonais em X, os detalhes de ferro e a diferenciação das peças dão uma impressão mais acabada. A apresentação enquadra bem o objeto, com vistas frente/trás mais diretas. O acesso à plataforma tem abertura no guarda-corpo. A escada, porém, é muito íngreme e merece rever a transição para o piso. A cobertura tem uma falha verificável no gerador: termina em uma abertura quadrada no topo e a estreita peça de cumeeira não fecha essa abertura. Há interseções de elementos e os encaixes devem ser revisados. Maior detalhamento também aumentou geometria e arquivo.

**A, com skills:** silhueta simples e legível, telhado de duas águas, bandeirola e paleta quente/fria agradável. Menos geometria e nomenclatura/coleções mais organizadas. O agente relatou correções de sobreposição das placas do telhado, bevel degenerado nos rebites e UV da bandeirola. Entretanto, as barras frontais do guarda-corpo cruzam a chegada da escada, contrariando a intenção expressa no comentário do próprio script. Os apoios da cobertura e os encontros das travessas precisam de revisão de construção; não basta a aparência isolada das peças. As vistas denominadas frente/trás são oblíquas, e a linha de horizonte no fundo prejudica um pouco sua apresentação.

As duas versões usam majoritariamente primitivas e cores de materiais. Nenhuma é um exemplo de grande complexidade de escultura ou texturização. Eu não daria vitória geral automática às skills neste caso: escolheria B para continuar a direção artística, e aproveitaria de A a disciplina de organização e revisão.

## Verificações e limites

Abri e inspecionei visualmente os seis renders; conferi os cabeçalhos PNG; reabri os dois .blend durante a avaliação e reimportei os GLBs finais no Blender com sucesso, contando a geometria exportada. Os GLBs não declaram imagens externas. Reabri também os dois .blend finais após a conclusão dos agentes. As métricas principais da tabela são do GLB final, não da malha base antes dos modificadores.

A declarou QA final sem erros/avisos, mas a passagem bloqueada mostra que isso não comprova correção funcional. Não apliquei a B o mesmo pacote automatizado de QA de A; não comparo taxas de aprovação desses verificadores. As inspeções independentes de abertura, importação, PNG e contagem de geometria foram iguais para ambas. Não testei navegação de personagem, colisão nem engine de jogo.

A avaliação não foi cega: tive conhecimento das pastas/condições ao acompanhar as execuções. Há somente uma amostra por condição e liberdade artística, de composição e número de revisões. Portanto, o resultado não demonstra que dispensar skills seja melhor em geral, nem permite concluir custo por token. Mostra que, neste pedido e modelo, mais orientação técnica não se converteu automaticamente em melhor resultado geral.

## Arquivos

- Pedido comum: ../request.txt
- Condições e versão: ../manifest.json
- A: ../run-a/ (com skills)
- B: ../run-b/ (sem skills)
- Contagens da reimportação: glb-a.json e glb-b.json
- Galeria lado a lado: ../comparison.html
