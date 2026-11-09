--[[
  Data.lua
  Saved variables, defaults, profiles, and data migration (DESIGN 8.2).

  ForeverWeaponRackDB (account wide)
    dataVersion   number
    profiles      name -> profile table (global settings only, never sets)
    profileKeys   "Character - Realm" -> profile name

  ForeverWeaponRackCharDB (per character)
    dataVersion   number
    sets          id -> set (see Sets.lua for the layout)
    order         list of set ids; list order = cycle order for shared keys
    nextSetId     next free set id
    cycle         key -> id of the set that key equipped last (shared keys)
    toggle        Equipment Toggle memory { active = bool, items = slot -> ref }
    toggleKeyPerChar, toggleKey   optional per-character Equipment Toggle key

  Saved data carries a version number. When the layout changes, bump
  Data.VERSION and add a step to MIGRATIONS so old data is converted instead
  of wiped.
]]

local _, FWR = ...
local L = FWR.L
local Util = FWR.Util

local Data = {}
FWR.Data = Data

-- Current layout version. Version 0 means "no stamp" (new install).
Data.VERSION = 1

Data.DEFAULT_PROFILE = "Default"

local PROFILE_DEFAULTS = {
  window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 40,
             width = 660, height = 400, scale = 1 },
  locked = false,
  flyoutDelay = 0.35,       -- seconds before the hover flyout opens
  toggleKey = nil,          -- Equipment Toggle key (profile scope)
  minimap = { hide = false, angle = 215 },
}

local ACCOUNT_DEFAULTS = {
  profiles = {},
  profileKeys = {},
}

local CHAR_DEFAULTS = {
  sets = {},
  order = {},
  nextSetId = 1,
  cycle = {},
  toggle = { active = false, items = {} },
  toggleKeyPerChar = false,
  toggleKey = nil,
}

-- Copy missing keys from defaults into dst, recursively. Existing values win.
local function FillDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if dst[k] == nil then
      dst[k] = Util.CopyTable(v)
    elseif type(v) == "table" and type(dst[k]) == "table" then
      FillDefaults(dst[k], v)
    end
  end
end
Data.FillDefaults = FillDefaults

------------------------------------------------------------------------------
-- Migrations
-- MIGRATIONS.x[n] converts data from version n-1 to version n. Each step
-- must be safe to run on data that is already partly in the new shape.
------------------------------------------------------------------------------

local MIGRATIONS = {
  account = {
    -- 0 -> 1: first versioned layout. Nothing to convert; defaults fill gaps.
    [1] = function(db)
      if type(db.profiles) ~= "table" then db.profiles = {} end
      if type(db.profileKeys) ~= "table" then db.profileKeys = {} end
    end,
  },
  char = {
    -- 0 -> 1: first versioned layout.
    [1] = function(db)
      if type(db.sets) ~= "table" then db.sets = {} end
      if type(db.order) ~= "table" then db.order = {} end
    end,
  },
}
Data.MIGRATIONS = MIGRATIONS

-- Returns true if the data can be used, false if it is from a newer version.
function Data.Migrate(db, kind)
  local from = tonumber(db.dataVersion) or 0
  if from > Data.VERSION then
    return false, from
  end
  local steps = MIGRATIONS[kind]
  for version = from + 1, Data.VERSION do
    local step = steps[version]
    if step then step(db) end
    db.dataVersion = version
  end
  return true, from
end

------------------------------------------------------------------------------
-- Character data clean-up: keep order and sets consistent.
------------------------------------------------------------------------------

local SLOT_STATES = { item = true, empty = true, skip = true }

function Data.SanitizeChar(db)
  -- Drop broken sets and make sure every slot exists.
  for id, set in pairs(db.sets) do
    if type(set) ~= "table" or type(set.name) ~= "string" then
      db.sets[id] = nil
    else
      set.id = id
      set.slots = type(set.slots) == "table" and set.slots or {}
      for _, slotKey in ipairs(FWR.SLOT_ORDER) do
        local slot = set.slots[slotKey]
        if type(slot) ~= "table" or not SLOT_STATES[slot.state] then
          set.slots[slotKey] = { state = "skip" }
        elseif slot.item and type(slot.item) ~= "table" then
          slot.item = nil
        end
        -- An Item state with no remembered item can't do anything.
        if set.slots[slotKey].state == "item" and not set.slots[slotKey].item then
          set.slots[slotKey].state = "skip"
        end
      end
    end
  end
  -- Order: keep known ids once each, then append any set that was missing.
  local seen, order = {}, {}
  for _, id in ipairs(db.order) do
    if db.sets[id] and not seen[id] then
      seen[id] = true
      order[#order + 1] = id
    end
  end
  local missing = {}
  for id in pairs(db.sets) do
    if not seen[id] then missing[#missing + 1] = id end
  end
  table.sort(missing)
  for _, id in ipairs(missing) do order[#order + 1] = id end
  db.order = order
  -- Next id must be above every id in use.
  local maxId = 0
  for id in pairs(db.sets) do
    if type(id) == "number" and id > maxId then maxId = id end
  end
  if type(db.nextSetId) ~= "number" or db.nextSetId <= maxId then
    db.nextSetId = maxId + 1
  end
  -- Cycle memory must point at existing sets.
  for key, id in pairs(db.cycle) do
    if not db.sets[id] then db.cycle[key] = nil end
  end
end

------------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------------

function Data.CharKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Unknown"
  return name .. " - " .. realm
end

-- Called from ADDON_LOADED once the saved variables exist.
function Data:Load()
  -- Account data
  local db = _G.ForeverWeaponRackDB
  if type(db) ~= "table" then
    db = {}
    _G.ForeverWeaponRackDB = db
  end
  local ok, from = Data.Migrate(db, "account")
  if not ok then
    -- Newer data: use a throwaway copy so we never overwrite it.
    FWR:Warn(L.DATA_NEWER:format("account"))
    db = {}
  elseif from > 0 and from < Data.VERSION then
    FWR:Print(L.DATA_MIGRATED:format(Data.VERSION))
  end
  FillDefaults(db, ACCOUNT_DEFAULTS)
  self.db = db

  -- Character data
  local char = _G.ForeverWeaponRackCharDB
  if type(char) ~= "table" then
    char = {}
    _G.ForeverWeaponRackCharDB = char
  end
  local okChar = Data.Migrate(char, "char")
  if not okChar then
    FWR:Warn(L.DATA_NEWER:format("character"))
    char = {}
  end
  FillDefaults(char, CHAR_DEFAULTS)
  Data.SanitizeChar(char)
  self.char = char

  -- Profile
  self.charKey = Data.CharKey()
  local profileName = db.profileKeys[self.charKey]
  if type(profileName) ~= "string" or type(db.profiles[profileName]) ~= "table" then
    profileName = Data.DEFAULT_PROFILE
  end
  self:UseProfile(profileName, true)
end

------------------------------------------------------------------------------
-- Profiles (global settings only; DESIGN 8.2)
------------------------------------------------------------------------------

function Data:Profile()
  return self.profile
end

function Data:ProfileName()
  return self.profileName
end

function Data:ListProfiles()
  local names = {}
  for name in pairs(self.db.profiles) do names[#names + 1] = name end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

function Data:ProfileExists(name)
  return type(self.db.profiles[name]) == "table"
end

function Data:UseProfile(name, silent)
  if type(self.db.profiles[name]) ~= "table" then
    self.db.profiles[name] = {}
  end
  local profile = self.db.profiles[name]
  FillDefaults(profile, PROFILE_DEFAULTS)
  self.profile = profile
  self.profileName = name
  self.db.profileKeys[self.charKey] = name
  if not silent then
    FWR:Fire("PROFILE_CHANGED", name)
  end
end

-- New profile, copied from the current one (or defaults if copyCurrent=false).
function Data:NewProfile(name, copyCurrent)
  name = Util.Trim(name)
  if name == "" or self:ProfileExists(name) then return false end
  if copyCurrent and self.profile then
    self.db.profiles[name] = Util.CopyTable(self.profile)
  else
    self.db.profiles[name] = {}
  end
  self:UseProfile(name)
  return true
end

function Data:DeleteProfile(name)
  if name == Data.DEFAULT_PROFILE or name == self.profileName then return false end
  if not self:ProfileExists(name) then return false end
  self.db.profiles[name] = nil
  -- Characters that used it fall back to Default next time they log in.
  for charKey, profileName in pairs(self.db.profileKeys) do
    if profileName == name then self.db.profileKeys[charKey] = Data.DEFAULT_PROFILE end
  end
  return true
end

function Data:ResetProfile()
  local name = self.profileName
  self.db.profiles[name] = {}
  self:UseProfile(name)
end

------------------------------------------------------------------------------
-- Equipment Toggle key: profile scope, or per character if chosen.
------------------------------------------------------------------------------

function Data:GetToggleKey()
  if self.char.toggleKeyPerChar then
    return self.char.toggleKey
  end
  return self.profile.toggleKey
end

function Data:SetToggleKey(key)
  if self.char.toggleKeyPerChar then
    self.char.toggleKey = key
  else
    self.profile.toggleKey = key
  end
end

function Data:SetToggleKeyPerChar(perChar)
  perChar = perChar and true or false
  if self.char.toggleKeyPerChar == perChar then return end
  -- Carry the key over so switching scope doesn't silently drop it.
  local current = self:GetToggleKey()
  self.char.toggleKeyPerChar = perChar
  if perChar and not self.char.toggleKey then
    self.char.toggleKey = current
  end
end
