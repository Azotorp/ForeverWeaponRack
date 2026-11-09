-- Shared-key cycling, toggle exclusivity and key validation.
local test, check, eq, S, FWR = T.test, T.check, T.eq, T.S, T.FWR

local overrides = {}
_G.ClearOverrideBindings = function() overrides = {} end
_G.SetOverrideBindingClick = function(_, _, key, button) overrides[key] = "CLICK " .. button .. ":LeftButton" end
_G.GetBindingAction = function(key) return overrides[key] or (key == "Q" and "MOVEFORWARD") or "" end
_G.BINDING_NAME_MOVEFORWARD = "Move Forward"

local confirmCalls = {}

local function ref(id)
  local link = S.Link(id)
  return { id = id, link = link, str = FWR.Identity.ItemString(link) }
end

local function reset()
  local db = FWR.Data.char
  db.sets, db.order, db.cycle, db.nextSetId = {}, {}, {}, 1
  FWR.Data:SetToggleKey(nil)
  confirmCalls = {}
  FWR.Confirm = function(text, onAccept, onCancel)
    confirmCalls[#confirmCalls + 1] = { text = text, accept = onAccept, cancel = onCancel }
  end
end

local function mk(name, id, key)
  local slots = FWR.Sets.NewSlots()
  slots.MAINHAND = { state = "item", item = ref(id) }
  local set = FWR.Sets.Create(name, slots)
  set.key = key
  return set
end

test("Shared key cycles in list order, wraps, skips worn sets and other keys", function()
  reset()
  S.bags[0][1] = S.Item(100); S.bags[0][2] = S.Item(101); S.bags[0][3] = S.Item(102)
  FWR.Identity.Invalidate()
  local a = mk("A", 100, "F")
  mk("X", 100, "G")
  local b = mk("B", 101, "F")
  local c = mk("C", 102, "F")
  eq(FWR.Bindings.PickForKey("F"), a, "first press: A")
  FWR.Bindings.Remember("F", a)
  eq(FWR.Bindings.PickForKey("F"), b, "then B")
  FWR.Bindings.Remember("F", c)
  eq(FWR.Bindings.PickForKey("F"), a, "wraps to A")
  -- Wearing A: it gets skipped.
  S.equipped[16] = S.bags[0][1]; S.bags[0][1] = nil
  FWR.Identity.Invalidate()
  eq(FWR.Bindings.PickForKey("F"), b, "worn A skipped")
end)

test("Key press through the hidden button equips and remembers", function()
  reset()
  S.bags[0][1] = S.Item(100); S.bags[0][2] = S.Item(101)
  FWR.Identity.Invalidate()
  local a = mk("A", 100, "F")
  local b = mk("B", 101, "F")
  FWR.Bindings.Apply()
  check(overrides.F ~= nil, "override set")
  local buttonName = overrides.F:match("CLICK ([^:]+)")
  local button = _G[buttonName]
  button.__scripts.OnClick(button, "LeftButton", true)
  button.__scripts.OnClick(button, "LeftButton", false)   -- key up: ignored
  for _ = 1, 6 do S.Settle() end
  eq(S.equipped[16] and S.equipped[16].id, 100, "A equipped")
  eq(FWR.Data.char.cycle.F, a.id, "remembered A")
  button.__scripts.OnClick(button, "LeftButton", true)
  for _ = 1, 6 do S.Settle() end
  eq(S.equipped[16] and S.equipped[16].id, 101, "B equipped")
  eq(FWR.Data.char.cycle.F, b.id)
end)

test("Bindings changed in combat go live after combat", function()
  reset()
  mk("A", 100, "H")
  S.combat = true
  overrides = {}
  check(not FWR.Bindings.Apply(), "deferred")
  check(FWR.Bindings.pending, "pending")
  eq(overrides.H, nil, "not live yet")
  S.combat = false
  S.Fire("PLAYER_REGEN_ENABLED")
  check(overrides.H ~= nil, "live after combat")
  check(not FWR.Bindings.pending)
end)

test("Toggle key is exclusive: sets lose it and show No key bound", function()
  reset()
  local a = mk("A", 100, "T")
  FWR.Bindings.RequestToggleKey("T")
  eq(#confirmCalls, 1, "asked first")
  confirmCalls[1].accept()
  eq(a.key, nil, "set lost its key")
  check(a.keyLost, "flagged")
  eq(FWR.Data:GetToggleKey(), "T")
  confirmCalls = {}
  local done
  FWR.Bindings.RequestSetKey(a.id, "T", function(ok) done = ok end)
  eq(done, false, "set can't take the toggle key")
  FWR.Data:SetToggleKey(nil)
end)

test("Conflicts with other bindings ask; plain clicks blocked", function()
  reset()
  local a = mk("A", 100, nil)
  FWR.Bindings.RequestSetKey(a.id, "Q")
  eq(#confirmCalls, 1, "asked")
  check(confirmCalls[1].text:find("Move Forward"), "names the other binding")
  confirmCalls[1].accept()
  eq(a.key, "Q")
  check(not FWR.Bindings.Validate("BUTTON1"), "plain left click blocked")
  check(not FWR.Bindings.Validate("BUTTON2"), "plain right click blocked")
  check(FWR.Bindings.Validate("SHIFT-BUTTON1"), "modified click allowed")
  check(FWR.Bindings.IsModifiedClick("SHIFT-BUTTON1"), "with a warning")
  check(FWR.Bindings.Validate("BUTTON4"), "mouse 4")
  check(FWR.Bindings.Validate("CTRL-MOUSEWHEELUP"), "wheel")
end)
