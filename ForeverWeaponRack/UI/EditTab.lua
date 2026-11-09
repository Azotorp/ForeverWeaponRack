--[[
  UI/EditTab.lua
  The Edit Set tab (DESIGN 4.1):
    - set dropdown (checkmark next to sets you're wearing)
    - name box with Rename and Save as New (naming rules, 4.3)
    - the four slots (states 3.2, smart rules 3.3, picking items 4.5,
      indicators 4.6)
    - key binding box for the set (5)
    - Save and Cancel for item changes (4.4)

  Editing never equips anything; it only changes saved data, so all of it
  works in combat.
]]

local _, FWR = ...
local L = FWR.L
local Sets = FWR.Sets
local Identity = FWR.Identity
local Tooltip = FWR.Tooltip
local Item = FWR.Item
local UI = FWR.UI
local FakeCursor = UI.FakeCursor
local Flyout = UI.Flyout

local EditTab = {}
UI.EditTab = EditTab

EditTab.selectedId = nil
EditTab.draft = nil

------------------------------------------------------------------------------
-- Where did the item on the real cursor come from? (drag and drop)
-- The game's cursor info has no bag position, so we note every pickup.
------------------------------------------------------------------------------

local lastPickup

if C_Container and C_Container.PickupContainerItem then
  hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot)
    lastPickup = { bag = bag, slot = slot }
  end)
elseif _G.PickupContainerItem then
  hooksecurefunc("PickupContainerItem", function(bag, slot)
    lastPickup = { bag = bag, slot = slot }
  end)
end
hooksecurefunc("PickupInventoryItem", function(inv)
  lastPickup = { inv = inv }
end)

-- The exact copy on the cursor, if we can tell; otherwise any copy.
local function CursorEntry(itemID, link)
  Identity.Invalidate()
  if lastPickup then
    local entry = Identity.FindAt(lastPickup.bag, lastPickup.slot, lastPickup.inv)
    if entry and entry.id == itemID then return entry end
  end
  local fallback
  for _, entry in ipairs(Identity.Scan()) do
    if entry.link == link then return entry end
    if entry.id == itemID and not fallback then fallback = entry end
  end
  return fallback
end

------------------------------------------------------------------------------
-- Selection and the unsaved-changes prompt
------------------------------------------------------------------------------

function EditTab.Selected()
  return Sets.Get(EditTab.selectedId)
end

function EditTab.IsDirty()
  return EditTab.draft ~= nil and EditTab.draft:IsDirty()
end

-- Unsaved draft slots for a set (Save as New from the Sets tab uses them).
function EditTab.DraftSlotsFor(setId)
  local draft = EditTab.draft
  if draft and draft.setId == setId and draft:IsDirty() then return draft.slots end
  return nil
end

--[[
  "Save changes?" (4.4): runs onContinue once the draft is saved or
  discarded; Cancel keeps everything as it is. onCancel is optional.
]]
function EditTab.ConfirmLeave(onContinue, onCancel)
  FakeCursor.Cancel()
  local draft, set = EditTab.draft, EditTab.Selected()
  if not (draft and set and draft:IsDirty()) then return onContinue() end
  UI.ShowDialog({
    text = L.SAVE_CHANGES_Q:format(set.name),
    buttons = {
      { text = L.SAVE, onClick = function()
          local ok, reason = draft:Save()
          if ok then
            FWR:Print(L.SET_SAVED:format(set.name))
            onContinue()
          else
            FWR:ErrorAndPrint(reason)
            if onCancel then onCancel() end
          end
        end },
      { text = L.DISCARD, onClick = function()
          draft:Revert()
          onContinue()
        end },
      { text = L.CANCEL, onClick = onCancel },
    },
    onCancel = onCancel,
  })
end

-- Select a set right away (no prompt).
function EditTab.SelectNow(setId)
  FakeCursor.Cancel()
  Flyout.Hide()
  local set = Sets.Get(setId)
  EditTab.selectedId = set and set.id or nil
  EditTab.draft = set and Sets.NewDraft(set) or nil
  if EditTab.frame then
    EditTab.frame.nameBox:SetText(set and set.name or "")
    EditTab.Refresh()
  end
end

-- Select a set, asking first if there are unsaved changes.
function EditTab.Select(setId)
  if setId == EditTab.selectedId and EditTab.draft then return end
  EditTab.ConfirmLeave(function() EditTab.SelectNow(setId) end)
end

------------------------------------------------------------------------------
-- Putting items in slots
------------------------------------------------------------------------------

local function Place(slotKey, ref, entry)
  local draft = EditTab.draft
  if not draft then return end
  local ok, err = draft:PlaceItem(slotKey, ref, entry)
  if not ok then FWR:ErrorText(err) end
  EditTab.Refresh()
end

-- Drop whatever is on the real cursor (dragged from bags or the character
-- sheet). The item goes straight back where it came from.
local function DropFromCursor(slotKey)
  local kind, itemID, link = GetCursorInfo()
  if kind ~= "item" then return false end
  local entry = CursorEntry(itemID, link)
  local ref
  if entry then
    ref = Identity.MakeRef(entry)
  else
    ref = { id = itemID, link = link, str = Identity.ItemString(link) }
  end
  ClearCursor()
  Place(slotKey, ref, entry)
  return true
end

function EditTab.PlaceEntry(slotKey, entry)
  Place(slotKey, Identity.MakeRef(entry), entry)
end

------------------------------------------------------------------------------
-- Slot handlers
------------------------------------------------------------------------------

local flyoutTimer

local function CancelFlyoutTimer()
  if flyoutTimer then
    flyoutTimer:Cancel()
    flyoutTimer = nil
  end
end

local function RangedAmmoType()
  local ranged = EditTab.draft and EditTab.draft.slots.RANGED
  if ranged and ranged.state == "item" and ranged.item then
    return Item.RangedAmmoType(ranged.item.id)
  end
  return nil
end

local handlers = {}

function handlers.OnClick(slotKey, mouseButton, button)
  local draft = EditTab.draft
  if not draft then return end
  Flyout.Hide()
  CancelFlyoutTimer()

  local slot = draft.slots[slotKey]
  -- Shift-click links the item in chat, like everywhere else in the game.
  if mouseButton == "LeftButton" and IsModifiedClick and IsModifiedClick("CHATLINK")
      and slot.item and slot.item.link and HandleModifiedItemClick then
    HandleModifiedItemClick(slot.item.link)
    return
  end

  if CursorHasItem() and mouseButton == "LeftButton" then
    DropFromCursor(slotKey)
    return
  end

  if FakeCursor.IsHolding() then
    if mouseButton == "LeftButton" then
      FakeCursor.DropOn(slotKey)
    else
      FakeCursor.Cancel()
    end
    EditTab.Refresh()
    button:ShowTooltip(FakeCursor.IsHolding())
    return
  end

  if mouseButton == "LeftButton" then
    FakeCursor.PickUp(draft, slotKey)
  else
    draft:Cycle(slotKey)
  end
  EditTab.Refresh()
  button:ShowTooltip(FakeCursor.IsHolding())
end

function handlers.OnReceiveDrag(slotKey)
  if DropFromCursor(slotKey) then return end
  if FakeCursor.IsHolding() then
    FakeCursor.DropOn(slotKey)
    EditTab.Refresh()
  end
end

function handlers.OnEnter(slotKey, button)
  button:ShowTooltip(FakeCursor.IsHolding())
  CancelFlyoutTimer()
  if FakeCursor.IsHolding() or CursorHasItem() then return end
  if Flyout.IsFor(button) then return end
  local delay = FWR.Data:Profile().flyoutDelay or 0.35
  flyoutTimer = C_Timer.NewTimer(delay, function()
    flyoutTimer = nil
    if not button:IsVisible() or not button:IsMouseOver() then return end
    if FakeCursor.IsHolding() or CursorHasItem() then return end
    local slot = EditTab.draft and EditTab.draft.slots[slotKey]
    GameTooltip:Hide()
    Flyout.Show(button, slotKey, {
      ammoType = RangedAmmoType(),
      current = slot and slot.state == "item" and slot.item or nil,
      onPick = function(entry) EditTab.PlaceEntry(slotKey, entry) end,
    })
  end)
end

function handlers.OnLeave()
  CancelFlyoutTimer()
  GameTooltip:Hide()
end

------------------------------------------------------------------------------
-- Building the tab
------------------------------------------------------------------------------

function EditTab.Create(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  EditTab.frame = f

  -- Set dropdown
  local setLabel = UI.Label(f, L.SET_LABEL)
  setLabel:SetPoint("TOPLEFT", 12, -14)
  f.dropdown = UI.Dropdown(f, 240, function()
    local items = {}
    for _, set in ipairs(Sets.All()) do
      items[#items + 1] = {
        text = set.name,
        checked = Identity.IsWearing(set),
        onSelect = function() EditTab.Select(set.id) end,
      }
    end
    return items
  end)
  f.dropdown:SetPoint("LEFT", setLabel, "LEFT", 60, 0)
  UI.SetTooltip(f.dropdown, L.SET_LABEL, L.SELECT_SET)

  -- Name box with Rename and Save as New
  local nameLabel = UI.Label(f, L.NAME_LABEL)
  nameLabel:SetPoint("TOPLEFT", 12, -50)
  f.nameBox = UI.EditBox(f, 200, function() EditTab.RefreshNaming() end, function()
    if f.renameButton:IsEnabled() then f.renameButton:Click() end
  end)
  f.nameBox:SetPoint("LEFT", nameLabel, "LEFT", 66, 0)
  f.renameButton = UI.Button(f, L.RENAME, 80, function() EditTab.Rename() end, L.RENAME,
    function() return f.nameReason or L.HINT_RENAME end)
  f.renameButton:SetPoint("LEFT", f.nameBox, "RIGHT", 8, 0)
  f.saveAsNewButton = UI.Button(f, L.SAVE_AS_NEW, 100, function() EditTab.SaveAsNew() end, L.SAVE_AS_NEW,
    function() return f.nameReason or L.HINT_RENAME end)
  f.saveAsNewButton:SetPoint("LEFT", f.renameButton, "RIGHT", 4, 0)

  -- Slots
  f.slots = {}
  for i, slotKey in ipairs(FWR.SLOT_ORDER) do
    local button = UI.CreateSlotButton(f, slotKey, handlers)
    button:SetPoint("TOPLEFT", 40 + (i - 1) * 96, -92)
    f.slots[slotKey] = button
  end

  -- Key binding
  local keyLabel = UI.Label(f, L.KEY_LABEL)
  keyLabel:SetPoint("TOPLEFT", 12, -186)
  f.keyBox = UI.KeyCapture(f, 180, {
    getKey = function()
      local set = EditTab.Selected()
      return set and set.key
    end,
    onKey = function(key)
      local set = EditTab.Selected()
      if not set then return end
      FWR.Bindings.RequestSetKey(set.id, key, function() EditTab.Refresh() end)
    end,
    onClear = function()
      local set = EditTab.Selected()
      if set then FWR.Bindings.SetSetKey(set.id, nil) end
    end,
  })
  f.keyBox:SetPoint("LEFT", keyLabel, "LEFT", 66, 0)
  UI.SetTooltip(f.keyBox, L.KEY_LABEL, function()
    local lines = { L.KEY_CLICK_TO_BIND, L.KEY_RIGHT_TO_CLEAR, L.KEY_ESC_CANCEL }
    local set = EditTab.Selected()
    if set and set.keyLost and not set.key then
      table.insert(lines, 1, "|cffff3333" .. L.KEY_NO_KEY_BOUND_TIP .. "|r")
    end
    return lines
  end)
  f.keyInfo = UI.Label(f, "", "GameFontHighlightSmall")
  f.keyInfo:SetPoint("LEFT", f.keyBox, "RIGHT", 10, 0)
  f.keyInfo:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.keyInfo:SetWordWrap(true)

  -- Save / Cancel
  f.saveButton = UI.Button(f, L.SAVE, 90, function() EditTab.Save() end, L.SAVE,
    function() return f.saveReason or L.HINT_UNSAVED end)
  f.saveButton:SetPoint("TOPLEFT", 12, -224)
  f.cancelButton = UI.Button(f, L.CANCEL, 90, function()
    FakeCursor.Cancel()
    if EditTab.draft then EditTab.draft:Revert() end
    EditTab.Refresh()
  end)
  f.cancelButton:SetPoint("LEFT", f.saveButton, "RIGHT", 6, 0)
  f.hint = UI.Label(f, "", "GameFontHighlightSmall")
  f.hint:SetPoint("LEFT", f.cancelButton, "RIGHT", 10, 0)
  f.hint:SetPoint("RIGHT", f, "RIGHT", -12, 0)

  -- Shown when there are no sets
  f.emptyHint = UI.Label(f, L.NO_SETS_HINT, "GameFontHighlight")
  f.emptyHint:SetPoint("TOP", 0, -100)
  f.addButton = UI.Button(f, L.ADD_SET, 110, function() EditTab.AddSet() end)
  f.addButton:SetPoint("TOP", f.emptyHint, "BOTTOM", 0, -12)

  f.content = { setLabel, f.dropdown, nameLabel, f.nameBox, f.renameButton, f.saveAsNewButton,
                keyLabel, f.keyBox, f.keyInfo, f.saveButton, f.cancelButton, f.hint }

  FakeCursor.onChange = function() EditTab.Refresh() end
  f:SetScript("OnHide", function()
    FakeCursor.Cancel()
    Flyout.Hide()
    CancelFlyoutTimer()
  end)
  return f
end

------------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------------

function EditTab.AddSet()
  local set = Sets.Create(Sets.NextDefaultName(), Sets.SlotsFromEquipped())
  FWR:Print(L.SET_CREATED:format(set.name))
  EditTab.SelectNow(set.id)
end

function EditTab.Rename()
  local set = EditTab.Selected()
  if not set then return end
  local old = set.name
  local ok, reason = Sets.Rename(set.id, EditTab.frame.nameBox:GetText())
  if ok then
    FWR:Print(L.SET_RENAMED:format(old, set.name))
  else
    FWR:ErrorText(reason)
  end
  EditTab.frame.nameBox:SetText(set.name)
  EditTab.Refresh()
end

-- Copies the set under the new name, including unsaved item changes (4.3).
function EditTab.SaveAsNew()
  local set = EditTab.Selected()
  if not set then return end
  FakeCursor.Cancel()
  local copy, reason = Sets.SaveAsNew(set.id, EditTab.frame.nameBox:GetText(), EditTab.draft.slots)
  if not copy then
    FWR:ErrorText(reason)
    return
  end
  FWR:Print(L.SET_CREATED:format(copy.name))
  EditTab.draft:Revert()
  EditTab.SelectNow(copy.id)
end

function EditTab.Save()
  local set, draft = EditTab.Selected(), EditTab.draft
  if not (set and draft) then return end
  FakeCursor.Cancel()
  local ok, reason = draft:Save()
  if ok then
    FWR:Print(L.SET_SAVED:format(set.name))
  elseif reason then
    FWR:ErrorAndPrint(reason)
  end
  EditTab.Refresh()
end

------------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------------

function EditTab.RefreshNaming()
  local f, set = EditTab.frame, EditTab.Selected()
  if not f then return end
  local ok, reason = false, nil
  if set then ok, reason = Sets.CheckName(f.nameBox:GetText(), set.name) end
  f.nameReason = (not ok) and reason or nil
  f.renameButton:SetEnabled(ok)
  f.saveAsNewButton:SetEnabled(ok)
end

-- View data for one slot button.
local function SlotView(slotKey, draft, resolved)
  local slot = draft.slots[slotKey]
  local r = resolved[slotKey]
  local state = slot.state
  if state == "item" and not slot.item then state = "skip" end
  local view = {
    state = state,
    item = slot.item,
    hidden = slotKey == "AMMO" and not Identity.AmmoApplies(draft.slots),
    entry = r.entry,
    missing = r.missing,
    inBank = r.inBank,
    closest = r.closest,
  }
  if r.state ~= "skip" then
    view.equipped = Identity.SlotSatisfied(slotKey, r)
  end
  if state == "item" and r.entry and r.entry.where == "bag" and slotKey ~= "AMMO" then
    view.boe = Tooltip.IsUnboundBoE(r.entry)
    view.trade = Tooltip.IsTradeable(r.entry)
    view.refund = Tooltip.IsRefundable(r.entry)
  end
  return view
end

function EditTab.Refresh()
  local f = EditTab.frame
  if not f or not f:IsVisible() then return end

  -- Keep the selection valid.
  local set = EditTab.Selected()
  if not set then
    local first = Sets.All()[1]
    if first then
      EditTab.SelectNow(first.id)
      return
    end
    EditTab.selectedId, EditTab.draft = nil, nil
  end

  local hasSet = set ~= nil
  for _, widget in ipairs(f.content) do widget:SetShown(hasSet) end
  for _, button in pairs(f.slots) do
    if not hasSet then
      button:Hide()
      button.label:Hide()
      button.stateText:Hide()
    end
  end
  f.emptyHint:SetShown(not hasSet)
  f.addButton:SetShown(not hasSet)
  if not hasSet then return end

  local draft = EditTab.draft
  local dirty = draft:IsDirty()

  -- Dropdown text: name, worn check, unsaved mark
  local text = set.name
  if Identity.IsWearing(set) then text = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " .. text end
  if dirty then text = text .. " |cffff8c1a" .. L.UNSAVED_MARK .. "|r" end
  f.dropdown:SetText(text)

  EditTab.RefreshNaming()

  -- Slots
  local resolved = Identity.Resolve(draft.slots)
  for _, slotKey in ipairs(FWR.SLOT_ORDER) do
    f.slots[slotKey]:Update(SlotView(slotKey, draft, resolved))
  end

  -- Key box and its info line
  f.keyBox:Refresh()
  local info = ""
  if set.key then
    local shared = FWR.Bindings.SharedWith(set.id, set.key)
    if #shared > 0 then
      local names = {}
      for _, other in ipairs(shared) do names[#names + 1] = other.name end
      info = L.KEY_SHARED:format(table.concat(names, ", "))
    end
    if FWR.Bindings.pending then info = (info ~= "" and (info .. "\n") or "") .. L.KEY_PENDING end
  elseif set.keyLost then
    info = "|cffff3333" .. L.KEY_NO_KEY_BOUND .. "|r"
  end
  f.keyInfo:SetText(info)

  -- Save / Cancel
  local allSkip = Sets.AllSkip(draft.slots)
  f.saveReason = allSkip and L.HINT_ALL_SKIP or nil
  f.saveButton:SetEnabled(dirty and not allSkip)
  f.cancelButton:SetEnabled(dirty or FakeCursor.IsHolding())
  if allSkip then
    f.hint:SetText("|cffffd200" .. L.HINT_ALL_SKIP .. "|r")
  elseif dirty then
    f.hint:SetText(L.HINT_UNSAVED)
  else
    f.hint:SetText("")
  end
end
