#!/usr/bin/env python3
"""Preserve one completed pair and audit its final files with the same procedure."""
from pathlib import Path
import argparse,datetime,json,re,shutil,struct,subprocess,concurrent.futures,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('case');ap.add_argument('--seconds-a',type=float,required=True);ap.add_argument('--seconds-b',type=float,required=True);ap.add_argument('--duration-basis',default='execution logs; not tokens');args=ap.parse_args()
src=Path('/workspace/blender-study/cases')/args.case;dst=ROOT/'cases'/args.case
for f in src.rglob('*'):
 if not f.is_file() or any(x in f.relative_to(src).parts for x in ['cache','config','.cache','.config','__pycache__']):continue
 if f.suffix not in ['.py','.png','.glb','.blend','.json','.txt','.md','.log']:continue
 target=dst/f.relative_to(src);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
review=dst/'review';review.mkdir(exist_ok=True)
shutil.copy2('/workspace/blender-study/review/audit_asset.py',review/'audit_asset.py')
blender=Path('/workspace/blender-study/tools/blender-5.2.3-linux-x64/blender')
def audit(pair):
 v,ext=pair;file=dst/f'run-{v}'/f'asset.{ext}';out=review/f'{ext}-{v}.json'
 cmd=[str(blender),'--background','--factory-startup','--threads','2','--python-exit-code','1','--python',str(review/'audit_asset.py'),'--',str(file),str(out)]
 result=subprocess.run(cmd,capture_output=True,text=True)
 (review/f'{ext}-{v}.log').write_text(result.stdout+result.stderr)
 if result.returncode:raise RuntimeError(f'audit {v}/{ext} failed: {result.stderr[-500:]}')
 return str(out)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
 for p in ex.map(audit,[(v,e) for v in 'ab' for e in ['blend','glb']]):print(p)

def glb_json(path):
 data=path.read_bytes();magic,ver,length=struct.unpack_from('<III',data)
 assert magic==0x46546c67 and ver==2 and length==len(data)
 n,typ=struct.unpack_from('<II',data,12);assert typ==0x4e4f534a
 d=json.loads(data[20:20+n]);return {'valid_header':True,'animations':[{'name':a.get('name'),'channels':len(a['channels']),'paths':sorted(set(c['target']['path'] for c in a['channels'])),'target_nodes':sorted(set(d['nodes'][c['target']['node']].get('name',str(c['target']['node'])) for c in a['channels'])),'samplers':len(a['samplers']),'time_bounds':[d['accessors'][s['input']].get('max') for s in a['samplers']]} for a in d.get('animations',[])],'skins':len(d.get('skins',[])),'external_uris':[x['uri'] for key in ['images','buffers'] for x in d.get(key,[]) if 'uri'in x and not x['uri'].startswith('data:')],'nodes':len(d.get('nodes',[])),'camera_nodes':[o.get('name') for o in d.get('nodes',[]) if 'camera' in o],'light_nodes':[o.get('name') for o in d.get('nodes',[]) if 'KHR_lights_punctual' in o.get('extensions',{})]}
metrics={}
for v in 'ab':
 p=dst/f'run-{v}';record=json.loads((review/f'glb-{v}.json').read_text());reads=(p/'skills-read.txt').read_text()
 names=sorted(set(re.findall(r'blender-[a-z0-9-]+(?=/SKILL\.md|\s|$)',reads)))
 names=[n for n in names if n not in ['blender-study']]
 if 'SKILL.md' in reads:
  names=sorted(set(re.findall(r'(blender-[a-z0-9-]+)/SKILL\.md',reads))) or names
 if v=='b':names=[]
 imgs={f.name:{'size':list(Image.open(f).size),'bytes':f.stat().st_size} for f in p.glob('*.png')}
 metrics[v]={**record,'elapsed_seconds_reported':getattr(args,'seconds_'+v),'duration_basis':args.duration_basis,'skills_read_reported':len(names),'skills_names_reported':names,'tokens':None,'files_bytes':{str(f.relative_to(p)):f.stat().st_size for f in sorted(p.rglob('*')) if f.is_file()},'images':imgs,'glb_structure':glb_json(p/'asset.glb'),'module_exports':{f.name:glb_json(f) for f in (p/'modules').glob('*.glb')}}
(dst/'metrics.json').write_text(json.dumps(metrics,indent=2,ensure_ascii=False))
(dst/'collection.json').write_text(json.dumps({'collected_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'audit':'same final blend and glb import/evaluation for both variants','no_asset_edits_by_evaluator':True},indent=2))
print(json.dumps({v:{k:metrics[v][k] for k in ['triangles','mesh_objects','materials','armatures','bones','skills_names_reported','elapsed_seconds_reported','max_vertex_displacement_from_frame_1']} for v in 'ab'},indent=2))
