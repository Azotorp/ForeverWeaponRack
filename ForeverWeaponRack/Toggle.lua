--[[
  Toggle.lua
  Equipment Toggle (DESIGN 5.4). One global key:
    - holding any weapon: unequip Main Hand, Off Hand and Ranged and
      remember exactly what was on (ammo and relics are left alone)
    - hands empty: put the remembered items back, in equip order
  The memory is saved per character, so it survives a reload or logout.
  If a remembered item was sold or banked, it re-equips what it can and
  warns about the rest.
]]

local _, FWR = ...
local L = FWR.L
local Item = FWR.Item
local Identity = FWR.Identity

local Toggle = {}
FWR.Toggle = Toggle

local HAND_SLOTS = { "MAINHAND", "OFFHAND", "RANGED" }

local function Memory()
  return FWR.Data.char.toggle
end

-- A relic in the Ranged slot doesn't count as a weapon.
local function CountsAsWeapon(slotKey, entry)
  if not entry then return false end
  if slotKey == "RANGED" and Item.IsRelic(entry.link) then return false end
  return true
end

function Toggle.HoldingWeapon()
  for _, slotKey in ipairs(HAND_SLOTS) do
    if CountsAsWeapon(slotKey, Identity.Equipped(slotKey)) then return true end
  end
  return false
end

function Toggle.HasMemory()
  local memory = Memory()
  return memory.active and next(memory.items) ~= nil
end

local function SkipAll()
  local slots = {}
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do slots[slotKey] = { state = "skip" } end
  return slots
end

-- Unequip the weapons you're holding and remember them.
function Toggle.Unequip(request)
  local items = {}
  for _, slotKey in ipairs(HAND_SLOTS) do
    local entry = Identity.Equipped(slotKey)
    if CountsAsWeapon(slotKey, entry) then
      items[slotKey] = Identity.MakeRef(entry)
    end
  end
  local job = {
    request = request,
    label = L.TOGGLE_NAME,
    desired = function()
      local desired = SkipAll()
      for slotKey in pairs(items) do desired[slotKey] = { state = "empty" } end
      return desired
    end,
    onFinish = function(success)
      if success then FWR:Print(L.TOGGLE_OFF) end
    end,
  }
  local started = FWR.Swap.StartJob(job, { allowMissing = true, confirmed = true })
  if started then
    -- Remember right away, so a reload mid-swap still knows what to put back.
    local memory = Memory()
    memory.active = true
    memory.items = items
  end
  return started
end

-- Put the remembered weapons back.
function Toggle.Reequip(request)
  local memory = Memory()
  if not Toggle.HasMemory() then
    FWR:Print(L.TOGGLE_NOTHING)
    return false
  end
  local items = memory.items
  local slots = SkipAll()
  for slotKey, ref in pairs(items) do
    slots[slotKey] = { state = "item", item = ref }
  end

  -- Warn about anything sold or banked; keep the memory if nothing is left.
  local resolved = Identity.Resolve(slots)
  local missing, found = {}, 0
  for slotKey in pairs(items) do
    local r = resolved[slotKey]
    if r.missing then
      local name = r.ref.link or tostring(r.ref.id)
      if r.inBank then name = L.SWAP_IN_BANK:format(name) end
      missing[#missing + 1] = name
    elseif r.state == "item" then
      found = found + 1
    end
  end
  if #missing > 0 then
    FWR:Warn(L.TOGGLE_MISSING:format(table.concat(missing, ", ")))
  end
  if found == 0 then return false end

  local job = {
    request = request,
    label = L.TOGGLE_NAME,
    desired = function() return Identity.Resolve(slots) end,
    onFinish = function(success)
      if success then
        memory.active = false
        memory.items = {}
        FWR:Print(L.TOGGLE_ON)
      end
    end,
  }
  return FWR.Swap.StartJob(job, { allowMissing = true, confirmed = true })
end

-- Called by Swap.Request for { kind = "toggle" }.
function Toggle.Run(request)
  Identity.Invalidate()
  if Toggle.HoldingWeapon() then
    return Toggle.Unequip(request)
  end
  return Toggle.Reequip(request)
end
