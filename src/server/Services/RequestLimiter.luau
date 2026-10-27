--!strict

-- Pure token bucket. Its instances live only on the server, one per player.
export type Bucket = {
	tokens: number,
	updatedAt: number,
	capacity: number,
	refillRate: number,
}

local RequestLimiter = {}

function RequestLimiter.new(capacity: number, refillRate: number, now: number): Bucket
	assert(capacity > 0 and refillRate > 0, "Rate limit must be positive")
	return { tokens = capacity, updatedAt = now, capacity = capacity, refillRate = refillRate }
end

function RequestLimiter.Consume(bucket: Bucket, now: number): boolean
	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillRate)
	bucket.updatedAt = math.max(bucket.updatedAt, now)
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RequestLimiter
