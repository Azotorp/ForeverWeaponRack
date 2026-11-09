--[[
  Queue.lua
  Holds the one request the game won't allow right now (DESIGN 6.3):
    - swaps blocked in combat (only if the game turns out to block them)
    - swaps while dead or mid-cast (busy states)
  Only the latest request is kept; earlier ones are dropped. It runs as soon
  as the block clears. Right-clicking the Queued indicator cancels it.

  Key binding changes made in combat are also "queued" (they go live after
  combat), but that lives in Bindings.lua; this module only reports it.
]]

local _, FWR = ...
local L = FWR.L

local Queue = {}
FWR.Queue = Queue

Queue.request = nil   -- the waiting request
Queue.reason = nil    -- "combat" | "dead" | "casting"

--[[
  TODO(test 1): equipping in combat through the add-on API is not confirmed
  in WoW Forever. We start by assuming it works. If the game blocks it
  (ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN for this add-on, or a
  "not in combat" error during a swap), Swap.lua calls
  Queue.MarkCombatBlocked(), and from then on, for this session, swaps in
  combat wait for combat to end. If testing confirms the block, the Macro
  mode branch (DESIGN 10) takes over.
]]
Queue.combatBlocked = false

function Queue.MarkCombatBlocked()
  if not Queue.combatBlocked then
    Queue.combatBlocked = true
    FWR:Warn(L.SWAP_COMBAT_BLOCKED)
  end
end

local function IsCasting()
  local casting = UnitCastingInfo("player")
  if FWR.IsSecret(casting) then return false end
  if casting then return true end
  local channel = UnitChannelInfo("player")
  if FWR.IsSecret(channel) then return false end
  return channel ~= nil
end

-- Why a swap can't run right now, or nil.
function Queue.BlockReason()
  local dead = UnitIsDeadOrGhost("player")
  if not FWR.IsSecret(dead) and dead then return "dead" end
  if IsCasting() then return "casting" end
  if Queue.combatBlocked and InCombatLockdown() then return "combat" end
  return nil
end

function Queue.ReasonText(reason)
  if reason == "dead" then return L.WHEN_DEAD end
  if reason == "casting" then return L.WHEN_CASTING end
  return L.WHEN_COMBAT
end

-- A short label for a request ("Tank", "Equipment Toggle", ...).
function Queue.Label(request)
  if not request then return "" end
  if request.kind == "toggle" then return L.TOGGLE_NAME end
  local set = FWR.Sets.Get(request.setId)
  if set then return set.name end
  if request.key then return GetBindingText and GetBindingText(request.key) or request.key end
  return "?"
end

function Queue.Set(request, reason)
  Queue.request = request
  Queue.reason = reason
  FWR:Print(L.SWAP_QUEUED:format(Queue.Label(request), Queue.ReasonText(reason)))
  FWR:Fire("QUEUE_CHANGED")
end

function Queue.Cancel(silent)
  if not Queue.request then return end
  Queue.request = nil
  Queue.reason = nil
  if not silent then FWR:Print(L.QUEUE_CANCELLED) end
  FWR:Fire("QUEUE_CHANGED")
end

function Queue.HasWork()
  return Queue.request ~= nil or (FWR.Bindings and FWR.Bindings.pending) or false
end

-- Run the queued request if nothing blocks it any more.
function Queue.TryRun()
  local request = Queue.request
  if not request then return end
  if Queue.BlockReason() then return end
  if FWR.Swap.busy then return end
  Queue.request = nil
  Queue.reason = nil
  FWR:Fire("QUEUE_CHANGED")
  request.source = "queue"
  FWR.Swap.Request(request)
end

local function Retry()
  FWR.Util.RunNextFrame("QUEUE_RETRY", Queue.TryRun)
end

FWR:RegisterEvent("PLAYER_REGEN_ENABLED", Retry)
FWR:RegisterEvent("PLAYER_ALIVE", Retry)
FWR:RegisterEvent("PLAYER_UNGHOST", Retry)
for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                         "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
  FWR:RegisterEvent(event, Retry, "player")
end
