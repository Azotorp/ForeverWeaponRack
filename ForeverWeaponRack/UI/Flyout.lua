--[[
  UI/Flyout.lua
  Hover flyout (DESIGN 4.5): hovering a slot (after the delay set in
  Settings) opens a panel of every item in your bags or equipped gear that
  fits and that you can actually equip.

    - icon, quality border and tooltip for each entry
    - click an entry to put it in the slot (same rules as drag and drop)
    - sorted by type, then highest item level, then quality
    - one column for a few items, more columns as the list grows
    - flips direction if it would go off screen
]]

local _, FWR = ...
local L = FWR.L
local API = FWR.API
local Item = FWR.Item
local Identity = FWR.Identity
local UI = FWR.UI

local Flyout = {}
UI.Flyout = Flyout

local BUTTON = 36
local GAP = 4
local PAD = 6

local frame = CreateFrame("Frame", "ForeverWeaponRackFlyout", UIParent, "BackdropTemplate")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:Hide()
UI.ApplyBackdrop(frame, 0.95)
frame.buttons = {}
frame.emptyText = UI.Label(frame, "", "GameFontDisableSmall")
frame.emptyText:SetPoint("CENTER")

local function EntryButton(i)
  local b = frame.buttons[i]
  if b then return b end
  b = CreateFrame("Button", nil, frame, "BackdropTemplate")
  b:SetSize(BUTTON, BUTTON)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.check = b:CreateTexture(nil, "OVERLAY")
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.check:SetSize(12, 12)
  b.check:SetPoint("TOPRIGHT", 3, 3)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  if b.SetBackdrop then b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 }) end
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", function(self)
    local e = self.entry
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if e.where == "bag" then
      GameTooltip:SetBagItem(e.bag, e.slot)
    else
      GameTooltip:SetInventoryItem("player", e.inv)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self)
    local pick = Flyout.onPick
    Flyout.Hide()
    if pick then pick(self.entry) end
  end)
  frame.buttons[i] = b
  return b
end

--[[
  Candidates for a slot. ammoType limits the Ammo list to what fits the
  set's ranged weapon. Ammo stacks are listed once per item.
]]
function Flyout.Candidates(slotKey, ammoType)
  local list, seenAmmo = {}, {}
  for _, entry in ipairs(Identity.Scan()) do
    local fits, target = Item.FitsSlot(entry.link, slotKey)
    if fits and target == slotKey then
      local ok = true
      if slotKey == "AMMO" then
        ok = entry.where == "bag" and not seenAmmo[entry.id] and Item.AmmoType(entry.link) == ammoType
        seenAmmo[entry.id] = true
      end
      if ok and Item.CheckUsable(entry) then
        list[#list + 1] = entry
      end
    end
  end
  table.sort(list, Item.CompareEntries)
  return list
end

-- Columns: one for up to 5 items, then a roughly square grid.
local function Layout(count)
  if count <= 5 then return 1, math.max(count, 1) end
  local rows = math.max(5, math.ceil(math.sqrt(count)))
  local cols = math.ceil(count / rows)
  return cols, rows
end

--[[
  Flyout.Show(anchor, slotKey, opts)
    opts.ammoType  "ARROW"|"BULLET" for the Ammo slot
    opts.onPick    function(entry)
    opts.current   ref currently in the slot (marked with a check)
]]
function Flyout.Show(anchor, slotKey, opts)
  local list = Flyout.Candidates(slotKey, opts.ammoType)
  Flyout.onPick = opts.onPick
  Flyout.anchor = anchor
  Flyout.slotKey = slotKey

  local cols, rows = Layout(#list)
  for i, entry in ipairs(list) do
    local b = EntryButton(i)
    b.entry = entry
    b.icon:SetTexture(entry.icon or 134400)
    local r, g, bl = API.GetItemQualityColor(entry.quality or 1)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(r, g, bl, 1) end
    b.check:SetShown(opts.current ~= nil and opts.current.id == entry.id
      and (slotKey == "AMMO" or opts.current.str == entry.str))
    if slotKey == "AMMO" then
      b.count:SetText(API.GetItemCount and API.GetItemCount(entry.id) or "")
    else
      b.count:SetText("")
    end
    local col = math.floor((i - 1) / rows)
    local row = (i - 1) % rows
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", PAD + col * (BUTTON + GAP), -PAD - row * (BUTTON + GAP))
    b:Show()
  end
  for i = #list + 1, #frame.buttons do frame.buttons[i]:Hide() end

  local width = PAD * 2 + cols * BUTTON + (cols - 1) * GAP
  local height = PAD * 2 + rows * BUTTON + (rows - 1) * GAP
  if #list == 0 then
    frame.emptyText:SetText(slotKey == "AMMO" and L.AMMO_NONE or L.FLYOUT_EMPTY)
    width, height = 160, 40
    frame.emptyText:Show()
  else
    frame.emptyText:Hide()
  end
  frame:SetSize(width, height)
  frame:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())

  -- Open to the right and down; flip if that goes off screen.
  frame:ClearAllPoints()
  local scale = frame:GetEffectiveScale()
  local screenW = UIParent:GetWidth() * UIParent:GetEffectiveScale()
  local right = (anchor:GetRight() or 0) * anchor:GetEffectiveScale() + width * scale
  local bottom = (anchor:GetTop() or 0) * anchor:GetEffectiveScale() - height * scale
  local horizontal = right > screenW and "LEFT" or "RIGHT"
  local vertical = bottom < 0 and "BOTTOM" or "TOP"
  local point = vertical .. (horizontal == "RIGHT" and "LEFT" or "RIGHT")
  local relative = vertical .. horizontal
  frame:SetPoint(point, anchor, relative, horizontal == "RIGHT" and 4 or -4, 0)
  frame:Show()
  frame.elapsed = 0
end

function Flyout.Hide()
  frame:Hide()
  Flyout.onPick = nil
  Flyout.anchor = nil
end

function Flyout.IsShown()
  return frame:IsShown()
end

function Flyout.IsFor(anchor)
  return frame:IsShown() and Flyout.anchor == anchor
end

-- Close when the mouse has left both the slot and the flyout for a moment.
frame:SetScript("OnUpdate", function(self, elapsed)
  local anchor = Flyout.anchor
  if (anchor and anchor:IsMouseOver()) or self:IsMouseOver() then
    self.elapsed = 0
    return
  end
  self.elapsed = (self.elapsed or 0) + elapsed
  if self.elapsed > 0.3 then Flyout.Hide() end
end)
