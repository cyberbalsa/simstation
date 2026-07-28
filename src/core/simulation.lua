local Constants = require("src.core.constants")
local Stable = require("src.core.stable")
local Rng = require("src.core.rng")
local World = require("src.core.world")
local EventLog = require("src.core.event_log")
local CommandQueue = require("src.core.command_queue")
local Pathfinding = require("src.core.pathfinding")
local HookContext = require("src.mods.context")

local Simulation = {}
Simulation.__index = Simulation

local CREW_NAMES = {
  "Avery",
  "Morgan",
  "Riley",
  "Quinn",
  "Casey",
  "Jordan",
  "Sidney",
  "Cameron",
  "Taylor",
  "Robin",
  "Frankie",
  "Drew",
  "Bailey",
  "Hayden",
  "Reese",
  "Skyler",
  "Dakota",
  "Emerson",
  "Sage",
  "Rowan",
  "Remy",
  "Finley",
  "Parker",
  "Marley",
}

local TASK_PRIORITY = {
  emergency = 1000,
  construction = 500,
  maintenance = 400,
  hauling = 300,
  service = 200,
}

local BLUEPRINT_COST = {
  floor = 2,
  wall = 3,
  cable = 1,
  door = 5,
}

local BLUEPRINT_WORK = {
  floor = 1200,
  wall = 1800,
  cable = 600,
  door = 2400,
}

local function center_core(world)
  local center_x = math.floor(world.width / 2)
  local center_y = math.floor(world.height / 2)
  world:seed_starting_core(center_x, center_y, 15, 11)
  return center_x, center_y
end

local function spawn_crew(sim, count, center_x, center_y)
  local world = sim.world
  for i = 1, count do
    local job = Constants.JOBS[((i - 1) % #Constants.JOBS) + 1]
    local x = center_x + sim.rngs.crew:integer(-10, 10)
    local y = center_y + sim.rngs.crew:integer(-7, 7)
    local index = assert(world:index(x, y))
    sim.crew[#sim.crew + 1] = {
      id = sim.next_entity_id,
      name = CREW_NAMES[((i - 1) % #CREW_NAMES) + 1] .. " " .. tostring(i),
      job = job,
      index = index,
      health = 1000,
      hunger = sim.rngs.crew:integer(20, 120),
      fatigue = sim.rngs.crew:integer(10, 80),
      morale = sim.rngs.crew:integer(650, 900),
      credits = 500,
      task_id = false,
      path = {},
      path_revision = world.topology_revision,
      move_cooldown = i % 3,
      work_skill = job == "engineer" and 140 or job == "assistant" and 110 or 80,
      alive = true,
    }
    sim.next_entity_id = sim.next_entity_id + 1
  end
end

function Simulation.new(options)
  options = options or {}
  local seed = math.floor(options.seed or 1337)
  local world = World.new(
    options.width or Constants.DEFAULT_WORLD_WIDTH,
    options.height or Constants.DEFAULT_WORLD_HEIGHT
  )
  local sim = setmetatable({
    schema_version = Constants.SCHEMA_VERSION,
    seed = seed,
    tick = 0,
    shift_index = 1,
    seconds_in_shift = 0,
    speed = 1,
    paused = false,
    world = world,
    crew = {},
    tasks = {},
    next_entity_id = 1,
    next_task_id = 1,
    rngs = {
      crew = Rng.new(seed + 101),
      incidents = Rng.new(seed + 202),
      economy = Rng.new(seed + 303),
    },
    commands = CommandQueue.new(),
    events = EventLog.new(),
    economy = {
      station_credits = 50000,
      material_units = 300,
      wages_due = 0,
      revenue_this_shift = 0,
      expenses_this_shift = 0,
      bailout_debt = 0,
      department_credits = {
        command = 8000,
        engineering = 7000,
        cargo = 7000,
        service = 5000,
        medical = 6000,
        science = 6000,
        security = 5000,
      },
    },
    station = {
      name = "NSS Bootstrap",
      grade = "C",
      alerts = {},
      incident_threat = 0,
    },
    metrics = {
      completed_tasks = 0,
      failed_tasks = 0,
      construction_completed = 0,
      injuries = 0,
    },
    hooks = options.hooks or false,
    mod_state = Stable.deep_copy(options.mod_state or {}),
    mod_diagnostics = {},
  }, Simulation)

  local center_x, center_y = center_core(world)
  spawn_crew(sim, options.crew_count or Constants.DEFAULT_CREW_COUNT, center_x, center_y)
  world:step_power()
  sim.events:emit(0, "station_started", {
    station = sim.station.name,
    seed = seed,
  })
  sim.last_state_hash = sim:state_hash()
  return sim
end

function Simulation:enqueue(kind, payload, issuer)
  return self.commands:push(kind, payload, issuer)
end

function Simulation:flush_commands()
  self:_process_commands()
end

function Simulation:_emit(kind, payload)
  local event = self.events:emit(self.tick, kind, payload)
  if self.hooks then
    self.hooks:observe(
      "org.simstation.core:hook/event/finalized",
      HookContext.new(
        self,
        Stable.deep_copy(event),
        nil,
        { enqueue = true }
      )
    )
  end
  return event
end

function Simulation:_task_by_id(task_id)
  for i = 1, #self.tasks do
    if self.tasks[i].id == task_id then
      return self.tasks[i]
    end
  end
  return nil
end

function Simulation:_create_construction_task(tile_index, blueprint)
  local task = {
    id = self.next_task_id,
    kind = "construction",
    blueprint = blueprint,
    target_index = tile_index,
    priority = TASK_PRIORITY.construction,
    state = "offered",
    claimed_by = false,
    work_remaining = BLUEPRINT_WORK[blueprint],
    created_tick = self.tick,
  }
  self.next_task_id = self.next_task_id + 1
  self.tasks[#self.tasks + 1] = task
  return task
end

function Simulation:_apply_command(command)
  local payload = command.payload
  if command.kind == "set_speed" then
    local speed = tonumber(payload.speed)
    if speed == 1 or speed == 2 or speed == 4 then
      self.speed = speed
      self.paused = false
      self:_emit("speed_changed", { speed = speed })
      return true
    end
    return false, "speed must be 1, 2, or 4"
  elseif command.kind == "set_paused" then
    self.paused = not not payload.paused
    self:_emit("pause_changed", { paused = self.paused })
    return true
  elseif command.kind == "blueprint" then
    local kind = payload.kind
    local cost = BLUEPRINT_COST[kind]
    if not cost then
      return false, "invalid blueprint type"
    end
    if self.economy.material_units < cost then
      return false, "insufficient construction material"
    end
    local ok, result = self.world:set_blueprint(payload.x, payload.y, kind)
    if not ok then
      return false, result
    end
    self.economy.material_units = self.economy.material_units - cost
    local task = self:_create_construction_task(result, kind)
    self:_emit("blueprint_placed", {
      task_id = task.id,
      x = payload.x,
      y = payload.y,
      blueprint = kind,
      material_cost = cost,
    })
    return true
  elseif command.kind == "toggle_door" then
    local index = self.world:index(payload.x, payload.y)
    if not index then
      return false, "outside map"
    end
    local structure = self.world.structure[index]
    if structure == Constants.STRUCTURE.DOOR_CLOSED then
      self.world.structure[index] = Constants.STRUCTURE.DOOR_OPEN
    elseif structure == Constants.STRUCTURE.DOOR_OPEN then
      self.world.structure[index] = Constants.STRUCTURE.DOOR_CLOSED
    else
      return false, "tile is not a door"
    end
    self.world:touch(payload.x, payload.y, true)
    self:_emit("door_toggled", { x = payload.x, y = payload.y })
    return true
  elseif command.kind == "trigger_meteor" then
    self:_trigger_meteor(true)
    return true
  end
  return false, "unknown command: " .. tostring(command.kind)
end

function Simulation:_process_commands()
  local commands = self.commands:drain()
  for i = 1, #commands do
    local command = commands[i]
    local before_mod_state = Stable.deep_copy(self.mod_state)
    local allowed, validation_error = true, nil
    if self.hooks then
      allowed, validation_error = self.hooks:validate(
        "org.simstation.core:hook/command/validate",
        Stable.deep_copy(command),
        HookContext.new(self)
      )
    end
    local ok, err
    if allowed then
      ok, err = self:_apply_command(command)
    else
      ok, err = false, validation_error or "rejected by a trusted mod"
    end
    if not ok then
      -- Validator state is part of the command transaction. A denied or
      -- otherwise invalid command cannot commit those tentative changes.
      self.mod_state = before_mod_state
      self:_emit("command_rejected", {
        sequence = command.sequence,
        command = command.kind,
        reason = err,
      })
    end
  end
end

local function task_score(sim, crew, task)
  if task.state ~= "offered" then
    return nil
  end
  local crew_x, crew_y = sim.world:coordinates(crew.index)
  local task_x, task_y = sim.world:coordinates(task.target_index)
  local distance = math.abs(crew_x - task_x) + math.abs(crew_y - task_y)
  local qualification = 0
  if task.kind == "construction" then
    if crew.job == "engineer" then
      qualification = 300
    elseif crew.job == "assistant" or crew.job == "cargo_technician" then
      qualification = 120
    else
      qualification = -100
    end
  end
  local score = task.priority
    + qualification
    - distance * 5
    - crew.hunger
    - crew.fatigue
  if sim.hooks then
    local transformed = sim.hooks:transform(
      "org.simstation.core:hook/task/score",
      score,
      HookContext.new(sim, Stable.deep_copy(task))
    )
    if transformed == nil then
      sim.paused = true
      return nil
    end
    assert(type(transformed) == "number" and transformed % 1 == 0,
      "task score hook must return an integer")
    score = Stable.clamp(transformed, -1000000, 1000000)
  end
  return score
end

local function task_work_index(world, task)
  if task.blueprint == Constants.BLUEPRINT.CABLE then
    return task.target_index
  end
  local x, y = world:coordinates(task.target_index)
  local candidates = {
    world:index(x, y - 1),
    world:index(x - 1, y),
    world:index(x + 1, y),
    world:index(x, y + 1),
  }
  for i = 1, 4 do
    local index = candidates[i]
    if index
      and world.tile[index] == Constants.TILE.FLOOR
      and world.structure[index] ~= Constants.STRUCTURE.WALL
    then
      return index
    end
  end
  return nil
end

function Simulation:_claim_task(crew)
  local best_task
  local best_score
  for i = 1, #self.tasks do
    local task = self.tasks[i]
    local score = task_score(self, crew, task)
    if score and (not best_score or score > best_score
      or (score == best_score and task.id < best_task.id))
    then
      best_task = task
      best_score = score
    end
  end
  if not best_task then
    return
  end
  local work_index = task_work_index(self.world, best_task)
  if not work_index then
    return
  end
  local path = Pathfinding.find(self.world, crew.index, work_index)
  if not path then
    return
  end
  best_task.state = "claimed"
  best_task.claimed_by = crew.id
  best_task.work_index = work_index
  crew.task_id = best_task.id
  crew.path = path
  crew.path_revision = self.world.topology_revision
  self:_emit("task_claimed", { task_id = best_task.id, crew_id = crew.id })
end

function Simulation:_release_task(crew, task, reason)
  if task and task.state ~= "completed" then
    task.state = "offered"
    task.claimed_by = false
  end
  crew.task_id = false
  crew.path = {}
  if reason then
    self:_emit("task_released", {
      task_id = task and task.id or false,
      crew_id = crew.id,
      reason = reason,
    })
  end
end

function Simulation:_work_crew(crew)
  if not crew.alive then
    return
  end
  local task = crew.task_id and self:_task_by_id(crew.task_id) or nil
  if not task then
    crew.task_id = false
    self:_claim_task(crew)
    return
  end
  if task.state == "completed" or task.claimed_by ~= crew.id then
    self:_release_task(crew, task)
    return
  end

  if crew.path_revision ~= self.world.topology_revision then
    local work_index = task_work_index(self.world, task)
    local path = work_index
      and Pathfinding.find(self.world, crew.index, work_index)
    if not path then
      self:_release_task(crew, task, "route invalidated")
      return
    end
    crew.path = path
    task.work_index = work_index
    crew.path_revision = self.world.topology_revision
  end

  if crew.index ~= task.work_index then
    crew.move_cooldown = crew.move_cooldown - 1
    if crew.move_cooldown <= 0 then
      local next_index = table.remove(crew.path, 1)
      if not next_index then
        local work_index = task_work_index(self.world, task)
        local path = work_index
          and Pathfinding.find(self.world, crew.index, work_index)
        if not path then
          self:_release_task(crew, task, "target unreachable")
          return
        end
        crew.path = path
        task.work_index = work_index
        next_index = table.remove(crew.path, 1)
      end
      if next_index then
        local structure = self.world.structure[next_index]
        if structure == Constants.STRUCTURE.DOOR_CLOSED then
          self.world.structure[next_index] = Constants.STRUCTURE.DOOR_OPEN
          local x, y = self.world:coordinates(next_index)
          self.world:touch(x, y, true)
          crew.path_revision = self.world.topology_revision
        end
        crew.index = next_index
      end
      crew.move_cooldown = 3
    end
    return
  end

  task.state = "executing"
  task.work_remaining = task.work_remaining - crew.work_skill
  crew.fatigue = Stable.clamp(crew.fatigue + 1, 0, 1000)
  if task.work_remaining <= 0 then
    local completed, kind = self.world:complete_blueprint(task.target_index)
    if completed then
      task.state = "completed"
      self.metrics.completed_tasks = self.metrics.completed_tasks + 1
      self.metrics.construction_completed = self.metrics.construction_completed + 1
      self:_emit("construction_completed", {
        task_id = task.id,
        crew_id = crew.id,
        blueprint = kind,
      })
    else
      task.state = "failed"
      self.metrics.failed_tasks = self.metrics.failed_tasks + 1
    end
    crew.task_id = false
    crew.path = {}
  end
end

function Simulation:_step_crew()
  table.sort(self.crew, function(a, b)
    return a.id < b.id
  end)
  for i = 1, #self.crew do
    self:_work_crew(self.crew[i])
  end
end

function Simulation:_step_needs_and_health()
  for i = 1, #self.crew do
    local crew = self.crew[i]
    if crew.alive then
      crew.hunger = Stable.clamp(crew.hunger + 1, 0, 1000)
      crew.fatigue = Stable.clamp(crew.fatigue + 1, 0, 1000)
      local pressure = self.world:pressure_dkpa(crew.index)
      if pressure < 500 then
        crew.health = crew.health - 8
      elseif self.world.o2[crew.index] < 12000 then
        crew.health = crew.health - 3
      else
        crew.health = math.min(1000, crew.health + 1)
      end
      if self.world.fire[crew.index] > 0 then
        crew.health = crew.health - self.world.fire[crew.index] * 5
      end
      if crew.health <= 0 then
        crew.health = 0
        crew.alive = false
        self.metrics.injuries = self.metrics.injuries + 1
        self:_release_task(crew, self:_task_by_id(crew.task_id), "crew incapacitated")
        self:_emit("crew_incapacitated", {
          crew_id = crew.id,
          name = crew.name,
        })
      end
    end
  end
end

function Simulation:_step_economy()
  local maintenance = math.floor(self.world.power_served_w / 10000)
  self.economy.station_credits = self.economy.station_credits - maintenance
  self.economy.expenses_this_shift = self.economy.expenses_this_shift + maintenance
  if self.economy.station_credits < 0 and self.economy.bailout_debt == 0 then
    local bailout = 25000
    self.economy.station_credits = self.economy.station_credits + bailout
    self.economy.bailout_debt = bailout * 2
    self:_emit("bailout_received", {
      credits = bailout,
      debt = bailout * 2,
    })
  end
end

function Simulation:_finish_shift()
  local wage_total = 0
  for i = 1, #self.crew do
    local crew = self.crew[i]
    if crew.alive then
      local specialist = crew.job == "engineer" or crew.job == "doctor"
      local wage = specialist and 280 or 220
      crew.credits = crew.credits + wage
      wage_total = wage_total + wage
    end
  end
  self.economy.station_credits = self.economy.station_credits - wage_total
  self.economy.expenses_this_shift = self.economy.expenses_this_shift + wage_total
  local score = self.economy.station_credits
    + self.metrics.completed_tasks * 100
    - self.metrics.injuries * 1000
  self.station.grade = score >= 60000 and "A"
    or score >= 40000 and "B"
    or score >= 10000 and "C"
    or "D"
  self:_emit("shift_finished", {
    shift = self.shift_index,
    grade = self.station.grade,
    wages = wage_total,
  })
  self.shift_index = self.shift_index + 1
  self.seconds_in_shift = 0
  self.economy.revenue_this_shift = 0
  self.economy.expenses_this_shift = 0
end

function Simulation:_trigger_meteor(forced)
  local center_x = math.floor(self.world.width / 2)
  local center_y = math.floor(self.world.height / 2)
  local side = self.rngs.incidents:integer(1, 4)
  local x, y
  if side == 1 then
    x, y = center_x, center_y - 11
  elseif side == 2 then
    x, y = center_x + 15, center_y
  elseif side == 3 then
    x, y = center_x, center_y + 11
  else
    x, y = center_x - 15, center_y
  end
  self.world:make_breach(x, y)
  local index = assert(self.world:index(x, y))
  self.world.fire[index] = forced and 4 or 2
  self.station.alerts[#self.station.alerts + 1] = {
    id = self.tick,
    kind = "meteor_breach",
    x = x,
    y = y,
    severity = forced and "critical" or "warning",
  }
  self:_emit("meteor_breach", {
    x = x,
    y = y,
    forced = not not forced,
  })
end

function Simulation:_step_incidents()
  self.station.incident_threat = self.station.incident_threat + 1
  if self.station.incident_threat >= 8 and self.rngs.incidents:chance(1, 6) then
    self.station.incident_threat = 0
    self:_trigger_meteor(false)
  end
end

function Simulation:step()
  self.tick = self.tick + 1
  self.seconds_in_shift = self.seconds_in_shift + 1

  self:_process_commands()
  self:_step_crew()

  if self.tick % Constants.GAS_STEP_TICKS == 0 then
    self.world:step_atmosphere()
  end
  if self.tick % Constants.POWER_STEP_TICKS == 0 then
    self.world:step_power()
  end
  if self.tick % Constants.NEEDS_STEP_TICKS == 0 then
    self:_step_needs_and_health()
  end
  if self.tick % Constants.ECONOMY_STEP_TICKS == 0 then
    self:_step_economy()
  end
  if self.tick % Constants.INCIDENT_STEP_TICKS == 0 then
    self:_step_incidents()
  end
  if self.seconds_in_shift >= Constants.SHIFT_SECONDS then
    self:_finish_shift()
  end
  if self.tick % 60 == 0 then
    self.last_state_hash = self:state_hash()
  end
end

function Simulation:render_snapshot()
  return {
    tick = self.tick,
    shift_index = self.shift_index,
    seconds_in_shift = self.seconds_in_shift,
    speed = self.speed,
    paused = self.paused,
    world = self.world,
    crew = self.crew,
    tasks = self.tasks,
    economy = self.economy,
    station = self.station,
    metrics = self.metrics,
    events = self.events.values,
    state_hash = self.last_state_hash or 0,
  }
end

function Simulation:state_hash()
  return Stable.hash(self:snapshot())
end

function Simulation:snapshot()
  local rngs = {}
  local rng_names = Stable.sorted_keys(self.rngs)
  for i = 1, #rng_names do
    local name = rng_names[i]
    rngs[name] = self.rngs[name]:snapshot()
  end
  return {
    schema_version = self.schema_version,
    seed = self.seed,
    tick = self.tick,
    shift_index = self.shift_index,
    seconds_in_shift = self.seconds_in_shift,
    speed = self.speed,
    paused = self.paused,
    world = self.world:snapshot(),
    crew = Stable.deep_copy(self.crew),
    tasks = Stable.deep_copy(self.tasks),
    next_entity_id = self.next_entity_id,
    next_task_id = self.next_task_id,
    rngs = rngs,
    economy = Stable.deep_copy(self.economy),
    station = Stable.deep_copy(self.station),
    metrics = Stable.deep_copy(self.metrics),
    mod_state = Stable.deep_copy(self.mod_state),
    commands = Stable.deep_copy(self.commands:snapshot()),
    events = Stable.deep_copy(self.events:snapshot()),
  }
end

function Simulation.from_snapshot(snapshot, options)
  options = options or {}
  assert(snapshot.schema_version == Constants.SCHEMA_VERSION, "unsupported save schema")
  local sim = setmetatable({
    schema_version = snapshot.schema_version,
    seed = snapshot.seed,
    tick = snapshot.tick,
    shift_index = snapshot.shift_index,
    seconds_in_shift = snapshot.seconds_in_shift,
    speed = snapshot.speed,
    paused = snapshot.paused,
    world = World.from_snapshot(snapshot.world),
    crew = Stable.deep_copy(snapshot.crew),
    tasks = Stable.deep_copy(snapshot.tasks),
    next_entity_id = snapshot.next_entity_id,
    next_task_id = snapshot.next_task_id,
    rngs = {
      crew = Rng.new(1),
      incidents = Rng.new(1),
      economy = Rng.new(1),
    },
    economy = Stable.deep_copy(snapshot.economy),
    station = Stable.deep_copy(snapshot.station),
    metrics = Stable.deep_copy(snapshot.metrics),
    hooks = options.hooks or false,
    mod_state = Stable.deep_copy(snapshot.mod_state or {}),
    mod_diagnostics = {},
    commands = CommandQueue.new(),
    events = EventLog.new(),
  }, Simulation)
  for name, rng_snapshot in pairs(snapshot.rngs) do
    sim.rngs[name]:restore(rng_snapshot)
  end
  sim.commands.next_sequence = snapshot.commands.next_sequence
  sim.commands.pending = Stable.deep_copy(snapshot.commands.pending)
  sim.events.next_id = snapshot.events.next_id
  sim.events.values = Stable.deep_copy(snapshot.events.values)
  sim.last_state_hash = sim:state_hash()
  return sim
end

return Simulation
