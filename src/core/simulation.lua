local Constants = require("src.core.constants")
local Stable = require("src.core.stable")
local Rng = require("src.core.rng")
local World = require("src.core.world")
local EventLog = require("src.core.event_log")
local CommandQueue = require("src.core.command_queue")
local Pathfinding = require("src.core.pathfinding")
local Scenario = require("src.core.scenario")
local Machine = require("src.core.machine")
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
  manufacturing = 420,
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

local JOB_DEPARTMENT = {
  engineer = "engineering",
  cargo_technician = "cargo",
  doctor = "medical",
  scientist = "science",
  security_officer = "security",
  botanist = "service",
  chef = "service",
  janitor = "service",
  assistant = "general",
}

local JOB_ACCESS = {
  engineer = {
    "public",
    "engineering",
    "engineering_power",
    "maintenance",
  },
  cargo_technician = { "public", "cargo" },
  doctor = { "public", "medical" },
  scientist = { "public", "science" },
  security_officer = { "public", "security", "maintenance" },
  botanist = { "public", "service" },
  chef = { "public", "service" },
  janitor = { "public", "service", "maintenance" },
  assistant = { "public", "general" },
}

local MACHINE_DEPARTMENT_PRIORITY = {
  engineering = 1,
  cargo = 2,
  general = 3,
  science = 4,
  medical = 5,
  service = 6,
  security = 7,
  command = 8,
}

local JOB_TOOLS = {
  engineer = {
    "cable",
    "crowbar",
    "multitool",
    "prying",
    "pulsing",
    "screwdriver",
    "screwing",
    "snipping",
    "welder",
    "wirecutters",
    "wrench",
  },
  cargo_technician = {
    "crowbar",
    "prying",
    "wrench",
  },
  scientist = {
    "multitool",
    "pulsing",
    "screwdriver",
    "screwing",
  },
  security_officer = {
    "crowbar",
    "prying",
  },
  janitor = {
    "crowbar",
    "prying",
  },
  assistant = {},
}

local function job_content_id(job)
  return "org.simstation.core:job/" .. job:gsub("_", "-")
end

local function center_core(world)
  local center_x = math.floor(world.width / 2)
  local center_y = math.floor(world.height / 2)
  world:seed_starting_core(center_x, center_y, 15, 11)
  return center_x, center_y
end

local function nearest_passable(world, origin_x, origin_y)
  local best_index
  local best_distance
  for index = 1, world.size do
    if world:is_passable(index) then
      local x, y = world:coordinates(index)
      local distance = math.abs(x - origin_x) + math.abs(y - origin_y)
      if not best_distance
        or distance < best_distance
        or (distance == best_distance and index < best_index)
      then
        best_index = index
        best_distance = distance
      end
    end
  end
  return best_index
end

local function choose_spawn(sim, job, center_x, center_y, spawns, usage)
  local department = JOB_DEPARTMENT[job] or "general"
  local job_id = job_content_id(job)
  local candidates = {}
  for index = 1, #(spawns or {}) do
    local spawn = spawns[index]
    if spawn.job == job_id or spawn.job == job then
      candidates[#candidates + 1] = spawn
    end
  end
  if #candidates == 0 then
    for index = 1, #(spawns or {}) do
      local spawn = spawns[index]
      if spawn.department == department then
        candidates[#candidates + 1] = spawn
      end
    end
  end
  if #candidates == 0 then
    for index = 1, #(spawns or {}) do
      local spawn = spawns[index]
      if (spawn.department or "general") == "general" then
        candidates[#candidates + 1] = spawn
      end
    end
  end
  if #candidates > 0 then
    local used = usage[job] or 0
    usage[job] = used + 1
    local selected = candidates[(used % #candidates) + 1]
    return selected.x, selected.y
  end
  return center_x + sim.rngs.crew:integer(-10, 10),
    center_y + sim.rngs.crew:integer(-7, 7)
end

local function spawn_crew(sim, count, center_x, center_y, spawns)
  local world = sim.world
  local spawn_usage = {}
  for i = 1, count do
    local job = Constants.JOBS[((i - 1) % #Constants.JOBS) + 1]
    local x, y = choose_spawn(
      sim,
      job,
      center_x,
      center_y,
      spawns,
      spawn_usage
    )
    local index = world:index(x, y)
    if not index or not world:is_passable(index) then
      index = assert(nearest_passable(world, x, y), "scenario has no passable spawn")
    end
    sim.crew[#sim.crew + 1] = {
      id = sim.next_entity_id,
      name = CREW_NAMES[((i - 1) % #CREW_NAMES) + 1] .. " " .. tostring(i),
      job = job,
      job_id = job_content_id(job),
      department = JOB_DEPARTMENT[job] or "general",
      access = Stable.deep_copy(JOB_ACCESS[job] or { "public" }),
      tools = Stable.deep_copy(JOB_TOOLS[job] or {}),
      remote_machine_access = false,
      silicon = false,
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

local function spawn_machines(sim, fixtures)
  for index = 1, #(fixtures or {}) do
    local fixture = fixtures[index]
    local machine = Machine.create(
      sim,
      fixture,
      sim.next_entity_id,
      index
    )
    sim.machines[#sim.machines + 1] = machine
    sim.next_entity_id = sim.next_entity_id + 1
  end
end

function Simulation.new(options)
  options = options or {}
  local seed = math.floor(options.seed or 1337)
  local content = options.content or { by_id = {}, by_kind = {}, ids = {} }
  local world
  local scenario_setup
  if options.scenario then
    world, scenario_setup = Scenario.instantiate(options.scenario, content)
  else
    world = World.new(
      options.width or Constants.DEFAULT_WORLD_WIDTH,
      options.height or Constants.DEFAULT_WORLD_HEIGHT
    )
  end
  local sim = setmetatable({
    schema_version = Constants.SCHEMA_VERSION,
    seed = seed,
    tick = 0,
    shift_index = 1,
    seconds_in_shift = 0,
    speed = 1,
    paused = false,
    machine_time_ds = 0,
    machine_wire_colors = Machine.wire_permutation(seed),
    world = world,
    crew = {},
    machines = {},
    tasks = {},
    next_entity_id = 1,
    next_task_id = 1,
    rngs = {
      crew = Rng.new(seed + 101),
      incidents = Rng.new(seed + 202),
      economy = Rng.new(seed + 303),
      machines = Rng.new(seed + 404),
    },
    commands = CommandQueue.new(),
    events = EventLog.new(),
    content = content,
    inventory = Stable.deep_copy(
      scenario_setup and scenario_setup.starting_inventory or {}
    ),
    scenario = {
      id = scenario_setup and scenario_setup.scenario_id
        or "org.simstation.core:scenario/bootstrap-contract",
      provenance = Stable.deep_copy(
        scenario_setup and scenario_setup.provenance or {}
      ),
      schema = scenario_setup and scenario_setup.scenario_schema or 1,
      map_format = scenario_setup and scenario_setup.map_format
        or "procedural-foundation-v1",
      meteor_targets = Stable.deep_copy(
        scenario_setup and scenario_setup.meteor_targets or {}
      ),
    },
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
      name = scenario_setup and scenario_setup.station_name or "NSS Bootstrap",
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
    grid_base_power_demand_w = 0,
    grid_base_power_served_w = 0,
    _machine_power_dirty = false,
  }, Simulation)

  local center_x, center_y
  if scenario_setup then
    center_x = math.floor(world.width / 2)
    center_y = math.floor(world.height / 2)
    spawn_machines(sim, scenario_setup.fixtures)
  else
    center_x, center_y = center_core(world)
  end
  spawn_crew(
    sim,
    options.crew_count or Constants.DEFAULT_CREW_COUNT,
    center_x,
    center_y,
    scenario_setup and scenario_setup.spawns or nil
  )
  sim:_step_power()
  sim.events:emit(0, "station_started", {
    station = sim.station.name,
    seed = seed,
    scenario = sim.scenario.id,
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

function Simulation:_machine_by_id(machine_id)
  for index = 1, #self.machines do
    if self.machines[index].id == machine_id
      or self.machines[index].scenario_fixture_id == machine_id
    then
      return self.machines[index]
    end
  end
  return nil
end

function Simulation:_crew_by_id(crew_id)
  for index = 1, #self.crew do
    if self.crew[index].id == crew_id then
      return self.crew[index]
    end
  end
  return nil
end

function Simulation:_recipe(recipe_id)
  local recipe = self.content
    and self.content.by_id
    and self.content.by_id[recipe_id]
  if not recipe or recipe.kind ~= "recipe" then
    return nil
  end
  return recipe
end

function Simulation:_allocate_machine_power()
  local ordered = Stable.sorted_values_by_id(self.machines)
  table.sort(ordered, function(a, b)
    local a_priority = Machine.power_priority(a)
    local b_priority = Machine.power_priority(b)
    if a_priority ~= b_priority then
      return a_priority < b_priority
    end
    return a.id < b.id
  end)

  local available = math.max(
    0,
    self.world.power_supply_w - self.grid_base_power_served_w
  )
  local machine_demand = 0
  local machine_served = 0
  for index = 1, #ordered do
    local machine = ordered[index]
    local request = Machine.power_request(machine)
    machine.requested_watts = request
    machine_demand = machine_demand + request
    local connected = Machine.is_connected(self, machine)
    local served = 0
    if connected and request <= available then
      served = request
      available = available - request
      machine_served = machine_served + request
    end
    Machine.set_power(machine, connected, served)
  end
  self.world.power_demand_w =
    self.grid_base_power_demand_w + machine_demand
  self.world.power_served_w =
    self.grid_base_power_served_w + machine_served
  self._machine_power_dirty = false
end

function Simulation:_step_power()
  self.world:step_power()
  self.grid_base_power_demand_w = self.world.power_demand_w
  self.grid_base_power_served_w = self.world.power_served_w
  self:_allocate_machine_power()
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

function Simulation:_queue_recipe(recipe_id, requested_machine_id)
  local recipe = self:_recipe(recipe_id)
  if not recipe then
    return false, "unknown recipe: " .. tostring(recipe_id)
  end
  local requested_machine = requested_machine_id
    and self:_machine_by_id(requested_machine_id)
    or nil
  if requested_machine_id and not requested_machine then
    return false, "unknown machine: " .. tostring(requested_machine_id)
  end
  local machine
  for index = 1, #self.machines do
    local candidate = self.machines[index]
    local selected = not requested_machine
      or candidate == requested_machine
    local candidate_priority =
      MACHINE_DEPARTMENT_PRIORITY[candidate.department] or 100
    local selected_priority = machine
        and (MACHINE_DEPARTMENT_PRIORITY[machine.department] or 100)
      or 101
    if selected
      and not candidate.destroyed
      and candidate.machine_tag == recipe.machine_tag
      and (
        not machine
        or candidate_priority < selected_priority
        or (
          candidate_priority == selected_priority
          and candidate.id < machine.id
        )
      )
    then
      machine = candidate
    end
  end
  if not machine then
    return false,
      "no compatible " .. tostring(recipe.machine_tag) .. " is available"
  end
  local ok, reason = Machine.queue_recipe(self, machine, recipe.id)
  if not ok then
    return false, type(reason) == "table"
      and tostring(reason.code)
      or tostring(reason)
  end
  return true
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
      local opened, reason = self.world:open_door(
        index,
        self.tick,
        "override",
        true
      )
      if not opened then
        return false, reason
      end
    elseif structure == Constants.STRUCTURE.DOOR_OPEN then
      local closed, reason = self.world:close_door(index)
      if not closed then
        return false, reason
      end
    else
      return false, "tile is not a door"
    end
    self:_emit("door_toggled", { x = payload.x, y = payload.y })
    return true
  elseif command.kind == "queue_recipe" then
    return self:_queue_recipe(payload.recipe_id, payload.machine_id)
  elseif command.kind == "machine_action" then
    local machine = self:_machine_by_id(payload.machine_id)
    if not machine then
      return false, "unknown machine: " .. tostring(payload.machine_id)
    end
    local actor = self:_crew_by_id(payload.actor_id)
    if not actor then
      return false, "actor-missing"
    end
    local request = {
      action_id = payload.action_id,
      actor_id = actor.id,
      machine_id = machine.id,
      parameters = Stable.deep_copy(payload.parameters or {}),
    }
    if self.hooks then
      local allowed, reason = self.hooks:validate(
        "org.simstation.core:hook/machine/action/validate",
        Stable.deep_copy(request),
        HookContext.new(self, {
          action = Stable.deep_copy(request),
          actor = Stable.deep_copy(actor),
          machine = Stable.deep_copy(machine),
        })
      )
      if not allowed then
        return false, reason or "rejected by a trusted mod"
      end
    end
    local ok, reason = Machine.perform(
      self,
      machine,
      payload.action_id,
      actor,
      payload.parameters or {}
    )
    if not ok then
      return false, type(reason) == "table"
        and tostring(reason.code)
        or tostring(reason)
    end
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
  if task.kind == "manufacturing" then
    local machine = sim:_machine_by_id(task.machine_id)
    if not machine or not machine.powered then
      return nil
    end
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
  elseif task.kind == "manufacturing" then
    if crew.job == "engineer" or crew.job == "cargo_technician" then
      qualification = 300
    elseif crew.job == "scientist" or crew.job == "assistant" then
      qualification = 100
    else
      qualification = -150
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
      and world:is_passable(index)
    then
      return index
    end
  end
  return nil
end

local function find_path_for_crew(sim, crew, target_index)
  return Pathfinding.find(
    sim.world,
    crew.index,
    target_index,
    math.min(sim.world.size, 16384),
    function(index)
      if sim.world.structure[index] == Constants.STRUCTURE.DOOR_CLOSED then
        return sim.world:can_open_door(index, crew.access)
      end
      return true
    end
  )
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
  local path = find_path_for_crew(self, crew, work_index)
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
      and find_path_for_crew(self, crew, work_index)
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
          and find_path_for_crew(self, crew, work_index)
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
          local opened, reason = self.world:open_door(
            next_index,
            self.tick,
            crew.access
          )
          if not opened then
            self:_release_task(crew, task, reason or "door unavailable")
            return
          end
        end
        crew.index = next_index
      end
      crew.move_cooldown = 3
    end
    return
  end

  if task.kind == "manufacturing" then
    local machine = self:_machine_by_id(task.machine_id)
    if not machine then
      task.state = "failed"
      self.metrics.failed_tasks = self.metrics.failed_tasks + 1
      crew.task_id = false
      crew.path = {}
      return
    end
    if not machine.powered then
      machine.state = "unpowered"
      return
    end
    machine.state = "working"
  end
  task.state = "executing"
  task.work_remaining = task.work_remaining - crew.work_skill
  crew.fatigue = Stable.clamp(crew.fatigue + 1, 0, 1000)
  if task.work_remaining <= 0 then
    if task.kind == "construction" then
      local completed, kind = self.world:complete_blueprint(task.target_index)
      if completed then
        task.state = "completed"
        self.metrics.completed_tasks = self.metrics.completed_tasks + 1
        self.metrics.construction_completed =
          self.metrics.construction_completed + 1
        self:_emit("construction_completed", {
          task_id = task.id,
          crew_id = crew.id,
          blueprint = kind,
        })
      else
        task.state = "failed"
        self.metrics.failed_tasks = self.metrics.failed_tasks + 1
      end
    elseif task.kind == "manufacturing" then
      local machine = self:_machine_by_id(task.machine_id)
      for output_index = 1, #(task.outputs or {}) do
        local output = task.outputs[output_index]
        self.inventory[output.id] = (self.inventory[output.id] or 0)
          + output.quantity
      end
      task.state = "completed"
      self.metrics.completed_tasks = self.metrics.completed_tasks + 1
      if machine then
        machine.task_id = false
        machine.recipe_id = false
        machine.state = "idle"
      end
      self:_step_power()
      self:_emit("manufacturing_completed", {
        task_id = task.id,
        crew_id = crew.id,
        machine_id = task.machine_id,
        recipe_id = task.recipe_id,
      })
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
  local occupied = {}
  for index = 1, #self.crew do
    if self.crew[index].alive then
      occupied[self.crew[index].index] = true
    end
  end
  self.world:step_doors(self.tick, occupied)
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
  local x, y
  local targets = self.scenario.meteor_targets or {}
  if #targets > 0 then
    local selected = self.rngs.incidents:integer(1, #targets)
    for offset = 0, #targets - 1 do
      local target = targets[((selected + offset - 1) % #targets) + 1]
      local target_index = self.world:index(target.x, target.y)
      if target_index
        and self.world.structure[target_index] == Constants.STRUCTURE.WALL
      then
        x, y = target.x, target.y
        break
      end
    end
  else
    local center_x = math.floor(self.world.width / 2)
    local center_y = math.floor(self.world.height / 2)
    local side = self.rngs.incidents:integer(1, 4)
    if side == 1 then
      x, y = center_x, center_y - 11
    elseif side == 2 then
      x, y = center_x + 15, center_y
    elseif side == 3 then
      x, y = center_x, center_y + 11
    else
      x, y = center_x - 15, center_y
    end
  end
  if not x or not self.world:make_breach(x, y) then
    self:_emit("meteor_missed", { forced = not not forced })
    return false
  end
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
  return true
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
  if self._machine_power_dirty then
    self:_allocate_machine_power()
  end
  self:_step_crew()

  if self.tick % Constants.GAS_STEP_TICKS == 0 then
    self.world:step_atmosphere()
  end
  if self.tick % Constants.POWER_STEP_TICKS == 0 then
    self:_step_power()
  end
  Machine.step_all(self, self.tick * 10)
  if self._machine_power_dirty then
    self:_allocate_machine_power()
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
    machines = self.machines,
    tasks = self.tasks,
    inventory = self.inventory,
    scenario = self.scenario,
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
    machine_time_ds = self.machine_time_ds,
    machine_wire_colors = Stable.deep_copy(self.machine_wire_colors),
    world = self.world:snapshot(),
    crew = Stable.deep_copy(self.crew),
    machines = Stable.deep_copy(self.machines),
    tasks = Stable.deep_copy(self.tasks),
    inventory = Stable.deep_copy(self.inventory),
    scenario = Stable.deep_copy(self.scenario),
    next_entity_id = self.next_entity_id,
    next_task_id = self.next_task_id,
    rngs = rngs,
    economy = Stable.deep_copy(self.economy),
    station = Stable.deep_copy(self.station),
    metrics = Stable.deep_copy(self.metrics),
    grid_base_power_demand_w = self.grid_base_power_demand_w,
    grid_base_power_served_w = self.grid_base_power_served_w,
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
    machine_time_ds = snapshot.machine_time_ds or snapshot.tick * 10,
    machine_wire_colors = Stable.deep_copy(
      snapshot.machine_wire_colors
        or Machine.wire_permutation(snapshot.seed)
    ),
    world = World.from_snapshot(snapshot.world),
    crew = Stable.deep_copy(snapshot.crew),
    machines = Stable.deep_copy(snapshot.machines or {}),
    tasks = Stable.deep_copy(snapshot.tasks),
    content = options.content or { by_id = {}, by_kind = {}, ids = {} },
    inventory = Stable.deep_copy(snapshot.inventory or {}),
    scenario = Stable.deep_copy(snapshot.scenario or {
      id = snapshot.world.map_id
        or "org.simstation.core:scenario/bootstrap-contract",
      schema = 1,
      map_format = "procedural-foundation-v1",
      provenance = {},
      meteor_targets = {},
    }),
    next_entity_id = snapshot.next_entity_id,
    next_task_id = snapshot.next_task_id,
    rngs = {
      crew = Rng.new(1),
      incidents = Rng.new(1),
      economy = Rng.new(1),
      machines = Rng.new(1),
    },
    economy = Stable.deep_copy(snapshot.economy),
    station = Stable.deep_copy(snapshot.station),
    metrics = Stable.deep_copy(snapshot.metrics),
    hooks = options.hooks or false,
    mod_state = Stable.deep_copy(snapshot.mod_state or {}),
    mod_diagnostics = {},
    grid_base_power_demand_w = snapshot.grid_base_power_demand_w
      or snapshot.world.power_demand_w
      or 0,
    grid_base_power_served_w = snapshot.grid_base_power_served_w
      or snapshot.world.power_served_w
      or 0,
    _machine_power_dirty = false,
    commands = CommandQueue.new(),
    events = EventLog.new(),
  }, Simulation)
  for name, rng_snapshot in pairs(snapshot.rngs or {}) do
    if not sim.rngs[name] then
      sim.rngs[name] = Rng.new(1)
    end
    sim.rngs[name]:restore(rng_snapshot)
  end
  for index = 1, #sim.machines do
    Machine.upgrade_instance(sim, sim.machines[index], index)
  end
  sim.commands.next_sequence = snapshot.commands.next_sequence
  sim.commands.pending = Stable.deep_copy(snapshot.commands.pending)
  sim.events.next_id = snapshot.events.next_id
  sim.events.values = Stable.deep_copy(snapshot.events.values)
  sim.last_state_hash = sim:state_hash()
  return sim
end

return Simulation
