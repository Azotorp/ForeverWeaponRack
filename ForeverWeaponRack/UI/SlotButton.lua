--[[
  UI/SlotButton.lua
  One set slot on the Edit Set tab (DESIGN 3.2 visuals, 4.6 indicators).

  States:
    Item         item icon, border in the item's quality color
    Empty        solid empty-slot background (same art as the character
                 sheet), border in a distinct "empty on purpose" color
    Leave alone  semi-transparent empty-slot background, no border

  Indicators: equipped check, red "missing" tint, BoE / Tradeable /
  Refundable badges, and a tooltip on everything.

  The button only draws. Clicks, drops and hover are passed to handlers:
    handlers.OnClick(slotKey, mouseButton)
    handlers.OnReceiveDrag(slotKey)
    handlers.OnEnter(slotKey, button) / handlers.OnLeave(slotKey, button)
]]

local _, FWR = ...
local L = FWR.L
local API = FWR.API
local UI = FWR.UI

local SIZE = 42
local EMPTY_BORDER = { 1.0, 0.55, 0.1 }   -- "empty on purpose"

local SLOT_NAMES = {
  MAINHAND = L.SLOT_MAINHAND, OFFHAND = L.SLOT_OFFHAND,
  RANGED = L.SLOT_RANGED, AMMO = L.SLOT_AMMO,
}
UI.SLOT_NAMES = SLOT_NAMES

local function Badge(button, point, x, y, r, g, b, text)
  local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  fs:SetPoint(point, x, y)
  fs:SetTextColor(r, g, b)
  fs:SetText(text)
  fs:Hide()
  return fs
end

function UI.CreateSlotButton(parent, slotKey, handlers)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(SIZE, SIZE)
  button.fwrSlotKey = slotKey    -- FakeCursor uses this to recognise slots
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  button.background = button:CreateTexture(nil, "BACKGROUND")
  button.background:SetPoint("TOPLEFT", 2, -2)
  button.background:SetPoint("BOTTOMRIGHT", -2, 2)
  button.background:SetTexture(FWR.Slots[slotKey].emptyTexture)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 2, -2)
  button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  button.missingTint = button:CreateTexture(nil, "OVERLAY")
  button.missingTint:SetAllPoints(button.icon)
  button.missingTint:SetColorTexture(0.9, 0, 0, 0.35)
  button.missingTint:Hide()

  button.check = button:CreateTexture(nil, "OVERLAY")
  button.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  button.check:SetSize(16, 16)
  button.check:SetPoint("TOPRIGHT", 4, 4)
  button.check:Hide()

  button.badgeBoE = Badge(button, "BOTTOMLEFT", 3, 2, 0.2, 1, 0.2, L.BADGE_BOE)
  button.badgeTrade = Badge(button, "TOPLEFT", 3, -2, 1, 0.82, 0, L.BADGE_TRADE)
  button.badgeRefund = Badge(button, "BOTTOMRIGHT", -3, 2, 0.4, 0.8, 1, L.BADGE_REFUND)

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  button.label = UI.Label(parent, SLOT_NAMES[slotKey], "GameFontNormalSmall")
  button.label:SetPoint("TOP", button, "BOTTOM", 0, -3)
  button.label:SetJustifyH("CENTER")

  button.stateText = UI.Label(parent, "", "GameFontHighlightSmall")
  button.stateText:SetPoint("TOP", button.label, "BOTTOM", 0, -1)
  button.stateText:SetJustifyH("CENTER")

  if button.SetBackdrop then
    button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  end

  button:SetScript("OnClick", function(self, mouseButton) handlers.OnClick(slotKey, mouseButton, self) end)
  button:SetScript("OnReceiveDrag", function() handlers.OnReceiveDrag(slotKey) end)
  button:SetScript("OnEnter", function(self) handlers.OnEnter(slotKey, self) end)
  button:SetScript("OnLeave", function(self) handlers.OnLeave(slotKey, self) end)

  function button:SetBorder(r, g, b, a)
    if self.SetBackdropBorderColor then self:SetBackdropBorderColor(r, g, b, a or 1) end
  end

  --[[
    view = {
      state, item (remembered ref), hidden (Ammo not used),
      entry, missing, inBank, closest, equipped, boe, trade, refund
    }
  ]]
  function button:Update(view)
    self.view = view
    local hidden = view.hidden
    self:SetShown(not hidden)
    self.label:SetShown(not hidden)
    self.stateText:SetShown(not hidden)
    if hidden then return end

    local state = view.state
    self.check:Hide()
    self.missingTint:Hide()
    self.badgeBoE:Hide()
    self.badgeTrade:Hide()
    self.badgeRefund:Hide()

    if state == "item" and view.item then
      local basic = FWR.Item.Basic(view.item.link or view.item.id)
      self.icon:SetTexture((view.entry and view.entry.icon) or (basic and basic.icon) or 134400)
      self.icon:SetAlpha(1)
      self.icon:Show()
      self.background:SetAlpha(1)
      local quality = (view.entry and view.entry.quality) or FWR.Item.Details(view.item.link or view.item.id).quality
      local r, g, b = API.GetItemQualityColor(quality or 1)
      self:SetBorder(r, g, b, 1)
      self.check:SetShown(view.equipped and true or false)
      if view.missing then
        self.missingTint:Show()
        self.icon:SetVertexColor(1, 0.4, 0.4)
      else
        self.icon:SetVertexColor(1, 1, 1)
      end
      self.badgeBoE:SetShown(view.boe and true or false)
      self.badgeTrade:SetShown(view.trade and true or false)
      self.badgeRefund:SetShown(view.refund and true or false)
      self.stateText:SetText("")
    elseif state == "empty" then
      self.icon:Hide()
      self.background:SetAlpha(1)
      self:SetBorder(EMPTY_BORDER[1], EMPTY_BORDER[2], EMPTY_BORDER[3], 1)
      self.check:SetShown(view.equipped and true or false)
      self.stateText:SetText("|cffff8c1a" .. L.STATE_EMPTY .. "|r")
    else -- skip / Leave alone
      self.icon:Hide()
      self.background:SetAlpha(0.35)
      self:SetBorder(0, 0, 0, 0)
      self.stateText:SetText("|cff888888" .. L.STATE_SKIP .. "|r")
    end
  end

  -- Tooltip: the item (exact copy if we have it) plus state and hints.
  function button:ShowTooltip(holding)
    local view = self.view
    if not view or view.hidden then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shownItem = false
    if view.state == "item" and view.item then
      local entry = view.entry
      if entry and entry.where == "bag" then
        GameTooltip:SetBagItem(entry.bag, entry.slot)
        shownItem = true
      elseif entry and entry.where == "inv" then
        GameTooltip:SetInventoryItem("player", entry.inv)
        shownItem = true
      elseif view.item.link then
        GameTooltip:SetHyperlink(view.item.link)
        shownItem = true
      end
    end
    if not shownItem then
      GameTooltip:SetText(SLOT_NAMES[slotKey], 1, 1, 1)
    else
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(SLOT_NAMES[slotKey], 1, 1, 1)
    end
    local stateName = (view.state == "item" and L.STATE_ITEM) or (view.state == "empty" and L.STATE_EMPTY) or L.STATE_SKIP
    local stateDesc = (view.state == "item" and L.STATE_ITEM_DESC) or (view.state == "empty" and L.STATE_EMPTY_DESC) or L.STATE_SKIP_DESC
    GameTooltip:AddDoubleLine(stateName, "", 1, 0.82, 0)
    GameTooltip:AddLine(stateDesc, 0.8, 0.8, 0.8, true)
    if view.state ~= "item" and view.item then
      GameTooltip:AddLine(L.TIP_REMEMBERED:format(view.item.link or tostring(view.item.id)), 0.7, 0.7, 0.7, true)
    end
    if view.state == "item" then
      if view.equipped then GameTooltip:AddLine(L.TIP_EQUIPPED, 0.2, 1, 0.2, true) end
      if view.missing then
        GameTooltip:AddLine(view.inBank and L.TIP_IN_BANK or L.TIP_MISSING, 1, 0.2, 0.2, true)
      elseif view.closest then
        GameTooltip:AddLine(L.TIP_CLOSEST, 1, 0.82, 0, true)
      end
      if view.boe then GameTooltip:AddLine(L.TIP_BOE, 0.2, 1, 0.2, true) end
      if view.trade then GameTooltip:AddLine(L.TIP_TRADE, 1, 0.82, 0, true) end
      if view.refund then GameTooltip:AddLine(L.TIP_REFUND, 0.4, 0.8, 1, true) end
    end
    GameTooltip:AddLine(" ")
    if holding then
      GameTooltip:AddLine(L.TIP_LEFT_DROP, 0.6, 0.8, 1, true)
    elseif view.state == "item" and view.item then
      GameTooltip:AddLine(L.TIP_LEFT_PICK, 0.6, 0.8, 1, true)
    end
    GameTooltip:AddLine(view.item and L.TIP_RIGHT_CYCLE or L.TIP_RIGHT_CYCLE_NOITEM, 0.6, 0.8, 1, true)
    GameTooltip:AddLine(L.TIP_DRAG, 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end

  return button
end
