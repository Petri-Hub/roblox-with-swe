import bpy, math, os
from mathutils import Vector
from bpy_extras import anim_utils
ROOT=os.path.dirname(os.path.abspath(__file__)); os.makedirs(os.path.join(ROOT,'logs'),exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True); sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.render.threads_mode='FIXED'; sc.render.threads=4
sc.render.resolution_x=sc.render.resolution_y=768; sc.render.resolution_percentage=100; sc.render.image_settings.file_format='PNG'; sc.render.fps=24; sc.frame_start=1; sc.frame_end=49; sc.view_settings.view_transform='AgX'
sc.world=bpy.data.worlds.new('World_Studio'); sc.world.color=(.12,.18,.25)
def coll(n):
 c=bpy.data.collections.new(n); sc.collection.children.link(c); return c
asset=coll('ASSET_Windmill_Island'); pres=coll('PRESENTATION'); active=asset
def mat(n,c,r=.78,m=0):
 x=bpy.data.materials.new('M_'+n); x.diffuse_color=(*c,1); x.roughness=r; x.metallic=m; bs=next(i for i in x.node_tree.nodes if i.type=='BSDF_PRINCIPLED'); bs.inputs['Base Color'].default_value=(*c,1); bs.inputs['Roughness'].default_value=r; bs.inputs['Metallic'].default_value=m; return x
grass=mat('Meadow',(.19,.39,.19)); soil=mat('Earth',(.32,.20,.12)); stone=mat('Stone',(.35,.39,.39)); plaster=mat('Warm_Limewash',(.88,.72,.49)); wood=mat('Chestnut_Wood',(.25,.105,.045)); wood2=mat('Light_Wood',(.48,.27,.12)); roofmat=mat('Terracotta',(.58,.13,.075)); iron=mat('Dark_Iron',(.08,.12,.14),.42,.55); leaf=mat('Sage',(.19,.39,.12)); leaf2=mat('Leaf_Light',(.40,.54,.16)); gold=mat('Hub_Brass',(.72,.42,.12),.32,.65)
def mov(o):
 for c in list(o.users_collection): c.objects.unlink(o)
 active.objects.link(o); return o
def finish(o,n,m): o.name=n; o.data.materials.append(m); return mov(o)
def cube(n,loc,dim,m,bev=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.dimensions=dim; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); finish(o,n,m)
 if bev:
  b=o.modifiers.new('Soft_cut_edges','BEVEL'); b.width=bev; b.segments=1; o.modifiers.new('Weighted_normals','WEIGHTED_NORMAL')
 return o
def cyl(n,loc,r,d,m,v=12,r2=None,rot=None):
 if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=d,location=loc)
 else: bpy.ops.mesh.primitive_cone_add(vertices=v,radius1=r,radius2=r2,depth=d,location=loc)
 o=bpy.context.object
 if rot:o.rotation_euler=rot
 return finish(o,n,m)
def ico(n,loc,scale,m,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,n,m)
def beam(n,a,b,w,m):
 a,b=Vector(a),Vector(b); d=b-a; o=cube(n,(a+b)*.5,(w,w,d.length),m); o.rotation_mode='QUATERNION'; o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized()); return o
# Layered polygonal island.
cyl('SM_Island_Earth',(0,0,-.02),3.15,.48,soil,16,2.95); cyl('SM_Island_Top',(0,0,.20),2.96,.20,grass,16,2.92)
for i in range(12):
 a=math.tau*i/12; ico('SM_Rim_Stone_%02d'%i,(2.88*math.cos(a),2.88*math.sin(a),.02),(.38,.34,.27),stone)
# Tower and recognizable cottage details.
cyl('SM_Tower',(0,0,1.60),.91,2.55,plaster,12,.68); cyl('SM_Foundation',(0,0,.47),.99,.22,stone,12,.97); cyl('SM_Eave_Beam',(0,0,2.88),.77,.18,wood,12,.75); cyl('SM_Roof',(0,0,3.18),.98,.68,roofmat,12,.05); cyl('SM_Roof_Cap',(0,0,3.54),.13,.12,gold,10,.10)
cube('SM_Door_Recess',(0,-.91,1.03),(.64,.10,1.08),wood); cube('SM_Door_Leaf',(0,-.98,1.04),(.53,.06,.94),wood2)
for x in [-.17,-.055,.06,.175]: cube('SM_Door_Plank',(x,-1.04,1.04),(.025,.012,.88),wood)
cube('SM_Door_Lintel',(0,-1.00,1.61),(.78,.13,.12),wood); ico('SM_Door_Knob',(.18,-1.05,1.02),(.045,.035,.045),gold,2)
for x in [-.45,.45]: cube('SM_Window_Frame',(x,-.72,2.25),(.24,.08,.35),wood); cube('SM_Window_Glass',(x,-.78,2.25),(.15,.03,.25),iron)
# Rotor: forward offset gives physical clearance; sails and hub parent to rotating center.
hub=bpy.data.objects.new('ANIM_Rotor_Hub',None); asset.objects.link(hub); hub.location=(0,-1.03,3.02)
axle=cyl('SM_Hub_Axle',(0,-.94,3.02),.18,.34,iron,12,rot=(math.pi/2,0,0))
cap=ico('SM_Rotor_Hub',(0,-1.22,3.02),(.22,.12,.22),gold,2); cap.parent=hub; cap.matrix_parent_inverse=hub.matrix_world.inverted()
for i in range(4):
 ang=math.radians(45+i*90)
 def pt(r,s=0):return (math.cos(ang)*r-math.sin(ang)*s,-1.19,3.02+math.sin(ang)*r+math.cos(ang)*s)
 vs=[pt(.18,-.07),pt(.43,-.14),pt(1.31,-.25),pt(1.42,0),pt(1.31,.25),pt(.43,.14),pt(.18,.07)]
 me=bpy.data.meshes.new('BladeMesh'); me.from_pydata(vs,[],[(0,1,2,3,4,5,6)]); me.materials.append(wood2); me.update(); ob=bpy.data.objects.new('SM_Rotor_Blade_%d'%i,me); asset.objects.link(ob); ob.parent=hub; ob.matrix_parent_inverse=hub.matrix_world.inverted(); ob.modifiers.new('Sail_thickness','SOLIDIFY').thickness=.065
 spar=beam('SM_Blade_Spar_%d'%i,pt(.2),pt(1.30),.065,wood); spar.parent=hub; spar.matrix_parent_inverse=hub.matrix_world.inverted()
 tip=ico('SM_Blade_Tip_%d'%i,pt(1.30),(.07,.07,.08),iron); tip.parent=hub; tip.matrix_parent_inverse=hub.matrix_world.inverted()
hub.rotation_mode='XYZ'; hub.rotation_euler[1]=0; hub.keyframe_insert(data_path='rotation_euler',index=1,frame=1); hub.rotation_euler[1]=math.tau; hub.keyframe_insert(data_path='rotation_euler',index=1,frame=49); hub.animation_data.action.name='Windmill_Rotor_Loop'
cb=anim_utils.action_ensure_channelbag_for_slot(hub.animation_data.action,hub.animation_data.action_slot)
for fc in cb.fcurves:
 for kp in fc.keyframe_points: kp.interpolation='LINEAR'
# Rear horseshoe picket fence remains clear of rotor sweep.
for side in [-1,1]:
 for j in range(5):
  y=.35+j*.42; x=side*(2.18-.20*abs(j-2)); cube('SM_Fence_Post',(x,y,.64),(.13,.13,.88),wood,.02)
 beam('SM_Fence_Rail',(side*2.25,.32,.85),(side*2.25,2.05,.85),.075,wood); beam('SM_Fence_Rail',(side*2.25,.32,.48),(side*2.25,2.05,.48),.065,wood)
for y in [.34,1.18,2.02]:
 cube('SM_Fence_Back_Post',(0,y,.64),(.13,.13,.88),wood,.02)
 for x in [-1.5,-.75,0,.75,1.5]:
  if x:cube('SM_Fence_Picket',(x,y,.64),(.08,.10,.66),wood2,.01)
 cube('SM_Fence_Back_Rail',(0,y,.85),(3.1,.08,.08),wood)
# Three grass clumps with restrained cyclic swaying.
for k,(x,y) in enumerate([(-1.65,-.15),(1.60,.10),(.55,1.85)]):
 parent=bpy.data.objects.new('ANIM_Grass_Sway_%d'%k,None); asset.objects.link(parent); parent.location=(x,y,.31)
 for j in range(5):
  a=math.tau*j/5; base=Vector((x+.04*math.cos(a),y+.04*math.sin(a),.34)); end=Vector((x+.28*math.cos(a),y+.23*math.sin(a),.85+(j%2)*.08)); d=end-base
  blade=cyl('SM_Grass_Blade_%d_%d'%(k,j),(base+end)*.5,.07,d.length,leaf if j%2 else leaf2,5,.008); blade.rotation_mode='QUATERNION'; blade.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized()); blade.parent=parent; blade.matrix_parent_inverse=parent.matrix_world.inverted()
 parent.rotation_mode='XYZ'; vals=[0,6 if k%2==0 else -6,0,-6 if k%2==0 else 6,0]
 for frame,val in zip([1,13,25,37,49],vals): parent.rotation_euler[1]=math.radians(val); parent.keyframe_insert(data_path='rotation_euler',index=1,frame=frame)
 parent.animation_data.action.name='Grass_Sway_Loop_%d'%k
 cb=anim_utils.action_ensure_channelbag_for_slot(parent.animation_data.action,parent.animation_data.action_slot)
 for fc in cb.fcurves:
  for kp in fc.keyframe_points: kp.interpolation='BEZIER'
# Separate studio set: no cameras, lights, floor in exported selection.
active=pres; backdrop=mat('Studio_Backdrop',(.15,.22,.30)); bpy.ops.mesh.primitive_plane_add(size=2000, location=(0,0,-.48)); floor=bpy.context.object; finish(floor,'PRESENT_Studio_Ground',backdrop)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def camera(n,loc,target):
 d=bpy.data.cameras.new(n); o=bpy.data.objects.new(n,d); pres.objects.link(o); o.location=loc; aim(o,target); d.type='ORTHO'; d.ortho_scale=8.2; return o
def area(n,loc,target,power,color,size):
 d=bpy.data.lights.new(n,'AREA'); d.energy=power; d.color=color; d.shape='DISK'; d.size=size; o=bpy.data.objects.new(n,d); pres.objects.link(o); o.location=loc; aim(o,target)
front=camera('CAM_Front',(0,-10,3.3),(0,0,1.75)); back=camera('CAM_Back',(0,10,3.4),(0,0,1.75)); presentation=camera('CAM_Presentation',(7,-10,7),(0,0,1.55))
area('LIGHT_Key',(-4,-6,9),(0,0,1.5),850,(1,.78,.56),5); area('LIGHT_Fill',(5,-3,5),(0,0,1.5),600,(.62,.78,1),4); area('LIGHT_Rim',(2,5,8),(0,0,1.5),1000,(1,.48,.25),3)
def render(path,frame,cam):sc.camera=cam; sc.frame_set(frame); sc.render.filepath=path; bpy.ops.render.render(write_still=True)
for n,c in [('front.png',front),('back.png',back),('presentation.png',presentation)]:render(os.path.join(ROOT,n),1,c)
for f in (1,16,32):render(os.path.join(ROOT,'motion-%02d.png'%f),f,presentation)
sc.camera=presentation; sc.frame_set(1); bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'asset.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in asset.objects:o.select_set(True)
bpy.context.view_layer.objects.active=hub
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'asset.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=True,export_force_sampling=True,export_nla_strips=False,export_cameras=False,export_lights=False)
print('DELIVERY',len(asset.objects),sum(len(o.data.polygons) for o in asset.objects if o.type=='MESH'))
