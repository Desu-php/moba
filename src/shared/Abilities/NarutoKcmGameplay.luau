--!strict
-- Chosen Roblox retention/safety policies, not certified native metamorph semantics.
local G={}
G.Policy=table.freeze({Id="KcmRawBaseDeltaPreserveResourcesV1",Health="PreserveCurrentAndMaximum",
 Mana="PreserveCurrentAndMaximum",Progression="NeverReplace",AttackCadence="PreserveExistingM1",
 DashAdmission="EnemyNonStructureOrWalkablePointNoWallCrossing",DashDamage="ExistingServerDamageMitigation"})
G.Dash=table.freeze({Mana=100,Cooldown=40,RangeWarcraft=650})
export type DashState={cooldownAt: number,lastRequest: number}
export type Hagoromo={deadline: number?,cutsceneAt: number?,granted: boolean}
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function G.modifier(rank: number): {health: number,armor: number,attack: number,speedWarcraft: number}?
 if not finite(rank) or rank%1~=0 or rank<1 or rank>3 then return nil end
 -- Raw attack/armor/speed deltas from Hpal comparator; never overwrite retained stats.
 return {health=0,armor=({5,10,15})[rank],attack=({25,50,100})[rank],speedWarcraft=({50,100,100})[rank]}
end
function G.newDash(): DashState return {cooldownAt=0,lastRequest=0} end
function G.dash(s: DashState,now: number,request: number,active: boolean,ready: boolean,mana: number,
 distanceWarcraft: number,kind: string,strength: number): (boolean,string,number,number?)
 if not finite(now) or not finite(request) or request%1~=0 or request<1 or not finite(mana)
  or not finite(distanceWarcraft) or distanceWarcraft<0 or not finite(strength) then return false,"Malformed",0,nil end
 if request<=s.lastRequest then return false,"Replay",0,nil end
 s.lastRequest=request
 if not active or not ready then return false,"Form",0,nil end
 if now<s.cooldownAt then return false,"Cooldown",0,nil end
 if kind~="Point" and kind~="Unit" then return false,"Target",0,nil end
 if distanceWarcraft>G.Dash.RangeWarcraft then return false,"Range",0,nil end
 if mana<G.Dash.Mana then return false,"Mana",0,nil end
 s.cooldownAt=now+G.Dash.Cooldown
 return true,"Accepted",G.Dash.Mana,if kind=="Unit" then 100+strength else nil
end
function G.newHagoromo(): Hagoromo return {deadline=nil,cutsceneAt=nil,granted=false} end
function G.updateHagoromo(s: Hagoromo,now: number,level: number,alive: boolean): string?
 if not finite(now) or not finite(level) or s.granted then return nil end
 if not s.deadline and level>=25 then s.deadline=now+360 end
 local deadline=s.deadline
 if not deadline or now<deadline then return nil end
 if not alive then s.cutsceneAt=nil; return nil end -- Safety: restart interrupted one-second alive presentation.
 if not s.cutsceneAt then s.cutsceneAt=now; return "Cutscene" end
 if now>=s.cutsceneAt+1 then s.granted=true; return "Granted" end
 return nil
end
return G
