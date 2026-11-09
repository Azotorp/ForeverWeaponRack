--[[
  ItemInfo.lua
  What an item is and where it can go:
    - which set slot it fits (DESIGN 3.1), with the two-hander redirect (3.3)
    - ranged weapon ammo type and ammo type (3.3)
    - usability, using the game's own checks (3.3, 7)
    - flyout sort order (4.5)
    - best ammo by damage per second, then item level (3.3)

  Everything is keyed off GetItemInfoInstant (always available, even for
  items not cached yet) and GetItemInfo (may return nil until cached).
]]

local _, FWR = ...
local API = FWR.API
local L = FWR.L

local Item = {}
FWR.Item = Item

------------------------------------------------------------------------------
-- Item class and subclass ids (Enum names with numeric fallbacks)
------------------------------------------------------------------------------

local ItemClass = (Enum and Enum.ItemClass) or {}
local WeaponSub = (Enum and Enum.ItemWeaponSubclass) or {}
local ArmorSub = (Enum and Enum.ItemArmorSubclass) or {}

Item.CLASS_WEAPON = ItemClass.Weapon or 2
Item.CLASS_ARMOR = ItemClass.Armor or 4
Item.CLASS_PROJECTILE = ItemClass.Projectile or 6

local W = {
  AXE1H = WeaponSub.Axe1H or 0,
  AXE2H = WeaponSub.Axe2H or 1,
  BOWS = WeaponSub.Bows or 2,
  GUNS = WeaponSub.Guns or 3,
  MACE1H = WeaponSub.Mace1H or 4,
  MACE2H = WeaponSub.Mace2H or 5,
  POLEARM = WeaponSub.Polearm or 6,
  SWORD1H = WeaponSub.Sword1H or 7,
  SWORD2H = WeaponSub.Sword2H or 8,
  WARGLAIVE = WeaponSub.Warglaive or 9,
  STAFF = WeaponSub.Staff or 10,
  FIST = WeaponSub.Unarmed or 13,
  GENERIC = WeaponSub.Generic or 14,
  DAGGER = WeaponSub.Dagger or 15,
  THROWN = WeaponSub.Thrown or 16,
  CROSSBOW = WeaponSub.Crossbow or 18,
  WAND = WeaponSub.Wand or 19,
  FISHINGPOLE = WeaponSub.Fishingpole or 20,
}
Item.W = W

local A = {
  SHIELD = ArmorSub.Shield or 6,
  LIBRAM = ArmorSub.Libram or 7,
  IDOL = ArmorSub.Idol or 8,
  TOTEM = ArmorSub.Totem or 9,
  SIGIL = ArmorSub.Sigil or 10,
  RELIC = ArmorSub.Relic or 11,
}
Item.A = A

-- Projectile subclasses (Classic): 2 = Arrow, 3 = Bullet.
local PROJECTILE_ARROW, PROJECTILE_BULLET = 2, 3

------------------------------------------------------------------------------
-- Equip locations accepted by each set slot
------------------------------------------------------------------------------

local SLOT_LOCS = {
  MAINHAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true },
  OFFHAND  = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true,
               INVTYPE_HOLDABLE = true },
  RANGED   = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
               INVTYPE_RELIC = true },
  AMMO     = { INVTYPE_AMMO = true },
}
Item.SLOT_LOCS = SLOT_LOCS

-- Every equip location we care about (used to skip other items in bags).
local ANY_LOC = {}
for _, locs in pairs(SLOT_LOCS) do
  for loc in pairs(locs) do ANY_LOC[loc] = true end
end
-- Two-handers dropped on the Off Hand are accepted (and moved to Main Hand).
ANY_LOC.INVTYPE_2HWEAPON = true

------------------------------------------------------------------------------
-- Basic info
------------------------------------------------------------------------------

-- itemInfo: item id, link, or item string. Returns a small table or nil.
function Item.Basic(itemInfo)
  if not itemInfo then return nil end
  local id, _, _, equipLoc, icon, classID, subclassID = API.GetItemInfoInstant(itemInfo)
  if not id then return nil end
  return { id = id, equipLoc = equipLoc, icon = icon, classID = classID, subclassID = subclassID }
end

-- Name, quality, item level, required level, bind type. Fields may be nil
-- if the item isn't cached yet; the item cache event refreshes the UI later.
function Item.Details(itemInfo)
  if not itemInfo then return {} end
  local name, link, quality, itemLevel, minLevel, _, _, _, _, _, _, _, _, bindType =
    API.GetItemInfo(itemInfo)
  if not name and API.RequestLoadItemDataByID then
    local id = API.GetItemInfoInstant(itemInfo)
    if id then API.RequestLoadItemDataByID(id) end
  end
  local level = itemLevel
  if API.GetDetailedItemLevelInfo and type(itemInfo) == "string" then
    local actual = API.GetDetailedItemLevelInfo(itemInfo)
    if actual then level = actual end
  end
  return { name = name, link = link, quality = quality, itemLevel = level,
           minLevel = minLevel, bindType = bindType }
end

function Item.IsRelevant(equipLoc)
  return equipLoc ~= nil and ANY_LOC[equipLoc] == true
end

function Item.IsTwoHand(itemInfo)
  local b = Item.Basic(itemInfo)
  return b ~= nil and b.equipLoc == "INVTYPE_2HWEAPON"
end

function Item.IsRelic(itemInfo)
  local b = Item.Basic(itemInfo)
  if not b then return false end
  if b.equipLoc == "INVTYPE_RELIC" then return true end
  if b.classID == Item.CLASS_ARMOR then
    local s = b.subclassID
    return s == A.LIBRAM or s == A.IDOL or s == A.TOTEM or s == A.SIGIL or s == A.RELIC
  end
  return false
end

-- "ARROW" for bows and crossbows, "BULLET" for guns, nil for anything else
-- (wands, thrown weapons, relics). DESIGN 3.3.
function Item.RangedAmmoType(itemInfo)
  local b = Item.Basic(itemInfo)
  if not b or b.classID ~= Item.CLASS_WEAPON then return nil end
  if b.subclassID == W.BOWS or b.subclassID == W.CROSSBOW then return "ARROW" end
  if b.subclassID == W.GUNS then return "BULLET" end
  return nil
end

-- "ARROW" or "BULLET" for ammo items, nil otherwise.
function Item.AmmoType(itemInfo)
  local b = Item.Basic(itemInfo)
  if not b then return nil end
  if b.classID == Item.CLASS_PROJECTILE or b.equipLoc == "INVTYPE_AMMO" then
    if b.subclassID == PROJECTILE_ARROW then return "ARROW" end
    if b.subclassID == PROJECTILE_BULLET then return "BULLET" end
  end
  return nil
end

------------------------------------------------------------------------------
-- Slot fit
------------------------------------------------------------------------------

local function CanDualWieldNow()
  if _G.CanDualWield then return _G.CanDualWield() and true or false end
  return true -- unknown: let the game decide when equipping
end

--[[
  Item.FitsSlot(itemInfo, slotKey) -> ok, targetSlotKey, errorText
  A two-hander dropped on the Off Hand fits, with targetSlotKey = "MAINHAND".
]]
function Item.FitsSlot(itemInfo, slotKey)
  local b = Item.Basic(itemInfo)
  if not b then return false, nil, L.ERR_WRONG_SLOT end
  local loc = b.equipLoc
  if slotKey == "OFFHAND" then
    if loc == "INVTYPE_2HWEAPON" then return true, "MAINHAND" end
    if loc == "INVTYPE_WEAPON" and not CanDualWieldNow() then
      return false, nil, L.ERR_CANT_DUAL_WIELD
    end
  end
  local locs = SLOT_LOCS[slotKey]
  if locs and locs[loc] then return true, slotKey end
  return false, nil, L.ERR_WRONG_SLOT
end

------------------------------------------------------------------------------
-- Usability: the game's own checks (DESIGN 3.3 "Only usable items", 7).
--   1. the game says the item type can be equipped at all
--   2. required level
--   3. C_PlayerInfo.CanUseItem (class, race, skill), when the API exists
--   4. red restriction lines in the item's tooltip (class, untrained weapon
--      skill, level, reputation), which is exactly what the game shows
-- Returns ok, errorText. entry may be an inventory entry (Identity.lua) or a
-- link; tooltip lines are read for the exact copy when we have a location.
------------------------------------------------------------------------------

function Item.CheckUsable(entryOrLink)
  local link = type(entryOrLink) == "table" and entryOrLink.link or entryOrLink
  if not link then return false, L.ERR_NOT_EQUIPPABLE end

  if API.IsEquippableItem and not API.IsEquippableItem(link) then
    return false, L.ERR_NOT_EQUIPPABLE
  end

  local details = Item.Details(link)
  local playerLevel = UnitLevel("player") or 0
  if details.minLevel and details.minLevel > playerLevel then
    return false, L.ERR_LEVEL:format(details.minLevel)
  end

  local restriction = FWR.Tooltip.FindRestriction(entryOrLink)
  if restriction == "level" then
    return false, L.ERR_LEVEL:format(details.minLevel or 0)
  elseif restriction == "class" then
    return false, L.ERR_NEVER
  elseif restriction then
    return false, L.ERR_PROFICIENCY
  end

  local id = API.GetItemInfoInstant(link)
  if id and C_PlayerInfo and C_PlayerInfo.CanUseItem then
    local ok, usable = pcall(C_PlayerInfo.CanUseItem, id)
    if ok and usable == false then
      return false, L.ERR_PROFICIENCY
    end
  end

  return true
end

------------------------------------------------------------------------------
-- Flyout sort order (DESIGN 4.5): grouped by type, then highest item level,
-- then quality. One-handers first (daggers, fist weapons, swords, axes,
-- maces), then two-handers (swords, axes, maces, polearms, staves).
------------------------------------------------------------------------------

local WEAPON_GROUP = {
  -- one-handers
  [W.DAGGER] = 1, [W.FIST] = 2, [W.SWORD1H] = 3, [W.AXE1H] = 4, [W.MACE1H] = 5,
  [W.WARGLAIVE] = 6, [W.GENERIC] = 7,
  -- two-handers
  [W.SWORD2H] = 11, [W.AXE2H] = 12, [W.MACE2H] = 13, [W.POLEARM] = 14, [W.STAFF] = 15,
  [W.FISHINGPOLE] = 19,
  -- ranged
  [W.BOWS] = 31, [W.CROSSBOW] = 32, [W.GUNS] = 33, [W.THROWN] = 34, [W.WAND] = 35,
}

-- Lower numbers sort first.
function Item.SortGroup(itemInfo)
  local b = Item.Basic(itemInfo)
  if not b then return 99 end
  if b.classID == Item.CLASS_WEAPON then
    return WEAPON_GROUP[b.subclassID] or (b.equipLoc == "INVTYPE_2HWEAPON" and 18 or 8)
  end
  if b.equipLoc == "INVTYPE_SHIELD" then return 21 end
  if b.equipLoc == "INVTYPE_HOLDABLE" then return 22 end
  if Item.IsRelic(itemInfo) then return 40 end
  if b.equipLoc == "INVTYPE_AMMO" then return 50 end
  return 90
end

-- Comparator for inventory entries (Identity.lua entries).
function Item.CompareEntries(a, b)
  local ga, gb = Item.SortGroup(a.link), Item.SortGroup(b.link)
  if ga ~= gb then return ga < gb end
  -- Ammo: damage per second first (DESIGN 3.3)
  if ga == 50 then
    local da, db = Item.AmmoDPS(a.link) or 0, Item.AmmoDPS(b.link) or 0
    if da ~= db then return da > db end
  end
  local la, lb = a.itemLevel or 0, b.itemLevel or 0
  if la ~= lb then return la > lb end
  local qa, qb = a.quality or 0, b.quality or 0
  if qa ~= qb then return qa > qb end
  local na, nb = a.name or "", b.name or ""
  if na ~= nb then return na < nb end
  return (a.order or 0) < (b.order or 0)
end

------------------------------------------------------------------------------
-- Ammo: damage per second, cached by item id
------------------------------------------------------------------------------

local ammoDPSCache = {}

function Item.AmmoDPS(itemInfo)
  local b = Item.Basic(itemInfo)
  if not b then return nil end
  local cached = ammoDPSCache[b.id]
  if cached ~= nil then return cached or nil end
  local dps = FWR.Tooltip.ReadAmmoDPS(type(itemInfo) == "string" and itemInfo or ("item:" .. b.id))
  if not dps and API.GetItemStats then
    local ok, stats = pcall(API.GetItemStats, type(itemInfo) == "string" and itemInfo or ("item:" .. b.id))
    if ok and type(stats) == "table" then
      dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
    end
  end
  -- Only cache real answers; item data may arrive later.
  if dps then ammoDPSCache[b.id] = dps end
  return dps
end

-- Best owned ammo of a type: highest damage per second, then item level.
-- Returns an inventory entry from Identity.Scan() or nil.
function Item.BestAmmo(ammoType)
  if not ammoType then return nil end
  local best
  for _, entry in ipairs(FWR.Identity.Scan()) do
    if entry.where == "bag" and Item.AmmoType(entry.link) == ammoType
        and Item.CheckUsable(entry) then
      if not best then
        best = entry
      else
        local da, db = Item.AmmoDPS(entry.link) or 0, Item.AmmoDPS(best.link) or 0
        if da > db or (da == db and (entry.itemLevel or 0) > (best.itemLevel or 0)) then
          best = entry
        end
      end
    end
  end
  return best
end
