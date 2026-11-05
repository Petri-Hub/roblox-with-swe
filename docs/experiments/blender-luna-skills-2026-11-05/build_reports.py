#!/usr/bin/env python3
"""Generate the reports from preserved evidence. Python: matplotlib, reportlab, Pillow."""
from pathlib import Path
import json, re, hashlib, html, argparse
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, KeepTogether
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
from PIL import Image as PILImage
ROOT=Path(__file__).resolve().parent
FONT=Path('/usr/share/fonts/truetype/dejavu')
pdfmetrics.registerFont(TTFont('DejaVu', str(FONT/'DejaVuSans.ttf')))
pdfmetrics.registerFont(TTFont('DejaVuBold', str(FONT/'DejaVuSans-Bold.ttf')))
pdfmetrics.registerFontFamily('DejaVu',normal='DejaVu',bold='DejaVuBold',italic='DejaVu',boldItalic='DejaVuBold')
ST=getSampleStyleSheet()
for n in ST.byName: ST[n].fontName='DejaVu'
ST['Normal'].fontSize=9;ST['Normal'].leading=14;ST['Normal'].spaceAfter=9
ST['Title'].fontSize=25;ST['Title'].leading=32;ST['Title'].textColor=colors.HexColor('#163345')
ST['Heading1'].fontSize=17;ST['Heading1'].leading=23;ST['Heading1'].spaceAfter=12
ST['Heading2'].fontSize=12;ST['Heading2'].leading=17
ST.add(ParagraphStyle(name='Caption',parent=ST['Normal'],fontSize=8,leading=11,textColor=colors.HexColor('#52616b'),alignment=TA_CENTER))
ST.add(ParagraphStyle(name='Small',parent=ST['Normal'],fontSize=7.5,leading=11))
A='#178c94';B='#ce713c';W,H=A4

def para(s,style='Normal'):return Paragraph(html.escape(str(s)).replace('\n','<br/>'),ST[style])
def p_list(items):return [para('• '+v) for v in items]
def image(path,w=248,h=248):
 pw,ph=PILImage.open(path).size
 scale=min(w/pw,h/ph)
 return Image(str(path),width=pw*scale,height=ph*scale)
def footer(canvas,doc):
 canvas.setStrokeColor(colors.HexColor('#ccd6da'));canvas.line(40,34,W-40,34)
 canvas.setFont('DejaVu',7);canvas.setFillColor(colors.HexColor('#52616b'))
 canvas.drawString(40,22,'Estudo exploratório · Blender + GPT-6 Luna · 05/11/2026')
 canvas.drawRightString(W-40,22,f'{doc.page}')
def table(rows,widths=None):
 t=Table([[para(c,'Small') for c in row] for row in rows],colWidths=widths,repeatRows=1,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e4eef1')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,0),.6,colors.HexColor('#91a6b0')),('BOTTOMPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),8),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#f4f6f7')])]))
 return t

def charts(folder,m,time_label="Tempo decorrido (min)"):
 out=folder/'charts';out.mkdir(exist_ok=True)
 metrics=[(time_label,[m[v].get('elapsed_seconds_reported',0)/60 for v in 'ab']),('Triângulos no GLB',[m[v].get('triangles',0) for v in 'ab']),('Tamanho do GLB (KB decimais)',[m[v]['files_bytes'].get('asset.glb',m[v]['files_bytes'].get('tower.glb',0))/1000 for v in 'ab']),('Skills consultadas (registro)',[m[v].get('skills_read_reported',0) for v in 'ab'])]
 plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False})
 fig,axs=plt.subplots(2,2,figsize=(10,7.2),layout='constrained')
 for ax,(title,vals) in zip(axs.flat,metrics):
  bars=ax.bar(['A · com skills','B · sem skills'],vals,color=[A,B],width=.54)
  ax.set_title(title,loc='left',weight='bold',pad=14);ax.set_ylim(0,max(max(vals)*1.25,1))
  for bar,val in zip(bars,vals):ax.text(bar.get_x()+bar.get_width()/2,bar.get_height()+max(max(vals)*.025,.025),f'{val:,.2f}'.replace(',','X').replace('.',',').replace('X','.'),ha='center',fontsize=10)
  ax.grid(axis='y',alpha=.18);ax.set_axisbelow(True)
 fig.suptitle('Medidas observadas · sem pontuação artificial de qualidade',fontsize=14,weight='bold')
 fig.savefig(out/'metrics.png',dpi=180);fig.savefig(out/'metrics.svg');plt.close(fig)
 return out/'metrics.png'

def case_report(config):
 folder=ROOT/config['folder'];m=json.loads((folder/'metrics.json').read_text()); chart=charts(folder,m,config.get("time_label","Tempo decorrido (min)"))
 title=config['title'];story=[para(title,'Title'),para('Comparação com e sem skills · relatório detalhado','Heading2'),para(config['summary']),Spacer(1,12)]
 # opening images at useful resolution
 hero=[]
 for v in 'ab':
  pics=config['images'][v];hero.append([image(folder/f'run-{v}'/pics[2],245,245),para('A — com skills' if v=='a' else 'B — sem skills','Caption')])
 story.append(Table([[hero[0][0],hero[1][0]],[hero[0][1],hero[1][1]]],colWidths=[255,255]))
 story += [Spacer(1,14),para('Leitura correta do resultado','Heading2'),para(config['interpretation']),para('Uma amostra por condição, avaliação não cega e sem telemetria real de tokens. O estudo documenta estas execuções; não estabelece uma classificação universal de modelos ou de skills.','Small'),PageBreak()]
 story += [para('1. Pedido e condições de execução','Heading1'),para((folder/'request.txt').read_text()),para('Condições comuns','Heading2')]
 story+=p_list(['Modelo declarado na chamada: gpt-6-luna; reasoning_effort: medium; fork_turns: none. Os agentes não herdaram a conversa nem souberam que se tratava de uma comparação.','Blender 5.2.3 LTS, modo headless, CPU, até quatro threads. Mesma máquina e mesma disponibilidade de ferramentas de imagem. Não foram utilizados Roblox Studio ou motor de jogo.','Pastas independentes por instrução, sem isolamento por containers. Sem internet, consulta cruzada ou novos subagentes autorizados. Não há auditoria completa dos acessos a arquivos.','A recebeu acesso ao pacote EL4CTEO/blender-skills e escolheu o que consultar; B foi instruído a usar seu conhecimento e a API instalada, sem consultar qualquer skill. Ambos puderam revisar e corrigir o resultado.','Não houve orçamento fixo de tokens, número fixo de revisões ou tempo máximo. Portanto, esforço de revisão e leitura de instruções fazem parte da diferença entre as condições.'])
 story += [para('Versão das skills','Heading2'),para('Commit fixo: fb92cfb4cc5a238c22113a6a230b09f535bd0656. Pacote consultado, sem instalação global e sem alterações nos arquivos rastreados do pacote. Skills lidas não significam scripts executados nem conformidade completa com cada recomendação.'),PageBreak()]
 story += [para('2. Medidas e custo observável','Heading1'),image(chart,510,365)]
 rows=[['Medida','A · com skills','B · sem skills']]
 def fmt(x):return str(x).replace('.',',')
 for label,key in [('Tempo registrado (s)','elapsed_seconds_reported'),('Skills lidas','skills_read_reported'),('Triângulos exportados','triangles'),('Objetos de malha exportados','mesh_objects'),('Materiais exportados','materials')]:rows.append([label,fmt(m['a'].get(key,'indisponível')),fmt(m['b'].get(key,'indisponível'))])
 for ext in ['blend','glb']:
  rows.append([f'Arquivo .{ext} (bytes)']+[str(m[v]['files_bytes'].get(f'asset.{ext}',m[v]['files_bytes'].get(f'tower.{ext}',0))) for v in 'ab'])
 rows.append(['Tokens reais','não disponíveis','não disponíveis'])
 story += [table(rows,[220,145,145]),Spacer(1,12),para(config.get('timing_note','Tempos conforme registros dos agentes.')),para('Tempo decorrido inclui raciocínio, ferramentas, renderização, revisão e espera em uma máquina compartilhada. Mais tempo não prova maior consumo de tokens. Quantidade de skills lidas também não é medição de tokens. Tamanho de arquivo não mede qualidade, e número de objetos não equivale a draw calls.'),PageBreak()]
 for extra_chart in config.get('extra_charts',[]):
  story += [para(extra_chart['title'],'Heading1'),image(folder/extra_chart['file'],510,340),para(extra_chart['note']),PageBreak()]
 for idx,label in enumerate(['Frente','Trás','Apresentação']):
  story += [para(f'3.{idx+1}. Galeria comparativa — {label}','Heading1')]
  pair=[image(folder/f'run-{v}'/config['images'][v][idx],250,250) for v in 'ab']
  story += [Table([pair,[para('A — com skills','Caption'),para('B — sem skills','Caption')]],colWidths=[255,255]),Spacer(1,15),para(config['gallery_notes'][idx]),para('As imagens são as produzidas pelos agentes, sem reconstruir a cena ou equalizar iluminação, lente e enquadramento. Essas diferenças influenciam o julgamento visual.','Small'),PageBreak()]
 for extra in config.get('extra_images',[]):
  story += [para(extra['title'],'Heading1'),para('Coluna esquerda: A, com skills. Coluna direita: B, sem skills.','Caption')]
  for i,frame in enumerate(extra['files']):
   imgs=[]
   for v in 'ab':
    p=folder/f'run-{v}'/frame
    imgs.append(image(p,200,200) if p.exists() else para('Não entregue'))
   story += [para(frame,'Heading2'),Table([imgs],colWidths=[255,255])]
  story.append(PageBreak())
 story += [para('4. Análise do resultado A — com skills','Heading1')]+[para(s) for s in config['analysis_a']]
 story += [para('5. Análise do resultado B — sem skills','Heading1')]+[para(s) for s in config['analysis_b']]+[PageBreak()]
 story += [para('6. Skills consultadas e efeito demonstrável','Heading1'),para('A lista abaixo vem dos registros do agente e de seu uso declarado. Não prova causalidade: não é possível atribuir uma decisão específica a uma skill apenas porque ela foi lida.')]
 srows=[['Skill registrada','Escopo e observação']]+config['skills']
 story += [table(srows,[190,320]),Spacer(1,12),para('O agente B declarou não consultar skills. Nenhum dos agentes alterou o conteúdo do pacote. “Uso” neste relatório significa consulta declarada, salvo quando há log específico de execução de um script. A checagem automática usada por A não foi aplicada simetricamente por B; taxas de aprovação de QA não são comparáveis.'),para('Fonte versionada: https://github.com/EL4CTEO/blender-skills/tree/fb92cfb4cc5a238c22113a6a230b09f535bd0656/skills','Small'),PageBreak()]
 story += [para('7. Desconstrução da conclusão','Heading1')]+[para(s) for s in config['critique']]
 story += [para('8. Verificação independente e limites','Heading1')]+[para(s) for s in config['verification']]+[PageBreak()]
 story += [para('9. Reprodução, rastreabilidade e próximos passos','Heading1'),para('As pastas run-a/ e run-b/ preservam os projetos, exportações, scripts, renders e logs. metrics.json registra medidas e tamanhos. Os scripts de inspeção e seus JSONs ficam em review/. O pedido literal está em request.txt. O gerador do PDF é build_reports.py, na raiz do estudo.'),para('Para reproduzir a geração: instale Blender 5.2.3 e execute o gerador de cada variante em sua própria pasta. Os scripts podem conter caminhos absolutos desta sessão: ajuste apenas o caminho do executável/saída conforme o README. Renderizações podem variar com versão, hardware e seed.'),para('Os GLBs foram medidos após importação para contar a geometria efetivamente exportada, incluindo modificadores aplicados. As contagens de malha base em métricas do .blend são distintas. Métricas não registradas permanecem ausentes; não há estimativa de tokens disfarçada de medição.')]
 story += p_list(config['next_steps'])
 story += [para('Integridade e arquivos','Heading2'),para('SHA256 dos artefatos preservados em SHA256SUMS.txt. O código do jogo não foi modificado. A branch guarda evidências e documentação; ela não integra estes assets ao jogo nem atesta compatibilidade no Roblox.'),para('Referências','Heading2'),para('Pacote de skills: https://github.com/EL4CTEO/blender-skills\nPágina de comparação que motivou o estudo: https://el4cteo.github.io/blender-skills/comparison/\nBlender: https://download.blender.org/release/Blender5.2/\nMedições e achados: arquivos locais versionados junto a este relatório.','Small')]
 pdf=folder/'report.pdf';doc=SimpleDocTemplate(str(pdf),pagesize=A4,rightMargin=40,leftMargin=40,topMargin=42,bottomMargin=48,title=title,author='Estudo exploratório assistido por Codex');doc.build(story,onFirstPage=footer,onLaterPages=footer)
 # Parallel readable Markdown with same analysis and original images
 md=[f'# {title}',config['summary'],config['interpretation'],'## Pedido',(folder/'request.txt').read_text(),'## Medidas','| Medida | A · com skills | B · sem skills |','|---|---:|---:|']
 md += ['| '+' | '.join(map(str,row))+' |' for row in rows[1:]]
 md += ['![Gráficos](charts/metrics.png)','## Galeria']
 for i,label in enumerate(['Frente','Trás','Apresentação']):
  md += [f'### {label}',f'![A — com skills](run-a/{config["images"]["a"][i]})',f'![B — sem skills](run-b/{config["images"]["b"][i]})',config['gallery_notes'][i]]
 for key,label in [('analysis_a','Resultado A'),('analysis_b','Resultado B'),('critique','Desconstrução da conclusão'),('verification','Verificação e limites'),('next_steps','Próximos passos')]:md += ['## '+label]+config[key]
 md += ['## Skills consultadas']+[f'- **[{n}](https://github.com/EL4CTEO/blender-skills/blob/fb92cfb4cc5a238c22113a6a230b09f535bd0656/skills/{n}/SKILL.md)**: {d}' for n,d in config['skills']]
 md += ['Nenhuma skill foi modificada. Tokens reais indisponíveis. Modelo gpt-6-luna medium, Blender 5.2.3, uma execução por condição; avaliação não cega. Veja o PDF e o manifesto para detalhes.']
 (folder/'REPORT.md').write_text('\n\n'.join(md))
 print(pdf)
 return pdf

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('configs',nargs='+');args=ap.parse_args()
 for p in args.configs:case_report(json.loads((ROOT/p).read_text()))
