--[[
  Swap.lua
  Equipping sets (DESIGN 6). Add-on mode: items are moved with the
  container/inventory API from a key press, a click, or /fwr equip.

  Flow for one request:
    1. Pick the set (shared keys cycle; see Bindings.PickForKey).
    2. Busy? (dead, casting, or combat if the game blocks it) -> Queue.
       A swap already moving items? -> keep this as the pending press; only
       the latest press runs when the current swap finishes (6.5).
    3. Checks before anything moves (6.2). Any failure cancels everything:
         a. missing items (or in the bank)
         b. bag space for everything that gets unequipped
         c. our own Accept/Cancel popup for unbound BoE, still-tradeable
            and refundable items. The game's own bind popup may still
            appear afterwards; we never click it.
    4. Plan the moves in equip order Main Hand -> Off Hand -> Ranged -> Ammo
       (6.1) and run as many as possible right away, inside the key press.
       Moves that depend on an item still locked from an earlier move wait
       for the locks to clear and run in the next pass. Each pass re-plans
       from what is really equipped, so a pass never works from stale data.

  Requests:
    { kind = "set", setId = n, source = "key"|"click"|"slash"|"queue" }
    { kind = "key", key = "F", source = "key" }      -- resolved when run
    { kind = "toggle", source = "key" }              -- Equipment Toggle
]]

local _, FWR = ...
local L = FWR.L
local API = FWR.API
local Item = FWR.Item
local Identity = FWR.Identity
local Tooltip = FWR.Tooltip

local Swap = {}
FWR.Swap = Swap

Swap.busy = false        -- items are moving
Swap.inPass = false      -- our moves are being sent right now
Swap.current = nil       -- the running job
Swap.pending = nil       -- latest request pressed while busy (key spam)

local MAX_PASSES = 4
local PASS_TIMEOUT = 3.0  -- seconds to wait for item locks before re-planning

local HAND_SLOTS = { "MAINHAND", "OFFHAND", "RANGED" }

------------------------------------------------------------------------------
-- Bag space
------------------------------------------------------------------------------

-- Free slots in normal bags (weapons can't go in quivers, ammo pouches or
-- other special bags). Returned in bag order.
function Swap.FreeBagSlots()
  local free = {}
  local first, last = BACKPACK_CONTAINER or 0, NUM_BAG_SLOTS or 4
  for bag = first, last do
    local _, family = API.GetContainerNumFreeSlots(bag)
    if family == nil or family == 0 then
      for slot = 1, API.GetContainerNumSlots(bag) or 0 do
        if not API.GetContainerItemInfo(bag, slot) then
          free[#free + 1] = { bag = bag, slot = slot }
        end
      end
    end
  end
  return free
end

------------------------------------------------------------------------------
-- Planning (pure: works on a snapshot, never touches the game)
------------------------------------------------------------------------------

local function Is2H(entry)
  return entry ~= nil and entry.equipLoc == "INVTYPE_2HWEAPON"
end

-- Can this item sit in that slot? (used when two equipped items trade places)
local function CanGo(entry, slotKey)
  local ok, target = Item.FitsSlot(entry.link, slotKey)
  return ok and target == slotKey
end

--[[
  Swap.Plan(desired, equipped, equippedAmmoId) -> plan
    desired[slotKey]  = { state = "item"|"empty"|"skip", entry = entry, ref = ref }
    equipped[slotKey] = inventory entry currently in MAINHAND/OFFHAND/RANGED
    equippedAmmoId    = item id in the ammo slot, or nil
  plan = { ops = { op, ... }, bagSlotsNeeded = n }
  op kinds:
    equip   { bag, slot } -> inv            (old item goes to that bag slot)
    move    fromInv -> inv                  (two equipped items trade places)
    unequip inv -> a free bag slot
    ammo    { bag, slot } -> ammo slot
    unammo  clear the ammo slot
  Each op lists the locations it touches, so the executor knows which moves
  depend on each other.
]]
function Swap.Plan(desired, equipped, equippedAmmoId)
  local occ = {}             -- slotKey -> entry (virtual, as moves happen)
  local where = {}           -- entry.key -> slotKey | "bag" | "gone"
  local bagPos = {}          -- entry.key -> { bag, slot } (virtual)
  for _, slotKey in ipairs(HAND_SLOTS) do
    local e = equipped[slotKey]
    if e then
      occ[slotKey] = e
      where[e.key] = slotKey
    end
  end

  local ops, needed = {}, 0

  local function invId(slotKey) return FWR.InvId(slotKey) end

  local function Unequip(slotKey)
    local old = occ[slotKey]
    if not old then return end
    ops[#ops + 1] = { kind = "unequip", slotKey = slotKey, inv = invId(slotKey),
                      touches = { "inv:" .. invId(slotKey) } }
    needed = needed + 1
    where[old.key] = "gone"
    occ[slotKey] = nil
  end

  local function Equip(entry, slotKey)
    local from = where[entry.key]
    local old = occ[slotKey]
    if from == nil or from == "bag" then
      local pos = bagPos[entry.key] or { bag = entry.bag, slot = entry.slot }
      -- Put the other hand away first, in the same key press: the off hand
      -- before a two-hander goes on, or a two-hander before an off-hand item
      -- goes on. (ItemRack Forever does the same, and it works in combat.)
      if slotKey == "MAINHAND" and Is2H(entry) and occ.OFFHAND then
        Unequip("OFFHAND")
      elseif slotKey == "OFFHAND" and Is2H(occ.MAINHAND) then
        Unequip("MAINHAND")
      end
      local op = { kind = "equip", bag = pos.bag, slot = pos.slot, slotKey = slotKey,
                   inv = invId(slotKey), entry = entry,
                   touches = { "bag:" .. pos.bag .. ":" .. pos.slot, "inv:" .. invId(slotKey) } }
      ops[#ops + 1] = op
      occ[slotKey] = entry
      where[entry.key] = slotKey
      if old then
        where[old.key] = "bag"
        bagPos[old.key] = pos
      end
    else
      -- The item is equipped in another hand: trade places.
      if old and not CanGo(old, from) then
        Unequip(slotKey)
        old = nil
      end
      ops[#ops + 1] = { kind = "move", fromSlotKey = from, fromInv = invId(from),
                        slotKey = slotKey, inv = invId(slotKey), entry = entry,
                        touches = { "inv:" .. invId(from), "inv:" .. invId(slotKey) } }
      occ[slotKey] = entry
      where[entry.key] = slotKey
      occ[from] = old
      if old then where[old.key] = from end
    end
  end

  for _, slotKey in ipairs(HAND_SLOTS) do
    local d = desired[slotKey]
    if d and d.state == "item" and d.entry then
      local current = occ[slotKey]
      if not (current and current.key == d.entry.key) then
        Equip(d.entry, slotKey)
      end
    elseif d and d.state == "empty" then
      Unequip(slotKey)
    end
  end

  local d = desired.AMMO
  if d and d.state == "item" and d.entry and d.ref then
    if equippedAmmoId ~= d.ref.id and d.entry.where == "bag" then
      ops[#ops + 1] = { kind = "ammo", bag = d.entry.bag, slot = d.entry.slot,
                        inv = invId("AMMO"), entry = d.entry,
                        touches = { "inv:" .. invId("AMMO") } }
    end
  elseif d and d.state == "empty" and equippedAmmoId then
    -- Ammo never leaves the bags, so this needs no bag space.
    ops[#ops + 1] = { kind = "unammo", inv = invId("AMMO"), touches = { "inv:" .. invId("AMMO") } }
  end

  return { ops = ops, bagSlotsNeeded = needed }
end

-- Snapshot of what's equipped right now, for Swap.Plan.
function Swap.EquippedSnapshot()
  local equipped = {}
  for _, slotKey in ipairs(HAND_SLOTS) do
    equipped[slotKey] = Identity.Equipped(slotKey)
  end
  local ammoId = GetInventoryItemID("player", FWR.InvId("AMMO"))
  return equipped, ammoId
end

------------------------------------------------------------------------------
-- Executing moves
------------------------------------------------------------------------------

local function IsLocationLocked(location)
  local kind, a, b = location:match("^(%a+):(%-?%d+):?(%-?%d*)$")
  if kind == "inv" then
    return IsInventoryItemLocked(tonumber(a)) and true or false
  elseif kind == "bag" then
    local info = API.GetContainerItemInfo(tonumber(a), tonumber(b))
    return info ~= nil and info.isLocked and true or false
  end
  return false
end

local function ClearStrayCursor()
  if CursorHasItem() then ClearCursor() end
end

-- Pick up from a bag slot or inventory slot and drop on another.
-- Returns true if the cursor ended up empty (the game took the move).
local function Move(pickup, drop)
  pickup()
  if not CursorHasItem() then return false end
  drop()
  if CursorHasItem() then
    ClearCursor()   -- the item goes back where it came from
    return false
  end
  return true
end

-- Free bag slots for unequips are taken from the END of the list, away from
-- where the game puts things by itself, so a move never lands on a slot the
-- game is filling at the same moment.
local function TakeFreeSlot(free)
  return table.remove(free)
end

function Swap.ExecuteOp(op, free)
  local PickupContainerItem = API.PickupContainerItem
  if op.kind == "equip" or op.kind == "ammo" then
    return Move(function() PickupContainerItem(op.bag, op.slot) end,
                function() PickupInventoryItem(op.inv) end)
  elseif op.kind == "move" then
    return Move(function() PickupInventoryItem(op.fromInv) end,
                function() PickupInventoryItem(op.inv) end)
  elseif op.kind == "unequip" then
    local target = TakeFreeSlot(free)
    if not target then return false end
    return Move(function() PickupInventoryItem(op.inv) end,
                function() PickupContainerItem(target.bag, target.slot) end)
  elseif op.kind == "unammo" then
    --[[
      TODO(test 3): how the ammo slot is cleared in Forever is not confirmed.
      In Classic the ammo slot only points at ammo that stays in your bags.
      We pick it up and drop it in a free bag slot (or clear the cursor if
      there is none). Check that the ammo slot ends up empty and no ammo is
      lost or split.
    ]]
    PickupInventoryItem(op.inv)
    if CursorHasItem() then
      local target = TakeFreeSlot(free)
      if target then
        PickupContainerItem(target.bag, target.slot)
      end
      ClearStrayCursor()
    end
    -- The next pass re-plans and retries if the slot is still filled.
    return true
  end
  return false
end

------------------------------------------------------------------------------
-- Swap log: the last few requests and what happened to them, so a failed
-- swap in game can be reported with /fwr debug swaps.
------------------------------------------------------------------------------

Swap.history = {}
local MAX_HISTORY = 15
local MAX_NOTES = 24
local activeLog   -- log entry of the request being handled right now

local function NewLog(request)
  local what
  if request.kind == "toggle" then
    what = L.TOGGLE_NAME
  elseif request.kind == "key" then
    what = "key " .. tostring(request.key)
  else
    local set = FWR.Sets.Get(request.setId)
    what = set and set.name or "?"
  end
  local entry = {
    at = date("%H:%M:%S"), source = request.source or "?", what = what,
    combat = InCombatLockdown() and true or false,
    result = "?", passes = 0, sent = 0, refused = 0, notes = {},
  }
  table.insert(Swap.history, 1, entry)
  if #Swap.history > MAX_HISTORY then table.remove(Swap.history) end
  activeLog = entry
  return entry
end

local function CurrentLog()
  return (Swap.current and Swap.current.log) or activeLog
end

function Swap.Note(text)
  local entry = CurrentLog()
  if entry and #entry.notes < MAX_NOTES then entry.notes[#entry.notes + 1] = tostring(text) end
end

local function LogResult(text)
  local entry = CurrentLog()
  if entry then entry.result = text end
end

-- Called by Bindings.Press when a key press hits a Lua error. If the error
-- came before this press got its own log entry, it gets one now.
function Swap.LogError(err, request)
  if request and (not activeLog or activeLog.request ~= request) and not Swap.current then
    NewLog(request).request = request
  end
  Swap.Note("Lua error: " .. tostring(err))
  LogResult("Lua error")
end

------------------------------------------------------------------------------
-- Jobs: one running swap
--   job = {
--     request   the request that started it
--     label     set name (for messages)
--     desired   function() -> desired table (re-evaluated every pass)
--     onFinish  function(success) (optional)
--   }
------------------------------------------------------------------------------

local waitTimer

local function StopWaitTimer()
  if waitTimer then
    waitTimer:Cancel()
    waitTimer = nil
  end
end

function Swap.Finish(success, quiet)
  local job = Swap.current
  StopWaitTimer()
  Swap.current = nil
  Swap.busy = false
  ClearStrayCursor()
  Identity.Invalidate()
  if job then
    if job.log then job.log.result = success and "done" or "failed: the game refused a move" end
    if not success and not quiet then
      FWR:ErrorAndPrint(L.SWAP_FAILED)
    end
    if job.onFinish then FWR.SafeCall(job.onFinish, success) end
  end
  FWR:Fire("QUEUE_CHANGED")
  -- Only the latest press made during the swap runs now (DESIGN 6.5).
  local nextRequest = Swap.pending
  Swap.pending = nil
  if nextRequest then
    Swap.Request(nextRequest)
  else
    FWR.Queue.TryRun()
  end
end

-- The game refused the swap because of combat: queue it for later.
function Swap.AbortForCombat()
  local job = Swap.current
  if not job then return end
  FWR.Queue.MarkCombatBlocked()
  -- A press made during this swap is newer, so it wins the queue slot.
  local request = Swap.pending or job.request
  Swap.pending = nil
  local log = job.log
  Swap.Finish(false, true)
  if log then log.result = "blocked by the game in combat, queued for after combat" end
  if request then
    FWR.Queue.Set(request, "combat")
  end
end

local function AllUnlocked(touched)
  for location in pairs(touched) do
    if IsLocationLocked(location) then return false end
  end
  return true
end

function Swap.RunPass()
  local job = Swap.current
  if not job then return end
  StopWaitTimer()
  job.passes = job.passes + 1
  job.waiting = false

  -- Fresh look at bags and equipment every pass.
  Identity.Invalidate()
  local desired = job.desired()
  local equipped, ammoId = Swap.EquippedSnapshot()
  local plan = Swap.Plan(desired, equipped, ammoId)

  if job.log then job.log.passes = job.passes end
  if #plan.ops == 0 then
    return Swap.Finish(true)
  end
  if job.passes > MAX_PASSES then
    return Swap.Finish(false)
  end

  local free = Swap.FreeBagSlots()
  local touched = {}
  local ran, failed = 0, 0
  Swap.inPass = true
  for _, op in ipairs(plan.ops) do
    local blocked = false
    for _, location in ipairs(op.touches) do
      if touched[location] or IsLocationLocked(location) then blocked = true break end
    end
    local opName = op.kind .. " " .. (op.slotKey or "AMMO")
    if not blocked then
      if Swap.ExecuteOp(op, free) then
        ran = ran + 1
        Swap.Note(("pass %d: %s sent"):format(job.passes, opName))
      else
        failed = failed + 1
        Swap.Note(("pass %d: %s refused (item stayed put)"):format(job.passes, opName))
      end
    else
      Swap.Note(("pass %d: %s waits for the previous move"):format(job.passes, opName))
    end
    -- Later moves that touch the same places wait for the next pass.
    for _, location in ipairs(op.touches) do touched[location] = true end
    -- The combat check in UI_ERROR_MESSAGE / ADDON_ACTION_* may have ended the job.
    if Swap.current ~= job then
      Swap.inPass = false
      return
    end
  end
  Swap.inPass = false
  if job.log then
    job.log.sent = job.log.sent + ran
    job.log.refused = job.log.refused + failed
  end

  if ran == 0 and failed > 0 then
    return Swap.Finish(false)
  end

  -- Wait for the game to confirm the moves (locks clear), then re-plan.
  job.touched = touched
  job.waiting = true
  waitTimer = C_Timer.NewTimer(PASS_TIMEOUT, function()
    waitTimer = nil
    if Swap.current == job then Swap.RunPass() end
  end)
end

local function CheckLocks()
  local job = Swap.current
  if not job or not job.waiting then return end
  if AllUnlocked(job.touched or {}) then
    Swap.RunPass()
  end
end

local function OnLockEvent()
  if Swap.current and Swap.current.waiting then
    FWR.Util.RunNextFrame("SWAP_LOCKS", CheckLocks)
  end
end

FWR:RegisterEvent("ITEM_LOCK_CHANGED", OnLockEvent)
FWR:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", OnLockEvent)
FWR:RegisterEvent("BAG_UPDATE_DELAYED", OnLockEvent)
FWR:RegisterEvent("UNIT_INVENTORY_CHANGED", OnLockEvent, "player")

-- If the game blocks our calls in combat, queue instead (see Queue.lua).
-- The event names the add-on; a block that fires while our own moves are
-- running in combat is treated as ours too, in case the name differs.
local function OnActionBlocked(event, addonName, func)
  if not Swap.current then return end
  if FWR.IsSecret(addonName) then addonName = nil end
  if FWR.IsSecret(func) then func = nil end
  Swap.Note(("%s: %s %s"):format(event, tostring(addonName), tostring(func)))
  if addonName == FWR.name or (Swap.inPass and InCombatLockdown()) then
    Swap.AbortForCombat()
  end
end
FWR:RegisterEvent("ADDON_ACTION_BLOCKED", OnActionBlocked)
FWR:RegisterEvent("ADDON_ACTION_FORBIDDEN", OnActionBlocked)

FWR:RegisterEvent("UI_ERROR_MESSAGE", function(_, _, message)
  if not Swap.current then return end
  if FWR.IsSecret(message) then return end
  Swap.Note("game error: " .. tostring(message))
  if not InCombatLockdown() then return end
  if message and (message == _G.ERR_NOT_IN_COMBAT or message == _G.ERR_AFFECTING_COMBAT) then
    Swap.AbortForCombat()
  end
end)

------------------------------------------------------------------------------
-- Checks before swapping (DESIGN 6.2)
------------------------------------------------------------------------------

local function ItemName(ref, entry)
  if entry and entry.link then return entry.link end
  if ref then return ref.link or Item.Details(ref.id).name or tostring(ref.id) end
  return "?"
end

-- Missing items: list of names, or nil if nothing is missing.
function Swap.MissingList(desired)
  local missing
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    local d = desired[slotKey]
    if d.state == "item" and d.missing then
      missing = missing or {}
      local name = ItemName(d.ref)
      if d.inBank then name = L.SWAP_IN_BANK:format(name) end
      missing[#missing + 1] = name
    end
  end
  return missing
end

-- Items that would be equipped from the bags and need a warning.
function Swap.WarningList(plan)
  local lines = {}
  for _, op in ipairs(plan.ops) do
    if op.kind == "equip" and op.entry then
      local reasons = {}
      if Tooltip.IsUnboundBoE(op.entry) then reasons[#reasons + 1] = L.SWAP_CONFIRM_BOE end
      if Tooltip.IsTradeable(op.entry) then reasons[#reasons + 1] = L.SWAP_CONFIRM_TRADE end
      if Tooltip.IsRefundable(op.entry) then reasons[#reasons + 1] = L.SWAP_CONFIRM_REFUND end
      if #reasons > 0 then
        lines[#lines + 1] = op.entry.link .. ": " .. table.concat(reasons, ", ")
      end
    end
  end
  return lines
end

--[[
  Start a job after the checks. Returns true if items started moving.
  opts.allowMissing: skip missing items instead of cancelling (toggle).
  opts.confirmed: the warning popup was already accepted.
]]
function Swap.StartJob(job, opts)
  opts = opts or {}
  job.log = activeLog
  if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then
    FWR:ErrorText(L.SWAP_CURSOR_BUSY)
    LogResult("cancelled: the cursor is holding an item or a spell")
    return false
  end

  Identity.Invalidate()
  local desired = job.desired()

  -- a. Missing items
  if not opts.allowMissing then
    local missing = Swap.MissingList(desired)
    if missing then
      FWR:ErrorAndPrint(L.SWAP_MISSING:format(job.label),
        L.SWAP_MISSING_DETAIL:format(job.label, table.concat(missing, ", ")))
      LogResult("cancelled: missing " .. table.concat(missing, ", "))
      return false
    end
  end

  local equipped, ammoId = Swap.EquippedSnapshot()
  local plan = Swap.Plan(desired, equipped, ammoId)
  if #plan.ops == 0 then
    if job.request and job.request.source ~= "key" and job.request.source ~= "queue" then
      FWR:Print(L.SWAP_NOTHING:format(job.label))
    end
    LogResult("nothing to do: already wearing it")
    if job.onFinish then FWR.SafeCall(job.onFinish, true) end
    return false
  end

  -- b. Bag space
  local free = Swap.FreeBagSlots()
  if plan.bagSlotsNeeded > #free then
    FWR:ErrorAndPrint(L.SWAP_BAGS_FULL,
      L.SWAP_BAGS_FULL_DETAIL:format(job.label, plan.bagSlotsNeeded, #free))
    LogResult(("cancelled: bags full (needs %d, has %d)"):format(plan.bagSlotsNeeded, #free))
    return false
  end

  -- c. Bind / trade / refund warnings
  if not opts.confirmed then
    local warnings = Swap.WarningList(plan)
    if #warnings > 0 then
      local text = L.SWAP_CONFIRM:format(job.label, table.concat(warnings, "\n"))
        .. "\n\n" .. L.SWAP_CONFIRM_NOTE
      FWR.Confirm(text, function()
        -- Accept is a click: a fresh hardware action. Re-run every check.
        if job.request then
          job.request.confirmed = true
          Swap.Request(job.request)
        else
          opts.confirmed = true
          Swap.StartJob(job, opts)
        end
      end)
      LogResult("waiting for the Bind on Equip / trade / refund popup")
      return false
    end
  end

  -- Go.
  LogResult("moving items")
  job.passes = 0
  Swap.current = job
  Swap.busy = true
  FWR:Fire("QUEUE_CHANGED")
  Swap.RunPass()
  return true
end

------------------------------------------------------------------------------
-- Requests
------------------------------------------------------------------------------

function Swap.JobForSet(set, request)
  return {
    request = request,
    label = set.name,
    desired = function() return Identity.Resolve(set.slots) end,
  }
end

-- The single entry point for every swap: keys, clicks, slash commands,
-- the queue and the Equipment Toggle.
function Swap.Request(request)
  local log = NewLog(request)
  log.request = request
  if Swap.busy then
    -- Key spam: remember only the latest press (DESIGN 6.5).
    Swap.pending = request
    log.result = "held: runs when the swap in progress finishes"
    return "pending"
  end

  -- Shared keys pick their set now (cycle order, skip rule).
  if request.kind == "key" then
    local set = FWR.Bindings.PickForKey(request.key)
    if not set then
      log.result = "nothing to do: no set on this key, or already wearing every set on it"
      return "nothing"
    end
    FWR.Bindings.Remember(request.key, set)
    log.what = log.what .. " -> " .. set.name
    request = { kind = "set", setId = set.id, source = request.source, confirmed = request.confirmed }
  end

  local blocked = FWR.Queue.BlockReason()
  if blocked then
    FWR.Queue.Set(request, blocked)
    log.result = "queued: waiting until " .. FWR.Queue.ReasonText(blocked)
    return "queued"
  end

  if request.kind == "toggle" then
    return FWR.Toggle.Run(request) and "started" or "nothing"
  end

  local set = FWR.Sets.Get(request.setId)
  if not set then
    log.result = "nothing to do: the set no longer exists"
    return "nothing"
  end
  local job = Swap.JobForSet(set, request)
  return Swap.StartJob(job, { confirmed = request.confirmed }) and "started" or "nothing"
end

-- Equip a set by name (/fwr equip <name>, macros).
function Swap.EquipByName(name)
  local set = FWR.Sets.FindByName(name)
  if not set then
    FWR:ErrorAndPrint(L.SWAP_NO_SET:format(FWR.Util.Trim(name)))
    return
  end
  Swap.Request({ kind = "set", setId = set.id, source = "slash" })
end

-- Used by the offline tests only.
function Swap.ResetForTests()
  StopWaitTimer()
  Swap.busy, Swap.current, Swap.pending = false, nil, nil
  activeLog = nil
end
