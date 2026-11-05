from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parent
configs=[json.loads((ROOT/'tower-report.json').read_text())]+[json.loads(p.read_text()) for p in sorted((ROOT/'cases').glob('*/report-config.json'))]
style='''body{margin:0;background:#141a1f;color:#edf2f4;font:17px/1.6 system-ui}main{max-width:1250px;margin:auto;padding:35px 20px}a{color:#89dfed}section{border-top:1px solid #43515c;margin-top:45px;padding-top:20px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}img{width:100%;display:block}figcaption{padding:6px;text-align:center}details{margin:20px 0}summary{cursor:pointer}.links{display:flex;gap:20px;flex-wrap:wrap}.meta{color:#b2c5ce}@media(max-width:650px){.pair{grid-template-columns:1fr}}'''
parts=['<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Blender e Luna — seis comparações</title><style>'+style+'</style><main><h1>Blender headless com Luna: com e sem skills</h1><p>Galeria de evidências. Os arquivos originais foram preservados; as imagens não receberam retoques. Uma execução por condição, avaliação não cega e sem telemetria de tokens.</p><div class="links"><a href="global-report.pdf">PDF global</a><a href="GLOBAL-REPORT.md">Síntese em Markdown</a><a href="PROTOCOL.md">Protocolo</a><a href="SHA256SUMS.txt">Hashes</a></div>']
for c in configs:
 folder=Path(c['folder']);m=json.loads((ROOT/folder/'metrics.json').read_text())
 def pic(v,file):
  src=(folder/f'run-{v}'/file).as_posix();return f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{html.escape(c["title"])} — {v.upper()}"></a><figcaption>{"A — com skills" if v=="a" else "B — sem skills"}</figcaption></figure>'
 parts += [f'<section><h2>{html.escape(c["title"])}</h2><p>{html.escape(c["summary"])}</p><p class="meta">Triângulos GLB: A {m["a"]["triangles"]:,} · B {m["b"]["triangles"]:,}. Skills consultadas: A {m["a"]["skills_read_reported"]} · B 0.</p><div class="links"><a href="{(folder/"report.pdf").as_posix()}">PDF detalhado</a><a href="{(folder/"REPORT.md").as_posix()}">Análise Markdown</a><a href="{(folder/"request.txt").as_posix()}">Pedido original</a></div>','<div class="pair">'+''.join(pic(v,c['images'][v][2]) for v in 'ab')+'</div>','<details><summary>Mostrar vistas de frente, trás e quadros adicionais</summary>']
 for i in range(2):parts+=['<div class="pair">'+''.join(pic(v,c['images'][v][i]) for v in 'ab')+'</div>']
 for extra in c.get('extra_images',[]):
  for f in extra['files']:parts+=['<h3>'+html.escape(f)+'</h3><div class="pair">'+''.join(pic(v,f) for v in 'ab' if (ROOT/folder/f'run-{v}'/f).exists())+'</div>']
 for page in c.get('inspection_pages',[]):
  parts+=['<h3>'+html.escape(page['title'])+'</h3><p>'+html.escape(page['note'])+'</p>']
  for row in page['rows']:
   parts+=['<h4>'+html.escape(row['label'])+'</h4><div class="pair">']
   for v in 'ab':
    if row.get(v):
     path=(folder/row[v]).as_posix();parts+=['<figure><img loading="lazy" src="'+path+'"><figcaption>'+v.upper()+'</figcaption></figure>']
   parts+=['</div>']
 parts+=['</details></section>']
parts+=['</main></html>'];(ROOT/'comparison.html').write_text(''.join(parts))
print(ROOT/'comparison.html')
