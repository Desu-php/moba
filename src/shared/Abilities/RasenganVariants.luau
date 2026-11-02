--!strict
-- Exact-map contracts A014/A0DK/A013; explicit bounded Roblox melee adaptation.
local V = {}
export type Choice = { id: string, selectedAt: number, readyAt: number, expiresAt: number }
export type State = { choice: Choice?, cooldowns: {[string]: number} }
function V.new(): State return {choice=nil,cooldowns={}} end
local function finite(n: number): boolean return n==n and math.abs(n)<math.huge end
function V.select(state: State, id: string, rank: number, startedAt: number, now: number, mana: number, ordinary: boolean): (Choice?, string, number)
 if not finite(now) or not finite(startedAt) or not finite(mana) or not finite(rank) or rank%1~=0 or rank<1 or rank>3 then return nil,"Malformed",0 end
 local previous=state.choice
 if id=="Odama" then
  if rank<2 then return nil,"Rank",0 end
  if previous or not ordinary or now<startedAt or now>=startedAt+1 then return nil,"Window",0 end
 elseif id=="Rasenshuriken" then
  if rank<3 then return nil,"Rank",0 end
  if not previous or previous.id~="Odama" or now<previous.selectedAt or now>=previous.selectedAt+1 then return nil,"Window",0 end
 else return nil,"Unsupported",0 end
 if now<(state.cooldowns[id] or 0) then return nil,"Cooldown",0 end
 if mana<200 then return nil,"Mana",0 end
 local preparation=if id=="Odama" then 2 else 1.3
 local choice={id=id,selectedAt=now,readyAt=now+preparation,expiresAt=now+15}
 state.choice=choice; state.cooldowns[id]=now+(if id=="Odama" then 40 else 60)
 return choice,"Accepted",200
end
function V.cancel(state: State) state.choice=nil end
function V.damage(id: string, level: number, strength: number): number
 if id=="Odama" then return 250+3*strength end
 return 120+strength+10*level
end
function V.stun(id: string): number return if id=="Odama" then 4 elseif id=="Rasenshuriken" then 4.5 else 3.5 end
-- JASS integer division is truncation; authoritative effective STR is integer.
function V.pulse(strength: number): number return math.floor((600+4*strength)/87) end
function V.selfDamage(strength: number): number return 30*math.floor((450+4*strength)/87) end
function V.radius(tick: number): number return 300+5*math.min(40,math.max(0,tick)) end
return table.freeze(V)
