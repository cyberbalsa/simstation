local Stable = require("src.core.stable")
local ContentId = require("src.content.id")

-- Shared runtime/content contract. This module intentionally has no love.*
-- dependency so the mod loader can validate lighting atomically.
local LightingContent = {}

LightingContent.SETTINGS_ID =
  "org.simstation.core:lighting-settings/station"
LightingContent.MAX_BINDINGS = 128
LightingContent.MAX_PROFILES = 256
LightingContent.DEFAULT_MAX_WORK_UNITS = 4000000

local PROFILE_KEYS = {
  bloom_ppm = true,
  bloom_radius_256 = true,
  color_srgb8 = true,
  falloff = true,
  flicker = true,
  height_256 = true,
  id = true,
  intensity_ppm = true,
  kind = true,
  name_key = true,
  occlusion = true,
  priority = true,
  radius_256 = true,
  replaces = true,
  schema = true,
}

local BINDING_KEYS = {
  activation = true,
  id = true,
  kind = true,
  level_curve = true,
  level_ppm = true,
  offset_x_256 = true,
  offset_y_256 = true,
  profile_id = true,
  replaces = true,
  schema = true,
  selector = true,
}

local SETTINGS_KEYS = {
  id = true,
  kind = true,
  linear_filter = true,
  max_emitters = true,
  max_radius_256 = true,
  max_work_units = true,
  replaces = true,
  schema = true,
  shader = true,
  space_ambient_srgb8 = true,
  station_ambient_srgb8 = true,
}

local FALL_OFF = {
  constant = true,
  ["goon-robust"] = true,
  linear = true,
  smoothstep = true,
}

local OCCLUSION = {
  none = true,
  ["tile-transmission"] = true,
}

local ACTIVATION_MODES = {
  always = true,
  emergency = true,
  independent = true,
  normal = true,
  signal = true,
}

local POWER_CHANNELS = {
  environment = true,
  equipment = true,
  lighting = true,
  none = true,
}

local PROVIDERS = {
  ["org.simstation.core:light-provider/fire-tile-v1"] = true,
  ["org.simstation.core:light-provider/light-feature-v1"] = true,
}

local DEFAULT_DEFINITIONS = {
  {
    id = LightingContent.SETTINGS_ID,
    kind = "lighting-settings",
    schema = 1,
    station_ambient_srgb8 = { 0, 0, 0 },
    space_ambient_srgb8 = { 255, 255, 255 },
    max_emitters = 2048,
    max_radius_256 = 3072,
    max_work_units = LightingContent.DEFAULT_MAX_WORK_UNITS,
    shader = true,
    linear_filter = true,
  },
  {
    id = "org.simstation.core:light-profile/goon-tube",
    kind = "light-profile",
    schema = 1,
    name_key = "light_profile.goon_tube",
    color_srgb8 = { 242, 242, 255 },
    radius_256 = 768,
    intensity_ppm = 1600000,
    height_256 = 614,
    falloff = "goon-robust",
    occlusion = "tile-transmission",
    flicker = { mode = "none" },
    priority = 100,
    bloom_ppm = 0,
    bloom_radius_256 = 0,
  },
  {
    id = "org.simstation.core:light-profile/goon-fire",
    kind = "light-profile",
    schema = 1,
    name_key = "light_profile.goon_fire",
    color_srgb8 = { 255, 105, 35 },
    radius_256 = 768,
    intensity_ppm = 900000,
    height_256 = 256,
    falloff = "smoothstep",
    occlusion = "tile-transmission",
    flicker = {
      mode = "hash-step",
      amplitude_ppm = 140000,
      period_ticks = 2,
    },
    priority = 200,
    bloom_ppm = 320000,
    bloom_radius_256 = 448,
  },
  {
    id = "org.simstation.core:light-binding/station-fixtures",
    kind = "light-binding",
    schema = 1,
    profile_id = "org.simstation.core:light-profile/goon-tube",
    selector = {
      kind = "provider",
      provider_id =
        "org.simstation.core:light-provider/light-feature-v1",
    },
    activation = {
      mode = "normal",
      power_channel = "lighting",
    },
    offset_x_256 = 0,
    offset_y_256 = 0,
    level_ppm = 1000000,
  },
  {
    id = "org.simstation.core:light-binding/fire",
    kind = "light-binding",
    schema = 1,
    profile_id = "org.simstation.core:light-profile/goon-fire",
    selector = {
      kind = "provider",
      provider_id = "org.simstation.core:light-provider/fire-tile-v1",
    },
    activation = {
      mode = "always",
      power_channel = "none",
    },
    offset_x_256 = 0,
    offset_y_256 = 0,
    level_ppm = 1000000,
    level_curve = {
      { input = 0, output_ppm = 0 },
      { input = 250000, output_ppm = 650000 },
      { input = 500000, output_ppm = 900000 },
      { input = 750000, output_ppm = 1150000 },
      { input = 1000000, output_ppm = 1400000 },
    },
  },
}

local function fail(message)
  return nil, message
end

local function closed_keys(value, allowed, label)
  if type(value) ~= "table" then
    return fail(label .. " must be an object")
  end
  for key in pairs(value) do
    if not allowed[key] then
      return fail(label .. " has unknown field " .. tostring(key))
    end
  end
  return true
end

local function integer(value, label, minimum, maximum)
  if type(value) ~= "number"
    or value % 1 ~= 0
    or value < minimum
    or value > maximum
  then
    return fail(string.format(
      "%s must be an integer from %d through %d",
      label,
      minimum,
      maximum
    ))
  end
  return value
end

local function nonempty_string(value, label)
  if type(value) ~= "string" or value == "" then
    return fail(label .. " must be a non-empty string")
  end
  return value
end

local function content_id(value, kind, label)
  local parsed, parse_error = ContentId.parse(value)
  if not parsed or parsed.kind ~= kind then
    return fail(
      label
        .. " must be a namespaced "
        .. kind
        .. " ID"
        .. (parse_error and (": " .. parse_error) or "")
    )
  end
  return value
end

local function rgb8(value, label)
  if type(value) ~= "table" or #value ~= 3 then
    return fail(label .. " must contain exactly three channels")
  end
  local result = {}
  for index = 1, 3 do
    local channel, channel_error = integer(
      value[index],
      label .. "[" .. tostring(index) .. "]",
      0,
      255
    )
    if not channel then
      return nil, channel_error
    end
    result[index] = channel
  end
  return result
end

local function sorted_unique_strings(value, label, maximum)
  if type(value) ~= "table" or #value < 1 or #value > maximum then
    return fail(string.format(
      "%s must contain 1 through %d values",
      label,
      maximum
    ))
  end
  local result = {}
  local previous
  for index = 1, #value do
    local current, current_error = nonempty_string(
      value[index],
      label .. "[" .. tostring(index) .. "]"
    )
    if not current then
      return nil, current_error
    end
    if previous and current <= previous then
      return fail(label .. " must be sorted and unique")
    end
    result[index] = current
    previous = current
  end
  return result
end

function LightingContent.validate_profile(definition)
  local ok, key_error = closed_keys(
    definition,
    PROFILE_KEYS,
    "light-profile"
  )
  if not ok then
    return nil, key_error
  end
  if definition.kind ~= "light-profile" or definition.schema ~= 1 then
    return fail("light-profile requires kind=light-profile/schema=1")
  end
  local id, id_error = content_id(
    definition.id,
    "light-profile",
    "light-profile.id"
  )
  if not id then
    return nil, id_error
  end
  local name_key, name_error = nonempty_string(
    definition.name_key,
    "light-profile.name_key"
  )
  if not name_key then
    return nil, name_error
  end
  local color, color_error = rgb8(
    definition.color_srgb8,
    "light-profile.color_srgb8"
  )
  if not color then
    return nil, color_error
  end
  local radius, radius_error = integer(
    definition.radius_256,
    "light-profile.radius_256",
    0,
    8192
  )
  if not radius then
    return nil, radius_error
  end
  local intensity, intensity_error = integer(
    definition.intensity_ppm,
    "light-profile.intensity_ppm",
    0,
    4000000
  )
  if not intensity then
    return nil, intensity_error
  end
  local height, height_error = integer(
    definition.height_256,
    "light-profile.height_256",
    1,
    4096
  )
  if not height then
    return nil, height_error
  end
  if not FALL_OFF[definition.falloff] then
    return fail("light-profile.falloff is unsupported")
  end
  if not OCCLUSION[definition.occlusion] then
    return fail("light-profile.occlusion is unsupported")
  end
  local flicker = definition.flicker
  if type(flicker) ~= "table" then
    return fail("light-profile.flicker must be an object")
  end
  local normalized_flicker
  if flicker.mode == "none" then
    for key in pairs(flicker) do
      if key ~= "mode" then
        return fail("light-profile.flicker has unknown field " .. tostring(key))
      end
    end
    normalized_flicker = { mode = "none" }
  elseif flicker.mode == "hash-step" then
    for key in pairs(flicker) do
      if key ~= "mode"
        and key ~= "amplitude_ppm"
        and key ~= "period_ticks"
      then
        return fail("light-profile.flicker has unknown field " .. tostring(key))
      end
    end
    local amplitude, amplitude_error = integer(
      flicker.amplitude_ppm,
      "light-profile.flicker.amplitude_ppm",
      0,
      500000
    )
    if not amplitude then
      return nil, amplitude_error
    end
    local period, period_error = integer(
      flicker.period_ticks,
      "light-profile.flicker.period_ticks",
      1,
      600
    )
    if not period then
      return nil, period_error
    end
    normalized_flicker = {
      mode = "hash-step",
      amplitude_ppm = amplitude,
      period_ticks = period,
    }
  else
    return fail("light-profile.flicker.mode is unsupported")
  end
  local priority, priority_error = integer(
    definition.priority,
    "light-profile.priority",
    -1000000,
    1000000
  )
  if not priority then
    return nil, priority_error
  end
  local bloom, bloom_error = integer(
    definition.bloom_ppm or 0,
    "light-profile.bloom_ppm",
    0,
    1000000
  )
  if not bloom then
    return nil, bloom_error
  end
  local bloom_radius, bloom_radius_error = integer(
    definition.bloom_radius_256 or 0,
    "light-profile.bloom_radius_256",
    0,
    4096
  )
  if not bloom_radius then
    return nil, bloom_radius_error
  end
  return {
    id = id,
    kind = "light-profile",
    schema = 1,
    name_key = name_key,
    color_srgb8 = color,
    radius_256 = radius,
    intensity_ppm = intensity,
    height_256 = height,
    falloff = definition.falloff,
    occlusion = definition.occlusion,
    flicker = normalized_flicker,
    priority = priority,
    bloom_ppm = bloom,
    bloom_radius_256 = bloom_radius,
  }
end

local function validate_selector(selector)
  if type(selector) ~= "table" or type(selector.kind) ~= "string" then
    return fail("light-binding.selector must be a tagged object")
  end
  if selector.kind == "provider" then
    for key in pairs(selector) do
      if key ~= "kind" and key ~= "provider_id" then
        return fail("provider selector has unknown field " .. tostring(key))
      end
    end
    if not PROVIDERS[selector.provider_id] then
      return fail("unknown light provider " .. tostring(selector.provider_id))
    end
    return {
      kind = "provider",
      provider_id = selector.provider_id,
    }
  elseif selector.kind == "definition" then
    for key in pairs(selector) do
      if key ~= "kind" and key ~= "definition_id" then
        return fail("definition selector has unknown field " .. tostring(key))
      end
    end
    local parsed, definition_error =
      ContentId.parse(selector.definition_id)
    if not parsed or parsed.kind ~= "machine" then
      return fail(
        "definition light selector must name machine content"
          .. (definition_error and (": " .. definition_error) or "")
      )
    end
    return {
      kind = "definition",
      definition_id = selector.definition_id,
    }
  elseif selector.kind == "source-path" then
    for key in pairs(selector) do
      if key ~= "kind"
        and key ~= "scenario_ids"
        and key ~= "path_root"
      then
        return fail("source-path selector has unknown field " .. tostring(key))
      end
    end
    local scenarios, scenarios_error = sorted_unique_strings(
      selector.scenario_ids,
      "source-path selector scenario_ids",
      64
    )
    if not scenarios then
      return nil, scenarios_error
    end
    for index = 1, #scenarios do
      local scenario, scenario_error = content_id(
        scenarios[index],
        "scenario",
        "source-path selector scenario_ids[" .. tostring(index) .. "]"
      )
      if not scenario then
        return nil, scenario_error
      end
    end
    local root, root_error = nonempty_string(
      selector.path_root,
      "source-path selector path_root"
    )
    if not root then
      return nil, root_error
    end
    local unsafe_root = #root > 1024
      or root:sub(1, 5) ~= "/obj/"
      or root:sub(-1) == "/"
    for component in root:gmatch("[^/]+") do
      if component == "." or component == ".." then
        unsafe_root = true
      end
    end
    if unsafe_root or root:find("//", 1, true) then
      return fail("source-path selector path_root is unsafe")
    end
    return {
      kind = "source-path",
      scenario_ids = scenarios,
      path_root = root,
    }
  end
  return fail("light-binding.selector kind is unsupported")
end

local function validate_activation(activation)
  if type(activation) ~= "table" then
    return fail("light-binding.activation must be an object")
  end
  for key in pairs(activation) do
    if key ~= "mode" and key ~= "power_channel" then
      return fail("light-binding.activation has unknown field " .. tostring(key))
    end
  end
  if not ACTIVATION_MODES[activation.mode] then
    return fail("light-binding.activation.mode is unsupported")
  end
  if not POWER_CHANNELS[activation.power_channel] then
    return fail("light-binding.activation.power_channel is unsupported")
  end
  if (
      activation.mode == "always"
      or activation.mode == "independent"
    )
    and activation.power_channel ~= "none"
  then
    return fail(
      activation.mode .. " light bindings require power_channel=none"
    )
  elseif (
      activation.mode == "normal"
      or activation.mode == "emergency"
      or activation.mode == "signal"
    )
    and activation.power_channel == "none"
  then
    return fail(activation.mode .. " light bindings require a power channel")
  end
  return {
    mode = activation.mode,
    power_channel = activation.power_channel,
  }
end

local function validate_level_curve(curve)
  if curve == nil then
    return nil
  end
  if type(curve) ~= "table" or #curve < 2 or #curve > 16 then
    return fail("light-binding.level_curve must contain 2 through 16 points")
  end
  local result = {}
  local previous = -1
  for index = 1, #curve do
    local point = curve[index]
    if type(point) ~= "table" then
      return fail("light-binding.level_curve points must be objects")
    end
    for key in pairs(point) do
      if key ~= "input" and key ~= "output_ppm" then
        return fail("light-binding.level_curve point has unknown field")
      end
    end
    local input, input_error = integer(
      point.input,
      "light-binding.level_curve.input",
      0,
      1000000
    )
    if not input then
      return nil, input_error
    end
    if input <= previous then
      return fail("light-binding.level_curve inputs must increase")
    end
    local output, output_error = integer(
      point.output_ppm,
      "light-binding.level_curve.output_ppm",
      0,
      4000000
    )
    if not output then
      return nil, output_error
    end
    result[index] = { input = input, output_ppm = output }
    previous = input
  end
  return result
end

function LightingContent.validate_binding(definition)
  local ok, key_error = closed_keys(
    definition,
    BINDING_KEYS,
    "light-binding"
  )
  if not ok then
    return nil, key_error
  end
  if definition.kind ~= "light-binding" or definition.schema ~= 1 then
    return fail("light-binding requires kind=light-binding/schema=1")
  end
  local id, id_error = content_id(
    definition.id,
    "light-binding",
    "light-binding.id"
  )
  if not id then
    return nil, id_error
  end
  local profile_id, profile_error = content_id(
    definition.profile_id,
    "light-profile",
    "light-binding.profile_id"
  )
  if not profile_id then
    return nil, profile_error
  end
  local selector, selector_error = validate_selector(definition.selector)
  if not selector then
    return nil, selector_error
  end
  local activation, activation_error =
    validate_activation(definition.activation)
  if not activation then
    return nil, activation_error
  end
  local offset_x, offset_x_error = integer(
    definition.offset_x_256 or 0,
    "light-binding.offset_x_256",
    -4096,
    4096
  )
  if not offset_x then
    return nil, offset_x_error
  end
  local offset_y, offset_y_error = integer(
    definition.offset_y_256 or 0,
    "light-binding.offset_y_256",
    -4096,
    4096
  )
  if not offset_y then
    return nil, offset_y_error
  end
  local level, level_error = integer(
    definition.level_ppm,
    "light-binding.level_ppm",
    0,
    4000000
  )
  if not level then
    return nil, level_error
  end
  local curve, curve_error = validate_level_curve(definition.level_curve)
  if definition.level_curve ~= nil and not curve then
    return nil, curve_error
  end
  return {
    id = id,
    kind = "light-binding",
    schema = 1,
    profile_id = profile_id,
    selector = selector,
    activation = activation,
    offset_x_256 = offset_x,
    offset_y_256 = offset_y,
    level_ppm = level,
    level_curve = curve,
  }
end

function LightingContent.validate_settings(definition)
  local ok, key_error = closed_keys(
    definition,
    SETTINGS_KEYS,
    "lighting-settings"
  )
  if not ok then
    return nil, key_error
  end
  if definition.kind ~= "lighting-settings" or definition.schema ~= 1 then
    return fail(
      "lighting-settings requires kind=lighting-settings/schema=1"
    )
  end
  if definition.id ~= LightingContent.SETTINGS_ID then
    return fail("lighting-settings must replace " .. LightingContent.SETTINGS_ID)
  end
  local station, station_error = rgb8(
    definition.station_ambient_srgb8,
    "lighting-settings.station_ambient_srgb8"
  )
  if not station then
    return nil, station_error
  end
  local space, space_error = rgb8(
    definition.space_ambient_srgb8,
    "lighting-settings.space_ambient_srgb8"
  )
  if not space then
    return nil, space_error
  end
  local max_emitters, max_emitters_error = integer(
    definition.max_emitters,
    "lighting-settings.max_emitters",
    1,
    4096
  )
  if not max_emitters then
    return nil, max_emitters_error
  end
  local max_radius, max_radius_error = integer(
    definition.max_radius_256,
    "lighting-settings.max_radius_256",
    0,
    8192
  )
  if not max_radius then
    return nil, max_radius_error
  end
  local requested_max_work_units = definition.max_work_units
  if requested_max_work_units == nil then
    requested_max_work_units = LightingContent.DEFAULT_MAX_WORK_UNITS
  end
  local max_work_units, max_work_error = integer(
    requested_max_work_units,
    "lighting-settings.max_work_units",
    1,
    64000000
  )
  if not max_work_units then
    return nil, max_work_error
  end
  if type(definition.shader) ~= "boolean"
    or type(definition.linear_filter) ~= "boolean"
  then
    return fail("lighting-settings shader/filter flags must be booleans")
  end
  return {
    id = LightingContent.SETTINGS_ID,
    kind = "lighting-settings",
    schema = 1,
    station_ambient_srgb8 = station,
    space_ambient_srgb8 = space,
    max_emitters = max_emitters,
    max_radius_256 = max_radius,
    max_work_units = max_work_units,
    shader = definition.shader,
    linear_filter = definition.linear_filter,
  }
end

local function registry_failure(registry, id, message)
  return nil, {
    id = id,
    owner = registry.owners and registry.owners[id] or nil,
    source = registry.sources and registry.sources[id] or nil,
    message = id .. ": " .. message,
  }
end

function LightingContent.validate_registry(registry)
  local profiles = {}
  local profile_ids = registry:ids("light-profile")
  if #profile_ids > LightingContent.MAX_PROFILES then
    return registry_failure(
      registry,
      profile_ids[LightingContent.MAX_PROFILES + 1],
      string.format(
        "resolved registry has more than %d light profiles",
        LightingContent.MAX_PROFILES
      )
    )
  end
  for index = 1, #profile_ids do
    local id = profile_ids[index]
    local profile, profile_error =
      LightingContent.validate_profile(registry:get(id))
    if not profile then
      return registry_failure(registry, id, profile_error)
    end
    profiles[id] = profile
  end

  local settings_ids = registry:ids("lighting-settings")
  for index = 1, #settings_ids do
    local id = settings_ids[index]
    local settings, settings_error =
      LightingContent.validate_settings(registry:get(id))
    if not settings then
      return registry_failure(registry, id, settings_error)
    end
  end

  local binding_ids = registry:ids("light-binding")
  if #binding_ids > LightingContent.MAX_BINDINGS then
    return registry_failure(
      registry,
      binding_ids[LightingContent.MAX_BINDINGS + 1],
      string.format(
        "resolved registry has more than %d light bindings",
        LightingContent.MAX_BINDINGS
      )
    )
  end
  local source_path_bindings = {}
  for index = 1, #binding_ids do
    local id = binding_ids[index]
    local binding, binding_error =
      LightingContent.validate_binding(registry:get(id))
    if not binding then
      return registry_failure(registry, id, binding_error)
    end
    if not profiles[binding.profile_id] then
      return registry_failure(
        registry,
        id,
        "unresolved profile " .. binding.profile_id
      )
    end
    local selector = binding.selector
    if selector.kind == "definition" then
      local target = registry:get(selector.definition_id)
      if not target or target.kind ~= "machine" then
        return registry_failure(
          registry,
          id,
          "unresolved machine definition " .. selector.definition_id
        )
      end
    elseif selector.kind == "source-path" then
      for scenario_index = 1, #selector.scenario_ids do
        local scenario_id = selector.scenario_ids[scenario_index]
        local scenario = registry:get(scenario_id)
        if not scenario or scenario.kind ~= "scenario" then
          return registry_failure(
            registry,
            id,
            "unresolved scenario " .. scenario_id
          )
        end
      end
      source_path_bindings[#source_path_bindings + 1] = binding
    end
  end

  for left_index = 1, #source_path_bindings do
    local left = source_path_bindings[left_index]
    for right_index = left_index + 1, #source_path_bindings do
      local right = source_path_bindings[right_index]
      if left.selector.path_root == right.selector.path_root then
        for scenario_index = 1, #left.selector.scenario_ids do
          local scenario_id = left.selector.scenario_ids[scenario_index]
          for other_index = 1, #right.selector.scenario_ids do
            if scenario_id == right.selector.scenario_ids[other_index] then
              return registry_failure(
                registry,
                right.id,
                "ambiguous source-path root "
                  .. right.selector.path_root
                  .. " for "
                  .. scenario_id
              )
            end
          end
        end
      end
    end
  end
  return true
end

local function default_content()
  local by_kind = {
    ["light-profile"] = {},
    ["light-binding"] = {},
    ["lighting-settings"] = {},
  }
  local by_id = {}
  for index = 1, #DEFAULT_DEFINITIONS do
    local definition = Stable.deep_copy(DEFAULT_DEFINITIONS[index])
    by_id[definition.id] = definition
    by_kind[definition.kind][#by_kind[definition.kind] + 1] = definition
  end
  return { by_id = by_id, by_kind = by_kind }
end

local function resolve_contract(source)
  local errors = {}
  local settings_definition = source.by_id[LightingContent.SETTINGS_ID]
  if not settings_definition then
    errors[#errors + 1] = "missing " .. LightingContent.SETTINGS_ID
  end
  local settings
  if settings_definition then
    local settings_error
    settings, settings_error =
      LightingContent.validate_settings(settings_definition)
    if not settings then
      errors[#errors + 1] = settings_error
    end
  end

  local profiles = {}
  local values = source.by_kind["light-profile"] or {}
  if #values > LightingContent.MAX_PROFILES then
    errors[#errors + 1] = string.format(
      "lighting profiles exceed the %d-profile limit",
      LightingContent.MAX_PROFILES
    )
  end
  for index = 1, #values do
    local profile, profile_error =
      LightingContent.validate_profile(values[index])
    if profile then
      profiles[profile.id] = profile
    else
      errors[#errors + 1] = profile_error
    end
  end

  local bindings = {}
  values = source.by_kind["light-binding"] or {}
  if #values > LightingContent.MAX_BINDINGS then
    errors[#errors + 1] = string.format(
      "lighting bindings exceed the %d-binding limit",
      LightingContent.MAX_BINDINGS
    )
  end
  for index = 1, #values do
    local binding, binding_error =
      LightingContent.validate_binding(values[index])
    if binding and profiles[binding.profile_id] then
      binding.profile = profiles[binding.profile_id]
      bindings[#bindings + 1] = binding
    elseif binding then
      errors[#errors + 1] =
        binding.id .. " references unknown profile " .. binding.profile_id
    else
      errors[#errors + 1] = binding_error
    end
  end
  table.sort(bindings, function(a, b)
    if a.profile.priority ~= b.profile.priority then
      return a.profile.priority > b.profile.priority
    end
    return a.id < b.id
  end)
  return {
    settings = settings,
    profiles = profiles,
    bindings = bindings,
    errors = errors,
  }
end

function LightingContent.resolve(content)
  local source = content
  if not source
    or type(source.by_id) ~= "table"
    or type(source.by_kind) ~= "table"
  then
    return resolve_contract(default_content())
  end
  local contract = resolve_contract(source)
  if #contract.errors == 0 then
    return contract
  end
  local errors = contract.errors
  contract = resolve_contract(default_content())
  assert(#contract.errors == 0, "embedded lighting contract is invalid")
  contract.errors = errors
  return contract
end

function LightingContent.default_definitions()
  return Stable.deep_copy(DEFAULT_DEFINITIONS)
end

return LightingContent
