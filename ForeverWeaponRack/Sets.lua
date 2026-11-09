--[[
  Sets.lua
  Weapon sets: storage, naming, order, slot states and the smart rules
  (DESIGN 3 and 4.3 / 4.4). Pure data logic; nothing here equips anything.

  A set (stored per character in FWR.Data.char.sets[id]):
    id        number
    name      string
    key       key binding string or nil (see Bindings.lua)
    keyLost   true if the Equipment Toggle took this set's key
    slots     slotKey -> slot

  A slot:
    state     "item" | "empty" | "skip"   (skip = Leave alone)
    item      remembered item reference (Identity.lua) or nil. Kept through
              the right-click cycle so it doesn't need dragging in again.
    manual    (Ammo only) true if the player picked this ammo themselves

  Editing goes through a Draft (Sets.NewDraft) so changes stay unsaved until
  Save (DESIGN 4.4).
]]

local _, FWR = ...
local L = FWR.L
local Util = FWR.Util
local Item = FWR.Item
local Identity = FWR.Identity

local Sets = {}
FWR.Sets = Sets

local function CharDB() return FWR.Data.char end

local function Changed()
  FWR:Fire("SETS_CHANGED")
end

------------------------------------------------------------------------------
-- Slots
------------------------------------------------------------------------------

function Sets.NewSlots()
  local slots = {}
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    slots[slotKey] = { state = "skip" }
  end
  return slots
end

-- What you're wearing right now, as slots (used by Add Set).
function Sets.SlotsFromEquipped()
  local slots = Sets.NewSlots()
  for _, slotKey in ipairs({ "MAINHAND", "OFFHAND", "RANGED" }) do
    local entry = Identity.Equipped(slotKey)
    if entry then
      slots[slotKey] = { state = "item", item = Identity.MakeRef(entry) }
    else
      slots[slotKey] = { state = "empty" }
    end
  end
  if Identity.AmmoApplies(slots) then
    local ammo = Identity.Equipped("AMMO")
    if ammo then
      slots.AMMO = { state = "item", item = Identity.MakeRef(ammo), manual = false }
    else
      Sets.AutoAmmo(slots)
    end
  end
  return slots
end

function Sets.SlotsEqual(a, b)
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    local sa, sb = a[slotKey], b[slotKey]
    if sa.state ~= sb.state then return false end
    if not Identity.SameRef(sa.item, sb.item) then return false end
  end
  return true
end

-- Every slot is (effectively) Leave alone: the set would do nothing.
function Sets.AllSkip(slots)
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    if Identity.EffectiveState(slots, slotKey) ~= "skip" then return false end
  end
  return true
end

local function MainHandIsTwoHand(slots)
  local mh = slots.MAINHAND
  return mh.state == "item" and mh.item ~= nil and Item.IsTwoHand(mh.item.id)
end

--[[
  Auto-pick best ammo (DESIGN 3.3). Runs when the Ranged slot gets a bow,
  gun, or crossbow. Ammo the player picked themselves is kept if it fits;
  ammo that doesn't fit (arrows with a gun) is replaced with the best
  matching ammo you own. Returns the new ammo reference or nil.
]]
function Sets.AutoAmmo(slots)
  local ranged = slots.RANGED
  if not (ranged.state == "item" and ranged.item) then return nil end
  local wanted = Item.RangedAmmoType(ranged.item.id)
  if not wanted then return nil end
  local current = slots.AMMO
  local fits = current.item ~= nil and Item.AmmoType(current.item.id) == wanted
  if current.state == "item" and fits and current.manual then
    return nil
  end
  local best = Item.BestAmmo(wanted)
  if best then
    local ref = Identity.MakeRef(best)
    if not (current.state == "item" and Identity.SameRef(current.item, ref)) then
      slots.AMMO = { state = "item", item = ref, manual = false }
      return ref
    end
    return nil
  end
  if current.item and not fits then
    -- Nothing that fits: forget the wrong ammo.
    slots.AMMO = { state = "skip" }
  end
  return nil
end

--[[
  Sets.PlaceItem(slots, slotKey, ref, entry) -> ok, errorText, targetSlotKey
  Put an item into a slot with the smart rules (DESIGN 3.3):
    - two-handers always go in the Main Hand
    - a two-hander in the Main Hand sets the Off Hand to Empty (remembered)
    - an Off Hand item while the Main Hand holds a two-hander sets the Main
      Hand to Empty (remembered); the latest choice wins
    - ammo must match the ranged weapon
    - only items the game would let you equip
    - a bow, gun, or crossbow in Ranged auto-picks the best ammo
  entry (optional) is the exact copy, for the usability check.
]]
function Sets.PlaceItem(slots, slotKey, ref, entry)
  if not ref or not ref.id then return false, L.ERR_WRONG_SLOT end
  local fits, target, err = Item.FitsSlot(ref.link or ref.id, slotKey)
  if not fits then return false, err end

  local usable, usableErr = Item.CheckUsable(entry or ref.link)
  if not usable then return false, usableErr end

  if target == "AMMO" then
    if not Identity.AmmoApplies(slots) then
      return false, L.ERR_NO_RANGED_FOR_AMMO
    end
    if Item.AmmoType(ref.id) ~= Item.RangedAmmoType(slots.RANGED.item.id) then
      return false, L.ERR_AMMO_MISMATCH
    end
    slots.AMMO = { state = "item", item = ref, manual = true }
    return true, nil, target
  end

  slots[target] = { state = "item", item = ref }

  if target == "MAINHAND" and Item.IsTwoHand(ref.id) then
    slots.OFFHAND.state = "empty"
  elseif target == "OFFHAND" and MainHandIsTwoHand(slots) then
    slots.MAINHAND.state = "empty"
  elseif target == "RANGED" then
    Sets.AutoAmmo(slots)
  end
  return true, nil, target
end

--[[
  Right-click cycle (DESIGN 3.2):
    with a remembered item:   Item -> Empty -> Leave alone -> Item ...
    never had an item:        Empty <-> Leave alone
  Returns the new state.
]]
function Sets.CycleState(slots, slotKey)
  local slot = slots[slotKey]
  local state = slot.state
  if state == "item" and not slot.item then state = "skip" end
  local nextState
  if slot.item then
    if state == "item" then nextState = "empty"
    elseif state == "empty" then nextState = "skip"
    else nextState = "item" end
  else
    nextState = (state == "empty") and "skip" or "empty"
  end
  slot.state = nextState

  if nextState == "item" then
    -- Coming back to Item re-applies the two-hander and ammo rules.
    if slotKey == "MAINHAND" and Item.IsTwoHand(slot.item.id) then
      slots.OFFHAND.state = "empty"
    elseif slotKey == "OFFHAND" and MainHandIsTwoHand(slots) then
      slots.MAINHAND.state = "empty"
    elseif slotKey == "RANGED" then
      Sets.AutoAmmo(slots)
    end
  end
  return nextState
end

-- Take the item out of a slot (fake cursor pickup). The slot becomes Empty
-- and forgets the item.
function Sets.ClearSlot(slots, slotKey)
  slots[slotKey] = { state = "empty" }
end

-- "One copy, two slots" (DESIGN 3.3): same item in both hands but only one
-- copy owned. Returns errorText or nil.
function Sets.CheckDuplicate(slots)
  local mhState = Identity.EffectiveState(slots, "MAINHAND")
  local ohState = Identity.EffectiveState(slots, "OFFHAND")
  if mhState ~= "item" or ohState ~= "item" then return nil end
  local mh, oh = slots.MAINHAND.item, slots.OFFHAND.item
  if mh.id ~= oh.id then return nil end
  local copies = 0
  for _, entry in ipairs(Identity.Scan()) do
    if entry.id == mh.id and entry.slotKey ~= "AMMO" then copies = copies + 1 end
  end
  if copies < 2 then
    local name = Item.Details(mh.link or mh.id).name or mh.link or tostring(mh.id)
    return L.DUP_ONE_COPY:format(name)
  end
  return nil
end

-- Can these slots be saved? Returns ok, reason.
function Sets.CanSave(slots)
  if Sets.AllSkip(slots) then return false, L.HINT_ALL_SKIP end
  local dup = Sets.CheckDuplicate(slots)
  if dup then return false, dup end
  return true
end

------------------------------------------------------------------------------
-- Set storage
------------------------------------------------------------------------------

function Sets.Get(id)
  return id and CharDB().sets[id] or nil
end

-- All sets in list order (the cycle order for shared keys).
function Sets.All()
  local db = CharDB()
  local list = {}
  for _, id in ipairs(db.order) do
    local set = db.sets[id]
    if set then list[#list + 1] = set end
  end
  return list
end

function Sets.Count()
  return #CharDB().order
end

function Sets.IndexOf(id)
  for i, setId in ipairs(CharDB().order) do
    if setId == id then return i end
  end
  return nil
end

function Sets.FindByName(name)
  local key = Util.NameKey(name)
  if key == "" then return nil end
  for _, set in ipairs(Sets.All()) do
    if Util.NameKey(set.name) == key then return set end
  end
  return nil
end

--[[
  Naming rules (DESIGN 4.3), case-insensitive.
  originalName: the set's current name (nil when there is no set).
  Returns ok, reason.
]]
function Sets.CheckName(name, originalName)
  local key = Util.NameKey(name)
  if key == "" then return false, L.NAME_EMPTY end
  if originalName and key == Util.NameKey(originalName) then return false, L.NAME_SAME end
  if Sets.FindByName(name) then return false, L.NAME_TAKEN end
  return true
end

function Sets.NextDefaultName()
  local n = Sets.Count() + 1
  while Sets.FindByName(L.DEFAULT_SET_NAME:format(n)) do n = n + 1 end
  return L.DEFAULT_SET_NAME:format(n)
end

function Sets.Create(name, slots)
  local db = CharDB()
  name = Util.Trim(name)
  if name == "" or Sets.FindByName(name) then name = Sets.NextDefaultName() end
  local id = db.nextSetId
  db.nextSetId = id + 1
  local set = { id = id, name = name, slots = Util.CopyTable(slots or Sets.NewSlots()) }
  db.sets[id] = set
  db.order[#db.order + 1] = id
  Changed()
  return set
end

function Sets.Rename(id, name)
  local set = Sets.Get(id)
  if not set then return false end
  local ok, reason = Sets.CheckName(name, set.name)
  if not ok then return false, reason end
  set.name = Util.Trim(name)
  Changed()
  return true
end

-- Save as New: copy under a new name, with the given slots (which may be
-- unsaved draft changes). The copy has no key binding.
function Sets.SaveAsNew(id, name, slots)
  local set = Sets.Get(id)
  local ok, reason = Sets.CheckName(name, set and set.name)
  if not ok then return nil, reason end
  local source = slots or (set and set.slots) or Sets.NewSlots()
  return Sets.Create(name, source)
end

function Sets.SaveSlots(id, slots)
  local set = Sets.Get(id)
  if not set then return false end
  local ok, reason = Sets.CanSave(slots)
  if not ok then return false, reason end
  set.slots = Util.CopyTable(slots)
  Changed()
  return true
end

-- Sets bound to a key, in list order.
function Sets.WithKey(key)
  local list = {}
  if not key then return list end
  for _, set in ipairs(Sets.All()) do
    if set.key == key then list[#list + 1] = set end
  end
  return list
end

--[[
  Delete a set. Cycle memory is tied to the set, not its position: if a
  key remembered this set, it now remembers the set before it (same key),
  so the next press goes to the set that came after the deleted one
  (DESIGN 5.3).
]]
function Sets.Delete(id)
  local db = CharDB()
  local set = db.sets[id]
  if not set then return false end
  for key, rememberedId in pairs(db.cycle) do
    if rememberedId == id then
      local previous
      for _, other in ipairs(Sets.WithKey(key)) do
        if other.id == id then break end
        previous = other
      end
      db.cycle[key] = previous and previous.id or nil
    end
  end
  db.sets[id] = nil
  for i, setId in ipairs(db.order) do
    if setId == id then table.remove(db.order, i) break end
  end
  Changed()
  return true
end

-- Swap a set with its neighbor (delta -1 = up, +1 = down).
function Sets.Move(id, delta)
  local order = CharDB().order
  local i = Sets.IndexOf(id)
  if not i then return false end
  local j = i + delta
  if j < 1 or j > #order then return false end
  order[i], order[j] = order[j], order[i]
  Changed()
  return true
end

------------------------------------------------------------------------------
-- Draft: unsaved edits for the Edit Set tab (DESIGN 4.4)
------------------------------------------------------------------------------

local Draft = {}
Draft.__index = Draft

function Sets.NewDraft(set)
  local draft = setmetatable({}, Draft)
  draft.setId = set.id
  draft.slots = Util.CopyTable(set.slots)
  return draft
end

function Draft:Set()
  return Sets.Get(self.setId)
end

function Draft:IsDirty()
  local set = self:Set()
  if not set then return false end
  return not Sets.SlotsEqual(self.slots, set.slots)
end

function Draft:Revert()
  local set = self:Set()
  if set then self.slots = Util.CopyTable(set.slots) end
end

function Draft:CanSave()
  if not self:IsDirty() then return false end
  return Sets.CanSave(self.slots)
end

function Draft:Save()
  local ok, reason = Sets.SaveSlots(self.setId, self.slots)
  if ok then self:Revert() end
  return ok, reason
end

function Draft:PlaceItem(slotKey, ref, entry)
  return Sets.PlaceItem(self.slots, slotKey, ref, entry)
end

function Draft:Cycle(slotKey)
  return Sets.CycleState(self.slots, slotKey)
end

function Draft:Clear(slotKey)
  Sets.ClearSlot(self.slots, slotKey)
end

-- Snapshot and restore, for undoing a fake-cursor chain (DESIGN 4.5).
function Draft:Snapshot()
  return Util.CopyTable(self.slots)
end

function Draft:Restore(snapshot)
  self.slots = Util.CopyTable(snapshot)
end
