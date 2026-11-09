--[[
  Bindings.lua
  Key bindings for sets and the Equipment Toggle (DESIGN 5).

  How keys are stored (decided with the user): every key lives in the
  add-on's saved data (set keys per character, the toggle key in the
  profile or per character) and goes live through Blizzard's binding system
  as override bindings (SetOverrideBindingClick). That means:
    - they work like any other key and show up to anything that asks the
      game what a key does (GetBindingAction), including other add-ons
    - they never leak to your other characters
    - "Use it anyway?" makes our key win on this character. The other
      binding is left in Blizzard's saved bindings and comes back if you
      clear ours or disable the add-on.
  Binding functions are blocked in combat, so changes made in combat are
  saved right away and go live when combat ends (5.1, 6.3).

  Each distinct key gets one hidden button; the binding "clicks" it. That
  button runs the shared-key cycle (5.3): sets with the same key are tried
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

local BUTTON_PREFIX = "ForeverWeaponRackKey"
local TOGGLE_BUTTON = "ForeverWeaponRackToggleButton"

local owner = CreateFrame("Frame", "ForeverWeaponRackBindingOwner", UIParent)

------------------------------------------------------------------------------
-- Hidden buttons the bindings click
------------------------------------------------------------------------------

--[[
  TODO(test): confirm a key press fires once. Modern clients send a "down"
  and an "up" click for CLICK bindings; we register both and act on the
  down click only. A client that sends one click without the down flag
  (down == nil) is handled too.
]]
local function MakeButton(name, onPress)
  local button = CreateFrame("Button", name, UIParent)
  button:SetSize(1, 1)
  button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
  button:EnableMouse(false)
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetScript("OnClick", function(self, _, down)
    if down == false then return end
    onPress(self)
  end)
  return button
end

local keyButtons = {}   -- index -> button

local function KeyButton(index)
  local button = keyButtons[index]
  if not button then
    button = MakeButton(BUTTON_PREFIX .. index, function(self)
      if self.fwrKey then
        FWR.Swap.Request({ kind = "key", key = self.fwrKey, source = "key" })
      end
    end)
    keyButtons[index] = button
  end
  return button
end

Bindings.toggleButton = MakeButton(TOGGLE_BUTTON, function()
  FWR.Swap.Request({ kind = "toggle", source = "key" })
end)

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
  local index = 0
  local done = {}
  for _, set in ipairs(Sets.All()) do
    local key = set.key
    if key and not done[key] then
      done[key] = true
      index = index + 1
      local button = KeyButton(index)
      button.fwrKey = key
      SetOverrideBindingClick(owner, true, key, button:GetName(), "LeftButton")
    end
  end
  for i = index + 1, #keyButtons do keyButtons[i].fwrKey = nil end
  local toggleKey = FWR.Data:GetToggleKey()
  if toggleKey then
    SetOverrideBindingClick(owner, true, toggleKey, TOGGLE_BUTTON, "LeftButton")
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
  return action:find("^CLICK " .. BUTTON_PREFIX) ~= nil or action:find("^CLICK " .. TOGGLE_BUTTON) ~= nil
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
