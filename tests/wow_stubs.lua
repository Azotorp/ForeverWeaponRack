--[[
  tests/wow_stubs.lua
  A tiny fake WoW client for running ForeverWeaponRack logic under plain
  Lua 5.1 (no UI). It simulates:
    - frames (no-op), events, C_Timer
    - an item database, bags, equipped weapon slots, and the cursor
      (PickupContainerItem / PickupInventoryItem) closely enough to test the
      swap engine end to end
  It is NOT a WoW emulator. It only exists to catch logic errors.
]]

local S = {}           -- simulator state and helpers, returned to tests
_G.STUB = S

------------------------------------------------------------------------------
-- Basics
------------------------------------------------------------------------------

S.time = 1000
S.timers = {}
S.events = {}          -- registered event frames
S.errors = {}
S.uiErrors = {}
S.chat = {}
S.combat = false
S.dead = false
S.casting = false
S.playerLevel = 60
S.canDualWield = true

function _G.geterrorhandler()
  return function(err)
    S.errors[#S.errors + 1] = err
    io.stderr:write("ERROR: " .. tostring(err) .. "\n" .. debug.traceback() .. "\n")
  end
end

function _G.GetTime() return S.time end
_G.date = os.date
function _G.wipe(t) for k in pairs(t) do t[k] = nil end return t end
function _G.hooksecurefunc() end
function _G.InCombatLockdown() return S.combat end
function _G.UnitIsDeadOrGhost() return S.dead end
function _G.UnitCastingInfo() if S.casting then return "Spell" end return nil end
function _G.UnitChannelInfo() return nil end
function _G.UnitName() return "Tester" end
function _G.GetRealmName() return "Realm" end
function _G.UnitLevel() return S.playerLevel end
function _G.CanDualWield() return S.canDualWield end
function _G.GetLocale() return "enUS" end
function _G.CursorHasItem() return S.cursor ~= nil end
function _G.ClearCursor() S.cursor = nil end
function _G.GetCursorInfo() if S.cursor then return "item", S.cursor.item.id, S.cursor.item.link end end

_G.C_Timer = {
  After = function(delay, fn) S.timers[#S.timers + 1] = { at = S.time + delay, fn = fn } end,
  NewTimer = function(delay, fn)
    local t = { at = S.time + delay, fn = fn, cancelled = false }
    t.Cancel = function(self) self.cancelled = true end
    t.IsCancelled = function(self) return self.cancelled end
    S.timers[#S.timers + 1] = t
    return t
  end,
}

-- Run timers that are due (repeat until none left at this time).
function S.RunTimers(advance)
  S.time = S.time + (advance or 0)
  for _ = 1, 50 do
    local due, rest = {}, {}
    for _, t in ipairs(S.timers) do
      if t.at <= S.time then due[#due + 1] = t else rest[#rest + 1] = t end
    end
    S.timers = rest
    if #due == 0 then return end
    for _, t in ipairs(due) do
      if not t.cancelled then t.fn(t) end
    end
  end
end

------------------------------------------------------------------------------
-- Frames: everything is a no-op except event registration and scripts.
------------------------------------------------------------------------------

local frameMeta = {}
frameMeta.__index = function(self, key)
  local v = rawget(frameMeta, key)
  if v then return v end
  -- Internal fields and add-on fields stay nil; unknown methods are no-ops.
  if type(key) == "string" and (key:sub(1, 2) == "__" or key:sub(1, 3) == "fwr" or key:match("^%l")) then
    return nil
  end
  return function() return nil end
end
local function NewObject(parent, name)
  return setmetatable({ __events = {}, __scripts = {}, __shown = true, __name = name, __parent = parent,
                        __text = nil, __w = 100, __h = 20, __enabled = true, __checked = false }, frameMeta)
end
function frameMeta.RegisterEvent(self, event) self.__events[event] = true; S.events[self] = true end
function frameMeta.RegisterUnitEvent(self, event) self.__events[event] = true; S.events[self] = true end
function frameMeta.UnregisterEvent(self, event) self.__events[event] = nil end
function frameMeta.SetScript(self, name, fn) self.__scripts[name] = fn end
function frameMeta.GetScript(self, name) return self.__scripts[name] end
function frameMeta.HookScript(self, name, fn)
  local old = self.__scripts[name]
  self.__scripts[name] = function(...) if old then old(...) end fn(...) end
end
function frameMeta.IsShown(self) return self.__shown end
function frameMeta.IsVisible(self)
  local f = self
  while f do
    if not f.__shown then return false end
    f = f.__parent
  end
  return true
end
function frameMeta.Show(self)
  local was = self.__shown
  self.__shown = true
  if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function frameMeta.Hide(self)
  local was = self.__shown
  self.__shown = false
  if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function frameMeta.SetShown(self, show) if show then self:Show() else self:Hide() end end
function frameMeta.GetName(self) return self.__name end
function frameMeta.GetParent(self) return self.__parent end
function frameMeta.CreateTexture(self) return NewObject(self) end
function frameMeta.CreateFontString(self) return NewObject(self) end
function frameMeta.SetText(self, t) self.__text = t end
function frameMeta.GetText(self) return self.__text end
function frameMeta.SetChecked(self, v) self.__checked = v and true or false end
function frameMeta.GetChecked(self) return self.__checked end
function frameMeta.SetEnabled(self, v) self.__enabled = v and true or false end
function frameMeta.Enable(self) self.__enabled = true end
function frameMeta.Disable(self) self.__enabled = false end
function frameMeta.IsEnabled(self) return self.__enabled end
function frameMeta.SetSize(self, w, h) self.__w, self.__h = w, h end
function frameMeta.SetWidth(self, w) self.__w = w end
function frameMeta.SetHeight(self, h) self.__h = h end
function frameMeta.GetWidth(self) return self.__w end
function frameMeta.GetHeight(self) return self.__h end
function frameMeta.GetStringHeight() return 14 end
function frameMeta.GetEffectiveScale() return 1 end
function frameMeta.GetScale() return 1 end
function frameMeta.GetRight() return 300 end
function frameMeta.GetLeft() return 200 end
function frameMeta.GetTop() return 500 end
function frameMeta.GetBottom() return 400 end
function frameMeta.GetCenter() return 250, 450 end
function frameMeta.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function frameMeta.IsMouseOver(self) return self.__mouseOver or false end
function frameMeta.HasFocus() return false end
function frameMeta.NumLines() return 0 end
function frameMeta.GetTextColor() return 1, 1, 1 end
function frameMeta.Click(self, button, down)
  if self.__scripts.OnClick then self.__scripts.OnClick(self, button or "LeftButton", down) end
end

function _G.CreateFrame(_, name, parent)
  local f = NewObject(parent, name)
  if name then _G[name] = f end
  return f
end

-- Fire a game event at every frame that registered it.
function S.Fire(event, ...)
  for frame in pairs(S.events) do
    if frame.__events[event] and frame.__scripts.OnEvent then
      frame.__scripts.OnEvent(frame, event, ...)
    end
  end
end

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) S.chat[#S.chat + 1] = msg end }
_G.UIErrorsFrame = { AddMessage = function(_, msg) S.uiErrors[#S.uiErrors + 1] = msg end }
_G.UIParent = CreateFrame("Frame")
_G.WorldFrame = CreateFrame("Frame")
_G.Minimap = CreateFrame("Frame")
_G.GameTooltip = CreateFrame("GameTooltip")
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.tinsert = table.insert
_G.ChatFontNormal = {}
function _G.GetBuildInfo() return "1.60.0", "99999", "Nov 1 2026", 16001 end
function _G.GetCursorPosition() return 500, 500 end
function _G.GetBindingText(key) return key end
function _G.IsModifiedClick() return false end
function _G.IsAltKeyDown() return false end
function _G.IsControlKeyDown() return false end
function _G.IsShiftKeyDown() return S.shift or false end
function _G.GetMinimapShape() return "ROUND" end

------------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------------

S.items = {}   -- id -> { name, equipLoc, classID, subclassID, quality, ilvl, minLevel, bindType, ammoDPS }

function S.DefineItem(id, def)
  def.id = id
  def.quality = def.quality or 2
  def.ilvl = def.ilvl or 50
  def.minLevel = def.minLevel or 1
  def.bindType = def.bindType or 1
  S.items[id] = def
end

-- A link with an optional enchant id, e.g. S.Link(100, 1900).
function S.Link(id, enchant)
  local def = S.items[id]
  return ("|cff1eff00|Hitem:%d:%s::::::::60:::::|h[%s]|h|r"):format(id, enchant and tostring(enchant) or "", def.name)
end

local function IdFrom(itemInfo)
  if type(itemInfo) == "number" then return itemInfo end
  if type(itemInfo) == "string" then
    return tonumber(itemInfo:match("item:(%d+)")) or tonumber(itemInfo)
  end
end

function _G.GetItemInfoInstant(itemInfo)
  local id = IdFrom(itemInfo)
  local def = id and S.items[id]
  if not def then return nil end
  return id, "Weapon", "Sub", def.equipLoc, 1000 + id, def.classID, def.subclassID
end

function _G.GetItemInfo(itemInfo)
  local id = IdFrom(itemInfo)
  local def = id and S.items[id]
  if not def then return nil end
  return def.name, S.Link(id), def.quality, def.ilvl, def.minLevel, "Weapon", "Sub", 1,
    def.equipLoc, 1000 + id, 0, def.classID, def.subclassID, def.bindType
end

function _G.IsEquippableItem(itemInfo)
  local id = IdFrom(itemInfo)
  return id and S.items[id] and S.items[id].equipLoc ~= nil and S.items[id].equipLoc ~= ""
end

------------------------------------------------------------------------------
-- Inventory: equipped slots and bags
------------------------------------------------------------------------------

S.equipped = {}           -- invId -> { id, link, count }
S.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
S.bagSizes = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
S.bankCounts = {}         -- id -> count in bank
S.cursor = nil            -- { item = {...}, from = { bag, slot } | { inv } }
S.log = {}                -- move log

function S.Item(id, enchant, count)
  return { id = id, link = S.Link(id, enchant), count = count or 1 }
end

function S.Reset()
  S.equipped = {}
  S.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  S.bagSizes = { [0] = 16, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
  S.bankCounts = {}
  S.cursor = nil
  S.log = {}
  S.combat, S.dead, S.casting = false, false, false
  S.uiErrors, S.chat = {}, {}
end

function _G.GetInventorySlotInfo(name)
  local map = { MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, AmmoSlot = 0 }
  return map[name], "Interface\\PaperDoll\\" .. name
end
function _G.GetInventoryItemLink(_, inv) return S.equipped[inv] and S.equipped[inv].link end
function _G.GetInventoryItemID(_, inv) return S.equipped[inv] and S.equipped[inv].id end
function _G.GetInventoryItemTexture(_, inv) return S.equipped[inv] and (1000 + S.equipped[inv].id) end
function _G.GetInventoryItemQuality(_, inv) return S.equipped[inv] and S.items[S.equipped[inv].id].quality end
function _G.GetInventoryItemCount(_, inv) return S.equipped[inv] and 1 or 0 end
function _G.IsInventoryItemLocked() return false end

_G.C_Container = {
  GetContainerNumSlots = function(bag) return S.bagSizes[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local it = S.bags[bag] and S.bags[bag][slot]
    if not it then return nil end
    return { itemID = it.id, hyperlink = it.link, iconFileID = 1000 + it.id,
             quality = S.items[it.id].quality, stackCount = it.count, isLocked = false,
             isBound = it.bound or false }
  end,
  GetContainerNumFreeSlots = function(bag)
    local free = 0
    for slot = 1, S.bagSizes[bag] or 0 do
      if not S.bags[bag][slot] then free = free + 1 end
    end
    return free, 0
  end,
  GetContainerItemLink = function(bag, slot)
    local it = S.bags[bag] and S.bags[bag][slot]
    return it and it.link
  end,
}

_G.C_Item = {
  GetItemCount = function(itemInfo, includeBank)
    local id = IdFrom(itemInfo)
    local n = 0
    for _, it in pairs(S.equipped) do if it.id == id then n = n + it.count end end
    for bag, slots in pairs(S.bags) do
      for _, it in pairs(slots) do if it.id == id then n = n + it.count end end
    end
    if includeBank then n = n + (S.bankCounts[id] or 0) end
    return n
  end,
}

-- Can this item go in this inventory slot?
local function Fits(item, inv)
  local loc = S.items[item.id].equipLoc
  if inv == 16 then return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND" or loc == "INVTYPE_2HWEAPON" end
  if inv == 17 then return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" end
  if inv == 18 then return loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_THROWN" or loc == "INVTYPE_RELIC" end
  if inv == 0 then return loc == "INVTYPE_AMMO" end
  return false
end

local function FirstFreeBagSlot(except)
  for bag = 0, 4 do
    for slot = 1, S.bagSizes[bag] or 0 do
      if not S.bags[bag][slot] and not (except and except.bag == bag and except.slot == slot) then
        return bag, slot
      end
    end
  end
end

local function Get(loc)
  if loc.inv then return S.equipped[loc.inv] end
  return S.bags[loc.bag][loc.slot]
end
local function Set(loc, item)
  if loc.inv then S.equipped[loc.inv] = item else S.bags[loc.bag][loc.slot] = item end
end

local function Fail(msg)
  S.uiErrors[#S.uiErrors + 1] = msg
  S.cursor = nil   -- item goes back
end

-- Put the cursor item into a location, swapping with what's there.
local function Drop(dest)
  local held = S.cursor
  local src = held.from
  if dest.inv ~= nil then
    if dest.inv == 0 then
      -- Ammo: the slot just references the item; nothing leaves the bags.
      if not Fits(held.item, 0) then return Fail("wrong slot") end
      S.equipped[0] = { id = held.item.id, link = held.item.link, count = 1, ammoRef = true }
      S.cursor = nil
      S.log[#S.log + 1] = "ammo<-" .. held.item.id
      return
    end
    if not Fits(held.item, dest.inv) then return Fail("wrong slot") end
    if S.combat and S.blockCombat then
      Fail("combat")
      S.Fire("ADDON_ACTION_BLOCKED", "ForeverWeaponRack", "PickupInventoryItem()")
      return
    end
    local old
    -- 2H into MH pushes the off hand into the bags.
    if dest.inv == 16 and S.items[held.item.id].equipLoc == "INVTYPE_2HWEAPON" and S.equipped[17]
        and not (src.inv == 17) then
      local b, s = FirstFreeBagSlot(src.bag and src or nil)
      if not b then return Fail("Inventory is full.") end
      S.bags[b][s] = S.equipped[17]
      S.equipped[17] = nil
    end
    -- Off hand while wearing a 2H pushes the 2H into the bags.
    if dest.inv == 17 and S.equipped[16] and S.items[S.equipped[16].id].equipLoc == "INVTYPE_2HWEAPON" then
      local b, s = FirstFreeBagSlot(src.bag and src or nil)
      if not b then return Fail("Inventory is full.") end
      S.bags[b][s] = S.equipped[16]
      S.equipped[16] = nil
    end
    old = Get(dest)
    if old and src.inv and not Fits(old, src.inv) then return Fail("can't swap") end
    Set(src, old)
    Set(dest, held.item)
    S.cursor = nil
    S.log[#S.log + 1] = ("%s->%s"):format(src.inv and ("inv" .. src.inv) or ("bag" .. src.bag .. ":" .. src.slot),
      "inv" .. dest.inv)
  else
    local old = Get(dest)
    if old and src.inv and not Fits(old, src.inv) then return Fail("can't swap") end
    Set(src, old)
    Set(dest, held.item)
    S.cursor = nil
    S.log[#S.log + 1] = ("%s->bag%d:%d"):format(src.inv and ("inv" .. src.inv) or ("bag" .. src.bag .. ":" .. src.slot),
      dest.bag, dest.slot)
  end
end

C_Container.PickupContainerItem = function(bag, slot)
  local loc = { bag = bag, slot = slot }
  if S.cursor then
    Drop(loc)
  else
    local it = Get(loc)
    if it then S.cursor = { item = it, from = loc } end
  end
end

function _G.PickupInventoryItem(inv)
  local loc = { inv = inv }
  if S.cursor then
    Drop(loc)
  else
    local it = Get(loc)
    if it then
      if inv == 0 then
        -- TODO-sim: picking up ammo; treat as clearing the ammo slot on drop
        S.cursor = { item = it, from = loc, ammo = true }
      else
        S.cursor = { item = it, from = loc }
      end
    end
  end
end

------------------------------------------------------------------------------
-- Tooltips (only what the add-on reads)
------------------------------------------------------------------------------

S.tempEnchants = {}   -- "bag:b:s" or "inv:n" -> name
_G.C_TooltipInfo = {
  GetBagItem = function(bag, slot)
    local it = S.bags[bag][slot]
    if not it then return nil end
    local lines = { { leftText = S.items[it.id].name } }
    local temp = S.tempEnchants["bag:" .. bag .. ":" .. slot]
    if temp then lines[#lines + 1] = { leftText = temp .. " (30 min)" } end
    return { lines = lines }
  end,
  GetInventoryItem = function(_, inv)
    local it = S.equipped[inv]
    if not it then return nil end
    local lines = { { leftText = S.items[it.id].name } }
    local temp = S.tempEnchants["inv:" .. inv]
    if temp then lines[#lines + 1] = { leftText = temp .. " (30 min)" } end
    return { lines = lines }
  end,
  GetHyperlink = function(link)
    local id = IdFrom(link)
    local def = S.items[id]
    if not def then return nil end
    local lines = { { leftText = def.name } }
    if def.ammoDPS then lines[#lines + 1] = { leftText = ("Adds %s damage per second"):format(def.ammoDPS) } end
    return { lines = lines }
  end,
}

-- Global strings the add-on reads
_G.ITEM_ENCHANT_TIME_LEFT_MIN = "%s (%d min)"
_G.ITEM_ENCHANT_TIME_LEFT_HOURS = "%s (%d |4hour:hrs;)"
_G.ITEM_ENCHANT_TIME_LEFT_SEC = "%s (%d sec)"
_G.BIND_TRADE_TIME_REMAINING = "You may trade this item with players that were also eligible to loot this item for the next %s."
_G.ITEM_BIND_ON_EQUIP = "Binds when equipped"
_G.DURABILITY_TEMPLATE = "Durability %d / %d"
_G.AMMO_DAMAGE_TEMPLATE = "Adds %s damage per second"
_G.ITEM_MIN_LEVEL = "Requires Level %d"
_G.ITEM_CLASSES_ALLOWED = "Classes: %s"
_G.BACKPACK_CONTAINER = 0
_G.NUM_BAG_SLOTS = 4
_G.Enum = {
  ItemClass = { Weapon = 2, Armor = 4, Projectile = 6 },
  ItemWeaponSubclass = { Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5, Polearm = 6,
    Sword1H = 7, Sword2H = 8, Staff = 10, Unarmed = 13, Dagger = 15, Thrown = 16, Crossbow = 18,
    Wand = 19, Fishingpole = 20 },
  ItemArmorSubclass = { Shield = 6, Libram = 7, Idol = 8, Totem = 9 },
  ItemBind = { OnEquip = 2 },
  TooltipDataLineType = { ItemBinding = 20, TradeTimeRemaining = 36 },
  TooltipDataItemBinding = { BindOnEquip = 7 },
}

------------------------------------------------------------------------------
-- Loading the add-on files in .toc order
------------------------------------------------------------------------------

function S.LoadAddon(root, files)
  local ns = {}
  for _, file in ipairs(files) do
    local chunk, err = loadfile(root .. "/" .. file)
    if not chunk then error(err) end
    chunk("ForeverWeaponRack", ns)
  end
  return ns
end

-- Settle: run timers and fire the inventory events the client would send.
function S.Settle()
  S.Fire("ITEM_LOCK_CHANGED")
  S.Fire("PLAYER_EQUIPMENT_CHANGED")
  S.Fire("BAG_UPDATE_DELAYED")
  S.RunTimers(0)
  S.RunTimers(0.2)
end

return S
