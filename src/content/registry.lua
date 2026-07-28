local ContentId = require("src.content.id")
local Stable = require("src.core.stable")

local Registry = {}
Registry.__index = Registry

local function copy(value)
  return Stable.deep_copy(value)
end

function Registry.new()
  return setmetatable({
    definitions = {},
    owners = {},
    sources = {},
    replacement_history = {},
    load_order = {},
    sealed = false,
  }, Registry)
end

local function dependency_set(manifest)
  local result = {}
  for i = 1, #(manifest.dependencies or {}) do
    local dependency = manifest.dependencies[i]
    local id = type(dependency) == "table" and dependency.id or dependency
    result[id] = true
  end
  return result
end

function Registry:add_pack(manifest, documents, source_paths)
  assert(not self.sealed, "content registry is sealed")
  assert(type(manifest) == "table" and manifest.id, "manifest is required")
  local dependencies = dependency_set(manifest)
  local declared_replacements = {}
  for i = 1, #(manifest.replaces or {}) do
    declared_replacements[manifest.replaces[i]] = true
  end

  for document_index = 1, #documents do
    local document = documents[document_index]
    assert(type(document) == "table", "content document must be a table")
    local definitions = document.definitions or document
    assert(type(definitions) == "table", "definitions must be an array")
    for definition_index = 1, #definitions do
      local definition = definitions[definition_index]
      assert(type(definition) == "table", "definition must be an object")
      local parsed, id_error = ContentId.parse(definition.id)
      assert(parsed, id_error)
      assert(
        parsed.pack == manifest.id or definition.replaces,
        "new content ID must use its owning pack namespace"
      )
      assert(
        not definition.kind or definition.kind == parsed.kind,
        "definition kind must match its content ID"
      )

      local replacement = definition.replaces
      if replacement then
        assert(replacement == definition.id, "replacement must target its own ID")
        assert(declared_replacements[replacement],
          "replacement is not declared by the manifest")
        local current_owner = self.owners[replacement]
        assert(current_owner, "replacement target does not exist: " .. replacement)
        assert(dependencies[current_owner],
          "replacement requires a direct dependency on current owner")
        local current = self.definitions[replacement]
        local current_parsed = assert(ContentId.parse(current.id))
        assert(current_parsed.kind == parsed.kind, "replacement kind mismatch")
        self.replacement_history[#self.replacement_history + 1] = {
          id = replacement,
          from = current_owner,
          to = manifest.id,
        }
      else
        assert(not self.definitions[definition.id],
          "duplicate content ID: " .. definition.id)
      end

      self.definitions[definition.id] = copy(definition)
      self.owners[definition.id] = manifest.id
      self.sources[definition.id] = source_paths
        and source_paths[document_index]
        or ("document-" .. tostring(document_index))
    end
  end
  self.load_order[#self.load_order + 1] = manifest.id
end

function Registry:seal()
  self.sealed = true
  return self
end

function Registry:get(id)
  local value = self.definitions[id]
  return value and copy(value) or nil
end

function Registry:ids(kind)
  local result = {}
  for id in pairs(self.definitions) do
    local parsed = ContentId.parse(id)
    if not kind or parsed.kind == kind then
      result[#result + 1] = id
    end
  end
  table.sort(result)
  return result
end

function Registry:report()
  local counts = {}
  for id in pairs(self.definitions) do
    local parsed = assert(ContentId.parse(id))
    counts[parsed.kind] = (counts[parsed.kind] or 0) + 1
  end
  return {
    packs = copy(self.load_order),
    definition_count = #self:ids(),
    counts_by_kind = counts,
    replacements = copy(self.replacement_history),
  }
end

return Registry
