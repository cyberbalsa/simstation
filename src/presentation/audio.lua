local Constants = require("src.core.constants")
local AudioCatalog = require("src.assets.audio_catalog")

local Audio = {}
Audio.__index = Audio

local ALIAS_PRIORITY = {
  major_alert = 220,
  meteor = 210,
  medical_alert = 180,
  rejected = 140,
  shift_bell = 130,
  door_close = 90,
  door_open = 90,
  construction = 80,
  bailout = 75,
  station_chime = 70,
  ui_click = 30,
}

local ALIAS_COOLDOWN_MS = {
  major_alert = 1800,
  meteor = 400,
  medical_alert = 900,
  rejected = 500,
  shift_bell = 1500,
  door_close = 80,
  door_open = 80,
  construction = 250,
  bailout = 750,
  station_chime = 1000,
  ui_click = 60,
}

local ALIAS_MAX_INSTANCES = {
  major_alert = 1,
  meteor = 2,
  medical_alert = 1,
  rejected = 1,
  shift_bell = 1,
  construction = 2,
  bailout = 1,
  station_chime = 1,
  ui_click = 3,
}

local ALIAS_BUS = {
  major_alert = "alarms",
  medical_alert = "alarms",
  rejected = "ui",
  shift_bell = "ui",
  station_chime = "ui",
  ui_click = "ui",
}

local function decibels_to_gain(decibels)
  return 10 ^ ((tonumber(decibels) or 0) / 20)
end

function Audio.new()
  local catalog = AudioCatalog.new()
  return setmetatable({
    catalog = catalog,
    last_event_id = 0,
    last_tick = 0,
    voices = {},
    alias_counts = {},
    last_played = {},
    last_error = catalog.error,
    voice_limit = catalog.voice_limit > 0 and catalog.voice_limit or 32,
    buses = {
      master = 1,
      music = 0.65,
      ambience = 0.75,
      speech = 1,
      ui = 0.8,
      alarms = 1,
      machinery = 0.75,
      sfx = 0.9,
    },
  }, Audio)
end

function Audio:_remove_voice(index, stop)
  local voice = self.voices[index]
  if stop then
    pcall(voice.source.stop, voice.source)
  end
  local count = (self.alias_counts[voice.alias] or 1) - 1
  self.alias_counts[voice.alias] = count > 0 and count or nil
  table.remove(self.voices, index)
end

function Audio:_reap_finished()
  for i = #self.voices, 1, -1 do
    local voice = self.voices[i]
    local ok, playing = pcall(voice.source.isPlaying, voice.source)
    if not ok or not playing then
      self:_remove_voice(i, false)
    end
  end
end

function Audio:_make_voice_room(priority)
  if #self.voices < self.voice_limit then
    return true
  end
  local candidate_index = 1
  for i = 2, #self.voices do
    local candidate = self.voices[candidate_index]
    local voice = self.voices[i]
    if voice.priority < candidate.priority
      or (
        voice.priority == candidate.priority
        and voice.started_at < candidate.started_at
      )
    then
      candidate_index = i
    end
  end
  if self.voices[candidate_index].priority >= priority then
    return false
  end
  self:_remove_voice(candidate_index, true)
  return true
end

function Audio:_play(alias, now)
  local entry = self.catalog:entry(alias)
  if not entry then
    return false
  end
  local cooldown = (ALIAS_COOLDOWN_MS[alias] or entry.cooldown_ms or 0) / 1000
  local last_played = self.last_played[alias]
  if last_played and now - last_played < cooldown then
    return false
  end
  local maximum = math.min(
    tonumber(entry.max_instances) or 4,
    ALIAS_MAX_INSTANCES[alias] or math.huge
  )
  if (self.alias_counts[alias] or 0) >= maximum then
    return false
  end
  local priority = ALIAS_PRIORITY[alias] or tonumber(entry.priority) or 50
  if not self:_make_voice_room(priority) then
    return false
  end

  local source, source_entry = self.catalog:new_voice(alias)
  if not source then
    self.last_error = source_entry
    return false
  end
  local bus_name = ALIAS_BUS[alias] or source_entry.bus or "sfx"
  local volume = self.buses.master
    * (self.buses[bus_name] or 1)
    * decibels_to_gain(source_entry.gain_db)
  source:setVolume(math.max(0, math.min(1, volume)))
  local ok, played = pcall(source.play, source)
  if not ok or played == false then
    self.last_error = ok and "audio source refused playback" or played
    return false
  end
  self.voices[#self.voices + 1] = {
    alias = alias,
    source = source,
    priority = priority,
    started_at = now,
  }
  self.alias_counts[alias] = (self.alias_counts[alias] or 0) + 1
  self.last_played[alias] = now
  return true
end

function Audio:_door_alias(snapshot, payload)
  local world = snapshot.world
  local index = world:index(payload.x, payload.y)
  if index and world.structure[index] == Constants.STRUCTURE.DOOR_OPEN then
    return "door_open"
  end
  return "door_close"
end

function Audio:_handle_event(snapshot, event, now)
  local kind = event.kind
  if kind == "station_started" then
    self:_play("station_chime", now)
  elseif kind == "blueprint_placed" then
    self:_play("ui_click", now)
  elseif kind == "door_toggled" then
    self:_play(self:_door_alias(snapshot, event.payload), now)
  elseif kind == "construction_completed" then
    self:_play("construction", now)
  elseif kind == "manufacturing_queued" then
    self:_play("ui_click", now)
  elseif kind == "manufacturing_completed" then
    self:_play("construction", now)
  elseif kind == "command_rejected" then
    self:_play("rejected", now)
  elseif kind == "crew_incapacitated" then
    self:_play("medical_alert", now)
  elseif kind == "bailout_received" then
    self:_play("bailout", now)
  elseif kind == "shift_finished" then
    self:_play("shift_bell", now)
  elseif kind == "meteor_breach" then
    self:_play("meteor", now)
    self:_play("major_alert", now)
  end
end

function Audio:update(snapshot)
  local now = love.timer.getTime()
  self:_reap_finished()
  local events = snapshot.events

  -- Loading an older save resets the presentation cursor without replaying
  -- historical events. Authoritative event IDs and simulation state are never
  -- modified by audio.
  if snapshot.tick < self.last_tick then
    self.last_event_id = #events > 0 and events[#events].id or 0
  else
    for i = 1, #events do
      local event = events[i]
      if event.id > self.last_event_id then
        self:_handle_event(snapshot, event, now)
        self.last_event_id = event.id
      end
    end
  end
  self.last_tick = snapshot.tick
end

return Audio
