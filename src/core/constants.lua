local Constants = {
  SCHEMA_VERSION = 1,
  SIM_HZ = 10,
  SHIFT_SECONDS = 8 * 60 * 60,
  TILE_SIZE = 32,
  CHUNK_SIZE = 16,
  DEFAULT_WORLD_WIDTH = 192,
  DEFAULT_WORLD_HEIGHT = 192,
  DEFAULT_CREW_COUNT = 24,
  MAX_EVENTS = 512,
  GAS_STEP_TICKS = 5,
  POWER_STEP_TICKS = 10,
  NEEDS_STEP_TICKS = 10,
  ECONOMY_STEP_TICKS = 60,
  INCIDENT_STEP_TICKS = 300,
  DOOR_AUTO_CLOSE_TICKS = 30,
  STANDARD_O2 = 21000,
  STANDARD_N2 = 79000,
  STANDARD_TEMPERATURE_MK = 293150,
  SPACE_TEMPERATURE_MK = 2700,
}

Constants.TILE = {
  SPACE = 0,
  FLOOR = 1,
}

-- Native turf semantics retain the interaction-relevant distinction that the
-- legacy gas grid deliberately collapses into SPACE/FLOOR.  Keep these dense
-- integer values stable: they are serialized in saves and hashed in replays.
Constants.TURF = {
  SPACE = 0,
  PLATING = 1,
  FLOOR = 2,
  REINFORCED_FLOOR = 3,
}

Constants.STRUCTURE = {
  EMPTY = 0,
  WALL = 1,
  DOOR_CLOSED = 2,
  DOOR_OPEN = 3,
}

Constants.WALL = {
  NONE = 0,
  STANDARD = 1,
  REINFORCED = 2,
}

-- A tile may contain several source objects (for example a window and grille).
-- Arithmetic bit tests are used instead of a Lua-version-specific bit library
-- so the same saves and behavior work under LuaJIT and stock Lua runtimes.
Constants.FEATURE = {
  WINDOW = 1,
  GRILLE = 2,
  TABLE = 4,
  CHAIR = 8,
  LIGHT = 16,
  STORAGE = 32,
  CRATE = 64,
  LATTICE = 128,
  CATWALK = 256,
  PIPE = 512,
  DISPOSAL = 1024,
  SIGN = 2048,
  DECAL = 4096,
}

Constants.BLUEPRINT = {
  FLOOR = "floor",
  WALL = "wall",
  CABLE = "cable",
  DOOR = "door",
}

Constants.JOBS = {
  "engineer",
  "cargo_technician",
  "doctor",
  "scientist",
  "security_officer",
  "botanist",
  "chef",
  "janitor",
  "assistant",
}

Constants.JOB_COLORS = {
  engineer = { 0.95, 0.70, 0.20 },
  cargo_technician = { 0.72, 0.48, 0.24 },
  doctor = { 0.35, 0.85, 0.95 },
  scientist = { 0.74, 0.45, 0.95 },
  security_officer = { 0.92, 0.28, 0.25 },
  botanist = { 0.38, 0.86, 0.36 },
  chef = { 0.95, 0.95, 0.95 },
  janitor = { 0.55, 0.38, 0.90 },
  assistant = { 0.65, 0.70, 0.72 },
}

return Constants
