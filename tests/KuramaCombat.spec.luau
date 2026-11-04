--!strict
local Config=require("../src/shared/Config/CombatConfig")
local Avatar=require("../src/shared/Config/KuramaAvatarConfig")
local Form=require("../src/shared/Abilities/NarutoKuramaState")
local State=require("../src/shared/Combat/CombatState")
local Rate=require("../src/shared/Combat/BasicAttackRules")
local n=0
local function check(name: string,ok: boolean) assert(ok,name);n+=1 end
local function near(a: number,b: number): boolean return math.abs(a-b)<1e-6 end
local profile=Config.Profiles.Kurama
check("source Ewar cooldown retained",profile.AttackCooldown==Form.RawEwar.attackCooldown)
check("source range plus avatar body",near(profile.MaxTargetDistance,Form.RawEwar.range/16+Avatar.BodyRadius))
check("no double form damage",profile.Damage==Config.Profiles.OrangeNinja.Damage and Form.modifier().attack==90)
check("swipe remains one target",profile.MaxTargets==1)
check("collider bottom remains above humanoid floor",Avatar.BodyOffset.Y-Avatar.BodySize.Y/2>=0)
for _,agility in {0,60,300,10000} do
 local speed=Rate.speed(profile,agility)
 local state=State.new()
 check("start at agility "..agility,State.Request(state,profile,10,1,speed)=="Started")
 local attack=state.active;assert(attack)
 check("no hit before claw contact "..agility,State.ClaimHit(state,attack.hitAt-.001)==nil)
 check("one authoritative hit "..agility,State.ClaimHit(state,attack.hitAt)==attack and State.ClaimHit(state,attack.hitAt)==nil)
 check("animation phase matches server contact "..agility,near((attack.hitAt-attack.startedAt)/(attack.endsAt-attack.startedAt),Avatar.HitPhase))
 check("cooldown cannot be bypassed after recovery "..agility,State.Request(state,profile,attack.endsAt+.001,2,speed)~="Started")
 State.TakeBuffer(state,state.nextAttackAt)
 check("next swing on deadline "..agility,State.Request(state,profile,state.nextAttackAt,3,speed)=="Started")
 check("attack speed ceiling "..agility,speed/profile.AttackCooldown<=profile.MaxAttacksPerSecond)
end
check("normal attack timing unchanged",Config.Profiles.OrangeNinja.AttackCooldown==.5 and Config.Profiles.OrangeNinja.HitDelay==.16)
print("ALL PASS: "..n.." Kurama combat cadence/contact/profile checks")
