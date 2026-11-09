--[[
  Core.lua
  Shared namespace, event dispatch, internal messages, chat output, and small
  compatibility helpers. Every other file starts with

      local ADDON_NAME, FWR = ...

  and adds its own module table to FWR (FWR.Data, FWR.Sets, FWR.Swap, ...).
]]

local ADDON_NAME, FWR = ...

FWR.name = ADDON_NAME
FWR.title = "ForeverWeaponRack"

-- Expose the namespace so testers can inspect it with /dump ForeverWeaponRack.
_G.ForeverWeaponRack = FWR

local unpack, select, type, pairs, ipairs, tostring = unpack, select, type, pairs, ipairs, tostring

------------------------------------------------------------------------------
-- Safe calls: one broken handler must not stop the others from running.
------------------------------------------------------------------------------

local function SafeCall(fn, ...)
  local n, args = select("#", ...), { ... }
  return xpcall(function() return fn(unpack(args, 1, n)) end, geterrorhandler())
end
FWR.SafeCall = SafeCall

------------------------------------------------------------------------------
-- Game events
--   FWR:RegisterEvent("BAG_UPDATE_DELAYED", function(event, ...) end)
--   FWR:RegisterEvent("UNIT_SPELLCAST_STOP", fn, "player")  -- unit filtered
------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function FWR:RegisterEvent(event, fn, unit)
  local list = eventHandlers[event]
  if not list then
    list = {}
    eventHandlers[event] = list
    if unit then
      eventFrame:RegisterUnitEvent(event, unit)
    else
      eventFrame:RegisterEvent(event)
    end
  end
  list[#list + 1] = fn
end

function FWR:UnregisterEvent(event, fn)
  local list = eventHandlers[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == fn then table.remove(list, i) end
  end
  if #list == 0 then
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
  end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  -- Copy first so handlers can unregister themselves while we loop.
  local snapshot = { unpack(list) }
  for _, fn in ipairs(snapshot) do
    SafeCall(fn, event, ...)
  end
end)

------------------------------------------------------------------------------
-- Internal messages between modules (not game events)
--   FWR:Listen("SETS_CHANGED", fn)   FWR:Fire("SETS_CHANGED", ...)
--
-- Messages used:
--   SETS_CHANGED       a set was created, renamed, edited, moved or deleted
--   INVENTORY_CHANGED  bags or equipped weapons changed
--   QUEUE_CHANGED      the queued request or swap state changed
--   BINDINGS_CHANGED   a key binding changed or went live
--   PROFILE_CHANGED    the active profile changed
--   SETTINGS_CHANGED   a profile setting changed
------------------------------------------------------------------------------

local messageHandlers = {}

function FWR:Listen(message, fn)
  local list = messageHandlers[message]
  if not list then
    list = {}
    messageHandlers[message] = list
  end
  list[#list + 1] = fn
end

function FWR:Fire(message, ...)
  local list = messageHandlers[message]
  if not list then return end
  local snapshot = { unpack(list) }
  for _, fn in ipairs(snapshot) do
    SafeCall(fn, message, ...)
  end
end

------------------------------------------------------------------------------
-- Chat and error output
------------------------------------------------------------------------------

local PREFIX = "|cff4fc3f7ForeverWeaponRack|r: "

local function Join(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  return table.concat(parts, " ")
end

function FWR:Print(...)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. Join(...))
end

-- Yellow chat line for things the player should notice.
function FWR:Warn(...)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "|cffffd200" .. Join(...) .. "|r")
end

-- The game's red error text at the top of the screen.
function FWR:ErrorText(message)
  if not message or message == "" then return end
  if UIErrorsFrame then
    if UIErrorsFrame.AddExternalErrorMessage then
      UIErrorsFrame:AddExternalErrorMessage(message)
    else
      UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
    end
  end
end

-- Red error text plus a chat line, for swap warnings that need details.
function FWR:ErrorAndPrint(message, details)
  self:ErrorText(message)
  self:Warn(details or message)
end

------------------------------------------------------------------------------
-- Secret values
-- WoW Forever runs on a client with "secret values": some API results can be
-- hidden from add-ons (mostly in combat). A secret value can be stored and
-- passed around but not compared or read. Every value we read from tooltips
-- and similar sources goes through FWR.Readable() first.
------------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue

function FWR.IsSecret(value)
  if issecretvalue then
    return issecretvalue(value) and true or false
  end
  return false
end

-- Returns the value, or nil if it is secret.
function FWR.Readable(value)
  if issecretvalue and issecretvalue(value) then return nil end
  return value
end

------------------------------------------------------------------------------
-- API compatibility. Forever uses the modern API (C_Container, C_Item, ...).
-- The old globals are only a fallback in case something is missing.
------------------------------------------------------------------------------

local API = {}
FWR.API = API

local C_Container = _G.C_Container
local C_Item = _G.C_Item

local function pick(tbl, name, global)
  if tbl and tbl[name] then return tbl[name] end
  return _G[global or name]
end

API.PickupContainerItem = pick(C_Container, "PickupContainerItem")
API.GetContainerNumSlots = pick(C_Container, "GetContainerNumSlots")
API.GetContainerNumFreeSlots = pick(C_Container, "GetContainerNumFreeSlots")
API.GetContainerItemLink = pick(C_Container, "GetContainerItemLink")

API.GetItemInfo = pick(C_Item, "GetItemInfo")
API.GetItemInfoInstant = pick(C_Item, "GetItemInfoInstant")
API.GetItemCount = pick(C_Item, "GetItemCount")
API.IsEquippableItem = pick(C_Item, "IsEquippableItem")
API.GetDetailedItemLevelInfo = pick(C_Item, "GetDetailedItemLevelInfo")
API.GetItemStats = pick(C_Item, "GetItemStats")
API.RequestLoadItemDataByID = pick(C_Item, "RequestLoadItemDataByID")
API.GetAddOnMetadata = pick(_G.C_AddOns, "GetAddOnMetadata")

-- Always returns a table (or nil for an empty slot), whatever the API style.
function API.GetContainerItemInfo(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    return C_Container.GetContainerItemInfo(bag, slot)
  end
  if not _G.GetContainerItemInfo then return nil end
  local icon, count, locked, quality, _, _, link, _, _, itemID, isBound = _G.GetContainerItemInfo(bag, slot)
  if not icon then return nil end
  return {
    iconFileID = icon, stackCount = count, isLocked = locked, quality = quality,
    hyperlink = link, itemID = itemID, isBound = isBound,
  }
end

function API.GetItemQualityColor(quality)
  if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
    local c = ITEM_QUALITY_COLORS[quality]
    return c.r, c.g, c.b
  end
  if quality and C_Item and C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then return r, g, b end
  end
  return 1, 1, 1
end

-- The frame under the mouse. GetMouseFocus was replaced by GetMouseFoci.
function API.GetMouseFocus()
  if _G.GetMouseFoci then
    local foci = _G.GetMouseFoci()
    return foci and foci[1]
  end
  if _G.GetMouseFocus then return _G.GetMouseFocus() end
  return nil
end

function API.InCombat()
  return InCombatLockdown() and true or false
end

FWR.version = (API.GetAddOnMetadata and API.GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"

------------------------------------------------------------------------------
-- Slots
-- The four set slots, in equip order (DESIGN 6.1: Main Hand, Off Hand,
-- Ranged, Ammo). Slot ids and empty-slot textures come from the game.
------------------------------------------------------------------------------

FWR.SLOT_ORDER = { "MAINHAND", "OFFHAND", "RANGED", "AMMO" }

FWR.Slots = {
  MAINHAND = { key = "MAINHAND", invName = "MainHandSlot", fallbackId = 16,
               fallbackTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
  OFFHAND  = { key = "OFFHAND", invName = "SecondaryHandSlot", fallbackId = 17,
               fallbackTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
  RANGED   = { key = "RANGED", invName = "RangedSlot", fallbackId = 18,
               fallbackTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged" },
  AMMO     = { key = "AMMO", invName = "AmmoSlot", fallbackId = 0,
               fallbackTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ammo" },
}

-- Inventory slot id -> slot key, filled below.
FWR.SlotByInvId = {}

for _, key in ipairs(FWR.SLOT_ORDER) do
  local def = FWR.Slots[key]
  local ok, id, texture = pcall(GetInventorySlotInfo, def.invName)
  def.invId = (ok and type(id) == "number") and id or def.fallbackId
  def.emptyTexture = (ok and texture) or def.fallbackTexture
  FWR.SlotByInvId[def.invId] = key
end

function FWR.InvId(slotKey)
  return FWR.Slots[slotKey].invId
end

------------------------------------------------------------------------------
-- Small utilities
------------------------------------------------------------------------------

local Util = {}
FWR.Util = Util

function Util.CopyTable(src)
  if type(src) ~= "table" then return src end
  local dst = {}
  for k, v in pairs(src) do dst[k] = Util.CopyTable(v) end
  return dst
end

function Util.Trim(text)
  if type(text) ~= "string" then return "" end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Case-insensitive name key (DESIGN 4.3: "Tank" and "tank" are the same).
function Util.NameKey(text)
  return string.lower(Util.Trim(text))
end

-- Escape Lua pattern magic characters.
function Util.EscapePattern(text)
  return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

--[[
  Turn one of the game's format strings (for example
  BIND_TRADE_TIME_REMAINING) into a Lua pattern that matches any value in any
  language. %s and %d become captures, |4singular:plural; grammar codes and
  |cXXXXXXXX / |r color codes become wildcards.
]]
function Util.FormatToPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  local s = fmt
  -- Remove color codes; tooltip text usually has them stripped already.
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  -- Placeholder tokens that survive escaping.
  s = s:gsub("%%%%", "\004")             -- a literal percent sign
  s = s:gsub("|4[^;]*;", "\001")         -- singular/plural grammar code
  s = s:gsub("%%%d*%$?[sd]", "\002")     -- %s, %d, %1$s
  s = s:gsub("%%%.?%d*f", "\003")        -- %f, %.1f
  s = Util.EscapePattern(s)
  s = s:gsub("\001", ".-")
  s = s:gsub("\002", "(.-)")
  s = s:gsub("\003", "([%%d%%.,]+)")
  s = s:gsub("\004", "%%%%")
  return "^" .. s .. "$"
end

-- The longest piece of plain text in a format string, for loose matching.
function Util.LongestLiteral(fmt)
  if type(fmt) ~= "string" then return nil end
  local best = ""
  local s = fmt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|4[^;]*;", "\001")
  s = s:gsub("%%%d*%$?[sdf]", "\001"):gsub("%%%.%d+f", "\001")
  for piece in s:gmatch("[^\001]+") do
    piece = Util.Trim(piece)
    if #piece > #best then best = piece end
  end
  if best == "" then return nil end
  return best
end

-- Parse a localized number such as "7,5" or "12.25".
function Util.ParseNumber(text)
  if type(text) ~= "string" then return nil end
  local cleaned = text:gsub("%s", "")
  -- Treat a lone comma as the decimal separator (de, fr, ...).
  if cleaned:find(",") and not cleaned:find("%.") then
    cleaned = cleaned:gsub(",", ".")
  else
    cleaned = cleaned:gsub(",", "")
  end
  return tonumber(cleaned)
end

-- Run fn on the next frame, at most once per key, to merge bursts of events.
local pendingNextFrame = {}
function Util.RunNextFrame(key, fn)
  if pendingNextFrame[key] then return end
  pendingNextFrame[key] = true
  C_Timer.After(0, function()
    pendingNextFrame[key] = nil
    SafeCall(fn)
  end)
end
