"""Reproducible Blender source: sculpted/skinned toad + authored animation clips."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector

OUT=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
COLORS=[('Skin',(0.78,.255,.055,1)),('Light',(0.98,.46,.13,1)),('Mark',(.24,.12,.31,1)),('Belly',(.93,.70,.39,1)),('Cloth',(.065,.10,.18,1)),('Pupil',(.025,.018,.025,1)),('Gold',(1,.79,.30,1)),('Steel',(.64,.70,.74,1)),('Edge',(.9,.94,.95,1))]
mats=[]
for name,col in COLORS:
 m=bpy.data.materials.new(name);m.diffuse_color=col;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=col;bs.inputs['Roughness'].default_value=.83
 mats.append(m)
meshes=[]
def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
def ell(name,pos,size,mat=0,bone=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=14,location=pos)
 o=bpy.context.object;o.name=name;o.scale=size;active(o);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mats[mat]);o['bone']=bone or '';meshes.append(o)
 for p in o.data.polygons:p.use_smooth=True
 return o
def tube(name,points,radius,mat,bone):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12;cu.bevel_depth=radius;cu.bevel_resolution=3
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for bp,co in zip(sp.bezier_points,points):bp.co=co;bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,cu);scene.collection.objects.link(o);active(o);bpy.ops.object.convert(target='MESH')
 o=bpy.context.object;o.data.materials.append(mats[mat]);o['bone']=bone;meshes.append(o)
 return o
def capsule(name,a,b,r,mat=0,bone=None):
 a,b=Vector(a),Vector(b);o=ell(name,(a+b)/2,(r,r,(b-a).length/2+r*.25),mat,bone)
 o.rotation_mode='QUATERNION';o.rotation_quaternion=(b-a).to_track_quat('Z','Y');active(o);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
 return o
def combine(objects,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;return o

# Continuous silhouette: voxel union removes the ball-and-cylinder seams.
skin=[]
skin.append(ell('Torso',(0,.55,1.95),(2.18,1.75,1.65)))
skin.append(ell('Head',(0,-.55,3.28),(2.72,1.73,1.00)))
skin.append(ell('Muzzle',(0,-1.15,2.98),(2.58,1.32,.62)))
for s in [-1,1]:
 skin.append(ell('BrowMass',(s*1.67,-.89,4.00),(.92,.84,.70)))
 skin.append(ell('Hip',(s*2.11,1.0,1.08),(1.28,1.45,.94)))
 skin.append(capsule('Shin',(s*2.92,1.18,.88),(s*2.78,-.20,.32),.42))
 skin.append(ell('HindFoot',(s*2.8,-.37,.29),(.64,.86,.27)))
 skin.append(capsule('UpperArm',(s*1.95,-.3,2.6),(s*2.85,-.85,1.35),.58))
 skin.append(capsule('Forearm',(s*2.85,-.85,1.35),(s*2.56,-1.91,.42),.42))
 skin.append(ell('Palm',(s*2.58,-2.03,.34),(.63,.55,.25)))
 for j in [-1,0,1]:
  start=(s*2.56+j*.25,-2.21,.29);end=(s*2.56+j*.42,-2.95+abs(j)*.12,.21)
  skin.append(capsule('Finger',start,end,.15))
  start=(s*2.78+j*.27,-.81,.25);end=(s*2.78+j*.5,-1.62+abs(j)*.16,.17)
  skin.append(capsule('Toe',start,end,.17))
body=combine(skin,'GamakichiSkin');meshes=[body]
active(body);rem=body.modifiers.new('Organic sculpt union','REMESH');rem.mode='VOXEL';rem.voxel_size=.065;rem.use_smooth_shade=True;bpy.ops.object.modifier_apply(modifier=rem.name)
smooth=body.modifiers.new('Sculpt smoothing','SMOOTH');smooth.factor=1.2;smooth.iterations=5;bpy.ops.object.modifier_apply(modifier=smooth.name)
dec=body.modifiers.new('Game topology','DECIMATE');dec.ratio=.30;bpy.ops.object.modifier_apply(modifier=dec.name)
for p in body.data.polygons:p.use_smooth=True
body.data.materials.clear()
for m in mats:body.data.materials.append(m)
# Broad belly and irregular organic purple markings are part of the surface.
for p in body.data.polygons:
 c=body.matrix_world@p.center;x,y,z=c
 p.material_index=0
 if abs(x)<1.68 and y<-.80 and .55<z<2.63:p.material_index=3
 if z>3.55 and abs(x)>1.05 and y<-.92:p.material_index=2
 if abs(x)>2.35 and .85<z<1.55 and y>.15 and math.sin(y*3+x*2)>-.3:p.material_index=2

# Deep-set eyes and a continuous mouth line, not floating eyeballs/beads.
ell('Jaw',(0,-1.12,2.49),(2.39,1.17,.34),1,'Jaw')
points=[]
for i in range(25):
 a=-1.22+i/24*2.44;points.append((math.sin(a)*2.60,-1.00-math.cos(a)*1.53,2.69+abs(a)*.12))
tube('Purple mouth border',points,.10,2,'Jaw')
tube('Mouth crease',[(x,y-.025,z+.065) for x,y,z in points],.027,5,'Head')
for s in [-1,1]:
 eye=ell('Eye',(s*1.63,-1.62,4.02),(.59,.20,.40),6,'Head')
 ell('Horizontal pupil',(s*1.63,-1.815,4.01),(.40,.045,.105),5,'Head')
 ell('Eye highlight',(s*1.63-.17,-1.85,4.12),(.065,.025,.055),8,'Head')
 tube('Upper eyelid',[(s*1.05,-1.60,4.18),(s*1.59,-1.83,4.34),(s*2.13,-1.55,4.30)],.105,0,'Head')
 tube('Lower eyelid',[(s*1.10,-1.61,3.85),(s*1.63,-1.79,3.69),(s*2.09,-1.55,3.86)],.065,2,'Head')
 ell('Nostril',(s*.49,-2.22,3.45),(.105,.035,.055),5,'Head')
 # Angled cheek stripes sit along the actual cheeks.
 for j in range(3):
  x=s*(2.08+j*.15)
  tube('Cheek marking',[(x,-1.85+j*.15,3.65-j*.1),(x+s*.10,-1.92+j*.19,3.28-j*.13)],.08,2,'Head')
 # Cloth shell around the back, shoulder to hem, with an open cream chest.
 verts=[];faces=[];steps=28
 for k in range(6):
  t=k/5;z=.62+t*2.35
  for i in range(steps+1):
   a=-.78+i/steps*(math.pi+1.56)
   x=2.2*math.cos(a)*(1-.12*t);y=.55+1.78*math.sin(a)
   verts.append((x,y,z))
 for k in range(5):
  for i in range(steps):
   n=k*(steps+1)+i;faces.append((n,n+1,n+steps+2,n+steps+1))
 if s==1:
  me=bpy.data.meshes.new('Haori');me.from_pydata(verts,[],faces);me.materials.append(mats[4]);o=bpy.data.objects.new('Open indigo haori',me);scene.collection.objects.link(o);o['bone']='Body';meshes.append(o)
  active(o);solid=o.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.06;bpy.ops.object.modifier_apply(modifier=solid.name)
  for p in o.data.polygons:p.use_smooth=True
 tube('Lapel piping',[(s*1.34,-.70,2.95),(s*1.52,-1.05,2.1),(s*1.67,-1.02,.72)],.055,3,'Body')

# Adult tanto: sculpted bevelled blade and wrapped hilt, weighted to the wrist.
def bevel_box(name,pos,scale,mat,bone):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=scale;active(o);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mats[mat]);o['bone']=bone;meshes.append(o)
 mod=o.modifiers.new('Soft bevel','BEVEL');mod.width=.055;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
bevel_box('Tanto grip',(2.57,-2.14,.48),(.24,.95,.25),5,'RightWrist')
bevel_box('Tanto guard',(2.57,-2.59,.48),(.72,.13,.4),6,'RightWrist')
verts=[(2.51,-2.65,.36),(2.51,-5.13,.36),(2.51,-5.52,.64),(2.51,-2.65,.90),(2.64,-2.65,.36),(2.64,-5.13,.36),(2.64,-5.52,.64),(2.64,-2.65,.90)]
faces=[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
me=bpy.data.meshes.new('Blade');me.from_pydata(verts,[],faces);me.materials.append(mats[7]);o=bpy.data.objects.new('Tanto blade',me);scene.collection.objects.link(o);o['bone']='RightWrist';meshes.append(o)
for i in range(5):tube('Hilt wrap',[(2.43,-1.78-i*.15,.49),(2.57,-1.85-i*.15,.64),(2.71,-1.92-i*.15,.49)],.035,2,'RightWrist')

# Purpose-built amphibian skeleton, not a humanoid auto-rig.
bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0));rig=bpy.context.object;rig.name='GamakichiRig'
eb=rig.data.edit_bones;eb.remove(eb[0]);bones={}
def bone(name,head,tail,parent=None):
 b=eb.new(name);b.head=head;b.tail=tail
 if parent:b.parent=eb[parent]
 bones[name]=(Vector(head),Vector(tail));return b
bone('Root',(0,0,0),(0,0,.5))
bone('Body',(0,.55,1.7),(0,.55,2.7),'Root')
bone('Head',(0,-.55,3.0),(0,-.55,4.0),'Body')
bone('Jaw',(0,-.65,2.63),(0,-1.65,2.63),'Head')
for s,label in [(-1,'Left'),(1,'Right')]:
 bone(label+'Shoulder',(s*1.95,-.3,2.6),(s*2.85,-.85,1.35),'Body')
 bone(label+'Elbow',(s*2.85,-.85,1.35),(s*2.56,-1.91,.42),label+'Shoulder')
 bone(label+'Wrist',(s*2.56,-1.91,.42),(s*2.56,-2.75,.23),label+'Elbow')
 bone(label+'Hip',(s*1.7,1.0,1.25),(s*2.92,1.18,.88),'Body')
 bone(label+'Knee',(s*2.92,1.18,.88),(s*2.78,-.2,.32),label+'Hip')
 bone(label+'Ankle',(s*2.78,-.2,.32),(s*2.78,-1.35,.18),label+'Knee')
bpy.ops.object.mode_set(mode='OBJECT')
def segdist(p,a,b):
 t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared));return (p-a-(b-a)*t).length
for o in meshes:
 for name in bones:o.vertex_groups.new(name=name)
 rigid=o.get('bone','')
 for v in o.data.vertices:
  if rigid:o.vertex_groups[rigid].add([v.index],1,'REPLACE');continue
  p=o.matrix_world@v.co;x,y,z=p
  if abs(x)<1.3 or z>3.2:allowed=['Body','Head']
  elif y<-.6 and z<2.9:allowed=[('Left' if x<0 else 'Right')+k for k in ['Shoulder','Elbow','Wrist']]+['Body']
  elif abs(x)>1.8 and z<1.9:allowed=[('Left' if x<0 else 'Right')+k for k in ['Hip','Knee','Ankle']]+['Body']
  else:allowed=['Body','Head',('Left' if x<0 else 'Right')+'Shoulder']
  nearest=sorted([(segdist(p,*bones[n]),n) for n in allowed])[:2]
  weights=[1/max(.08,d)**4 for d,n in nearest];total=sum(weights)
  for w,(_,n) in zip(weights,nearest):o.vertex_groups[n].add([v.index],w/total,'REPLACE')
 finalmod=o.modifiers.new('Gamakichi skinning','ARMATURE');finalmod.object=rig;o.parent=rig

# Join to a single, textured mesh under the importer triangle limit.
mesh=combine(meshes,'Gamakichi');active(mesh)
for mod in list(mesh.modifiers):mesh.modifiers.remove(mod)
dec=mesh.modifiers.new('Import budget','DECIMATE');dec.ratio=.36;bpy.ops.object.modifier_apply(modifier=dec.name)
mod=mesh.modifiers.new('Gamakichi skinning','ARMATURE');mod.object=rig
# A palette texture preserves the graphic anime colours through FBX import.
palette=bpy.data.images.new('GamakichiPalette',width=256,height=256,alpha=False)
pixels=[]
for y in range(256):
 for x in range(256):
  idx=min(len(COLORS)-1,(y//64)*4+x//64);pixels.extend(COLORS[idx][1])
palette.pixels=pixels;palette.filepath_raw=str(OUT/'GamakichiPalette.png');palette.file_format='PNG';palette.save()
for layer in list(mesh.data.uv_layers):mesh.data.uv_layers.remove(layer)
uv=mesh.data.uv_layers.new(name='UVMap')
for poly in mesh.data.polygons:
 material=mesh.data.materials[poly.material_index];idx=next((i for i,m in enumerate(mats) if m==material),0)
 for li in poly.loop_indices:uv.data[li].uv=((idx%4+.5)/4,(idx//4+.5)/4)
material=bpy.data.materials.new('GamakichiPaint');material.use_nodes=True
bs=material.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.83
tex=material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=palette;tex.interpolation='Closest';material.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
mesh.data.materials.clear();mesh.data.materials.append(material)
for p in mesh.data.polygons:p.material_index=0
mesh.data.calc_loop_triangles();print('TRIANGLES',len(mesh.data.loop_triangles),flush=True)

# Actual editable animation actions, also exported individually for Roblox.
scene.render.fps=30
clips={}
def reset():
 for p in rig.pose.bones:p.rotation_mode='XYZ';p.rotation_euler=(0,0,0);p.location=(0,0,0);p.scale=(1,1,1)
def make_clip(name,length,fn):
 rig.animation_data_create();action=bpy.data.actions.new(name);rig.animation_data.action=action
 for f in range(length+1):
  reset();fn(f/length)
  for p in rig.pose.bones:p.keyframe_insert('rotation_euler',frame=f+1);p.keyframe_insert('location',frame=f+1)
 scene.frame_start=1;scene.frame_end=length+1;clips[name]={'duration':length/30,'frames':[]}
 for f in range(length+1):
  scene.frame_set(f+1);frame={}
  for p in rig.pose.bones:
   m=p.matrix;frame[p.name]=[round(m[i][j],6) for i in range(3) for j in range(4)]
  clips[name]['frames'].append(frame)
 active(mesh);rig.select_set(True)
 bpy.ops.export_scene.fbx(filepath=str(OUT/(name+'.fbx')),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,path_mode='COPY',embed_textures=True)
 return action
def posebone(n,rot):rig.pose.bones[n].rotation_euler=rot
def idle(t):
 w=math.sin(t*math.tau);rig.pose.bones['Body'].location.z=w*.035;posebone('Head',(w*.018,0,0))
def walk(t):
 w=math.sin(t*math.tau);rig.pose.bones['Body'].location.z=(1-math.cos(t*math.tau*2))*.055
 posebone('Body',(.025*w,0,.035*w));posebone('Head',(-.025*w,0,0))
 for s,n in [(-1,'Left'),(1,'Right')]:
  phase=w*s;posebone(n+'Shoulder',(.22*phase,.08*phase,.07*phase));posebone(n+'Elbow',(-.32*max(0,phase),0,0));posebone(n+'Wrist',(.15*phase,0,0))
  posebone(n+'Hip',(-.25*phase,.12*phase,0));posebone(n+'Knee',(.34*max(0,-phase),0,0));posebone(n+'Ankle',(-.14*phase,0,0))
def attack(t):
 wind=math.sin(t/.30*math.pi/2) if t<.30 else max(0,1-(t-.30)/.20)**2
 strike=math.sin(min(1,max(0,(t-.30)/.20))*math.pi/2) if t<.50 else math.cos((t-.50)/.50*math.pi/2)**2
 posebone('Body',(.07*wind-.13*strike,0,.15*wind-.18*strike));posebone('RightShoulder',(-.65*wind+.62*strike,.25*wind-.6*strike,-.25*wind));posebone('RightElbow',(-.55*wind+.25*strike,0,0));posebone('RightWrist',(.15*wind,-.25*strike,0));posebone('Head',(.05*wind-.1*strike,0,-.1*wind))
def oil(t):
 f=math.sin(t*math.pi);posebone('Head',(-.2*f,0,0));posebone('Jaw',(.48*f,0,0));posebone('Body',(.08*f,0,0))
actions=[make_clip('Idle',60,idle),make_clip('Walk',30,walk),make_clip('Attack',30,attack),make_clip('Oil',24,oil)]
rig.animation_data.action=actions[0];scene.frame_set(1)
reset();active(mesh);rig.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'Gamakichi.fbx'),use_selection=True,object_types={'MESH','ARMATURE'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=False,path_mode='COPY',embed_textures=True)
(OUT/'clips.json').write_text(json.dumps(clips,separators=(',',':')))
(OUT/'rig.json').write_text(json.dumps({n:{'head':list(h),'tail':list(t),'rest':[round(rig.data.bones[n].matrix_local[i][j],6) for i in range(3) for j in range(4)]} for n,(h,t) in bones.items()},indent=2))

# Neutral turntable preview, without an in-game shader hiding the topology.
def point_at(obj,p):obj.rotation_euler=(Vector(p)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(9,-14,8));cam=bpy.context.object;point_at(cam,(0,-.3,2.2));scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=11.4
world=scene.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.14,.19,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7
for pos,power,size in [((2,-6,10),1100,7),((-6,-1,6),800,6),((1,6,8),1200,5)]:
 bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;point_at(l,(0,0,2))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04));floor=bpy.context.object;floor.name='PreviewFloor';fm=bpy.data.materials.new('Studio floor');fm.diffuse_color=(.055,.075,.11,1);floor.data.materials.append(fm)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Gamakichi.blend'))
scene.render.filepath=str(OUT/'preview.png');bpy.ops.render.render(write_still=True)
print('GAMAKICHI_ASSETS_READY',flush=True)
