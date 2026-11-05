import bpy
for o in bpy.context.selected_objects: o.select_set(False)
col=bpy.data.collections['ASSET_Windmill_Island']
for o in col.objects:
    if o.type=='MESH': o.select_set(True)
print('QA_SELECTED',len(bpy.context.selected_objects))
