--[[
  UI/FakeCursor.lua
  The fake cursor for the Edit Set tab (DESIGN 4.5). Left-clicking a slot
  picks its item up on a fake cursor; the real item never leaves your bags,
  so the game's destroy popup can never appear.

    - Click another slot to drop it there. If that slot had an item, you
      pick that one up next (a "chain").
    - Slots that don't fit reject the drop (you keep holding the item).
    - Clicking anywhere else undoes the whole chain: every slot goes back to
      how it was before the first pickup (decided with the user).
    - Switching sets, closing the window, or right-clicking also undoes it.
]]

local _, FWR = ...
local Item = FWR.Item
local UI = FWR.UI

local FakeCursor = {}
UI.FakeCursor = FakeCursor

FakeCursor.held = nil       -- { ref = itemRef, fromSlotKey = "MAINHAND" }
FakeCursor.draft = nil      -- the draft being edited
FakeCursor.snapshot = nil   -- draft slots before the first pickup
FakeCursor.onChange = nil   -- called after any change (redraw)

-- The icon that follows the mouse.
local follower = CreateFrame("Frame", nil, UIParent)
follower:SetFrameStrata("TOOLTIP")
follower:SetSize(32, 32)
follower:Hide()
follower.icon = follower:CreateTexture(nil, "OVERLAY")
follower.icon:SetAllPoints()
follower:SetScript("OnUpdate", function(self)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  self:ClearAllPoints()
  self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale - 14)
end)

local function Changed()
  if FakeCursor.held then
    local basic = Item.Basic(FakeCursor.held.ref.link or FakeCursor.held.ref.id)
    follower.icon:SetTexture(basic and basic.icon or 134400)
    follower:Show()
  else
    follower:Hide()
  end
  if FakeCursor.onChange then FWR.SafeCall(FakeCursor.onChange) end
end

function FakeCursor.IsHolding()
  return FakeCursor.held ~= nil
end

-- Pick the item up from a slot of the draft.
function FakeCursor.PickUp(draft, slotKey)
  local slot = draft.slots[slotKey]
  if not (slot.state == "item" and slot.item) then return false end
  if not FakeCursor.held then
    FakeCursor.draft = draft
    FakeCursor.snapshot = draft:Snapshot()
  end
  FakeCursor.held = { ref = slot.item, fromSlotKey = slotKey }
  draft:Clear(slotKey)
  Changed()
  return true
end

--[[
  Drop the held item on a slot. Returns true if it was placed. If the slot
  (or, for a two-hander dropped on the Off Hand, the Main Hand) held an item,
  that item becomes the held one.
]]
function FakeCursor.DropOn(slotKey)
  local held, draft = FakeCursor.held, FakeCursor.draft
  if not held or not draft then return false end
  local fits, target, err = Item.FitsSlot(held.ref.link or held.ref.id, slotKey)
  if not fits then
    FWR:ErrorText(err)
    return false
  end
  local previous = draft.slots[target]
  local displaced = (previous.state == "item" and previous.item) or nil
  local ok, placeErr = draft:PlaceItem(slotKey, held.ref)
  if not ok then
    FWR:ErrorText(placeErr)
    return false
  end
  if displaced then
    FakeCursor.held = { ref = displaced, fromSlotKey = target }
    Changed()
  else
    FakeCursor.Finish()
  end
  return true
end

-- Chain finished normally: keep the changes.
function FakeCursor.Finish()
  FakeCursor.held = nil
  FakeCursor.snapshot = nil
  FakeCursor.draft = nil
  Changed()
end

-- Undo the whole chain.
function FakeCursor.Cancel()
  if not FakeCursor.held then return end
  if FakeCursor.draft and FakeCursor.snapshot then
    FakeCursor.draft:Restore(FakeCursor.snapshot)
  end
  FakeCursor.Finish()
end

-- Clicking anywhere that isn't one of our slot buttons undoes the chain.
-- Mouse down comes before the slot's own click, so slot clicks are skipped.
FWR:RegisterEvent("GLOBAL_MOUSE_DOWN", function()
  if not FakeCursor.held then return end
  local focus = FWR.API.GetMouseFocus()
  if focus and focus.fwrSlotKey then return end
  FakeCursor.Cancel()
end)
