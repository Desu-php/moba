--!strict
type Pose={[string]:{number}}
local P={}
function P.sample(id:string,phase:number,base:Pose):Pose
 local p=math.clamp(phase,0,1)
 local weight=math.min(1,p/.12,(1-p)/.18)
 local pose:Pose={Waist={-.12,0,0},Neck={.1,0,0},RightShoulder={.3,0,.1},RightElbow={.5,0,0},LeftShoulder={.3,0,-.1},LeftElbow={.5,0,0}}
 if id=="Kirin" then
  local release=math.clamp((p-.7)/.3,0,1)
  pose.RightShoulder={2.85-1.25*release,0,.15};pose.RightElbow={.12,0,0};pose.RightWrist={-.1,0,0};pose.Neck={-.2+.35*release,0,0}
 elseif id=="KirinPrepare" or id=="KirinBoost" or id=="SasukeFireball" or id=="PhoenixFlowers" then
  pose.LeftShoulder={1.15,-.15,.45};pose.LeftElbow={1.5,0,0};pose.LeftWrist={0,0,.25}
  pose.RightShoulder={1.05,.15,-.35};pose.RightElbow={1.5,0,0};pose.RightWrist={0,0,-.25}
  pose.Neck={if id=="KirinPrepare" or id=="KirinBoost" then -.3 else .08,0,0}
 elseif string.find(id,"Susanoo") or id=="ChidoriNagashi" then
  pose.Waist={-.08,0,0};pose.Neck={-.12,0,0}
  pose.LeftShoulder={.45,0,-.65};pose.RightShoulder={.45,0,.65};pose.LeftElbow={.25,0,0};pose.RightElbow={.25,0,0}
 elseif string.find(id,"Chibaku") then
  pose.LeftShoulder={1.35,-.12,.4};pose.RightShoulder={1.35,.12,-.4};pose.LeftElbow={1.25,0,0};pose.RightElbow={1.25,0,0}
 elseif id=="ChidoriEiso" or id=="ChidoriSenbon" or id=="EntonPull" then
  pose.LeftShoulder={1.6,0,-.12};pose.LeftElbow={.1,0,0};pose.Waist={-.2,-.22,0}
 elseif id=="Aoda" or id=="Garuda" then
  pose.Waist={-.6,0,0};pose.Neck={.3,0,0};pose.LeftShoulder={.85,0,-.1};pose.LeftElbow={.1,0,0}
 else
  -- Eye techniques: frame the eye with the free hand, keeping the sword clear.
  pose.LeftShoulder={1.3,-.25,.3};pose.LeftElbow={1.65,0,0};pose.LeftWrist={-.2,0,.2};pose.Neck={.08,-.15,0}
 end
 for joint,v in pose do local a=base[joint] or {0,0,0};base[joint]={a[1]+(v[1]-a[1])*weight,a[2]+(v[2]-a[2])*weight,a[3]+(v[3]-a[3])*weight} end
 return base
end
return P
