--!strict
-- Explicit key presses only. This queue bridges one in-flight acknowledgement;
-- it never chooses an upgrade for the player or extends the server's cast window.
export type State = { castId: number, stage: string, awaiting: string?, deadline: number, items: {string}, closed: boolean }
local Queue = {}
local previous: {[string]: string} = { Odama = "Rasengan", Rasenshuriken = "Odama" }
function Queue.new(castId: number, stage: string, deadline: number, awaiting: string?): State
	return {castId=castId,stage=stage,awaiting=awaiting,deadline=deadline,items={},closed=false}
end
function Queue.clear(state: State)
	state.closed=true; state.awaiting=nil; table.clear(state.items)
end
function Queue.expired(state: State, now: number): boolean
	if state.closed or now>=state.deadline then Queue.clear(state); return true end
	return false
end
function Queue.enqueue(state: State, id: string, now: number): (boolean, string)
	if Queue.expired(state,now) then return false,"Window" end
	if not previous[id] then return false,"Unsupported" end
	if state.awaiting==id or state.stage==id or table.find(state.items,id) then return true,"Duplicate" end
	local last=state.items[#state.items] or state.awaiting or state.stage
	if (last~=previous[id] and not (id=="Rasenshuriken" and last=="Rasengan")) or #state.items>=2 then return false,"Sequence" end
	table.insert(state.items,id); return true,"Queued"
end
function Queue.observe(state: State, castId: number, variant: string, deadline: number, now: number): boolean
	if Queue.expired(state,now) then return false end
	if castId~=state.castId then Queue.clear(state); return false end
	-- Attributes may trail the successful Result event. Wait for this exact stage.
	if state.awaiting and variant~=state.awaiting then return true end
	if variant~=state.stage and variant~=state.awaiting then Queue.clear(state); return false end
	state.stage=variant; state.awaiting=nil; state.deadline=deadline
	if variant=="Rasenshuriken" then Queue.clear(state); return false end
	return not Queue.expired(state,now)
end
function Queue.next(state: State, now: number): string?
	if Queue.expired(state,now) or state.awaiting then return nil end
	return state.items[1]
end
function Queue.sent(state: State, id: string, now: number)
	assert(state.items[1]==id and not state.awaiting and not state.closed,"Upgrade queue order")
	table.remove(state.items,1); state.awaiting=id
	-- An unanswered request is discarded; it cannot replay after a timeout.
	state.deadline=now+1.25
end
return Queue
