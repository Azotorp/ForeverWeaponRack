--[[
  Bindings.lua
  Key bindings for sets and the Equipment Toggle (DESIGN 5).

  How keys are stored (decided with the user): every key lives in the
  add-on's saved data (set keys per character, the toggle key in the
  profile or per character) and goes live through Blizzard's binding system
  as override bindings (SetOverrideBinding). That means:
    - they work like any other key and show up to anything that asks the
      game what a key does (GetBindingAction), including other add-ons
    - they never leak to your other characters
    - "Use it anyway?" makes our key win on this character. The other
      binding is left in Blizzard's saved bindings and comes back if you
      clear ours or disable the add-on.
  Binding functions are blocked in combat, so changes made in combat are
  saved right away and go live when combat ends (5.1, 6.3).

  How a key press reaches the swap code: each key is bound to one of the
  hidden commands in Bindings.xml (FOREVERWEAPONRACK_KEY1..N and
  FOREVERWEAPONRACK_TOGGLE). The game runs the command's code straight from
  the key press, the same path ItemRack Forever uses to swap weapons in
  combat. (Version 0.1.0 "clicked" a hidden plain button instead, and in-game
  testing showed that path does not swap in combat in WoW Forever.)

  A command runs the shared-key cycle (5.3): sets with the same key are tried
  in list order, starting after the one this key equipped last, skipping
  sets you're already wearing.
]]

local _, FWR = ...
local L = FWR.L
local Sets = FWR.Sets
local Identity = FWR.Identity

local Bindings = {}
FWR.Bindings = Bindings

Bindings.pending = false   -- changes waiting for combat to end

local COMMAND_PREFIX = "FOREVERWEAPONRACK_KEY"
local TOGGLE_COMMAND = "FOREVERWEAPONRACK_TOGGLE"
-- Must match the number of FOREVERWEAPONRACK_KEYn entries in Bindings.xml.
Bindings.MAX_KEYS = 100

Bindings.keyBySlot = {}   -- command number -> key it is bound to right now

local owner = CreateFrame("Frame", "ForeverWeaponRackBindingOwner", UIParent)

------------------------------------------------------------------------------
-- Key presses (called from Bindings.xml, on key down)
------------------------------------------------------------------------------

-- Run a request from a key press. Errors are logged for /fwr debug swaps and
-- still shown by the game's error handler.
function Bindings.Press(request)
  local ok, err = xpcall(function() return FWR.Swap.Request(request) end, function(e)
    FWR.Swap.LogError(e, request)
    return e
  end)
  if not ok then geterrorhandler()(err) end
end

function FWR.OnKeyCommand(slot)
  local key = Bindings.keyBySlot[slot]
  if not key then return end
  Bindings.Press({ kind = "key", key = key, source = "key" })
end

function FWR.OnToggleCommand()
  Bindings.Press({ kind = "toggle", source = "key" })
end

------------------------------------------------------------------------------
-- Shared-key cycle (DESIGN 5.3)
------------------------------------------------------------------------------

-- The set a press of this key should equip now, or nil.
function Bindings.PickForKey(key)
  local sets = Sets.WithKey(key)
  local count = #sets
  if count == 0 then return nil end
  local remembered = FWR.Data.char.cycle[key]
  local start = 0
  for i, set in ipairs(sets) do
    if set.id == remembered then start = i break end
  end
  for step = 1, count do
    local set = sets[(start + step - 1) % count + 1]
    -- Skip rule: only skip a set you're already wearing exactly.
    if not Identity.IsWearing(set) then return set end
  end
  return nil
end

function Bindings.Remember(key, set)
  FWR.Data.char.cycle[key] = set.id
end

------------------------------------------------------------------------------
-- Making keys live
------------------------------------------------------------------------------

-- The toggle's key is exclusive: a set using it loses its key (5.4).
local function EnforceToggleExclusive()
  local toggleKey = FWR.Data:GetToggleKey()
  if not toggleKey then return end
  for _, set in ipairs(Sets.All()) do
    if set.key == toggleKey then
      set.key = nil
      set.keyLost = true
    end
  end
end

function Bindings.Apply()
  if not FWR.Data.char then return false end
  EnforceToggleExclusive()
  if InCombatLockdown() then
    Bindings.pending = true
    FWR:Fire("QUEUE_CHANGED")
    return false
  end
  ClearOverrideBindings(owner)
  wipe(Bindings.keyBySlot)
  local slot = 0
  local done = {}
  for _, set in ipairs(Sets.All()) do
    local key = set.key
    if key and not done[key] then
      done[key] = true
      slot = slot + 1
      if slot <= Bindings.MAX_KEYS then
        Bindings.keyBySlot[slot] = key
        SetOverrideBinding(owner, true, key, COMMAND_PREFIX .. slot)
      elseif slot == Bindings.MAX_KEYS + 1 then
        FWR:Warn(L.KEY_TOO_MANY:format(Bindings.MAX_KEYS))
      end
    end
  end
  local toggleKey = FWR.Data:GetToggleKey()
  if toggleKey then
    SetOverrideBinding(owner, true, toggleKey, TOGGLE_COMMAND)
  end
  local wasPending = Bindings.pending
  Bindings.pending = false
  if wasPending then FWR:Fire("QUEUE_CHANGED") end
  FWR:Fire("BINDINGS_CHANGED")
  return true
end

FWR:RegisterEvent("PLAYER_REGEN_ENABLED", function()
  if Bindings.pending then Bindings.Apply() end
end)
FWR:Listen("SETS_CHANGED", function() FWR.Util.RunNextFrame("BINDINGS_APPLY", Bindings.Apply) end)
FWR:Listen("PROFILE_CHANGED", function() FWR.Util.RunNextFrame("BINDINGS_APPLY", Bindings.Apply) end)

------------------------------------------------------------------------------
-- Building key strings from input (used by the key capture box)
------------------------------------------------------------------------------

local MODIFIER_KEYS = {
  LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true, SHIFT = true, CTRL = true, ALT = true, META = true,
}

function Bindings.IsModifierOnly(key)
  if IsKeyPressIgnoredForBinding then return IsKeyPressIgnoredForBinding(key) end
  return MODIFIER_KEYS[key] == true or key == "UNKNOWN"
end

-- "ALT-CTRL-SHIFT-KEY" in the game's own order.
function Bindings.Chord(key)
  if CreateKeyChordStringUsingMetaKeyState then
    return CreateKeyChordStringUsingMetaKeyState(key)
  end
  local chord = ""
  if IsAltKeyDown() then chord = chord .. "ALT-" end
  if IsControlKeyDown() then chord = chord .. "CTRL-" end
  if IsShiftKeyDown() then chord = chord .. "SHIFT-" end
  return chord .. key
end

local MOUSE_NAMES = {
  LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3",
  Button4 = "BUTTON4", Button5 = "BUTTON5",
}

function Bindings.MouseKey(button)
  if GetConvertedKeyOrButton then return GetConvertedKeyOrButton(button) end
  return MOUSE_NAMES[button] or button
end

function Bindings.WheelKey(delta)
  return delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
end

local function BaseKey(chord)
  return chord:match("([^%-]+)$") or chord
end

local function HasModifier(chord)
  return chord:find("ALT%-") or chord:find("CTRL%-") or chord:find("SHIFT%-") or chord:find("META%-")
end

-- Plain left and right click are always blocked (5.2).
function Bindings.Validate(chord)
  if not chord or chord == "" then return false end
  local base = BaseKey(chord)
  if (base == "BUTTON1" or base == "BUTTON2") and not HasModifier(chord) then
    return false, L.KEY_PLAIN_CLICK
  end
  return true
end

-- Modified left/right click: allowed, but may clash (5.2).
function Bindings.IsModifiedClick(chord)
  local base = BaseKey(chord)
  return (base == "BUTTON1" or base == "BUTTON2") and HasModifier(chord) and true or false
end

------------------------------------------------------------------------------
-- Conflicts (5.1)
------------------------------------------------------------------------------

function Bindings.KeyText(key)
  if not key then return L.KEY_NONE end
  if GetBindingText then return GetBindingText(key) end
  return key
end

local function IsOurs(action)
  return action:find("^FOREVERWEAPONRACK_") ~= nil
end

-- What else uses this key (the default UI, action bar add-ons, any add-on).
-- Returns a readable name, or nil if the key is free or only ours.
function Bindings.OtherUser(key)
  local action = GetBindingAction(key, true)
  if FWR.IsSecret(action) or not action or action == "" or IsOurs(action) then return nil end
  local clickTarget = action:match("^CLICK ([^:]+)")
  if clickTarget then
    return L.KEY_ANOTHER_ADDON:format(clickTarget)
  end
  local name = _G["BINDING_NAME_" .. action]
  if not name and GetBindingName then name = GetBindingName(action) end
  return name or action
end

local function SetNames(list)
  local names = {}
  for _, set in ipairs(list) do names[#names + 1] = "\"" .. set.name .. "\"" end
  return table.concat(names, ", ")
end

-- Other sets that share this key with setId (for the "cycles" hint).
function Bindings.SharedWith(setId, key)
  local list = {}
  for _, set in ipairs(Sets.WithKey(key)) do
    if set.id ~= setId then list[#list + 1] = set end
  end
  return list
end

local function Announce(name, key)
  if InCombatLockdown() then
    FWR:Print(L.KEY_PENDING)
  else
    FWR:Print(L.KEY_BOUND:format(name, Bindings.KeyText(key)))
  end
end

------------------------------------------------------------------------------
-- Assigning keys
------------------------------------------------------------------------------

function Bindings.SetSetKey(setId, key)
  local set = Sets.Get(setId)
  if not set then return end
  set.key = key
  set.keyLost = nil
  FWR:Fire("SETS_CHANGED")
  Bindings.Apply()
  if key then Announce(set.name, key) end
end

function Bindings.SetToggleKey(key)
  if key then
    for _, set in ipairs(Sets.WithKey(key)) do
      set.key = nil
      set.keyLost = true
    end
  end
  FWR.Data:SetToggleKey(key)
  FWR:Fire("SETS_CHANGED")
  Bindings.Apply()
  if key then Announce(L.TOGGLE_NAME, key) end
end

--[[
  Ask before binding a captured key to a set. Shared keys between our own
  sets need no question (that's how cycling works). Calls done(true) when
  the key was bound.
]]
function Bindings.RequestSetKey(setId, key, done)
  done = done or function() end
  local ok, err = Bindings.Validate(key)
  if not ok then
    FWR:ErrorText(err)
    return done(false)
  end
  if key == FWR.Data:GetToggleKey() then
    FWR:ErrorAndPrint(L.KEY_TOGGLE_OWNS)
    return done(false)
  end
  local other = Bindings.OtherUser(key)
  local clickWarning = Bindings.IsModifiedClick(key) and ("\n\n" .. L.KEY_CLICK_WARNING) or ""
  if other or clickWarning ~= "" then
    local text = other and L.KEY_IN_USE:format(other) or L.KEY_CLICK_WARNING
    if other then text = text .. clickWarning end
    FWR.Confirm(text, function()
      Bindings.SetSetKey(setId, key)
      done(true)
    end, function() done(false) end)
    return
  end
  Bindings.SetSetKey(setId, key)
  done(true)
end

function Bindings.RequestToggleKey(key, done)
  done = done or function() end
  local ok, err = Bindings.Validate(key)
  if not ok then
    FWR:ErrorText(err)
    return done(false)
  end
  local questions = {}
  local sets = Sets.WithKey(key)
  if #sets > 0 then questions[#questions + 1] = L.KEY_IN_USE_SETS:format(SetNames(sets)) end
  local other = Bindings.OtherUser(key)
  if other then questions[#questions + 1] = L.KEY_IN_USE:format(other) end
  if Bindings.IsModifiedClick(key) then questions[#questions + 1] = L.KEY_CLICK_WARNING end
  if #questions > 0 then
    FWR.Confirm(table.concat(questions, "\n\n"), function()
      Bindings.SetToggleKey(key)
      done(true)
    end, function() done(false) end)
    return
  end
  Bindings.SetToggleKey(key)
  done(true)
end
