# Protocolo e limitações de execução

## Objetivo

Documentar entregas produzidas por GPT-6 Luna em Blender headless, comparando um agente com acesso a um pacote fixo de skills e outro sem esse acesso autorizado. Não estimar tokens que as ferramentas não expõem. Preservar acertos, falhas e divergências dos agentes sem corrigir suas modelagens após a entrega.

## Desenho

- Torre inicial, seguida de cinco pedidos adicionais, um par por categoria.
- Cada par: dois subagentes novos, `model=gpt-6-luna`, `reasoning_effort=medium`, `fork_turns=none`.
- Ambos recebem o mesmo pedido literal, preservado em `request.txt`; não são informados de benchmark ou comparação.
- Os dois agentes de um caso podem trabalhar simultaneamente; o caso seguinte só começa após a conclusão e o PDF do caso anterior.
- Agentes têm pastas diferentes. Essa é separação por instruções, com a mesma máquina e o mesmo sistema de arquivos; não é um controle de segurança entre containers.
- A recebe o caminho de `EL4CTEO/blender-skills` no commit `fb92cfb4cc5a238c22113a6a230b09f535bd0656`, lê `AGENTS.md`, começa por `blender-core` e escolhe skills pertinentes.
- B é instruído a não consultar skills, referências ou scripts desses pacotes e usa seu conhecimento de Blender e a API instalada.
- Sem internet, consulta cruzada de resultados ou novos subagentes autorizados; configuração e cache devem ficar na pasta de trabalho.
- Blender 5.2.3 LTS, CLI/headless, Cycles CPU, até quatro threads. Renderização e análise de imagem disponíveis para ambos.
- Ambos podem revisar e corrigir suas entregas autonomamente. Não há orçamento fixo de tokens, número idêntico de revisões ou limite artificial de tempo.

## Instruções operacionais comuns dos cinco casos adicionais

“Leia o pedido de trabalho em [pasta do caso]/request.txt e execute-o por completo. Não leia pastas ou resultados de outros agentes. Use /workspace/blender-study/tools/blender-5.2.3-linux-x64/blender, em modo headless, Cycles CPU, até 4 threads; configure BLENDER_EXE se necessário. Configuração e cache devem ficar na sua pasta. Não use internet, outras skills externas nem subagentes. Use seu julgamento para definir o trabalho e as revisões necessárias. Registre início/fim em UTC, comandos executados, falhas e correções em execution-log.txt. Guarde as saídas de execução/QA em logs dentro da sua pasta. Não peça aprovação; conclua as entregas com uma revisão visual real das imagens e reporte limitações honestamente. Ao concluir informe arquivos, verificações e skills consultadas.”

A diferença operacional é a instrução para A consultar e registrar as skills, versus a proibição e o registro de ausência para B. As pastas também são distintas. Os pedidos naturais dos objetos permanecem iguais em cada par.

## Intervenções do avaliador

Não foram dadas dicas artísticas ou de implementação após os pedidos. Na torre houve solicitação simétrica de andamento/finalização. No blaster houve sinalização de reinício do ambiente, seguida de retomada dos dois agentes sobre os artefatos preservados. A retomada foi registrada e a duração integral desse caso não é conhecida. Solicitações operacionais de andamento, quando necessárias, são documentadas; não equivalem a uma nova tentativa do pedido.

## Medidas

- Tamanhos de arquivo, dimensões dos PNGs, reabertura dos `.blend` e reimportação dos GLBs são conferidos independentemente.
- A geometria principal comparada vem do GLB final, com as opções de exportação escolhidas pelos agentes. Polígonos-base e triângulos avaliados do .blend são medidos separadamente para detectar modificadores omitidos ou aumentos na exportação. Número de malhas não equivale a draw calls medidas.
- Em casos animados, a auditoria compara posições de vértices avaliados em quadros amostrados, registra rigs e lê a estrutura de animação do GLB. Isso não comprova ausência de artefatos entre amostras. No moinho, a checagem foi corrigida para ativar explicitamente o único clipe importado de cada objeto; o Blender deixava os demais guardados por padrão. O teste registra essa configuração e também a chave de fechamento 49.
- No moinho, um teste BVH de superfícies avaliou pás contra obstáculos selecionados em 48 quadros inteiros. A lista de objetos, exclusões e resultados é preservada. Não é detecção contínua nem certificação de física/colisão no engine.
- Leituras de skills e horários vêm dos logs dos agentes, sem auditoria total de acessos a arquivos. Onde houver marcação de orquestração, ela é preservada à parte.
- O consumo de tokens de entrada, saída e cache não foi exposto. Nenhum gráfico estima esse consumo.

## Avaliação

A avaliação não é cega: o avaliador conhece os caminhos e acompanhou os agentes. Não foram atribuídas notas subjetivas numéricas. Composição e iluminação são escolhidas pelos agentes, portanto a preferência visual mistura qualidade da geometria, materiais e apresentação. Uma amostra por condição e tarefas heterogêneas não permitem inferência estatística ou ranking universal.

QA executado por A faz parte da intervenção; não se afirma uma comparação simétrica de taxas de aprovação desse QA. O avaliador aplica o mesmo teste de abertura/importação e inspeção às duas versões e registra limitações sem alterar os assets.

## Correção da contagem da criatura

A primeira auditoria de reimportação incluiu a Icosphere de 80 triângulos que o Blender cria como custom shape de ossos. O objeto não pertence ao GLB. A auditoria foi corrigida para excluí-lo, os JSONs iniciais foram preservados e todas as contagens finais foram confrontadas diretamente com definições/instâncias do glTF. A contagem final da criatura é 1.428 triângulos em A e 5.556 em B.
