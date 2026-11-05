#!/usr/bin/env python3
"""Build global report only after all six per-case PDFs are complete."""
from pathlib import Path
import json,html,re
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
story=[para('Blender headless com Luna: síntese de seis comparações','Title'),para('Torre inicial + cinco categorias adicionais · com e sem skills','Heading2'),para('O estudo preserva doze entregas em contextos separados, seus pedidos, renders, arquivos Blender/GLB e registros. A questão foi prática: as skills melhoram o resultado que um agente Luna entrega sob um pedido natural? Os achados variam com a categoria e não sustentam uma resposta universal.'),para('Conclusão global','Heading1')]
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
story += [para('3.1. Dados geométricos completos','Heading1')]
geometry_rows=[['Caso','Polígonos-base A / B','Triângulos-base A / B','Avaliados .blend A / B','GLB final A / B']]
organization_rows=[['Caso','Vértices GLB A / B','Definições A / B','Instâncias A / B','Clipes A / B','GLB bytes A / B']]
records=[]
for label,c,m in zip(labels,configs,data):
 pair=lambda key: ' / '.join(str(m[v]['source_geometry'][key]) for v in 'ab')
 geometry_rows.append([label,pair('base_polygons'),pair('base_triangles'),pair('evaluated_triangles_in_blend'),' / '.join(str(m[v]['triangles']) for v in 'ab')])
 organization_rows.append([label,' / '.join(str(m[v]['geometry_export']['position_vertices_instantiated']) for v in 'ab'),' / '.join(str(m[v]['geometry_export']['mesh_definitions']) for v in 'ab'),' / '.join(str(m[v]['geometry_export']['mesh_instances']) for v in 'ab'),' / '.join(str(m[v]['geometry_export']['animation_clips']) for v in 'ab'),' / '.join(str(m[v]['files_bytes'].get('asset.glb',m[v]['files_bytes'].get('tower.glb',0))) for v in 'ab')])
 for v in 'ab':
  records.append({'case':label,'variant':v,'with_skills':v=='a','base_polygons':m[v]['source_geometry']['base_polygons'],'base_triangles':m[v]['source_geometry']['base_triangles'],'evaluated_triangles_blend':m[v]['source_geometry']['evaluated_triangles_in_blend'],'triangles_glb':m[v]['triangles'],'vertices_glb_positions':m[v]['geometry_export']['position_vertices_instantiated'],'mesh_definitions':m[v]['geometry_export']['mesh_definitions'],'mesh_instances':m[v]['geometry_export']['mesh_instances'],'materials':m[v]['materials'],'animation_clips':m[v]['geometry_export']['animation_clips'],'glb_bytes':m[v]['files_bytes'].get('asset.glb',m[v]['files_bytes'].get('tower.glb',0)),'blend_bytes':m[v]['files_bytes'].get('asset.blend',m[v]['files_bytes'].get('tower.blend',0)),'logged_seconds':m[v]['elapsed_seconds_reported'],'skills_read':m[v]['skills_read_reported'],'tokens':None})
story += [table(geometry_rows,[60,105,105,120,120]),Spacer(1,12),para('Base: polígonos e triângulos antes dos modificadores, apenas nos objetos correspondentes ao export. Avaliado: resultado dos modificadores no .blend. GLB: geometria realmente entregue, contando instâncias. Divergências são dados do pipeline, não necessariamente erro do contador.','Small'),para('3.2. Vértices e organização do arquivo','Heading2'),table(organization_rows,[55,100,70,75,60,150]),Spacer(1,12),para('Vértices do GLB contam atributos de posição por instância; UVs/normais podem duplicar posições. Definições são malhas armazenadas no arquivo; instâncias são os nós que as reutilizam. Nenhuma coluna estima draw calls, FPS ou tokens. Os dados também estão em comparison.csv e comparison-data.json.','Small'),PageBreak()]
import csv
with (ROOT/'comparison.csv').open('w',newline='') as f:
 writer=csv.DictWriter(f,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
(ROOT/'comparison-data.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
fig,axs=plt.subplots(3,2,figsize=(11,10),layout='constrained')
for ax,label,m in zip(axs.flat,labels,data):
 for v,col,title in [('a',A,'com skills'),('b',B,'sem skills')]:
  vals=[m[v]['source_geometry']['base_triangles'],m[v]['source_geometry']['evaluated_triangles_in_blend'],m[v]['triangles']]
  ax.plot(['Base','Avaliado','GLB'],vals,'o-',color=col,label=title)
 ax.set_title(label,loc='left',weight='bold');ax.set_ylabel('Triângulos');ax.grid(alpha=.2);ax.legend(fontsize=8);ax.spines[['top','right']].set_visible(False)
fig.suptitle('Geometria ao longo do pipeline — escalas independentes por caso',weight='bold');fig.savefig(charts/'pipeline-geometry.png',dpi=180);fig.savefig(charts/'pipeline-geometry.svg');plt.close(fig)
story += [para('3.3. Base, modificadores e exportação','Heading1'),image(charts/'pipeline-geometry.png',510,470),para('A diferença entre base e avaliado mostra o efeito dos modificadores. Quando o GLB volta à contagem-base, os detalhes avaliados no .blend não foram todos incorporados ao export. O kit A mostra o caso oposto: o GLB é muito mais denso que a contagem-base declarada. As escalas verticais variam por categoria; compare as três etapas dentro de cada painel.'),PageBreak()]
for idx,(label,c,m) in enumerate(zip(labels,configs,data)):
 folder=ROOT/c['folder'];story += [para(f'4.{idx+1}. {c["title"]}','Heading1')]
 pair=[image(folder/f'run-{v}'/c['images'][v][2],250,250) for v in 'ab'];story += [Table([pair,[para('A — com skills','Caption'),para('B — sem skills','Caption')]],colWidths=[255,255]),Spacer(1,12),para(c['summary']),para(c['interpretation']),para('Achados que impedem uma leitura simplista','Heading2')]
 story += [para(t) for t in c.get('global_caveats',c['critique'][:2])]
 story += [para(f'Relatório completo: {c["folder"]}/report.pdf. Pedido, evidências e script de reprodução no mesmo diretório.','Small'),PageBreak()]
 for extra in c.get('extra_images',[]):
  story += [para(label+' — quadros de animação','Heading1'),para('Esquerda: A, com skills. Direita: B, sem skills.','Caption')]
  for frame in extra['files']:
   pair=[image(folder/f'run-{v}'/frame,180,180) if (folder/f'run-{v}'/frame).exists() else para('Não entregue') for v in 'ab']
   story += [para(frame,'Heading2'),Table([pair],colWidths=[255,255])]
  story.append(PageBreak())
for c in configs:
 folder=ROOT/c['folder']
 for chart in c.get('extra_charts',[]):
  story += [para(c['title']+' — '+chart['title'],'Heading1'),image(folder/chart['file'],510,340),para(chart['note']),PageBreak()]
for c in configs:
 for inspection in c.get('inspection_pages',[]):
  folder=ROOT/c['folder'];story += [para(inspection['title'],'Heading1'),para(inspection['note'])]
  for row in inspection['rows']:
   story += [para(row['label'],'Heading2'),Table([[image(folder/row['a'],210,210) if row.get('a') else para('Não entregue'),image(folder/row['b'],210,210) if row.get('b') else para('Não entregue')]],colWidths=[255,255])]
  story.append(PageBreak())
story += [para('5. Recomendação operacional','Heading1')]+[para(t) for t in global_text['recommendations']]
story += [para('6. O que seria necessário para medir melhor','Heading1')]+[para(t) for t in global_text['next_experiment']]
story += [PageBreak(),para('Artefatos e reprodução','Heading1'),para('Os seis PDFs individuais, este PDF global, gráficos PNG/SVG, Markdown, scripts, métricas e evidências estão na branch docs/blender-luna-skills-study do repositório Petri-Hub/roblox-with-swe. Não foi alterado código do jogo. Não houve integração no Roblox Studio.'),para('Pacote: EL4CTEO/blender-skills, commit fb92cfb4cc5a238c22113a6a230b09f535bd0656. Hashes dos artefatos em SHA256SUMS.txt. Gere os PDFs individuais com build_reports.py e este documento com build_global.py. Dependências de relatório: matplotlib, reportlab e Pillow, com DejaVu Sans. Os scripts originais dos agentes podem exigir ajuste de caminhos locais.'),para('Não existe gráfico de tokens: a telemetria não estava disponível. Não são atribuídas notas subjetivas numéricas ou significância estatística a uma amostra por condição.','Small')]
SimpleDocTemplate(str(ROOT/'global-report.pdf'),pagesize=A4,leftMargin=40,rightMargin=40,topMargin=42,bottomMargin=48,title='Blender headless com Luna — síntese global',author='Estudo exploratório assistido por Codex').build(story,onFirstPage=footer,onLaterPages=footer)
md=['# Blender headless com Luna — síntese global']+global_text['conclusion']+['## Resultados por categoria']
for label,c in zip(labels,configs):md += [f'### {label}',c['summary'],c['interpretation'],f'[PDF]({c["folder"]}/report.pdf)']
for key,label in [('limits','Limites'),('recommendations','Recomendação operacional'),('next_experiment','Próximo experimento')]:md += ['## '+label]+global_text[key]
md += ['## Dados geométricos', '| Caso | Polígonos-base A/B | Triângulos-base A/B | Avaliados A/B | GLB A/B |', '|---|---:|---:|---:|---:|']+['| '+' | '.join(map(str,row))+' |' for row in geometry_rows[1:]]
md += ['[Dados CSV](comparison.csv) · [Dados JSON](comparison-data.json)', '![Etapas da geometria](global-charts/pipeline-geometry.png)']
md += ['![Geometria e tamanho](global-charts/geometry-and-size.png)','![Skills consultadas](global-charts/skills-read.png)']
(ROOT/'GLOBAL-REPORT.md').write_text(re.sub(r'(?m)(\|[^\n]*\|)\n\n(?=\|)',r'\1\n','\n\n'.join(md)));print(ROOT/'global-report.pdf')
