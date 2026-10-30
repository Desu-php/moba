--!strict
local Protocol = {}
function Protocol.accepts(current: number, received: any): boolean
	return typeof(received) == "number" and received == current and received >= 1 and received % 1 == 0
end
function Protocol.acceptsClient(current: number?, received: any, phase: any, isolatedStudio: boolean): boolean
	if current == nil then return isolatedStudio and phase == nil and received == nil end
	return phase ~= "Finished" and Protocol.accepts(current, received)
end
return Protocol
