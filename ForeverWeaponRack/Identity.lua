--[[
  Identity.lua
  Scanning bags and equipped weapons, and telling copies of the same item
  apart (DESIGN 6.4):

    1. Full item: item id, enchant, random stats, gems and the rest of the
       item link (minus the parts that change on their own: player level and
       specialization).
    2. Temporary enchant as a tiebreaker (sharpening stones, poisons, ...).
       If the expected temp enchant wore off, the next-closest copy is used.
    3. Truly identical copies: a copy already in the target slot, then the
       first one by bag order, then a copy equipped in another slot.

  If no copy matches the full item, a copy of the same item with different
  enchants or gems is used as the closest match (decided with the user).
  The same check decides whether you're "already wearing" a set.

  Item references saved in sets look like:
    { id = itemID, link = itemLink, str = normalized item string, temp = name? }
]]

local _, FWR = ...
local API = FWR.API
local Item = FWR.Item
local Tooltip = FWR.Tooltip

local Identity = {}
FWR.Identity = Identity

------------------------------------------------------------------------------
-- Item strings
------------------------------------------------------------------------------

--[[
  Normalized item string: "item:id:enchant:gem1:..." with the fields that
  change without the item changing (link level, specialization) cleared, and
  zeros treated as empty so different link formats compare equal.
  Field positions (1 = "item"): 2 id, 3 enchant, 4-7 gems, 8 suffix,
  9 unique id, 10 link level, 11 specialization, then modifiers and bonuses.
]]
function Identity.ItemString(link)
  if type(link) ~= "string" then return nil end
  local s = link:match("item:[%-%d:]+")
  if not s then return nil end
  local fields = {}
  for field in (s .. ":"):gmatch("([^:]*):") do
    if field == "0" then field = "" end
    fields[#fields + 1] = field
  end
  fields[10] = ""
  fields[11] = ""
  while #fields > 2 and fields[#fields] == "" do
    fields[#fields] = nil
  end
  return table.concat(fields, ":")
end

------------------------------------------------------------------------------
-- Inventory scan
-- Entries (in scan order: equipped weapon slots, then bags in bag order):
--   key        "inv:16" or "bag:0:5"
--   where      "inv" or "bag"
--   inv        inventory slot id (inv only), slotKey set slot it's in
--   bag, slot  container position (bag only)
--   id, link, str, icon, quality, count, locked, isBound
--   equipLoc, classID, subclassID, itemLevel, name, order
------------------------------------------------------------------------------

local generation = 0
local scanCache

function Identity.Generation()
  return generation
end

-- Something in the bags or equipment changed.
function Identity.Invalidate()
  generation = generation + 1
  scanCache = nil
  FWR.Util.RunNextFrame("INVENTORY_CHANGED", function()
    FWR:Fire("INVENTORY_CHANGED")
  end)
end

local function MakeEntry(entries, base, link, id, icon, quality, count, locked, isBound)
  if not link then return end
  local basic = Item.Basic(link)
  if not basic or not Item.IsRelevant(basic.equipLoc) then return end
  local details = Item.Details(link)
  base.link = link
  base.id = id or basic.id
  base.str = Identity.ItemString(link)
  base.icon = icon or basic.icon
  base.quality = quality or details.quality
  base.count = count or 1
  base.locked = locked and true or false
  base.isBound = isBound
  base.equipLoc = basic.equipLoc
  base.classID = basic.classID
  base.subclassID = basic.subclassID
  base.itemLevel = details.itemLevel
  base.name = details.name
  base.order = #entries + 1
  entries[#entries + 1] = base
end

local function BagRange()
  local first = BACKPACK_CONTAINER or 0
  local last = NUM_BAG_SLOTS or 4
  return first, last
end

function Identity.Scan()
  if scanCache then return scanCache end
  local entries = {}
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    local invId = FWR.InvId(slotKey)
    local link = GetInventoryItemLink("player", invId)
    if link then
      MakeEntry(entries, { key = "inv:" .. invId, where = "inv", inv = invId, slotKey = slotKey },
        link, GetInventoryItemID("player", invId), GetInventoryItemTexture("player", invId),
        GetInventoryItemQuality("player", invId), GetInventoryItemCount("player", invId),
        IsInventoryItemLocked(invId), true)
    end
  end
  local first, last = BagRange()
  for bag = first, last do
    local numSlots = API.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = API.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink then
        MakeEntry(entries, { key = "bag:" .. bag .. ":" .. slot, where = "bag", bag = bag, slot = slot },
          info.hyperlink, info.itemID, info.iconFileID, info.quality, info.stackCount,
          info.isLocked, info.isBound)
      end
    end
  end
  scanCache = entries
  return entries
end

-- The entry currently equipped in a set slot, or nil.
function Identity.Equipped(slotKey)
  local invId = FWR.InvId(slotKey)
  for _, entry in ipairs(Identity.Scan()) do
    if entry.where == "inv" and entry.inv == invId then return entry end
  end
  return nil
end

function Identity.FindByKey(key)
  for _, entry in ipairs(Identity.Scan()) do
    if entry.key == key then return entry end
  end
  return nil
end

-- Find the entry for an exact location ({bag, slot} or {inv}).
function Identity.FindAt(bag, slot, inv)
  if inv then return Identity.FindByKey("inv:" .. inv) end
  return Identity.FindByKey("bag:" .. bag .. ":" .. slot)
end

------------------------------------------------------------------------------
-- Item references (what a set stores)
------------------------------------------------------------------------------

function Identity.MakeRef(entry)
  local ref = { id = entry.id, link = entry.link, str = entry.str }
  if entry.equipLoc ~= "INVTYPE_AMMO" then
    ref.temp = Tooltip.GetTempEnchant(entry)
  end
  return ref
end

function Identity.SameRef(a, b)
  if a == b then return true end
  if not a or not b then return false end
  return a.id == b.id and a.str == b.str and a.temp == b.temp
end

-- Is the item (by id) in the bank? Only true if bags/equipped don't have it.
function Identity.InBank(itemID)
  if not itemID or not API.GetItemCount then return false end
  local withBank = API.GetItemCount(itemID, true) or 0
  local without = API.GetItemCount(itemID, false) or 0
  return withBank > without
end

------------------------------------------------------------------------------
-- Effective slot state
-- Ammo is only used when the Ranged slot holds a bow, gun, or crossbow;
-- otherwise it's hidden and treated as Leave alone (decided with the user).
------------------------------------------------------------------------------

function Identity.AmmoApplies(slots)
  local ranged = slots.RANGED
  return ranged ~= nil and ranged.state == "item" and ranged.item ~= nil
    and Item.RangedAmmoType(ranged.item.id) ~= nil
end

function Identity.EffectiveState(slots, slotKey)
  local slot = slots[slotKey]
  if not slot then return "skip" end
  if slotKey == "AMMO" and not Identity.AmmoApplies(slots) then return "skip" end
  if slot.state == "item" and not slot.item then return "skip" end
  return slot.state
end

------------------------------------------------------------------------------
-- Resolution
------------------------------------------------------------------------------

-- Score one candidate copy for a saved reference. Higher is better.
local function Score(ref, entry, slotKey)
  local score = 0
  if ref.str and entry.str == ref.str then score = score + 8 end
  if ref.temp and Tooltip.GetTempEnchant(entry) == ref.temp then score = score + 4 end
  if entry.where == "inv" and entry.slotKey == slotKey then
    score = score + 2
  elseif entry.where == "bag" then
    score = score + 1
  end
  return score
end

-- Best copy of ref for slotKey, skipping copies already claimed by another
-- slot of the same set. Returns entry, isClosestMatch.
function Identity.BestCopy(ref, slotKey, claimed, entries)
  entries = entries or Identity.Scan()
  local best, bestScore
  for _, entry in ipairs(entries) do
    if entry.id == ref.id and entry.slotKey ~= "AMMO" and not (claimed and claimed[entry.key]) then
      local score = Score(ref, entry, slotKey)
      -- Strictly greater keeps the first entry (scan order) on ties.
      if not best or score > bestScore then
        best, bestScore = entry, score
      end
    end
  end
  local closest = best ~= nil and ref.str ~= nil and best.str ~= ref.str
  return best, closest
end

-- Ammo: equipped ammo of that id if any, else the first bag stack.
local function FindAmmo(ref, entries)
  local firstBag
  for _, entry in ipairs(entries) do
    if entry.id == ref.id then
      if entry.where == "inv" and entry.slotKey == "AMMO" then
        return entry
      end
      if entry.where == "bag" and not firstBag then firstBag = entry end
    end
  end
  return firstBag
end

--[[
  Identity.Resolve(slots) -> result
  result[slotKey] = {
    state   "item" | "empty" | "skip" (effective)
    ref     saved reference (item state)
    entry   inventory entry to use (item state), nil if missing
    missing true if no copy is in bags or equipped
    inBank  true if a missing item is in the bank
    closest true if the copy isn't an exact match
  }
]]
function Identity.Resolve(slots)
  local entries = Identity.Scan()
  local claimed = {}
  local result = {}
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    local state = Identity.EffectiveState(slots, slotKey)
    local r = { state = state }
    result[slotKey] = r
    if state == "item" then
      local ref = slots[slotKey].item
      r.ref = ref
      if slotKey == "AMMO" then
        r.entry = FindAmmo(ref, entries)
      else
        r.entry, r.closest = Identity.BestCopy(ref, slotKey, claimed, entries)
        if r.entry then claimed[r.entry.key] = true end
      end
      if not r.entry then
        r.missing = true
        r.inBank = Identity.InBank(ref.id)
      end
    end
  end
  return result
end

-- Is the resolved slot already satisfied by what's equipped?
function Identity.SlotSatisfied(slotKey, r)
  if r.state == "item" then
    if slotKey == "AMMO" then
      return r.ref ~= nil and GetInventoryItemID("player", FWR.InvId("AMMO")) == r.ref.id
    end
    return r.entry ~= nil and r.entry.where == "inv" and r.entry.slotKey == slotKey
  elseif r.state == "empty" then
    return GetInventoryItemID("player", FWR.InvId(slotKey)) == nil
  end
  return true
end

------------------------------------------------------------------------------
-- "Already wearing" (checkmarks, header warning, shared-key skip rule)
------------------------------------------------------------------------------

local wearingCache, wearingGeneration = {}, -1

function Identity.InvalidateWearing()
  wearingCache = {}
end

FWR:Listen("SETS_CHANGED", function() Identity.InvalidateWearing() end)

-- True if every slot that isn't Leave alone already matches. A set that is
-- all Leave alone is never "worn".
function Identity.IsWearingSlots(slots)
  local res = Identity.Resolve(slots)
  local any = false
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    local r = res[slotKey]
    if r.state ~= "skip" then
      any = true
      if not Identity.SlotSatisfied(slotKey, r) then return false end
    end
  end
  return any
end

function Identity.IsWearing(set)
  if not set then return false end
  if wearingGeneration ~= generation then
    wearingCache, wearingGeneration = {}, generation
  end
  local cached = wearingCache[set.id]
  if cached == nil then
    cached = Identity.IsWearingSlots(set.slots)
    wearingCache[set.id] = cached
  end
  return cached
end

------------------------------------------------------------------------------
-- Events that change the inventory
------------------------------------------------------------------------------

local function OnInventoryEvent()
  Identity.Invalidate()
end

FWR:RegisterEvent("BAG_UPDATE_DELAYED", OnInventoryEvent)
FWR:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", OnInventoryEvent)
FWR:RegisterEvent("UNIT_INVENTORY_CHANGED", OnInventoryEvent, "player")
FWR:RegisterEvent("WEAPON_ENCHANT_CHANGED", OnInventoryEvent)
FWR:RegisterEvent("PLAYER_ENTERING_WORLD", OnInventoryEvent)
-- Item names, quality and level can arrive later for uncached items.
FWR:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
  FWR.Util.RunNextFrame("ITEM_INFO", function() Identity.Invalidate() end)
end)
