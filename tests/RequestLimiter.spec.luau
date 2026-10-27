--!strict

local Limiter = require("../src/server/Services/RequestLimiter")
local bucket = Limiter.new(6, 8, 100)
for _ = 1, 6 do
	assert(Limiter.Consume(bucket, 100), "Configured burst should be allowed")
end
for _ = 1, 1000 do
	assert(not Limiter.Consume(bucket, 100), "Flood must not increase available tokens")
end
assert(not Limiter.Consume(bucket, 100.0625), "Partial token must not allow a request")
assert(Limiter.Consume(bucket, 100.125), "One token must refill after 1/rate seconds")
assert(not Limiter.Consume(bucket, 100.125), "Refilled token must be consumed")
assert(not Limiter.Consume(bucket, 99), "Backwards clock must not refill tokens")
for _ = 1, 6 do
	assert(Limiter.Consume(bucket, 200), "Idle bucket should refill to capacity")
end
assert(not Limiter.Consume(bucket, 200), "Idle time must not accumulate beyond capacity")
assert(Limiter.Consume(Limiter.new(6, 8, 200), 200), "One player must not throttle another")

local sustained = Limiter.new(6, 8, 0)
local allowed = 0
for i = 0, 10000 do
	if Limiter.Consume(sustained, i / 1000) then
		allowed += 1
	end
end
assert(allowed <= 86 and allowed >= 85, "10s flood must be bounded by burst + refill")
print("PASS RequestLimiter: burst, flood, fractional refill, clock rollback, cap, player isolation, sustained limit")
