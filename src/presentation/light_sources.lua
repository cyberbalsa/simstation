local Constants = require("src.core.constants")

local LightSources = {}
LightSources.MAX_CANDIDATE_CHECKS = 65536

local FIRE_PROVIDER =
  "org.simstation.core:light-provider/fire-tile-v1"
local FIXTURE_PROVIDER =
  "org.simstation.core:light-provider/light-feature-v1"

local function path_is(path, root)
  return path == root
    or (
      path:sub(1, #root) == root
      and path:sub(#root + 1, #root + 1) == "/"
    )
end

local function contains_sorted(values, wanted)
  local low = 1
  local high = #values
  while low <= high do
    local middle = math.floor((low + high) / 2)
    local value = values[middle]
    if value == wanted then
      return true
    elseif value < wanted then
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return false
end

local function fixture_enabled(world, index)
  if not world:has_feature(index, Constants.FEATURE.LIGHT) then
    return false
  end
  local state = world:peek_interaction_state(index, "light")
  return not state
    or (
      state.installed ~= false
        and state.broken ~= true
        and state.on ~= false
    )
end

local function machine_enabled(machine)
  return machine.destroyed ~= true
    and not (machine.status and machine.status.broken == true)
end

local function controller_operational(machine)
  local data = machine.data or {}
  return machine_enabled(machine)
    and data.operating ~= false
    and data.do_not_operate ~= true
    and data.shorted ~= true
end

local function apc_channel_field(channel)
  if channel == "environment" then
    return "environ"
  end
  return channel
end

function LightSources.area_channel_service(world, machines)
  local result = {
    lighting = { seen = {}, served = {} },
    equipment = { seen = {}, served = {} },
    environment = { seen = {}, served = {} },
  }
  for machine_index = 1, #(machines or {}) do
    local machine = machines[machine_index]
    if machine.kind == "apc" and machine.index then
      local area_id = world.area[machine.index] or 0
      if area_id > 0 then
        local operational = controller_operational(machine)
        local grid_served = world.area_powered[area_id] == true
        for _, channel in ipairs({
          "lighting",
          "equipment",
          "environment",
        }) do
          local channel_result = result[channel]
          channel_result.seen[area_id] = true
          local field = apc_channel_field(channel)
          local requested_value = machine.data and machine.data[field]
          if requested_value == nil then
            requested_value = 3
          end
          local requested =
            type(requested_value) == "number"
            and requested_value % 1 == 0
            and requested_value >= 0
            and requested_value <= 3
            and requested_value > 1
          if grid_served and operational and requested then
            channel_result.served[area_id] = true
          end
        end
      end
    end
  end
  return result
end

local function source_powered(world, services, source, channel)
  if channel == "none" then
    return true
  end
  if source.machine then
    local machine = source.machine
    local status = machine.status or {}
    if not machine_enabled(machine)
      or machine.powered ~= true
      or status.power_off == true
      or status.no_power == true
    then
      return false
    end
  end
  local index = source.index
  local area_id = index and world.area[index] or 0
  local channel_service = services[channel]
  if area_id and area_id > 0
    and channel_service
    and channel_service.seen[area_id]
  then
    return channel_service.served[area_id] == true
  end
  if source.machine
    and source.machine.power
    and source.machine.power.channel == channel
  then
    return source.machine.powered == true
  end
  return index and world.powered[index] == true or false
end

local function activation_enabled(world, services, source, activation)
  if source.enabled == false then
    return false
  end
  local mode = activation.mode
  if mode == "always" or mode == "independent" then
    return true
  end
  local powered = source_powered(
    world,
    services,
    source,
    activation.power_channel
  )
  if mode == "normal" then
    return powered
  elseif mode == "emergency" then
    return not powered and source.reserve_available == true
  end
  -- Signal bindings remain reserved until an authoritative signal provider
  -- is added. Silently lighting them would turn a data typo into gameplay.
  return false
end

local function curve_level(curve, input, fallback)
  if not curve then
    return fallback
  end
  if input <= curve[1].input then
    return curve[1].output_ppm
  end
  for index = 2, #curve do
    local right = curve[index]
    if input <= right.input then
      local left = curve[index - 1]
      local span = right.input - left.input
      local numerator =
        (input - left.input) * (right.output_ppm - left.output_ppm)
      return left.output_ppm + math.floor(numerator / span)
    end
  end
  return curve[#curve].output_ppm
end

local function string_hash(value)
  local hash = 5381
  for index = 1, #value do
    hash = (hash * 131 + value:byte(index)) % 2147483647
  end
  return hash
end

local function flicker_level(profile, source_id, source_index, tick, level)
  local flicker = profile.flicker
  if flicker.mode ~= "hash-step" or flicker.amplitude_ppm <= 0 then
    return level
  end
  local phase = math.floor((tick or 0) / flicker.period_ticks)
  local hash = (
    string_hash(source_id)
      + (source_index or 0) * 1103515245
      + phase * 12345
  ) % 1000001
  local signed = hash * 2 - 1000000
  local scale = 1000000
    + math.floor(signed * flicker.amplitude_ppm / 1000000)
  return math.max(0, math.floor(level * scale / 1000000))
end

local function provider_sources(world, provider_id)
  local result = {}
  if provider_id == FIXTURE_PROVIDER then
    for index = 1, world.size do
      if world:has_feature(index, Constants.FEATURE.LIGHT) then
        local x, y = world:coordinates(index)
        result[#result + 1] = {
          id = "fixture:" .. tostring(index),
          index = index,
          x = x,
          y = y,
          enabled = fixture_enabled(world, index),
          input_ppm = 1000000,
        }
      end
    end
  elseif provider_id == FIRE_PROVIDER then
    for index = 1, world.size do
      local intensity = world.fire[index] or 0
      if intensity > 0 then
        local x, y = world:coordinates(index)
        result[#result + 1] = {
          id = "fire:" .. tostring(index),
          index = index,
          x = x,
          y = y,
          enabled = true,
          input_ppm = math.min(1000000, intensity * 250000),
        }
      end
    end
  end
  return result
end

local function definition_sources(world, machines, definition_id)
  local result = {}
  for index = 1, #(machines or {}) do
    local machine = machines[index]
    if machine.definition_id == definition_id and machine.index then
      local x, y = machine.x, machine.y
      if not x or not y then
        x, y = world:coordinates(machine.index)
      end
      result[#result + 1] = {
        id = "machine:" .. tostring(machine.id),
        index = machine.index,
        x = x,
        y = y,
        enabled = machine_enabled(machine),
        input_ppm = 1000000,
        machine = machine,
      }
    end
  end
  return result
end

local function source_path_source_index(world, scenario, contract)
  local result = {}
  if not scenario then
    return result
  end
  local appearances = scenario.map and scenario.map.appearances or {}
  for appearance_index = 1, #appearances do
    local appearance = appearances[appearance_index]
    if appearance.role == "object" then
      local winner
      for binding_index = 1, #contract.bindings do
        local binding = contract.bindings[binding_index]
        local selector = binding.selector
        if selector.kind == "source-path"
          and contains_sorted(
            selector.scenario_ids,
            world.map_id or ""
          )
          and path_is(appearance.source_path, selector.path_root)
          and (
            not winner
            or #selector.path_root > #winner.selector.path_root
            or (
              #selector.path_root == #winner.selector.path_root
              and binding.id < winner.id
            )
          )
        then
          winner = binding
        end
      end
      if winner then
        local sources = result[winner.id]
        if not sources then
          sources = {}
          result[winner.id] = sources
        end
        local x, y = world:coordinates(appearance.index)
        sources[#sources + 1] = {
          id = string.format(
            "appearance:%d:%d",
            appearance.index,
            appearance.order
          ),
          index = appearance.index,
          x = x,
          y = y,
          enabled = true,
          input_ppm = 1000000,
        }
      end
    end
  end
  for _, sources in pairs(result) do
    table.sort(sources, function(a, b)
      return a.id < b.id
    end)
  end
  return result
end

local function sources_for_binding(world, machines, binding)
  local selector = binding.selector
  if selector.kind == "provider" then
    return provider_sources(world, selector.provider_id)
  elseif selector.kind == "definition" then
    return definition_sources(world, machines, selector.definition_id)
  end
  return {}
end

local function selector_cache_key(selector)
  if selector.kind == "provider" then
    return "provider:" .. selector.provider_id
  elseif selector.kind == "definition" then
    return "definition:" .. selector.definition_id
  end
  return table.concat({
    "source-path:",
    selector.path_root,
    ":",
    table.concat(selector.scenario_ids, ","),
  })
end

local function cached_sources_for_binding(
  cache,
  world,
  machines,
  scenario,
  binding,
  contract
)
  if binding.selector.kind == "source-path" then
    local index_key = "@source-path-index"
    if not cache[index_key] then
      cache[index_key] = source_path_source_index(
        world,
        scenario,
        contract
      )
    end
    return cache[index_key][binding.id] or {}
  end
  local key = selector_cache_key(binding.selector)
  local sources = cache[key]
  if not sources then
    sources = sources_for_binding(world, machines, binding)
    table.sort(sources, function(a, b)
      return a.id < b.id
    end)
    cache[key] = sources
  end
  return sources
end

local function emitter_signature(emitters)
  local values = { tostring(#emitters) }
  for index = 1, #emitters do
    local emitter = emitters[index]
    values[#values + 1] = emitter.id
    values[#values + 1] = tostring(emitter.x_256)
    values[#values + 1] = tostring(emitter.y_256)
    values[#values + 1] = tostring(emitter.level_ppm)
    values[#values + 1] = emitter.profile.id
  end
  return table.concat(values, "|")
end

local function signature_value(value)
  if value == nil then
    return "-"
  elseif value == true then
    return "1"
  elseif value == false then
    return "0"
  end
  local encoded = tostring(value)
  return tostring(#encoded) .. ":" .. encoded
end

function LightSources.machine_signature(machines)
  local rows = {}
  for index = 1, #(machines or {}) do
    local machine = machines[index]
    local data = machine.data or {}
    local status = machine.status or {}
    local power = machine.power or {}
    local values = {
      signature_value(machine.id),
      signature_value(machine.kind),
      signature_value(machine.definition_id),
      signature_value(machine.index),
      signature_value(machine.x),
      signature_value(machine.y),
      signature_value(machine.destroyed),
      signature_value(machine.powered),
      signature_value(status.broken),
      signature_value(status.power_off),
      signature_value(status.no_power),
      signature_value(power.channel),
      signature_value(data.operating),
      signature_value(data.do_not_operate),
      signature_value(data.shorted),
      signature_value(data.lighting),
      signature_value(data.equipment),
      signature_value(data.environ),
    }
    rows[#rows + 1] = table.concat(values, "\31")
  end
  table.sort(rows)
  return table.concat(rows, "\30")
end

local function emitter_work_units(emitter)
  local radius = math.ceil(emitter.radius_256 / 256)
  local diameter = radius * 2 + 1
  return diameter * diameter * math.max(1, radius)
end

function LightSources.collect(world, machines, content, contract, tick)
  local services = LightSources.area_channel_service(world, machines)
  local scenario = content
    and content.by_id
    and content.by_id[world.map_id]
    or nil
  local emitters = {}
  local source_cache = {}
  local work_units = 0
  local dropped = 0
  local candidate_checks = 0
  local candidate_limit_reached = false
  for binding_index = 1, #contract.bindings do
    local binding = contract.bindings[binding_index]
    local sources = cached_sources_for_binding(
      source_cache,
      world,
      machines,
      scenario,
      binding,
      contract
    )
    for source_index = 1, #sources do
      candidate_checks = candidate_checks + 1
      if candidate_checks > LightSources.MAX_CANDIDATE_CHECKS then
        candidate_limit_reached = true
        break
      end
      local source = sources[source_index]
      if activation_enabled(
        world,
        services,
        source,
        binding.activation
      ) then
        local level = curve_level(
          binding.level_curve,
          source.input_ppm,
          binding.level_ppm
        )
        local id = binding.id .. "#" .. source.id
        level = flicker_level(
          binding.profile,
          id,
          source.index,
          tick,
          level
        )
        if level > 0 then
          local radius = math.min(
            binding.profile.radius_256,
            contract.settings.max_radius_256
          )
          local x_256 =
            (source.x - 1) * 256
            + 128
            + binding.offset_x_256
          local y_256 =
            (source.y - 1) * 256
            + 128
            + binding.offset_y_256
          local emitter = {
            id = id,
            index = source.index,
            tile_x = math.floor(x_256 / 256) + 1,
            tile_y = math.floor(y_256 / 256) + 1,
            x_256 = x_256,
            y_256 = y_256,
            radius_256 = radius,
            level_ppm = level,
            profile = binding.profile,
            priority = binding.profile.priority,
          }
          emitter.work_units = emitter_work_units(emitter)
          local next_work = work_units + emitter.work_units
          if #emitters < contract.settings.max_emitters
            and next_work <= contract.settings.max_work_units
          then
            emitters[#emitters + 1] = emitter
            work_units = next_work
          else
            dropped = dropped + 1
          end
        end
      end
    end
    if candidate_limit_reached then
      dropped = dropped + 1
      break
    end
  end
  table.sort(emitters, function(a, b)
    return a.id < b.id
  end)
  return
    emitters,
    emitter_signature(emitters),
    dropped,
    work_units,
    candidate_checks,
    candidate_limit_reached
end

return LightSources
