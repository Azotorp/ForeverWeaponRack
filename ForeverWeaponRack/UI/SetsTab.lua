--[[
  UI/SetsTab.lua
  The Sets tab (DESIGN 4.2): one row per set.

    Name (editable) | Rename | Save as New | Edit | Equip | Up | Down | Delete

  - Edit jumps to the Edit Set tab with that set selected.
  - Equip equips the set (a click is a valid hardware action).
  - Up / Down swap with the neighbor; grayed out at the top / bottom.
  - Delete asks first.
  - Add Set sits below the table. List order = cycle order for shared keys.
]]

local _, FWR = ...
local L = FWR.L
local Sets = FWR.Sets
local Identity = FWR.Identity
local UI = FWR.UI

local SetsTab = {}
UI.SetsTab = SetsTab

local ROW_HEIGHT = 28

local function Rename(row)
  local set = Sets.Get(row.setId)
  if not set then return end
  local old = set.name
  local ok, reason = Sets.Rename(set.id, row.nameBox:GetText())
  if ok then
    FWR:Print(L.SET_RENAMED:format(old, set.name))
  else
    FWR:ErrorText(reason)
  end
end

local function SaveAsNew(row)
  local set = Sets.Get(row.setId)
  if not set then return end
  -- Includes unsaved item changes from the Edit Set tab (4.3).
  local copy, reason = Sets.SaveAsNew(set.id, row.nameBox:GetText(), UI.EditTab.DraftSlotsFor(set.id))
  if copy then
    FWR:Print(L.SET_CREATED:format(copy.name))
    row.nameBox:SetText(set.name)
  else
    FWR:ErrorText(reason)
  end
end

local function Delete(row)
  local set = Sets.Get(row.setId)
  if not set then return end
  local id, name = set.id, set.name
  FWR.Confirm(L.DELETE_SET_Q:format(name), function()
    if UI.EditTab.selectedId == id then
      UI.EditTab.selectedId, UI.EditTab.draft = nil, nil
    end
    Sets.Delete(id)
    FWR:Print(L.SET_DELETED:format(name))
  end)
end

local function UpdateRowNaming(row)
  local set = Sets.Get(row.setId)
  local ok, reason = false, nil
  if set then ok, reason = Sets.CheckName(row.nameBox:GetText(), set.name) end
  row.nameReason = (not ok) and reason or nil
  row.rename:SetEnabled(ok)
  row.saveAsNew:SetEnabled(ok)
end

local function CreateRow(parent, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
  row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints()
  row.stripe:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.04 or 0)

  row.check = row:CreateTexture(nil, "OVERLAY")
  row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  row.check:SetSize(16, 16)
  row.check:SetPoint("LEFT", 2, 0)

  row.alert = CreateFrame("Frame", nil, row)
  row.alert:SetSize(16, 16)
  row.alert:SetPoint("LEFT", 18, 0)
  local alertTex = row.alert:CreateTexture(nil, "OVERLAY")
  alertTex:SetAllPoints()
  alertTex:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  UI.SetTooltip(row.alert, L.KEY_NO_KEY_BOUND, L.KEY_NO_KEY_BOUND_TIP)

  row.nameBox = UI.EditBox(row, 140, function() UpdateRowNaming(row) end, function()
    if row.rename:IsEnabled() then Rename(row) end
  end)
  row.nameBox:SetPoint("LEFT", 42, 0)

  local function tip() return row.nameReason or L.HINT_RENAME end
  row.rename = UI.Button(row, L.RENAME, 62, function() Rename(row) end, L.RENAME, tip)
  row.rename:SetPoint("LEFT", row.nameBox, "RIGHT", 6, 0)
  row.saveAsNew = UI.Button(row, L.SAVE_AS_NEW, 88, function() SaveAsNew(row) end, L.SAVE_AS_NEW, tip)
  row.saveAsNew:SetPoint("LEFT", row.rename, "RIGHT", 3, 0)
  row.edit = UI.Button(row, L.EDIT, 44, function()
    UI.MainWindow.ShowTab("edit")
    UI.EditTab.Select(row.setId)
  end)
  row.edit:SetPoint("LEFT", row.saveAsNew, "RIGHT", 3, 0)
  row.equip = UI.Button(row, L.EQUIP, 50, function()
    FWR.Swap.Request({ kind = "set", setId = row.setId, source = "click" })
  end)
  row.equip:SetPoint("LEFT", row.edit, "RIGHT", 3, 0)
  row.up = UI.Button(row, L.UP, 36, function() Sets.Move(row.setId, -1) end)
  row.up:SetPoint("LEFT", row.equip, "RIGHT", 3, 0)
  row.down = UI.Button(row, L.DOWN, 46, function() Sets.Move(row.setId, 1) end)
  row.down:SetPoint("LEFT", row.up, "RIGHT", 3, 0)
  row.delete = UI.Button(row, L.DELETE, 56, function() Delete(row) end)
  row.delete:SetPoint("LEFT", row.down, "RIGHT", 3, 0)
  return row
end

function SetsTab.Create(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  SetsTab.frame = f

  f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 8, -8)
  f.scroll:SetPoint("BOTTOMRIGHT", -28, 40)
  f.list = CreateFrame("Frame", nil, f.scroll)
  f.list:SetSize(10, 10)
  f.scroll:SetScrollChild(f.list)
  f.scroll:SetScript("OnSizeChanged", function(self, width) f.list:SetWidth(width) end)
  f.rows = {}

  f.empty = UI.Label(f, L.NO_SETS_HINT, "GameFontDisable")
  f.empty:SetPoint("TOP", 0, -40)

  f.addButton = UI.Button(f, L.ADD_SET, 110, function()
    local set = Sets.Create(Sets.NextDefaultName(), Sets.SlotsFromEquipped())
    FWR:Print(L.SET_CREATED:format(set.name))
  end)
  f.addButton:SetPoint("BOTTOMLEFT", 10, 10)
  return f
end

function SetsTab.Refresh()
  local f = SetsTab.frame
  if not f or not f:IsVisible() then return end
  local sets = Sets.All()
  f.list:SetWidth(f.scroll:GetWidth())
  for i, set in ipairs(sets) do
    local row = f.rows[i]
    if not row then
      row = CreateRow(f.list, i)
      f.rows[i] = row
    end
    -- Don't wipe a name the player is typing.
    local typing = row.nameBox:HasFocus() and row.setId == set.id
    row.setId = set.id
    if not typing then row.nameBox:SetText(set.name) end
    row.check:SetShown(Identity.IsWearing(set))
    row.alert:SetShown(set.keyLost and not set.key and true or false)
    row.up:SetEnabled(i > 1)
    row.down:SetEnabled(i < #sets)
    UpdateRowNaming(row)
    row:Show()
  end
  for i = #sets + 1, #f.rows do f.rows[i]:Hide() end
  f.list:SetHeight(math.max(1, #sets * ROW_HEIGHT))
  f.empty:SetShown(#sets == 0)
end
