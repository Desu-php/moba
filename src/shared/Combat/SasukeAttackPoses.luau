--!strict
-- Authored for R15: planted feet, sword cuts and a distinct left-hand lightning thrust.
-- Normalised contact phase comes from the same attack profile as server damage.
export type Pose = {[string]: {number}}
local P = {}
local function smooth(t:number):number t=math.clamp(t,0,1);return t*t*(3-2*t) end
local function blend(a:Pose,b:Pose,t:number):Pose
 local out:Pose={};t=smooth(t)
 for joint,v in a do local w=b[joint] or v;out[joint]={v[1]+(w[1]-v[1])*t,v[2]+(w[2]-v[2])*t,v[3]+(w[3]-v[3])*t} end
 return out
end
local guard:Pose={Waist={-.08,-.12,0},Neck={.06,.08,0},
 RightShoulder={.52,.08,.12},RightElbow={1.15,0,0},RightWrist={0,0,0},
 LeftShoulder={.42,-.12,-.18},LeftElbow={1.05,0,0},LeftWrist={0,0,0},
 LeftHip={.1,0,-.03},RightHip={-.1,0,.03},LeftKnee={-.08,0,0},RightKnee={-.08,0,0}}
local function poses(chidori:boolean,step:number):(Pose,Pose)
 local wind=table.clone(guard);local strike=table.clone(guard)
 if chidori then
  wind.Waist={-.18,.38,0};wind.Neck={.12,-.22,0}
  wind.LeftShoulder={-.35,-.18,-.18};wind.LeftElbow={.7,0,0}
  strike.Waist={-.25,-.36,0};strike.Neck={.16,.2,0}
  strike.LeftShoulder={1.62,.1,-.12};strike.LeftElbow={.06,0,0};strike.LeftWrist={-.1,0,0}
  wind.RightShoulder={-.4,.2,.25};wind.RightElbow={.22,0,0};wind.RightWrist={0,.15,.1}
  strike.RightShoulder=wind.RightShoulder;strike.RightElbow=wind.RightElbow;strike.RightWrist=wind.RightWrist
  strike.LeftHip={.18,0,-.03};strike.RightHip={-.2,0,.03}
 else
  local sign=if step%3==2 then -1 else 1
  wind.Waist={-.1,-.38*sign,0};wind.Neck={.06,.24*sign,0}
  wind.RightShoulder={1.95,-.35*sign,.65*sign};wind.RightElbow={.9,0,0};wind.RightWrist={-.35,0,-.15*sign}
  strike.Waist={-.2,.4*sign,-.04*sign};strike.Neck={.1,-.25*sign,0}
  strike.RightShoulder={1.15,.25*sign,-.38*sign};strike.RightElbow={.32,0,0};strike.RightWrist={-1.45,0,.1*sign}
  if step%3==0 then
   -- Straight overhead cut: same damage and timing, only the visual changes.
   wind.RightShoulder={2.65,.05,.12};wind.RightElbow={.45,0,0};wind.RightWrist={-.3,0,0}
   strike.RightShoulder={1.25,.05,.05};strike.RightElbow={.2,0,0};strike.RightWrist={-1.4,0,0}
   strike.Waist={-.25,.12,0}
  end
 end
 return wind,strike
end
function P.sample(kind:string,phase:number,step:number,contact:number):Pose
 local wind,strike=poses(kind~="Attack",step)
 local p=math.clamp(phase,0,1);contact=math.clamp(contact,.1,.8)
 if kind=="Impact" then
  -- Contact pose persists independently of the ordinary swing's short recovery.
  if p<.22 then return strike end
  return blend(strike,guard,(p-.22)/.78)
 end
 local windEnd=contact*.4
 if p<windEnd then return blend(guard,wind,p/windEnd)
 elseif p<contact then return blend(wind,strike,(p-windEnd)/(contact-windEnd))
 elseif p<contact+.09 then return strike
 else return blend(strike,guard,(p-contact-.09)/(1-contact-.09)) end
end
return P
