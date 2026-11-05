#!/usr/bin/env python3
"""Check report artifacts and links; does not claim engine or gameplay validation."""
from pathlib import Path
import json,re,subprocess,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parent
configs=[json.loads((ROOT/'tower-report.json').read_text())]+[json.loads(p.read_text()) for p in sorted((ROOT/'cases').glob('*/report-config.json'))]
results=[]
for c in configs:
 folder=ROOT/c['folder'];pdf=folder/'report.pdf';assert pdf.is_file() and pdf.stat().st_size>1000
 text=subprocess.check_output(['pdftotext',str(pdf),'-'],text=True)
 pages=[p for p in text.split('\f') if p.strip()]
 assert len(pages)>=6,(pdf,'missing sections')
 for idx,p in enumerate(pages,1):assert len(p.strip())>70,(pdf,'suspiciously empty page',idx)
 assert 'Tokens reais' in text and 'não disponíveis' in text
 for v in 'ab':
  files=c['images'][v]+[f for extra in c.get('extra_images',[]) for f in extra['files']]
  for f in files:assert Image.open(folder/f'run-{v}'/f).size==(768,768),(c['title'],v,f)
 m=json.loads((folder/'metrics.json').read_text())
 for v in 'ab':
  assert m[v]['tokens'] is None
  assert m[v]['triangles']>0
  glb='tower.glb' if c['folder']=='.' else 'asset.glb'
  assert (folder/f'run-{v}'/glb).stat().st_size==m[v]['files_bytes'][glb]
  assert (folder/f'run-{v}'/glb.replace('.glb','.blend')).is_file()
 results.append({'report':str(pdf.relative_to(ROOT)),'pages':len(pages),'bytes':pdf.stat().st_size,'pngs_expected':sum(len(c['images'][v])+sum(len(e['files']) for e in c.get('extra_images',[])) for v in 'ab')})
if (ROOT/'global-report.pdf').exists():
 assert len(configs)==6
 text=subprocess.check_output(['pdftotext',str(ROOT/'global-report.pdf'),'-'],text=True)
 assert 'Conclusão global' in text
 results.append({'report':'global-report.pdf','pages':len([p for p in text.split('\f') if p.strip()]),'bytes':(ROOT/'global-report.pdf').stat().st_size})
for f in ROOT.rglob('*'):
 if f.is_file() and '__pycache__' not in f.parts:assert f.stat().st_size<95_000_000,(f,'large file')
(ROOT/'validation.json').write_text(json.dumps({'checks':'PDF text/pages, PNG size, final GLB file sizes, required files, unavailable tokens kept null; not engine or gameplay tests','reports':results},indent=2,ensure_ascii=False))
print(json.dumps(results,indent=2,ensure_ascii=False))
