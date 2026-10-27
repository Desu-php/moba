--!strict
export type Actor = { userId: number?, teamId: string }
export type Death = { read kind: string, read teamId: string, read victimUserId: number?, read killer: Actor?, read assists: { Actor } }
export type PlayerSample = { userId: number, teamId: string, active: boolean, alive: boolean, inRange: boolean }
export type Reward = { XP: number, Gold: number }
export type Grant = { XP: number, Gold: number, Kills: number, Deaths: number, MinionKills: number, Assists: number }
local Rules = {}
function Rules.plan(event: Death, players: { PlayerSample }, minion: Reward?, hero: Reward, assist: Reward, enabled: boolean): { [number]: Grant }
 local grants: { [number]: Grant } = {}
 if not enabled then return grants end
 local byId: { [number]: PlayerSample } = {}
 for _, player in players do if player.active then byId[player.userId] = player end end
 local function grant(id: number): Grant
  if not grants[id] then grants[id] = { XP = 0, Gold = 0, Kills = 0, Deaths = 0, MinionKills = 0, Assists = 0 } end
  return grants[id]
 end
 if event.kind == "Hero" and event.victimUserId and byId[event.victimUserId] then grant(event.victimUserId).Deaths = 1 end
 local killer = event.killer
 if not killer or killer.teamId == event.teamId then return grants end
 local killerPlayer = if killer.userId then byId[killer.userId] else nil
 if killerPlayer and killerPlayer.teamId ~= killer.teamId then killerPlayer = nil end
 if event.kind == "Minion" and minion then
  for _, player in players do
   if player.active and player.alive and player.inRange and player.teamId == killer.teamId then grant(player.userId).XP = minion.XP end
  end
  if killerPlayer then local g = grant(killerPlayer.userId); g.Gold = minion.Gold; g.MinionKills = 1 end
 elseif event.kind == "Hero" then
  if killerPlayer then local g = grant(killerPlayer.userId); g.XP = hero.XP; g.Gold = hero.Gold; g.Kills = 1 end
  for _, actor in event.assists do
   local player = if actor.userId then byId[actor.userId] else nil
   if player and player.teamId == actor.teamId and player.teamId ~= event.teamId and player ~= killerPlayer then
    local g = grant(player.userId); g.XP = assist.XP; g.Gold = assist.Gold; g.Assists = 1
   end
  end
 end
 return grants
end
return Rules
