local Pathfinding = {}

local function less(a, b)
  if a.f ~= b.f then
    return a.f < b.f
  end
  if a.h ~= b.h then
    return a.h < b.h
  end
  return a.index < b.index
end

local function heap_push(heap, node)
  local index = #heap + 1
  heap[index] = node
  while index > 1 do
    local parent = math.floor(index / 2)
    if not less(node, heap[parent]) then
      break
    end
    heap[index] = heap[parent]
    index = parent
  end
  heap[index] = node
end

local function heap_pop(heap)
  local root = heap[1]
  local last = heap[#heap]
  heap[#heap] = nil
  if #heap == 0 then
    return root
  end
  local index = 1
  while true do
    local left = index * 2
    if left > #heap then
      break
    end
    local right = left + 1
    local child = left
    if right <= #heap and less(heap[right], heap[left]) then
      child = right
    end
    if not less(heap[child], last) then
      break
    end
    heap[index] = heap[child]
    index = child
  end
  heap[index] = last
  return root
end

local function heuristic(world, from_index, to_index)
  local from_x, from_y = world:coordinates(from_index)
  local to_x, to_y = world:coordinates(to_index)
  return math.abs(from_x - to_x) + math.abs(from_y - to_y)
end

local function walkable(world, index)
  if not index or world.tile[index] == 0 then
    return false
  end
  return world.structure[index] ~= 1
end

function Pathfinding.find(world, start_index, target_index, maximum_nodes)
  maximum_nodes = maximum_nodes or 4096
  if start_index == target_index then
    return {}
  end
  if not walkable(world, target_index) then
    return nil, "target is not walkable"
  end

  local open = {}
  local best_g = { [start_index] = 0 }
  local came_from = {}
  local closed = {}
  local start_h = heuristic(world, start_index, target_index)
  heap_push(open, {
    index = start_index,
    g = 0,
    h = start_h,
    f = start_h,
  })

  local expanded = 0
  while #open > 0 and expanded < maximum_nodes do
    local current = heap_pop(open)
    if not closed[current.index] and current.g == best_g[current.index] then
      if current.index == target_index then
        local reverse = {}
        local cursor = target_index
        while cursor ~= start_index do
          reverse[#reverse + 1] = cursor
          cursor = came_from[cursor]
        end
        local path = {}
        for i = #reverse, 1, -1 do
          path[#path + 1] = reverse[i]
        end
        return path
      end

      closed[current.index] = true
      expanded = expanded + 1
      local x, y = world:coordinates(current.index)
      -- This fixed order is part of the deterministic pathfinding contract.
      local neighbors = {
        world:index(x, y - 1),
        world:index(x - 1, y),
        world:index(x + 1, y),
        world:index(x, y + 1),
      }
      for i = 1, 4 do
        local neighbor = neighbors[i]
        if walkable(world, neighbor) and not closed[neighbor] then
          local pressure = world:pressure_dkpa(neighbor)
          local hazard = pressure < 500 and 50 or 0
          hazard = hazard + world.fire[neighbor] * 100
          local tentative = current.g + 10 + hazard
          if not best_g[neighbor] or tentative < best_g[neighbor] then
            best_g[neighbor] = tentative
            came_from[neighbor] = current.index
            local h = heuristic(world, neighbor, target_index) * 10
            heap_push(open, {
              index = neighbor,
              g = tentative,
              h = h,
              f = tentative + h,
            })
          end
        end
      end
    end
  end
  return nil, "no path within node budget"
end

return Pathfinding
