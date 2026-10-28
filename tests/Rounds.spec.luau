--!strict
local Rules = require("../src/shared/Game/MatchState")
local Protocol = require("../src/shared/Game/RoundProtocol")
local Config = require("../src/shared/Config/RoundConfig")
local count = 0
local function check(name: string, ok: boolean)
	assert(ok, name); count += 1; print("PASS Rounds: " .. name)
end
local state = Rules.new({ "Blue", "Red" })
check("default intermission ten seconds", Config.IntermissionTime == 10)
check("initial round one", state.roundId == 1)
check("cannot reset active or waiting match", not Rules.restart(state, 100, 1))
for round = 1, 3 do
	local now = round * 100
	check("insufficient players wait", not Rules.advance(state, now, 0, 2, 5, 5) and state.phase == "WaitingForPlayers")
	check("join starts preparation", Rules.advance(state, now, 2, 2, 5, 5))
	check("leave cancels preparation", Rules.advance(state, now + 1, 1, 2, 5, 5) and state.phase == "WaitingForPlayers")
	Rules.advance(state, now + 2, 2, 2, 5, 5)
	check("fresh preparation deadline", state.preparationEnds == now + 7)
	check("not early", not Rules.advance(state, now + 6.9, 2, 2, 5, 5))
	check("round begins", Rules.advance(state, now + 7, 2, 2, 5, 5) and state.phase == "InProgress")
	check("first wave waits", not Rules.waveDue(state, now + 11, 20))
	check("wave one each round", Rules.waveDue(state, now + 12, 20) and state.wave == 1)
	state.teams.Blue.count = 4; state.teams.Red.count = 3
	check("active departure policy unchanged", not Rules.advance(state, now + 13, 0, 2, 5, 5) and state.phase == "InProgress")
	check("finish once", Rules.eliminate(state, "Red", now + 14) and state.winner == "Blue")
	check("same-frame other base cannot change winner", not Rules.eliminate(state, "Blue", now + 14) and state.winner == "Blue")
	check("schedule once", Rules.schedule(state, now + 14, 10) and not Rules.schedule(state, now + 15, 100))
	check("deadline not extended", state.intermissionEnds == now + 24)
	check("result retained first two seconds", not Rules.intermission(state, now + 15.9, 2))
	check("result transitions", Rules.intermission(state, now + 16, 2) and state.phase == "Intermission")
	check("repeated transition ignored", not Rules.intermission(state, now + 17, 2))
	check("late join observes", Rules.assign(state, nil) == nil)
	check("no waves during intermission", not Rules.waveDue(state, now + 100, 20))
	check("no early reset", not Rules.restart(state, now + 23.9, round))
	check("stale reset rejected", not Rules.restart(state, now + 24, round - 1))
	check("restart at deadline", Rules.restart(state, now + 24, round))
	check("monotonic round", state.roundId == round + 1)
	check("duplicate reset rejected", not Rules.restart(state, now + 24, round))
	check("complete state reset", state.phase == "WaitingForPlayers" and state.winner == nil and state.wave == 0
		and state.startedAt == 0 and state.finishedAt == 0 and state.preparationEnds == 0 and state.nextWaveAt == 0 and state.intermissionEnds == 0)
	check("teams restored", #Rules.active(state) == 2 and state.teams.Blue.count == 0 and state.teams.Red.count == 0)
	check("old epoch rejected", not Protocol.accepts(state.roundId, round))
	check("new epoch accepted", Protocol.accepts(state.roundId, round + 1))
end
for _, value in { 0 / 0, math.huge, -1, 0, 1.5, "4", {}, false } do
	check("malformed epoch rejected", not Protocol.accepts(state.roundId, value))
end
check("missing epoch rejected", not Protocol.accepts(state.roundId, nil))
local untouched = Rules.new({ "Blue", "Red" }); untouched.phase = "Finished"
check("unscheduled fixture cannot auto reset", not Rules.intermission(untouched, 100, 2))
print("ALL PASS: " .. count .. " round lifecycle/protocol checks")
