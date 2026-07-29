-- Goon-compatible gas mixture math pinned to goonstation/goonstation commit
-- 1b2b250abb5be747d55e274de0203a59cfc8da78.
--
-- Documented fixed-point units:
--   quantity     integer qmol (1e-4 mol; exactly one DM QUANTIZE step)
--   temperature  integer millikelvin
--   volume       integer litres
--   heat capacity  integer "hcq" (1e-4 J/K; qmol * specific heat)
--   thermal energy "teu" (mK * hcq = 1e-7 J); 1 J = 1e7 teu
--
-- Intermediate math uses plain IEEE-754 double arithmetic floored back to
-- integers immediately, so results are bit-identical on every supported Lua
-- runtime. No transcendental functions are used. Source floats that DM keeps
-- unrounded are quantized to the nearest qmol (ties up), which the fidelity
-- ledger records as deterministic-equivalent.
local Gas = {}

-- APPLY_TO_GASES roster, _std/macros/atmos.dm:249-257.
Gas.SPECIES = {
  "oxygen",
  "nitrogen",
  "carbon_dioxide",
  "toxins",
  "farts",
  "radgas",
  "nitrous_oxide",
  "oxygen_agent_b",
}

-- _std/macros/atmos.dm:230-237.
Gas.SPECIFIC_HEAT = {
  oxygen = 40,
  nitrogen = 50,
  carbon_dioxide = 40,
  toxins = 150,
  farts = 69,
  radgas = 5,
  nitrous_oxide = 60,
  oxygen_agent_b = 300,
}

Gas.QMOL_PER_MOL = 10000
Gas.R_KPA_L_PER_K_MOL = 8.3144626 -- _std/macros/atmos.dm:30
Gas.ONE_ATMOSPHERE_PA = 101325 -- _std/macros/atmos.dm:32
Gas.CELL_VOLUME_L = 2500 -- _std/macros/atmos.dm:34
Gas.T20C_MK = 293150 -- _std/defines/temperatures.dm:4
Gas.SPACE_TEMPERATURE_MK = 2700 -- TCMB, code/turf/turf.dm:272-280
Gas.SPACE_HEAT_CAPACITY_HCQ = 7000000000 -- 700,000 J/K space turf
-- One legacy tile gas unit is declared to be 1 mmol (10 qmol). The standard
-- pressurized tile therefore holds 100 mol versus the source cell's 103.98
-- mol; the fidelity ledger records this adapter as engine-adapted.
Gas.TILE_UNIT_QMOL = 10

-- _std/macros/atmos.dm:296-298: 0.0003 mol and 0.0003 J/K in fixed point.
local MINIMUM_REACT_QMOL = 3
local MINIMUM_HEAT_CAPACITY_HCQ = 3
-- _std/macros/atmos.dm:118: 1 K.
local MINIMUM_TEMPERATURE_DELTA_MK = 1000
-- _std/macros/atmos.dm:133,142-143,146,138.
local FIRE_MINIMUM_TEMPERATURE_MK = 373150
local PLASMA_MINIMUM_BURN_TEMPERATURE_MK = 373150
local PLASMA_UPPER_TEMPERATURE_MK = 2643150
local PLASMA_OXYGEN_FULLBURN = 10
local FIRE_PLASMA_ENERGY_J_PER_QMOL = 300 -- 3,000,000 J/mol

local SPECIES = Gas.SPECIES
local SPECIFIC_HEAT = Gas.SPECIFIC_HEAT
local floor = math.floor

-- DM QUANTIZE(x) = round(x, 0.0001): nearest qmol, exact halves up. Only
-- nonnegative rates and amounts pass through this helper.
local function quantize(value)
  return floor(value + 0.5)
end

Gas.quantize = quantize

local function trunc(value)
  if value >= 0 then
    return floor(value)
  end
  return -floor(-value)
end

function Gas.new(volume_l, temperature_mk)
  local mixture = {
    volume_l = floor(volume_l or Gas.CELL_VOLUME_L),
    temperature_mk = floor(temperature_mk or 0),
  }
  for index = 1, #SPECIES do
    mixture[SPECIES[index]] = 0
  end
  return mixture
end

function Gas.total_qmol(mixture)
  local total = 0
  for index = 1, #SPECIES do
    total = total + mixture[SPECIES[index]]
  end
  return total
end

function Gas.heat_capacity_hcq(mixture)
  local total = 0
  for index = 1, #SPECIES do
    local species = SPECIES[index]
    total = total + mixture[species] * SPECIFIC_HEAT[species]
  end
  return total
end

function Gas.thermal_energy_teu(mixture)
  return mixture.temperature_mk * Gas.heat_capacity_hcq(mixture)
end

-- MIXTURE_PRESSURE, _std/macros/atmos.dm:314: moles * R * T / volume.
function Gas.pressure_pa(mixture)
  local volume = mixture.volume_l
  if not volume or volume <= 0 then
    return 0
  end
  local total = Gas.total_qmol(mixture)
  if total <= 0 then
    return 0
  end
  return floor(
    total * mixture.temperature_mk * Gas.R_KPA_L_PER_K_MOL / (volume * 10000)
  )
end

-- FEA_gas_mixture.dm:216-237 with group_multiplier fixed at 1.
function Gas.merge(mixture, giver)
  if not giver then
    return false
  end
  local delta = mixture.temperature_mk - giver.temperature_mk
  if delta > MINIMUM_TEMPERATURE_DELTA_MK
    or delta < -MINIMUM_TEMPERATURE_DELTA_MK
  then
    local self_capacity = Gas.heat_capacity_hcq(mixture)
    local giver_capacity = Gas.heat_capacity_hcq(giver)
    local combined = self_capacity + giver_capacity
    if combined > 0 then
      mixture.temperature_mk = floor(
        (
          giver.temperature_mk * giver_capacity
          + mixture.temperature_mk * self_capacity
        ) / combined
      )
    end
  end
  for index = 1, #SPECIES do
    local species = SPECIES[index]
    mixture[species] = mixture[species] + giver[species]
  end
  return true
end

-- FEA_gas_mixture.dm:241-257. Returns nil when nothing can be removed.
function Gas.remove_qmol(mixture, amount_qmol)
  local total = Gas.total_qmol(mixture)
  if amount_qmol > total then
    amount_qmol = total
  end
  if amount_qmol <= 0 then
    return nil
  end
  local removed = Gas.new(Gas.CELL_VOLUME_L, mixture.temperature_mk)
  for index = 1, #SPECIES do
    local species = SPECIES[index]
    local share = quantize((mixture[species] / total) * amount_qmol)
    if share > mixture[species] then
      share = mixture[species]
    end
    removed[species] = share
    mixture[species] = mixture[species] - share
  end
  return removed
end

-- FEA_gas_mixture.dm:261-277 with the ratio expressed in parts-per-million.
function Gas.remove_ratio_ppm(mixture, ratio_ppm)
  if ratio_ppm <= 0 then
    return nil
  end
  if ratio_ppm > 1000000 then
    ratio_ppm = 1000000
  end
  local removed = Gas.new(Gas.CELL_VOLUME_L, mixture.temperature_mk)
  for index = 1, #SPECIES do
    local species = SPECIES[index]
    local share = quantize(mixture[species] * ratio_ppm / 1000000)
    if share > mixture[species] then
      share = mixture[species]
    end
    removed[species] = share
    mixture[species] = mixture[species] - share
  end
  return removed
end

-- FEA_gas_mixture.dm:572-583. The per-side deltas truncate toward zero,
-- which loses at most one millikelvin per side; the ledger records the
-- rounding as deterministic-equivalent.
function Gas.temperature_share(mixture, sharer, conduction_coefficient)
  local delta = mixture.temperature_mk - sharer.temperature_mk
  if delta <= MINIMUM_TEMPERATURE_DELTA_MK
    and delta >= -MINIMUM_TEMPERATURE_DELTA_MK
  then
    return false
  end
  local self_capacity = Gas.heat_capacity_hcq(mixture)
  local sharer_capacity = Gas.heat_capacity_hcq(sharer)
  if self_capacity <= MINIMUM_HEAT_CAPACITY_HCQ
    or sharer_capacity <= MINIMUM_HEAT_CAPACITY_HCQ
  then
    return false
  end
  local heat = conduction_coefficient * delta
    * (self_capacity * sharer_capacity / (self_capacity + sharer_capacity))
  mixture.temperature_mk = mixture.temperature_mk
    - trunc(heat / self_capacity)
  sharer.temperature_mk = sharer.temperature_mk
    + trunc(heat / sharer_capacity)
  return true
end

-- FEA_gas_mixture.dm:107-149.
local function fire(mixture, mult)
  local old_capacity = Gas.heat_capacity_hcq(mixture)
  local energy_j = 0
  local burned = false
  if mixture.toxins > MINIMUM_REACT_QMOL then
    local temperature_scale
    if mixture.temperature_mk > PLASMA_UPPER_TEMPERATURE_MK then
      temperature_scale = 1
    else
      temperature_scale =
        (mixture.temperature_mk - PLASMA_MINIMUM_BURN_TEMPERATURE_MK)
        / (PLASMA_UPPER_TEMPERATURE_MK - PLASMA_MINIMUM_BURN_TEMPERATURE_MK)
    end
    local oxygen_burn_rate = 1.4 - temperature_scale
    local plasma_burn_rate
    if mixture.oxygen > mixture.toxins * PLASMA_OXYGEN_FULLBURN then
      plasma_burn_rate = (mixture.toxins * temperature_scale) / 4
    else
      plasma_burn_rate =
        (temperature_scale * (mixture.oxygen / PLASMA_OXYGEN_FULLBURN)) / 4
    end
    if plasma_burn_rate > MINIMUM_REACT_QMOL then
      plasma_burn_rate = plasma_burn_rate * mult
      oxygen_burn_rate = oxygen_burn_rate * mult
      -- Plasma usage divided by 3 for balance, matching the source comment.
      local consumed_toxins = quantize(plasma_burn_rate / 3)
      mixture.toxins = mixture.toxins - consumed_toxins
      mixture.oxygen = mixture.oxygen
        - quantize(plasma_burn_rate * oxygen_burn_rate)
      mixture.carbon_dioxide = mixture.carbon_dioxide + consumed_toxins
      energy_j = energy_j
        + FIRE_PLASMA_ENERGY_J_PER_QMOL * plasma_burn_rate
      burned = true
    end
  end
  if energy_j > 0 then
    local new_capacity = Gas.heat_capacity_hcq(mixture)
    if new_capacity > MINIMUM_HEAT_CAPACITY_HCQ then
      mixture.temperature_mk = floor(
        (mixture.temperature_mk * old_capacity + energy_j * 10000000)
          / new_capacity
      )
    end
  end
  return burned
end

Gas.fire = fire

-- FEA_gas_mixture.dm:71-103. Returns true when any reaction or combustion
-- changed the mixture, mirroring the source's nonzero return.
function Gas.react(mixture, mult)
  mult = mult or 1
  local active = false
  if mixture.temperature_mk > 900000
    and mixture.toxins > MINIMUM_REACT_QMOL
    and mixture.carbon_dioxide > MINIMUM_REACT_QMOL
  then
    if mixture.oxygen_agent_b > MINIMUM_REACT_QMOL then
      local rate = math.min(
        mixture.carbon_dioxide * 0.75,
        mixture.toxins * 0.25,
        mixture.oxygen_agent_b * 0.05
      )
      rate = quantize(rate) * mult
      mixture.carbon_dioxide = mixture.carbon_dioxide - rate
      mixture.oxygen = mixture.oxygen + rate
      mixture.oxygen_agent_b = mixture.oxygen_agent_b - quantize(rate * 0.05)
      local capacity = Gas.heat_capacity_hcq(mixture)
      if capacity > 0 then
        -- 20,000 J/mol = 20,000,000 mK*hcq per qmol.
        mixture.temperature_mk = mixture.temperature_mk
          + floor(rate * 20000000 / capacity)
      end
      active = true
    end
    if mixture.farts > MINIMUM_REACT_QMOL then
      local rate = math.min(
        mixture.carbon_dioxide * 0.75,
        mixture.toxins * 0.25,
        mixture.farts * 0.05
      )
      rate = quantize(rate) * mult
      mixture.carbon_dioxide = mixture.carbon_dioxide - rate
      mixture.toxins = mixture.toxins + rate
      mixture.farts = mixture.farts - quantize(rate * 0.05)
      local capacity = Gas.heat_capacity_hcq(mixture)
      if capacity > 0 then
        -- 10,000 J/mol = 10,000,000 mK*hcq per qmol.
        mixture.temperature_mk = mixture.temperature_mk
          + floor(rate * 10000000 / capacity)
      end
      active = true
    end
  end
  if mixture.temperature_mk > FIRE_MINIMUM_TEMPERATURE_MK then
    if fire(mixture, mult) then
      active = true
    end
  end
  return active
end

-- Pools members into one transient mixture the way pipe_network.dm:111-131
-- and equalize_gases (pipe_network.dm:152-188) total their members.
-- Members are {gas = mixture, granularity_qmol = int, species = set-or-nil}.
function Gas.pool(members)
  local pooled = Gas.new(0, 0)
  local total_volume = 0
  local total_energy_teu = 0
  local total_capacity = 0
  for index = 1, #members do
    local gas = members[index].gas
    total_volume = total_volume + gas.volume_l
    local capacity = Gas.heat_capacity_hcq(gas)
    total_capacity = total_capacity + capacity
    total_energy_teu = total_energy_teu + gas.temperature_mk * capacity
    for species_index = 1, #SPECIES do
      local species = SPECIES[species_index]
      pooled[species] = pooled[species] + gas[species]
    end
  end
  pooled.volume_l = total_volume
  if total_capacity > 0 then
    pooled.temperature_mk = floor(total_energy_teu / total_capacity)
  else
    pooled.temperature_mk = 0
  end
  return pooled
end

-- Redistributes a pooled mixture across members by volume ratio, exactly
-- conserving every species. Each member's floor share is rounded down to its
-- granularity (tile adapters use 10 qmol = one legacy unit) and any species
-- a member cannot hold is withheld from it; every remainder goes to the
-- first largest-volume member with granularity one and no species filter.
-- This deterministic remainder policy stands in for the source's float
-- shares and is recorded as deterministic-equivalent.
function Gas.distribute(pooled, members)
  local total_volume = pooled.volume_l
  if total_volume <= 0 then
    return false
  end
  local sink_index = nil
  for index = 1, #members do
    local member = members[index]
    if (member.granularity_qmol or 1) == 1 and not member.species then
      if sink_index == nil
        or member.gas.volume_l > members[sink_index].gas.volume_l
      then
        sink_index = index
      end
    end
  end
  assert(sink_index, "gas distribution requires an unrestricted member")
  local changed = false
  for species_index = 1, #SPECIES do
    local species = SPECIES[species_index]
    local total = pooled[species]
    local assigned = 0
    for index = 1, #members do
      local member = members[index]
      local share = 0
      if member.species == nil or member.species[species] then
        share = floor(total * member.gas.volume_l / total_volume)
        local granularity = member.granularity_qmol or 1
        if granularity > 1 then
          share = share - share % granularity
        end
      end
      if index ~= sink_index then
        if member.gas[species] ~= share then
          member.gas[species] = share
          changed = true
        end
        assigned = assigned + share
      end
    end
    local sink_share = total - assigned
    local sink = members[sink_index]
    if sink.gas[species] ~= sink_share then
      sink.gas[species] = sink_share
      changed = true
    end
  end
  for index = 1, #members do
    local gas = members[index].gas
    if gas.temperature_mk ~= pooled.temperature_mk then
      gas.temperature_mk = pooled.temperature_mk
      changed = true
    end
  end
  return changed
end

-- proc/equalize_gases, pipe_network.dm:152-188.
function Gas.equalize(members)
  local pooled = Gas.pool(members)
  if pooled.volume_l <= 0 then
    return false
  end
  return Gas.distribute(pooled, members)
end

return Gas
