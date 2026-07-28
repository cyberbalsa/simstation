-- Deterministic, headless simulation benchmark and soak harness.
--
-- This script intentionally depends only on the pure-Lua simulation and the
-- vendored JSON codec. It can run with LuaJIT outside LÖVE and without Git LFS
-- media. Machine-readable JSON is the only stdout output.

package.path = "./?.lua;./?/init.lua;" .. package.path

local Constants = require("src.core.constants")
local Json = require("src.vendor.json")
local Simulation = require("src.core.simulation")

local SCHEMA_VERSION = 1
local BASELINE_PATH = "tests/fixtures/benchmark-baselines.json"

local SCENARIOS = {
  smoke = {
    width = 48,
    height = 48,
    crew = 24,
    ticks = 240,
    checkpoint_every = 60,
    warmup_ticks = 60,
    minimum_ticks_per_second = 0,
    maximum_p95_tick_ms = 0,
    disaster = false,
  },
  ci = {
    width = 192,
    height = 192,
    crew = 100,
    ticks = 600,
    checkpoint_every = 120,
    warmup_ticks = 120,
    minimum_ticks_per_second = 40,
    maximum_p95_tick_ms = 25,
    disaster = true,
  },
  ["nominal-100"] = {
    width = 192,
    height = 192,
    crew = 100,
    ticks = 1800,
    checkpoint_every = 300,
    warmup_ticks = 120,
    minimum_ticks_per_second = 40,
    maximum_p95_tick_ms = 25,
    disaster = false,
  },
  ["disaster-100"] = {
    width = 192,
    height = 192,
    crew = 100,
    ticks = 1800,
    checkpoint_every = 300,
    warmup_ticks = 120,
    minimum_ticks_per_second = 40,
    maximum_p95_tick_ms = 25,
    disaster = true,
  },
  soak = {
    width = 192,
    height = 192,
    crew = 100,
    ticks = Constants.SHIFT_SECONDS,
    checkpoint_every = 600,
    warmup_ticks = 120,
    minimum_ticks_per_second = 40,
    maximum_p95_tick_ms = 25,
    disaster = true,
  },
}

local function fail_usage(message)
  error("argument error: " .. message, 0)
end

local function positive_integer(value, name, allow_zero)
  local number = tonumber(value)
  local minimum = allow_zero and 0 or 1
  if not number or number % 1 ~= 0 or number < minimum then
    fail_usage(name .. " must be an integer >= " .. tostring(minimum))
  end
  return number
end

local function nonnegative_number(value, name)
  local number = tonumber(value)
  if not number or number < 0 or number ~= number or number == math.huge then
    fail_usage(name .. " must be a finite number >= 0")
  end
  return number
end

local function copy_configuration(source)
  local result = {}
  for key, value in pairs(source) do
    result[key] = value
  end
  return result
end

local function parse_arguments(values)
  local options = {
    scenario = "ci",
    seed = 1337,
    require_golden = false,
    baseline_path = BASELINE_PATH,
  }
  local index = 1
  while index <= #values do
    local argument = values[index]
    local function take_value()
      index = index + 1
      if index > #values then
        fail_usage(argument .. " requires a value")
      end
      return values[index]
    end
    if argument == "--scenario" then
      options.scenario = take_value()
    elseif argument == "--seed" then
      options.seed = positive_integer(take_value(), "--seed", true)
    elseif argument == "--ticks" then
      options.ticks = positive_integer(take_value(), "--ticks")
    elseif argument == "--shifts" then
      options.shifts = positive_integer(take_value(), "--shifts")
    elseif argument == "--width" then
      options.width = positive_integer(take_value(), "--width")
    elseif argument == "--height" then
      options.height = positive_integer(take_value(), "--height")
    elseif argument == "--crew" then
      options.crew = positive_integer(take_value(), "--crew", true)
    elseif argument == "--checkpoint-every" then
      options.checkpoint_every =
        positive_integer(take_value(), "--checkpoint-every")
    elseif argument == "--warmup-ticks" then
      options.warmup_ticks =
        positive_integer(take_value(), "--warmup-ticks", true)
    elseif argument == "--min-tps" then
      options.minimum_ticks_per_second =
        nonnegative_number(take_value(), "--min-tps")
    elseif argument == "--max-p95-ms" then
      options.maximum_p95_tick_ms =
        nonnegative_number(take_value(), "--max-p95-ms")
    elseif argument == "--baseline" then
      options.baseline_path = take_value()
    elseif argument == "--require-golden" then
      options.require_golden = true
    elseif argument == "--output" then
      options.output = take_value()
    elseif argument == "--help" or argument == "-h" then
      fail_usage(
        "use tools/dev.py benchmark --help for the supported interface"
      )
    else
      fail_usage("unknown option " .. tostring(argument))
    end
    index = index + 1
  end

  local definition = SCENARIOS[options.scenario]
  if not definition then
    fail_usage("unknown scenario " .. tostring(options.scenario))
  end
  local configuration = copy_configuration(definition)
  configuration.scenario = options.scenario
  configuration.seed = options.seed
  for _, name in ipairs({
    "ticks",
    "width",
    "height",
    "crew",
    "checkpoint_every",
    "warmup_ticks",
    "minimum_ticks_per_second",
    "maximum_p95_tick_ms",
  }) do
    if options[name] ~= nil then
      configuration[name] = options[name]
    end
  end
  if options.shifts then
    if options.scenario ~= "soak" then
      fail_usage("--shifts is only valid with the soak scenario")
    end
    configuration.shifts = options.shifts
    configuration.ticks = Constants.SHIFT_SECONDS * options.shifts
  elseif options.scenario == "soak" and options.ticks == nil then
    configuration.shifts = 1
  end
  options.configuration = configuration
  return options
end

local function schedule_commands(simulation, configuration, tick)
  local center_x = math.floor(configuration.width / 2)
  local center_y = math.floor(configuration.height / 2)

  if tick == 1 then
    simulation:enqueue("blueprint", {
      x = center_x - 7,
      y = center_y - 4,
      kind = "wall",
    })
    simulation:enqueue("blueprint", {
      x = center_x + 7,
      y = center_y + 4,
      kind = "door",
    })
    simulation:enqueue("blueprint", {
      x = center_x - 5,
      y = center_y + 5,
      kind = "wall",
    })
  elseif tick == 25 or tick == 45 then
    simulation:enqueue("toggle_door", {
      x = center_x,
      y = center_y - 11,
    })
  elseif tick == 150 then
    simulation:enqueue("blueprint", {
      x = center_x + 4,
      y = center_y - 5,
      kind = "door",
    })
  end

  if configuration.disaster
    and (tick == 60 or (tick > 60 and (tick - 60) % 1800 == 0))
  then
    simulation:enqueue("trigger_meteor", {})
  end

  if configuration.scenario == "soak"
    and tick > 300
    and tick % 300 == 0
  then
    simulation:enqueue("toggle_door", {
      x = center_x,
      y = center_y - 11,
    })
  end
end

local function run_warmup(configuration)
  if configuration.warmup_ticks == 0 then
    return
  end
  local simulation = Simulation.new({
    seed = configuration.seed,
    width = configuration.width,
    height = configuration.height,
    crew_count = configuration.crew,
  })
  for tick = 1, configuration.warmup_ticks do
    schedule_commands(simulation, configuration, tick)
    simulation:step()
  end
end

local function add_error(errors, message)
  errors[#errors + 1] = message
end

local function validate_state(simulation, configuration)
  local errors = {}
  if simulation.tick ~= configuration.ticks then
    add_error(errors, "final tick does not match requested tick count")
  end
  if configuration.shifts
    and (
      simulation.shift_index ~= configuration.shifts + 1
      or simulation.seconds_in_shift ~= 0
    )
  then
    add_error(errors, "soak did not finish the requested complete shifts")
  end
  if #simulation.crew ~= configuration.crew then
    add_error(errors, "crew record count changed")
  end
  if #simulation.events.values > Constants.MAX_EVENTS then
    add_error(errors, "retained event log exceeded its hard cap")
  end
  if #simulation.tasks > 512 then
    add_error(errors, "retained task records exceeded the soak cap of 512")
  end
  if #simulation.station.alerts > 512 then
    add_error(errors, "retained alert records exceeded the soak cap of 512")
  end
  if #simulation.commands.pending ~= 0 then
    add_error(errors, "command queue was not empty after the final tick")
  end

  local seen_crew_ids = {}
  for index = 1, #simulation.crew do
    local crew = simulation.crew[index]
    if seen_crew_ids[crew.id] then
      add_error(errors, "duplicate crew ID " .. tostring(crew.id))
    end
    seen_crew_ids[crew.id] = true
    if type(crew.index) ~= "number"
      or crew.index % 1 ~= 0
      or crew.index < 1
      or crew.index > simulation.world.size
    then
      add_error(errors, "crew index is outside the world")
    end
    if crew.health < 0 or crew.health > 1000 then
      add_error(errors, "crew health is outside canonical bounds")
    end
  end

  local species = { "o2", "n2", "co2", "plasma", "n2o", "vapor" }
  for species_index = 1, #species do
    local values = simulation.world[species[species_index]]
    if #values ~= simulation.world.size then
      add_error(errors, species[species_index] .. " array has the wrong size")
    else
      for tile_index = 1, #values do
        local value = values[tile_index]
        if value < 0 or value % 1 ~= 0 then
          add_error(
            errors,
            species[species_index] .. " contains a negative/non-integer value"
          )
          break
        end
      end
    end
  end
  return errors
end

local function execute_run(configuration)
  collectgarbage("collect")
  local simulation = Simulation.new({
    seed = configuration.seed,
    width = configuration.width,
    height = configuration.height,
    crew_count = configuration.crew,
  })
  collectgarbage("collect")
  local initial_memory_kib = collectgarbage("count")
  local peak_memory_kib = initial_memory_kib
  local checkpoints = {}
  -- A fixed 0.1 ms histogram keeps percentile instrumentation bounded during
  -- 30-shift soaks. Bucket 10000 is the >=1000 ms overflow bucket.
  local tick_duration_histogram = {}
  local simulation_seconds = 0
  local maximum_tick_ms = 0
  local instrumentation_seconds = 0

  for tick = 1, configuration.ticks do
    schedule_commands(simulation, configuration, tick)
    local tick_started = os.clock()
    simulation:step()
    local tick_seconds = os.clock() - tick_started
    local tick_ms = tick_seconds * 1000
    simulation_seconds = simulation_seconds + tick_seconds
    maximum_tick_ms = math.max(maximum_tick_ms, tick_ms)
    local duration_bucket = math.min(10000, math.floor(tick_ms * 10))
    tick_duration_histogram[duration_bucket] =
      (tick_duration_histogram[duration_bucket] or 0) + 1
    if tick % configuration.checkpoint_every == 0
      or tick == configuration.ticks
    then
      local instrument_started = os.clock()
      checkpoints[#checkpoints + 1] = {
        tick = tick,
        state_hash = simulation:state_hash(),
      }
      local memory_kib = collectgarbage("count")
      if memory_kib > peak_memory_kib then
        peak_memory_kib = memory_kib
      end
      instrumentation_seconds = instrumentation_seconds
        + (os.clock() - instrument_started)
    end
  end

  simulation_seconds = math.max(0.000000001, simulation_seconds)
  local percentile_target = math.max(
    1,
    math.ceil(configuration.ticks * 0.95)
  )
  local percentile_count = 0
  local p95_tick_ms = maximum_tick_ms
  for bucket = 0, 10000 do
    percentile_count = percentile_count
      + (tick_duration_histogram[bucket] or 0)
    if percentile_count >= percentile_target then
      p95_tick_ms = bucket == 10000
        and maximum_tick_ms
        or (bucket + 1) / 10
      break
    end
  end
  collectgarbage("collect")
  local final_memory_kib = collectgarbage("count")
  local errors = validate_state(simulation, configuration)
  local alive = 0
  for index = 1, #simulation.crew do
    if simulation.crew[index].alive then
      alive = alive + 1
    end
  end
  return {
    checkpoints = checkpoints,
    final_state_hash = checkpoints[#checkpoints].state_hash,
    simulation_cpu_seconds = simulation_seconds,
    instrumentation_cpu_seconds = instrumentation_seconds,
    ticks_per_second = configuration.ticks / simulation_seconds,
    mean_tick_ms = simulation_seconds * 1000 / configuration.ticks,
    p95_tick_ms = p95_tick_ms,
    maximum_tick_ms = maximum_tick_ms,
    initial_memory_kib = initial_memory_kib,
    final_memory_kib = final_memory_kib,
    peak_memory_kib = peak_memory_kib,
    retained_memory_growth_kib = final_memory_kib - initial_memory_kib,
    crew_alive = alive,
    task_count = #simulation.tasks,
    event_count = #simulation.events.values,
    alert_count = #simulation.station.alerts,
    construction_completed = simulation.metrics.construction_completed,
    invariant_errors = errors,
  }
end

local function checkpoints_equal(first, second)
  if #first ~= #second then
    return false
  end
  for index = 1, #first do
    if first[index].tick ~= second[index].tick
      or first[index].state_hash ~= second[index].state_hash
    then
      return false
    end
  end
  return true
end

local function read_json(path)
  local handle = io.open(path, "rb")
  if not handle then
    return nil
  end
  local source = handle:read("*a")
  handle:close()
  return Json.decode(source)
end

local function baseline_matches(baseline, configuration)
  local expected_configuration = baseline and baseline.configuration
  if not expected_configuration then
    return false
  end
  for _, key in ipairs({
    "scenario",
    "seed",
    "width",
    "height",
    "crew",
    "ticks",
    "checkpoint_every",
  }) do
    if expected_configuration[key] ~= configuration[key] then
      return false
    end
  end
  return true
end

local function add_gate(gates, identifier, passed, actual, expected)
  gates[#gates + 1] = {
    id = identifier,
    passed = not not passed,
    actual = actual,
    expected = expected,
  }
end

local function build_report(options)
  local configuration = options.configuration
  run_warmup(configuration)
  collectgarbage("collect")
  local primary = execute_run(configuration)
  collectgarbage("collect")
  local replay = execute_run(configuration)

  local gates = {}
  add_gate(
    gates,
    "deterministic-replay",
    checkpoints_equal(primary.checkpoints, replay.checkpoints),
    replay.final_state_hash,
    primary.final_state_hash
  )
  add_gate(
    gates,
    "minimum-throughput",
    primary.ticks_per_second >= configuration.minimum_ticks_per_second,
    primary.ticks_per_second,
    configuration.minimum_ticks_per_second
  )
  if configuration.maximum_p95_tick_ms > 0 then
    add_gate(
      gates,
      "p95-tick-budget",
      primary.p95_tick_ms <= configuration.maximum_p95_tick_ms,
      primary.p95_tick_ms,
      configuration.maximum_p95_tick_ms
    )
  end
  add_gate(
    gates,
    "authoritative-invariants",
    #primary.invariant_errors == 0 and #replay.invariant_errors == 0,
    #primary.invariant_errors + #replay.invariant_errors,
    0
  )
  add_gate(
    gates,
    "retained-memory-growth",
    primary.retained_memory_growth_kib <= 65536,
    primary.retained_memory_growth_kib,
    65536
  )

  local baseline_document = read_json(options.baseline_path)
  if baseline_document
    and baseline_document.schema_version ~= SCHEMA_VERSION
  then
    error("unsupported benchmark baseline schema", 0)
  end
  local baseline = baseline_document
    and baseline_document.scenarios
    and baseline_document.scenarios[configuration.scenario]
  local matching_baseline = baseline_matches(baseline, configuration)
  if matching_baseline then
    add_gate(
      gates,
      "golden-checkpoints",
      checkpoints_equal(primary.checkpoints, baseline.checkpoints)
        and primary.final_state_hash == baseline.final_state_hash,
      primary.final_state_hash,
      baseline.final_state_hash
    )
  elseif options.require_golden then
    add_gate(
      gates,
      "golden-checkpoints",
      false,
      "no matching baseline",
      options.baseline_path
    )
  end

  local passed = true
  for index = 1, #gates do
    if not gates[index].passed then
      passed = false
      break
    end
  end

  return {
    schema_version = SCHEMA_VERSION,
    status = passed and "pass" or "fail",
    scenario = configuration.scenario,
    configuration = {
      seed = configuration.seed,
      width = configuration.width,
      height = configuration.height,
      crew = configuration.crew,
      ticks = configuration.ticks,
      shifts = configuration.shifts or 0,
      checkpoint_every = configuration.checkpoint_every,
      warmup_ticks = configuration.warmup_ticks,
      minimum_ticks_per_second =
        configuration.minimum_ticks_per_second,
      maximum_p95_tick_ms = configuration.maximum_p95_tick_ms,
    },
    runtime = {
      lua = _VERSION,
      jit = jit and jit.version or "none",
    },
    reference_budget = {
      simulation_hz = Constants.SIM_HZ,
      four_x_ticks_per_second = Constants.SIM_HZ * 4,
      reference_mean_tick_ms = 12,
      reference_p95_tick_ms = 20,
    },
    metrics = {
      final_state_hash = primary.final_state_hash,
      replay_state_hash = replay.final_state_hash,
      checkpoints = primary.checkpoints,
      simulation_cpu_seconds = primary.simulation_cpu_seconds,
      replay_cpu_seconds = replay.simulation_cpu_seconds,
      instrumentation_cpu_seconds = primary.instrumentation_cpu_seconds,
      ticks_per_second = primary.ticks_per_second,
      mean_tick_ms = primary.mean_tick_ms,
      p95_tick_ms = primary.p95_tick_ms,
      maximum_tick_ms = primary.maximum_tick_ms,
      initial_memory_kib = primary.initial_memory_kib,
      final_memory_kib = primary.final_memory_kib,
      peak_memory_kib = primary.peak_memory_kib,
      retained_memory_growth_kib = primary.retained_memory_growth_kib,
      crew_alive = primary.crew_alive,
      task_count = primary.task_count,
      event_count = primary.event_count,
      alert_count = primary.alert_count,
      construction_completed = primary.construction_completed,
      invariant_errors = primary.invariant_errors,
      replay_invariant_errors = replay.invariant_errors,
    },
    gates = gates,
  }
end

local function write_output(path, encoded)
  if not path then
    return
  end
  local handle, err = io.open(path, "wb")
  if not handle then
    error("cannot write benchmark output: " .. tostring(err), 0)
  end
  handle:write(encoded, "\n")
  handle:close()
end

local function main()
  local options = parse_arguments(arg or {})
  local report = build_report(options)
  local encoded = Json.encode(report)
  write_output(options.output, encoded)
  io.write(encoded, "\n")
  return report.status == "pass" and 0 or 1
end

local ok, result = xpcall(main, debug.traceback)
if not ok then
  local report = {
    schema_version = SCHEMA_VERSION,
    status = "error",
    error = tostring(result),
  }
  io.write(Json.encode(report), "\n")
  os.exit(3)
end
os.exit(result)
