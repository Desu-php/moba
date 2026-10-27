--!strict
export type Actor = { userId: number?, teamId: string }
export type Hit = { actor: Actor, at: number }
export type Ledger = { claimed: boolean, last: Hit?, contributions: { [number]: Hit } }
local Ledger = {}
function Ledger.new(): Ledger return { claimed = false, last = nil, contributions = {} } end
function Ledger.record(ledger: Ledger, actor: Actor, victimTeam: string, now: number)
 if ledger.claimed or actor.teamId == victimTeam then return end
 local hit = { actor = actor, at = now }; ledger.last = hit
 if actor.userId then ledger.contributions[actor.userId] = hit end
end
function Ledger.claim(ledger: Ledger, now: number, window: number): (boolean, Actor?, { Actor })
 if ledger.claimed then return false, nil, {} end
 ledger.claimed = true
 local last = ledger.last
 local killer = if last and now - last.at >= 0 and now - last.at <= window then last.actor else nil
 local assists = {}
 for _, hit in ledger.contributions do
  if now - hit.at >= 0 and now - hit.at <= window and (not killer or hit.actor.userId ~= killer.userId) then
   table.insert(assists, hit.actor)
  end
 end
 table.clear(ledger.contributions); ledger.last = nil
 return true, killer, assists
end
function Ledger.forget(ledger: Ledger, userId: number)
 ledger.contributions[userId] = nil
 if ledger.last and ledger.last.actor.userId == userId then ledger.last = nil end
end
return Ledger
