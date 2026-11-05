"""Retarget Blender world poses to the imported Roblox bind pose; no animation uploads needed."""
import json, math
from pathlib import Path
P=Path(__file__).resolve().parent
rig=json.loads((P/'rig.json').read_text()); imp=json.loads((P/'imported.json').read_text());clips=json.loads((P/'clips.json').read_text())
def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
def inv(a):
 r=[[a[j][i] for j in range(3)]+[0] for i in range(3)]+[[0,0,0,1]]
 for i in range(3):r[i][3]=-sum(r[i][k]*a[k][3] for k in range(3))
 return r
def bm(v):return [v[i*4:i*4+4] for i in range(3)]+[[0,0,0,1]]
def rm(v):return [v[3+i*3:6+i*3]+[v[i]] for i in range(3)]+[[0,0,0,1]]
def cf(m):
 # Quaternion CFrames keep each animation below Studio's source size limit.
 trace=m[0][0]+m[1][1]+m[2][2]
 if trace>0:
  k=math.sqrt(trace+1)*2;w=.25*k;x=(m[2][1]-m[1][2])/k;y=(m[0][2]-m[2][0])/k;z=(m[1][0]-m[0][1])/k
 elif m[0][0]>m[1][1] and m[0][0]>m[2][2]:
  k=math.sqrt(1+m[0][0]-m[1][1]-m[2][2])*2;w=(m[2][1]-m[1][2])/k;x=.25*k;y=(m[0][1]+m[1][0])/k;z=(m[0][2]+m[2][0])/k
 elif m[1][1]>m[2][2]:
  k=math.sqrt(1+m[1][1]-m[0][0]-m[2][2])*2;w=(m[0][2]-m[2][0])/k;x=(m[0][1]+m[1][0])/k;y=.25*k;z=(m[1][2]+m[2][1])/k
 else:
  k=math.sqrt(1+m[2][2]-m[0][0]-m[1][1])*2;w=(m[1][0]-m[0][1])/k;x=(m[0][2]+m[2][0])/k;y=(m[1][2]+m[2][1])/k;z=.25*k
 v=[m[i][3] for i in range(3)]+[x,y,z,w]
 return 'CFrame.new('+','.join(format(0 if abs(x)<.00001 else x,'.6g') for x in v)+')'
# FBX importer maps Blender (x,y,z) to Roblox (-x,z,y).
C=[[-1,0,0,0],[0,0,1,0],[0,1,0,0],[0,0,0,1]]
rest={b['name']:rm(b['world']) for b in imp['bones']}
local={b['name']:rm(b['cf']) for b in imp['bones']}
parents={b['name']:b['parent'] for b in imp['bones']}
mesh=rm(imp['cf'])
destination=P.parents[1]/'src/shared/AodaAnimationFrames'
destination.mkdir(exist_ok=True)
loader=['--!strict', '-- Blender poses retargeted to the imported snake skeleton.', 'return {']
for name,clip in clips.items():
 out=['--!nocheck','-- Generated from assets/aoda/Aoda.blend.','return {duration='+str(clip['duration'])+',frames={']
 for frame in clip['frames']:
  desired={n:mul(mul(mul(mul(C,bm(frame[n])),inv(bm(rig[n]['rest']))),inv(C)),rest[n]) for n in rest}
  out.append('{'+','.join(n+'='+cf(mul(inv(local[n]),mul(inv(desired[parents[n]] if parents[n] else mesh),desired[n]))) for n in rest)+'},')
 out.append('}}')
 (destination/(name+'.luau')).write_text('\n'.join(out)+'\n')
 loader.append(name+'=require(script.Parent.AodaAnimationFrames.'+name+'),')
loader.append('}')
(P.parents[1]/'src/shared/AodaClips.luau').write_text('\n'.join(loader)+'\n')
print('Retargeted',len(clips),'clips /',len(rest),'bones')
