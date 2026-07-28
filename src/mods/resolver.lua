local Semver = require("src.mods.semver")

local Resolver = {}

local function copy_array(values)
  local result = {}
  for i = 1, #(values or {}) do
    result[i] = values[i]
  end
  return result
end

local function dependency_record(value)
  if type(value) == "string" then
    return { id = value, version = "*" }
  elseif type(value) == "table"
    and type(value.id) == "string"
    and type(value.version or "*") == "string"
  then
    return { id = value.id, version = value.version or "*" }
  end
  return nil, "dependency must contain an ID and version constraint"
end

local function normalize_records(values, label)
  local result = {}
  for i = 1, #(values or {}) do
    local record, err = dependency_record(values[i])
    if not record then
      return nil, label .. " " .. tostring(i) .. ": " .. err
    end
    result[#result + 1] = record
  end
  table.sort(result, function(a, b)
    if a.id ~= b.id then
      return a.id < b.id
    end
    return a.version < b.version
  end)
  return result
end

local function valid_pack_id(value)
  if type(value) ~= "string"
    or #value > 160
    or not value:find(".", 1, true)
    or value:sub(1, 1) == "."
    or value:sub(-1) == "."
    or value:find("..", 1, true)
  then
    return false
  end
  local count = 0
  for component in value:gmatch("[^.]+") do
    count = count + 1
    if not component:match("^[a-z0-9][a-z0-9-]*$") then
      return false
    end
  end
  return count >= 2
end

local function normalize_manifest(manifest)
  if type(manifest) ~= "table" then
    return nil, "mod manifest must be a table"
  end
  if not valid_pack_id(manifest.id) then
    return nil, "invalid reverse-DNS mod ID: " .. tostring(manifest.id)
  end
  local version, version_error = Semver.parse(manifest.version)
  if not version then
    return nil, "mod " .. manifest.id .. " has invalid version: " .. version_error
  end
  local dependencies, dependencies_error = normalize_records(
    manifest.dependencies,
    "dependency"
  )
  if not dependencies then
    return nil, dependencies_error
  end
  local optional, optional_error = normalize_records(
    manifest.optional_dependencies,
    "optional dependency"
  )
  if not optional then
    return nil, optional_error
  end
  local conflicts, conflicts_error = normalize_records(manifest.conflicts, "conflict")
  if not conflicts then
    return nil, conflicts_error
  end
  local priority = tonumber(manifest.load_priority or 0)
  if not priority or priority % 1 ~= 0 or priority < -1000 or priority > 1000 then
    return nil, "mod " .. manifest.id .. " has invalid load_priority"
  end
  return {
    source = manifest,
    id = manifest.id,
    version = manifest.version,
    parsed_version = version,
    api = manifest.api or "*",
    dependencies = dependencies,
    optional_dependencies = optional,
    conflicts = conflicts,
    load_after = copy_array(manifest.load_after),
    load_before = copy_array(manifest.load_before),
    load_priority = priority,
    package_sha256 = manifest.package_sha256 or "",
  }
end

local function compatible(candidate, constraint)
  local ok, err = Semver.satisfies(candidate.version, constraint)
  if ok == nil then
    return nil, err
  end
  return ok
end

local function add_edge(edges, indegree, from, to)
  if from == to then
    return nil, "mod cannot order itself: " .. from
  end
  edges[from] = edges[from] or {}
  if not edges[from][to] then
    edges[from][to] = true
    indegree[to] = indegree[to] + 1
  end
  return true
end

local function order_less(left, right)
  if left.load_priority ~= right.load_priority then
    return left.load_priority < right.load_priority
  end
  if left.id ~= right.id then
    return left.id < right.id
  end
  return left.package_sha256 < right.package_sha256
end

local function sorted_targets(values)
  local result = {}
  for value in pairs(values or {}) do
    result[#result + 1] = value
  end
  table.sort(result)
  return result
end

local function find_cycle(by_id, edges)
  local states = {}
  local path = {}
  local function visit(id)
    if states[id] == "visiting" then
      local start = 1
      while path[start] ~= id do
        start = start + 1
      end
      local cycle = {}
      for i = start, #path do
        cycle[#cycle + 1] = path[i]
      end
      cycle[#cycle + 1] = id
      return cycle
    elseif states[id] == "done" then
      return nil
    end
    states[id] = "visiting"
    path[#path + 1] = id
    local targets = sorted_targets(edges[id])
    for i = 1, #targets do
      local cycle = visit(targets[i])
      if cycle then
        return cycle
      end
    end
    path[#path] = nil
    states[id] = "done"
    return nil
  end
  local ids = {}
  for id in pairs(by_id) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  for i = 1, #ids do
    local cycle = visit(ids[i])
    if cycle then
      return cycle
    end
  end
end

function Resolver.resolve(manifests, options)
  options = options or {}
  local by_id = {}
  local normalized = {}
  for i = 1, #manifests do
    local candidate, err = normalize_manifest(manifests[i])
    if not candidate then
      return nil, err
    end
    if by_id[candidate.id] then
      return nil, "duplicate mod ID: " .. candidate.id
    end
    by_id[candidate.id] = candidate
    normalized[#normalized + 1] = candidate
  end
  table.sort(normalized, order_less)

  local edges = {}
  local indegree = {}
  local phases = {}
  for id in pairs(by_id) do
    edges[id] = {}
    indegree[id] = 0
    phases[id] = 0
  end

  for i = 1, #normalized do
    local candidate = normalized[i]
    if options.api_version and candidate.api ~= "*" then
      local allowed, err = Semver.satisfies(options.api_version, candidate.api)
      if allowed == nil then
        return nil, "mod " .. candidate.id .. " has invalid API constraint: " .. err
      elseif not allowed then
        return nil, string.format(
          "mod %s requires API %s; runtime is %s",
          candidate.id,
          candidate.api,
          options.api_version
        )
      end
    end

    for j = 1, #candidate.dependencies do
      local dependency = candidate.dependencies[j]
      local target = by_id[dependency.id]
      if not target then
        return nil, string.format(
          "mod %s requires missing dependency %s",
          candidate.id,
          dependency.id
        )
      end
      local allowed, err = compatible(target, dependency.version)
      if allowed == nil then
        return nil, "invalid dependency constraint: " .. err
      elseif not allowed then
        return nil, string.format(
          "mod %s requires %s %s; enabled version is %s",
          candidate.id,
          dependency.id,
          dependency.version,
          target.version
        )
      end
      local ok, edge_error = add_edge(edges, indegree, target.id, candidate.id)
      if not ok then
        return nil, edge_error
      end
    end

    for j = 1, #candidate.optional_dependencies do
      local dependency = candidate.optional_dependencies[j]
      local target = by_id[dependency.id]
      if target then
        local allowed, err = compatible(target, dependency.version)
        if allowed == nil then
          return nil, "invalid optional dependency constraint: " .. err
        elseif allowed then
          local ok, edge_error = add_edge(edges, indegree, target.id, candidate.id)
          if not ok then
            return nil, edge_error
          end
        end
      end
    end

    for j = 1, #candidate.conflicts do
      local conflict = candidate.conflicts[j]
      local target = by_id[conflict.id]
      if target then
        local matches, err = compatible(target, conflict.version)
        if matches == nil then
          return nil, "invalid conflict constraint: " .. err
        elseif matches then
          return nil, string.format(
            "mod %s conflicts with %s %s",
            candidate.id,
            conflict.id,
            conflict.version
          )
        end
      end
    end

    for j = 1, #candidate.load_after do
      local target = candidate.load_after[j]
      if by_id[target] then
        local ok, edge_error = add_edge(edges, indegree, target, candidate.id)
        if not ok then
          return nil, edge_error
        end
      end
    end
    for j = 1, #candidate.load_before do
      local target = candidate.load_before[j]
      if by_id[target] then
        local ok, edge_error = add_edge(edges, indegree, candidate.id, target)
        if not ok then
          return nil, edge_error
        end
      end
    end
  end

  local ready = {}
  for id, count in pairs(indegree) do
    if count == 0 then
      ready[#ready + 1] = by_id[id]
    end
  end
  table.sort(ready, order_less)
  local result = {}
  while #ready > 0 do
    local candidate = table.remove(ready, 1)
    local source = candidate.source
    source.dependency_phase = phases[candidate.id]
    result[#result + 1] = source
    local targets = sorted_targets(edges[candidate.id])
    for i = 1, #targets do
      local target_id = targets[i]
      phases[target_id] = math.max(phases[target_id], phases[candidate.id] + 1)
      indegree[target_id] = indegree[target_id] - 1
      if indegree[target_id] == 0 then
        ready[#ready + 1] = by_id[target_id]
        table.sort(ready, order_less)
      end
    end
  end
  if #result ~= #normalized then
    local cycle = find_cycle(by_id, edges) or { "unknown" }
    return nil, "mod dependency cycle: " .. table.concat(cycle, " -> ")
  end
  return result
end

return Resolver
