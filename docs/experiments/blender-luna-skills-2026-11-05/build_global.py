#!/usr/bin/env python3
"""Build global report only after all six per-case PDFs are complete."""
from pathlib import Path
import json,html
import matplotlib.pyplot as plt
from reportlab.platypus import SimpleDocTemplate,PageBreak,Spacer,Table
from reportlab.lib.pagesizes import A4
from build_reports import ROOT,para,image,table,footer,A,B
configs=[json.loads((ROOT/'tower-report.json').read_text())]+[json.loads(p.read_text()) for p in sorted((ROOT/'cases').glob('*/report-config.json'))]
assert len(configs)==6,'All five additional cases plus tower must be complete first'
for c in configs:assert (ROOT/c['folder']/'report.pdf').exists()
data=[json.loads((ROOT/c['folder']/'metrics.json').read_text()) for c in configs]
labels=['Torre','Blaster','Criatura','Pátio','Moinho','Kit modular']
charts=ROOT/'global-charts';charts.mkdir(exist_ok=True)
fig,axs=plt.subplots(2,1,figsize=(11,8),layout='constrained')
for ax,key,title in [(axs[0],'triangles','Triângulos exportados · a geometria depende do pedido'),(axs[1],'glb_bytes','Tamanho do GLB (KB decimais)')]:
 av=[];bv=[]
 for m in data:
  for v,vals in [('a',av),('b',bv)]:
   if key=='triangles':vals.append(m[v]['triangles'])
   else:vals.append(m[v]['files_bytes'].get('asset.glb',m[v]['files_bytes'].get('tower.glb',0))/1000)
 x=list(range(6));ax.bar([i-.19 for i in x],av,width=.36,color=A,label='A · com skills');ax.bar([i+.19 for i in x],bv,width=.36,color=B,label='B · sem skills')
 ax.set_xticks(x,labels);ax.set_title(title,loc='left',weight='bold');ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True);ax.legend();ax.spines[['top','right']].set_visible(False)
fig.savefig(charts/'geometry-and-size.png',dpi=180);fig.savefig(charts/'geometry-and-size.svg');plt.close(fig)
fig,ax=plt.subplots(figsize=(11,4),layout='constrained');av=[m['a']['skills_read_reported'] for m in data];ax.bar(labels,av,color=A);ax.set_title('Skills consultadas por A, conforme registros — B declarou zero em todos os casos',loc='left',fontsize=11);ax.set_ylabel('SKILL.md distintos');ax.set_ylim(0,max(av)+2)
for i,n in enumerate(av):ax.text(i,n+.1,str(n),ha='center')
ax.spines[['top','right']].set_visible(False);fig.savefig(charts/'skills-read.png',dpi=180);fig.savefig(charts/'skills-read.svg');plt.close(fig)
story=[para('Blender headless com Luna: síntese de seis comparações','Title'),para('Torre inicial + cinco categorias adicionais · com e sem skills','Heading2'),para('O estudo preserva doze entregas independentes, seus pedidos, renders, arquivos Blender/GLB e registros. A questão foi prática: as skills melhoram o resultado que um agente Luna entrega sob um pedido natural? Os achados variam com a categoria e não sustentam uma resposta universal.'),para('Conclusão global','Heading1')]
global_text=json.loads((ROOT/'global-findings.json').read_text())
story += [para(t) for t in global_text['conclusion']]+[PageBreak()]
story += [para('1. O que foi comparado','Heading1'),para('Dois GPT-6 Luna medium por pedido, sem histórico herdado e sem saber da comparação. A tinha acesso ao mesmo pacote fixo de skills; B foi instruído a não consultar nenhum pacote. Mesmo Blender 5.2.3 headless e CPU, separação por pasta, revisão autônoma. Os pares adicionais foram executados um de cada vez. Não houve instalação global das skills.'),para('Limites que mudam a interpretação','Heading2')]
story += [para('• '+t) for t in global_text['limits']]
story += [para('O protocolo completo, os pedidos e os logs foram versionados. “Sem skills” significa ausência de consulta autorizada e declarada nesta tarefa; não significa ausência de conhecimento prévio no modelo.'),PageBreak()]
story += [para('2. Geometria e tamanho das entregas','Heading1'),image(charts/'geometry-and-size.png',510,390),para('Os números são dos GLBs finais reimportados. Menor geometria ou arquivo pode ser vantagem de orçamento, mas também pode refletir simplificação ou omissão de detalhes. Comparar categorias diferentes como se tivessem a mesma dificuldade seria inadequado. Não somo os triângulos para criar um ranking geral.'),image(charts/'skills-read.png',510,185),PageBreak()]
rows=[['Caso','Triângulos A / B','GLB KB A / B','Skills A','Leitura do resultado']]
for label,c,m in zip(labels,configs,data):
 sizes=[m[v]['files_bytes'].get('asset.glb',m[v]['files_bytes'].get('tower.glb',0))/1000 for v in 'ab']
 rows.append([label,f"{m['a']['triangles']} / {m['b']['triangles']}",f'{sizes[0]:.1f} / {sizes[1]:.1f}',str(m['a']['skills_read_reported']),c.get('global_takeaway',c['summary'])])
story += [para('3. Quadro comparativo','Heading1'),table(rows,[55,85,85,45,240]),para('Os tempos individuais estão nos PDFs de cada caso. No blaster houve retomada do ambiente e a marcação inicial não cobre todo o trabalho dos agentes; por isso não incluo um ranking agregado de velocidade. Tokens reais continuam indisponíveis em todas as condições.'),PageBreak()]
for idx,(label,c,m) in enumerate(zip(labels,configs,data)):
 folder=ROOT/c['folder'];story += [para(f'4.{idx+1}. {c["title"]}','Heading1')]
 pair=[image(folder/f'run-{v}'/c['images'][v][2],250,250) for v in 'ab'];story += [Table([pair,[para('A — com skills','Caption'),para('B — sem skills','Caption')]],colWidths=[255,255]),Spacer(1,12),para(c['summary']),para(c['interpretation']),para('Achados que impedem uma leitura simplista','Heading2')]
 story += [para(t) for t in c.get('global_caveats',c['critique'][:2])]
 story += [para(f'Relatório completo: {c["folder"]}/report.pdf. Pedido, evidências e script de reprodução no mesmo diretório.','Small'),PageBreak()]
 for extra in c.get('extra_images',[]):
  story += [para(label+' — quadros de animação','Heading1')]
  for frame in extra['files']:
   pair=[image(folder/f'run-{v}'/frame,190,190) if (folder/f'run-{v}'/frame).exists() else para('Não entregue') for v in 'ab']
   story += [para(frame,'Heading2'),Table([pair],colWidths=[255,255])]
  story.append(PageBreak())
story += [para('5. Recomendação operacional','Heading1')]+[para(t) for t in global_text['recommendations']]
story += [para('6. O que seria necessário para medir melhor','Heading1')]+[para(t) for t in global_text['next_experiment']]
story += [para('Artefatos e reprodução','Heading1'),para('Os seis PDFs individuais, este PDF global, gráficos PNG/SVG, Markdown, scripts, métricas e evidências estão na branch docs/blender-luna-skills-study do repositório Petri-Hub/roblox-with-swe. Não foi alterado código do jogo. Não houve integração no Roblox Studio.'),para('Pacote: EL4CTEO/blender-skills, commit fb92cfb4cc5a238c22113a6a230b09f535bd0656. Hashes dos artefatos em SHA256SUMS.txt. Gere os PDFs individuais com build_reports.py e este documento com build_global.py. Dependências de relatório: matplotlib, reportlab e Pillow, com DejaVu Sans. Os scripts originais dos agentes podem exigir ajuste de caminhos locais.'),para('Não existe gráfico de tokens: a telemetria não estava disponível. Não são atribuídas notas subjetivas numéricas ou significância estatística a uma amostra por condição.','Small')]
SimpleDocTemplate(str(ROOT/'global-report.pdf'),pagesize=A4,leftMargin=40,rightMargin=40,topMargin=42,bottomMargin=48,title='Blender headless com Luna — síntese global',author='Estudo exploratório assistido por Codex').build(story,onFirstPage=footer,onLaterPages=footer)
md=['# Blender headless com Luna — síntese global']+global_text['conclusion']+['## Resultados por categoria']
for label,c in zip(labels,configs):md += [f'### {label}',c['summary'],c['interpretation'],f'[PDF]({c["folder"]}/report.pdf)']
for key,label in [('limits','Limites'),('recommendations','Recomendação operacional'),('next_experiment','Próximo experimento')]:md += ['## '+label]+global_text[key]
md += ['![Geometria e tamanho](global-charts/geometry-and-size.png)','![Skills consultadas](global-charts/skills-read.png)']
(ROOT/'GLOBAL-REPORT.md').write_text('\n\n'.join(md));print(ROOT/'global-report.pdf')
