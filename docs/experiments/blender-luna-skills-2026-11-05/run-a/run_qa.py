import bpy,sys,json
sys.path.insert(0,'/workspace/blender-study/skill-source/skills/blender-asset-qa/scripts')
import qa_check
objs=[o.name for o in bpy.data.collections['ASSET_Watchtower'].objects]
r=qa_check.run(objects=objs,profile='game')
print(json.dumps({k:r.get(k) for k in ['ok','pass','errors','warnings','ground_z','zfighting','floating']},default=str))
print('TOTALS',json.dumps({'objects':len(r.get('objects',{})),'tris':sum(v.get('tris',0) for v in r.get('objects',{}).values()),'dimensions':list(max(o.location[i]+o.dimensions[i]/2 for o in bpy.data.collections['ASSET_Watchtower'].objects) - min(o.location[i]-o.dimensions[i]/2 for o in bpy.data.collections['ASSET_Watchtower'].objects) for i in range(3))}))
