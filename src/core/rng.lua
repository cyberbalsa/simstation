-- Park-Miller "minimal standard" RNG. All arithmetic stays below 2^53, so the
-- sequence is stable in LuaJIT's doubles and ordinary Lua number builds.
local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function normalize_seed(seed)
  seed = math.floor(tonumber(seed) or 1) % MODULUS
  if seed <= 0 then
    seed = seed + MODULUS - 1
  end
  return seed
end

function Rng.new(seed)
  return setmetatable({ state = normalize_seed(seed) }, Rng)
end

function Rng:next_int()
  self.state = (self.state * MULTIPLIER) % MODULUS
  return self.state
end

function Rng:float()
  return (self:next_int() - 1) / (MODULUS - 1)
end

function Rng:integer(minimum, maximum)
  assert(maximum >= minimum, "invalid RNG integer range")
  local range = maximum - minimum + 1
  return minimum + (self:next_int() % range)
end

function Rng:chance(numerator, denominator)
  assert(denominator > 0, "chance denominator must be positive")
  return (self:next_int() % denominator) < numerator
end

function Rng:pick(values)
  assert(#values > 0, "cannot pick from an empty list")
  return values[self:integer(1, #values)]
end

function Rng:snapshot()
  return { state = self.state }
end

function Rng:restore(snapshot)
  self.state = normalize_seed(snapshot.state)
end

return Rng
