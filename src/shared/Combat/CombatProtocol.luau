--!strict

-- Match request: (monotonic requestId, current Character, RoundId), no combat parameters.
-- Isolated CombatOnlyTest keeps the two-argument protocol.
-- CombatEvent is server -> clients only; see docs/COMBAT.md for packet fields.
export type Snapshot = {
	roundId: number?,
	character: Model, profileId: string, revision: number, mode: string,
	comboStep: number, lastAttackAt: number, nextAttackAt: number, stunUntil: number, attackSerial: number,
}
export type Attack = { id: number, requestId: number, step: number, startedAt: number, hitAt: number, endsAt: number }
export type Event = {
	kind: string, snapshot: Snapshot?, character: Model?, requestId: number?, reason: string?,
	attack: Attack?, attackId: number?, step: number?,
	hits: { { character: Model, position: Vector3 } }?, hitboxCFrame: CFrame?, hitboxSize: Vector3?,
}
return table.freeze({
	FolderName = "CombatRemotes",
	BasicAttackName = "BasicAttack",
	EventName = "CombatEvent",
})
