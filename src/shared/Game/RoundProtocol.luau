--!strict
local Protocol = {}
function Protocol.accepts(current: number, received: any): boolean
	return typeof(received) == "number" and received == current and received >= 1 and received % 1 == 0
end
return Protocol
