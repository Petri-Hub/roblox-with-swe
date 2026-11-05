import bpy, math, os
from mathutils import Vector, Matrix
OUT=os.path.dirname(os.path.abspath(__file__))
# Reset
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name != 'Collection': bpy.data.collections.remove(d)
root=bpy.context.scene.collection
assets=bpy.data.collections.new('ASSET | modular dungeon kit'); root.children.link(assets)
studio=bpy.data.collections.new('STUDIO | render only'); root.children.link(studio)
# materials
def mat(name,color,metal=0,rough=.85):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    return m
stone=mat('Stone | slate gray',(0.25,.29,.31)); edge=mat('Stone | cut edges',(.38,.40,.38)); dark=mat('Iron | charcoal',(.10,.12,.12),.65,.45); gold=mat('Torch | aged brass',(.55,.29,.08),.55,.42); flame=mat('Flame | amber',(1,.28,.025),0,.35)
def move_to(obj,col):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
def bevel(obj,amount=.08,segments=1):
    mod=obj.modifiers.new('Soft chipped low-poly edges','BEVEL'); mod.width=amount; mod.segments=segments
    mod2=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=mod.name); bpy.ops.object.modifier_apply(modifier=mod2.name)
def cube(name,loc,scale,material,col=assets,bev=.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); move_to(o,col); o.data.materials.append(material)
    if bev: bevel(o,bev)
    return o
def meshobj(name,verts,faces,material,col=assets):
    me=bpy.data.meshes.new(name+' mesh'); me.from_pydata(verts,[],faces); me.materials.append(material); me.update(); o=bpy.data.objects.new(name,me); col.objects.link(o); return o
def cone(name,loc,r1,r2,depth,material,vertices=6,rotation=None,col=assets):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rotation or (0,0,0)); o=bpy.context.object; o.name=name; move_to(o,col); o.data.materials.append(material); return o
# Module dimensions: 4u grid; wall height 4, thickness .4
# floor tile centered local origin z=0
def floor_module(name='MOD | Floor 4x4'):
    return cube(name,(0,0,-.12),(4,4,.24),stone,bev=.045)
def wall_module(name='MOD | Wall 4x4'):
    o=cube(name,(0,0,2),(4,.4,4),stone,bev=.07)
    # edge bands, relief stones front and back lightweight shallow cubes
    for y in (-.215,.215):
        for x in (-1.25,1.25):
            cube(name+' | face block',(x,y,1.0),(1.15,.06,1.25),edge,bev=.045)
            cube(name+' | upper block',(x,y,2.85),(1.15,.06,1.0),edge,bev=.045)
        cube(name+' | footing',(0,y,.28),(4.04,.10,.42),edge,bev=.04)
        cube(name+' | cap',(0,y,3.78),(4.08,.12,.32),edge,bev=.04)
    return o
def arch_module(name='MOD | Door arch 4x4'):
    # free opening 2.1 wide, 3.15 high: two legs and header
    for x in (-1.35,1.35): cube(name+' | jamb',(x,0,2), (1.3,.62,4),stone,bev=.07)
    cube(name+' | lintel',(0,0,3.53),(1.4,.62,.94),stone,bev=.07)
    # raised voussoir accents
    for x in (-1.37,-.92,0,.92,1.37):
        cube(name+' | voussoir',(x,-.34,3.52),(.36,.12,.98),edge,bev=.045)
    cube(name+' | threshold',(0,0,.015),(2.25,.66,.12),edge,bev=.025)
def corner_module(name='MOD | Corner 90deg 4x4'):
    # corner segment composing two 4-unit walls centered around shared corner at local origin
    cube(name+' | arm X',(1.8,0,2),(4,.4,4),stone,bev=.07)
    cube(name+' | arm Y',(0,1.8,2),(.4,4,4),stone,bev=.07)
    for x,y in ((0,0),): cube(name+' | corner pier',(0,0,2),(.8,.8,4),edge,bev=.07)
def column_module(name='MOD | Column 1x1x4'):
    cube(name+' | shaft',(0,0,2),(.72,.72,3.25),stone,bev=.08)
    cube(name+' | base',(0,0,.22),(1,.95,.44),edge,bev=.07)
    cube(name+' | capital',(0,0,3.78),(1.08,1.0,.44),edge,bev=.07)
def torch_module(name='MOD | Wall torch'):
    # front is -Y; local origin at mount plane, mount extends forward
    cube(name+' | wall plate',(0,0,0),(.38,.13,.62),dark,bev=.055)
    # rod oriented vertical
    cone(name+' | bracket',(0,-.22,.12),.10,.08,.55,dark,6,(math.pi/2,0,0))
    cone(name+' | cup',(0,-.34,.40),.19,.12,.24,gold,6)
    cone(name+' | flame',(0,-.34,.72),.12,0,.48,flame,5)
# create collections by type for exports
modules={}
for key,fn in [('Floor',floor_module),('Wall',wall_module),('Corner',corner_module),('DoorArch',arch_module),('Column',column_module),('Torch',torch_module)]:
    c=bpy.data.collections.new('MODULE | '+key); assets.children.link(c); before=set(bpy.data.objects); fn(); new=set(bpy.data.objects)-before
    for o in new: move_to(o,c)
    modules[key]=c
# Demo assembly collection
D=bpy.data.collections.new('DEMO | curved corridor and traversable entrance'); assets.children.link(D)
def add_inst(key,loc,rot=0):
    c=modules[key]
    for src in c.objects:
        o=src.copy(); o.data=src.data; D.objects.link(o); o.location=Matrix.Rotation(rot,3,'Z') @ Vector(src.location)+Vector(loc); o.rotation_euler[2]+=rot
# main 3 tile long corridor, walls, open gateway on west end
for x in (-4,0,4): add_inst('Floor',(x,0,0))
# side walls at north/south, across x segments
for x in (-4,0,4):
    add_inst('Wall',(x,2,0),0); add_inst('Wall',(x,-2,0),math.pi)
# entrance end at x=-6 facing camera in renders, arch module oriented 90 degrees (local x wall direction -> world y)
add_inst('DoorArch',(-6,0,0),math.pi/2)
# curved turn at east: floor continues north; wall continuation at y=4 and east side corner visual
for y in (4,8): add_inst('Floor',(4,y,0))
# north boundary runs x=0,4,8 at y=10
for x in (0,4,8): add_inst('Wall',(x,10,0),0)
# east closure segment at x=6, along y; open continuation at y=10 corner
for y in (4,8): add_inst('Wall',(6,y,0),math.pi/2)
# visible pillars and torches along walls
for x in (-3,1,5):
    add_inst('Torch',(x,1.76,2.6),0)
    add_inst('Column',(x,1.0,0))
# additional columns at bend
for x,y in ((5,9),(1,9)): add_inst('Column',(x,y,0))
# Convert assembly copies into D objects; exports should only include kit assets & demo, while module glbs use source module collection.
# scene camera / studio
# Ground studio large plane
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.40)); ground=bpy.context.object; ground.name='Studio floor (not exported)'; move_to(ground,studio); ground.data.materials.append(mat('Studio | warm charcoal',(.065,.075,.082)))
def aim(obj,pt): obj.rotation_euler=(Vector(pt)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,color,size,target):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=color; data.shape='DISK'; data.size=size; o=bpy.data.objects.new(name,data); studio.objects.link(o); o.location=loc; aim(o,target)
area('Key softbox',(1,-8,13),1800,(1,.76,.54),8,(0,2,1))
area('Cool fill',(-9,-1,8),1200,(.48,.68,1),7,(0,2,1))
area('Rim',(4,11,12),2100,(1,.48,.18),6,(1,3,1))
# camera
def camera(name,loc,target,lens=48):
    data=bpy.data.cameras.new(name); o=bpy.data.objects.new(name,data); studio.objects.link(o); o.location=loc; data.lens=lens; aim(o,target); return o
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=12; scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'
scene.world.color=(.12,.12,.12)
# collections visibility camera set
# render cameras intended demonstrate entrance and curved plan; all frame sculpture.
views=[('front.png',(-11,-15,9),(0,3,1.5)),('back.png',(12,16,9),(0,3,1.5)),('presentation.png',(-13,-13,11),(1,3,1.5))]
for fname,loc,target in views:
    cam=camera('Camera | '+fname,loc,target,50); scene.camera=cam; scene.render.filepath=os.path.join(OUT,fname); bpy.ops.render.render(write_still=True)
# Export functions, deselect all, use glTF selected objects
# Remove studio objects from export, include source modules and demo objects
bpy.ops.object.select_all(action='DESELECT')
for o in list(assets.all_objects): o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(assets.all_objects))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'asset.glb'), export_format='GLB', use_selection=True, export_apply=True, export_cameras=False, export_lights=False)
# separate by module type
for key,c in modules.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in c.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(c.objects))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'modules',key.lower()+'.glb'), export_format='GLB', use_selection=True, export_apply=True, export_cameras=False, export_lights=False)
# save blend
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'asset.blend'))
print('GENERATED', OUT)
