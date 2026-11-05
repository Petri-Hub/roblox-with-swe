import bpy, math, os
from mathutils import Vector
from math import sin, cos, pi
ROOT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(ROOT,'logs'), exist_ok=True)
# Clean scene
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection': bpy.data.collections.remove(c)
scene=bpy.context.scene
asset=bpy.data.collections.new('WINDMILL_ASSET'); scene.collection.children.link(asset)
studio=bpy.data.collections.new('STUDIO_ONLY'); scene.collection.children.link(studio)
def move_to(obj, coll):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    coll.objects.link(obj)
def mat(name,color,rough=.8):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough
    return m
cream=mat('Warm ivory plaster',(0.86,.72,.48)); red=mat('Terracotta roof',(.55,.13,.085)); wood=mat('Honey oak',(.34,.16,.065)); dark=mat('Deep brown',(.11,.055,.025)); grass=mat('Island meadow',(.22,.38,.16)); edge=mat('Earth cut',(.31,.20,.12)); leaf=mat('Sage leaves',(.20,.47,.20)); leaf2=mat('Fresh leaf tips',(.43,.62,.20)); metal=mat('Aged brass',(.72,.43,.12),.35); water=mat('Lagoon',(.10,.35,.43))
def finish(obj,name,material,coll=asset):
    obj.name=name; obj.data.materials.append(material); move_to(obj,coll); return obj
def cube(name,loc,scale,material,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc); o=bpy.context.object; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); finish(o,name,material)
    if bevel:
        mod=o.modifiers.new('Soft carved edges','BEVEL'); mod.width=bevel; mod.segments=1
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o
def cyl(name,loc,radius,depth,material,verts=12,rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rotation or (0,0,0)); return finish(bpy.context.object,name,material)
def ico(name,loc,scale,material,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1, location=loc); o=bpy.context.object; o.scale=scale; return finish(o,name,material)
# island, broad enough for safe blade sweep
cyl('Floating island earth',(0,0,.20),3.05,.72,edge,48)
cyl('Meadow top',(0,0,.57),3.02,.12,grass,48)
# water base visible as studio-like lagoon accent asset geometry
cyl('Lagoon disk',(0,0,-.29),3.42,.12,water,64)
# mill tapered stone/plaster body, mesh frustum
verts=[]; faces=[]; n=12
for z,r in [(.63,.68),(2.52,.47)]:
    for i in range(n):
        a=2*pi*i/n+pi/12; verts.append((r*cos(a),r*sin(a),z))
for i in range(n): faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
faces += [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
me=bpy.data.meshes.new('faceted tower mesh'); me.from_pydata(verts,[],faces); me.materials.append(cream); ob=bpy.data.objects.new('Tapered mill tower',me); asset.objects.link(ob)
# roof low-poly cone
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=.75, radius2=.08, depth=.63, location=(0,0,2.77), rotation=(0,0,pi/12)); finish(bpy.context.object,'Terracotta conical roof',red)
# roof eaves ring
cyl('Roof eave',(0,0,2.49),.74,.09,wood,12)
# door front y=-
# arch-like simple door with lintel
cube('Oak door',(0,-.603,1.19),(.43,.09,.92),wood,.045)
cube('Door inset',(0,-.655,1.20),(.31,.025,.73),dark,.025)
cyl('Brass door knob',(.105,-.68,1.15),.035,.025,metal,8,(pi/2,0,0))
# small front window
cube('Window frame',(.0,-.493,2.05),(.32,.08,.33),wood,.03)
cube('Window dark glass',(0,-.542,2.05),(.22,.025,.23),dark,.015)
cube('Window mullion vertical',(0,-.56,2.05),(.035,.025,.23),metal,.006)
cube('Window mullion cross',(0,-.56,2.05),(.22,.025,.035),metal,.006)
# rotor plane local coordinates in XZ, at y front; parent rotates around y. Rotor center x=0,z=2.42
rot=bpy.data.objects.new('Rotor assembly',None); asset.objects.link(rot); rot.location=(0,-1.02,3.23)
# Forward shaft hub and a diagonal oak bracket visibly tie the rotor back to the roofline.
hub=cyl('Rotor brass hub',(0,-1.02,3.23),.15,.25,metal,12,(pi/2,0,0)); hub.parent=rot; hub.location=(0,0,0)
cyl('Rotor axle',(0,-.79,3.13),.075,.68,dark,10,(pi/2,0,0))
brace=cube('Rotor support bracket',(0,-.83,2.91),(.16,.16,.82),wood,.025); brace.rotation_euler[0]=.50
# spoke elements as long tapered low-poly mesh, blade endpoints at radial 1.50, starts .12
for idx in range(4):
    angle=idx*pi/2
    # local blade points in XY initially, orient whole object local around Y via vertices in XZ
    # Blade broad at root then narrows at tip, trailing edge angled
    radial=[.12,.40,1.48,1.48,.40]
    width=[.11,.26,.12,-.09,-.20]
    # width across tangent using local xz plane. rotation in xz
    pts=[]
    for r,w in zip(radial,width):
        x=r*sin(angle)+w*cos(angle); z=r*cos(angle)-w*sin(angle)
        pts.append((x,-.045,z))
    # extrude thickness in local y
    v=[(x,y,z) for y in [-.055,.055] for x,_,z in pts]
    f=[tuple(range(5)),tuple(range(9,4,-1))]
    for j in range(5): f.append((j,(j+1)%5,(j+1)%5+5,j+5))
    mesh=bpy.data.meshes.new('sail blade mesh'); mesh.from_pydata(v,[],f); mesh.materials.append(wood); mesh.materials.append(cream)
    blade=bpy.data.objects.new('Oak sail %d'%(idx+1),mesh); asset.objects.link(blade); blade.parent=rot
    bevel=blade.modifiers.new('Blade edge softness','BEVEL'); bevel.width=.025; bevel.segments=1
    blade.modifiers.new('Blade normals','WEIGHTED_NORMAL')
# hub cap in front parent
cap=cyl('Hub cap',(0,-.92,2.42),.09,.07,metal,12,(pi/2,0,0)); cap.parent=rot; cap.location=(0,-.18,0)
# Fence segments around far perimeter, with pickets, leave front center clear; ensure outside rotor envelope
# island radius 3; place fence near radius 2.55. Segmented rails in back arc + sides
for i in range(28):
    a=-pi*.90+i*(pi*1.8/27) # arc leaving a front entry gap near camera direction? this covers most around
    x,y=2.52*cos(a),2.52*sin(a)
    # front y negative arc gets close to door but far enough from rotor
    cube('Fence picket %02d'%i,(x,y,.91),(.105,.12,.65),wood,.025)
# rails approximate polygonal annulus back half + sides, leave front access
for start,end in [(pi*.08,pi*.92),(-pi*.92,-pi*.08)]:
    count=12
    for j in range(count):
        a1=start+(end-start)*j/count; a2=start+(end-start)*(j+1)/count
        p1=Vector((2.52*cos(a1),2.52*sin(a1),.91)); p2=Vector((2.52*cos(a2),2.52*sin(a2),.91))
        mid=(p1+p2)/2; vec=p2-p1
        rail=cube('Fence rail',(mid.x,mid.y,1.00),(vec.length,.075,.08),wood,.015); rail.rotation_euler[2]=math.atan2(vec.y,vec.x)
        rail=cube('Fence lower rail',(mid.x,mid.y,.80),(vec.length,.065,.07),wood,.012); rail.rotation_euler[2]=math.atan2(vec.y,vec.x)
# vegetation clumps, sculpted stems as tapered cones/leaf blades and parent sway empties
for gi,(gx,gy) in enumerate([(-1.30,-1.25),(1.28,-1.10),(1.40,.85)]):
    sway=bpy.data.objects.new('Swaying grass tuft %d'%(gi+1),None); asset.objects.link(sway); sway.location=(gx,gy,.66)
    for j in range(5):
        ang=j*2*pi/5+gi
        lean=.20+.04*(j%2); height=.34+.10*(j%3)
        # lance-shaped leaf mesh local with tapered point, parented
        vx=[(0,0,0),(-.08,0,height*.55),(-lean,0,height),( .08,0,height*.55),(0,0,0)]
        mesh=bpy.data.meshes.new('leaf blade'); mesh.from_pydata(vx,[],[(0,1,2,3)]); mesh.materials.append(leaf if j%2 else leaf2)
        leafob=bpy.data.objects.new('Meadow blade',mesh); asset.objects.link(leafob); leafob.parent=sway; leafob.location=(.07*cos(ang),.07*sin(ang),0); leafob.rotation_euler[2]=ang
        sol=leafob.modifiers.new('Leaf thickness','SOLIDIFY'); sol.thickness=.025
# animate rotor and tufts, seamless 48 frame cyclic at 24 fps
scene.frame_start=1; scene.frame_end=48; scene.render.fps=24
rot.rotation_mode='XYZ'
rot.rotation_euler[1]=0; rot.keyframe_insert(data_path='rotation_euler',frame=1)
rot.rotation_euler[1]=2*pi; rot.keyframe_insert(data_path='rotation_euler',frame=49)
for gi in range(3):
    obj=bpy.data.objects.get('Swaying grass tuft %d'%(gi+1)); obj.rotation_mode='XYZ'
    for frame,ang in [(1,-.12),(13,.12),(25,-.12),(37,.12),(49,-.12)]:
        obj.rotation_euler[1]=ang; obj.keyframe_insert(data_path='rotation_euler',frame=frame)
# linear rotor, smooth vegetation, cycles
for obj in bpy.data.objects:
    ad=obj.animation_data
    if not ad or not ad.action: continue
    action=ad.action
    for layer in action.layers:
        for strip in layer.strips:
            bag=strip.channelbag(ad.action_slot) if ad.action_slot else None
            if not bag: continue
            for fc in bag.fcurves:
                for kp in fc.keyframe_points: kp.interpolation='LINEAR'
                fc.modifiers.new('CYCLES')
# Set frame 1 and camera setup
scene.frame_set(1)
# studio floor
floor_mat=mat('Studio blue backdrop',(.055,.105,.16))
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.38)); finish(bpy.context.object,'Studio floor',floor_mat,studio)
def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def camera(name,loc,target,lens=52):
    bpy.ops.object.camera_add(location=loc); c=bpy.context.object; move_to(c,studio); c.name=name; c.data.lens=lens; aim(c,target); return c
cam_front=camera('Front camera',(4.8,-9.7,5.2),(0,0,1.25),52)
cam_back=camera('Back camera',(-5.7,8.7,4.6),(0,0,1.25),52)
cam_present=camera('Presentation camera',(6.5,-8.5,6.7),(0,0,1.25),52)
# studio lights
for name,loc,power,size,color in [('Key', (1,-5,8),1100,5,(1,.82,.61)),('Fill',(-5,-2,5),800,4,(.56,.72,1)),('Rim',(2,5,6),1300,3,(1,.55,.32))]:
    bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; move_to(l,studio); l.name=name; l.data.energy=power; l.data.shape='DISK'; l.data.size=size; l.data.color=color; aim(l,(0,0,1))
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=20
scene.render.threads_mode='FIXED'; scene.render.threads=4
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.view_settings.view_transform='AgX'
# Render three angles and motion frames
scene.camera=cam_front; scene.render.filepath=os.path.join(ROOT,'front.png'); bpy.ops.render.render(write_still=True)
scene.camera=cam_back; scene.render.filepath=os.path.join(ROOT,'back.png'); bpy.ops.render.render(write_still=True)
scene.camera=cam_present; scene.render.filepath=os.path.join(ROOT,'presentation.png'); bpy.ops.render.render(write_still=True)
for fr in (1,16,32):
    scene.frame_set(fr); scene.camera=cam_present; scene.render.filepath=os.path.join(ROOT,'motion-%02d.png'%fr); bpy.ops.render.render(write_still=True)
# Save blend with studio cameras/lights retained; export selected asset objects only
scene.frame_set(1); bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'asset.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in asset.objects: obj.select_set(True)
bpy.context.view_layer.objects.active=next(iter(asset.objects))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'asset.glb'), export_format='GLB', use_selection=True, export_animations=True, export_frame_range=False, export_force_sampling=True, export_materials='EXPORT', export_cameras=False, export_lights=False)
print('OUTPUT_ROOT',ROOT)
