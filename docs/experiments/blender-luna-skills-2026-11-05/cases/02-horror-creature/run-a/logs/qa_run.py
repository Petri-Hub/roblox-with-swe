import bpy, sys, json
sys.path.insert(0,'/workspace/blender-study/skill-source/skills/blender-asset-qa/scripts')
import qa_check
objs=[o.name for o in bpy.data.collections['ASSET_VigiaDoBrejo'].objects if o.type=='MESH']
r=qa_check.run(objects=objs, profile='render')
open('/workspace/blender-study/cases/02-horror-creature/run-a/logs/qa.json','w').write(json.dumps(r,indent=2,default=str))
print('QA_JSON',json.dumps(r,default=str))
