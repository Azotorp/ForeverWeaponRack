--[[
  UI/Widgets.lua
  Small building blocks used by every window: buttons, labels, edit boxes,
  check boxes, sliders, a dropdown, our own Accept/Cancel dialog, and the
  "press a key" capture box.

  The dialog and dropdown are our own frames on purpose: no shared Blizzard
  popup or menu frames are touched, so the add-on can't taint them (the
  game's own bind-confirm popup must keep working untouched, DESIGN 6.2).
]]

local _, FWR = ...
local L = FWR.L

local UI = {}
FWR.UI = UI

UI.BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function UI.ApplyBackdrop(frame, alpha)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop(UI.BACKDROP)
  frame:SetBackdropColor(0.05, 0.05, 0.08, alpha or 0.95)
  frame:SetBackdropBorderColor(0.6, 0.6, 0.65, 1)
end

------------------------------------------------------------------------------
-- Tooltips on any frame (DESIGN 4.6: tooltips on every slot and button)
------------------------------------------------------------------------------

-- lines: a string, a list of strings, or a function returning either.
function UI.SetTooltip(frame, title, lines)
  frame.fwrTipTitle, frame.fwrTipLines = title, lines
  if frame.fwrTipHooked then return end
  frame.fwrTipHooked = true
  frame:HookScript("OnEnter", function(self)
    if not self.fwrTipTitle then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.fwrTipTitle, 1, 1, 1)
    local body = self.fwrTipLines
    if type(body) == "function" then body = body(self) end
    if type(body) == "string" then body = { body } end
    for _, line in ipairs(body or {}) do
      GameTooltip:AddLine(line, nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------------
-- Basic widgets
------------------------------------------------------------------------------

function UI.Button(parent, text, width, onClick, tipTitle, tipLines)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 80, 22)
  button:SetText(text)
  if onClick then button:SetScript("OnClick", onClick) end
  if tipTitle then UI.SetTooltip(button, tipTitle, tipLines) end
  -- Disabled buttons still show their tooltip (it explains why).
  if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
  return button
end

function UI.Label(parent, text, font)
  local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  label:SetText(text or "")
  label:SetJustifyH("LEFT")
  return label
end

function UI.EditBox(parent, width, onChanged, onEnter)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width or 150, 20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(48)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self)
    if onEnter then onEnter(self) end
    self:ClearFocus()
  end)
  if onChanged then
    box:SetScript("OnTextChanged", function(self, userInput) onChanged(self, userInput) end)
  end
  return box
end

function UI.CheckBox(parent, text, onToggle, tipTitle, tipLines)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  local label = UI.Label(check, text, "GameFontHighlight")
  label:SetPoint("LEFT", check, "RIGHT", 2, 1)
  check.label = label
  check:SetScript("OnClick", function(self) onToggle(self:GetChecked() and true or false) end)
  if tipTitle then UI.SetTooltip(check, tipTitle, tipLines) end
  return check
end

function UI.Slider(parent, text, minValue, maxValue, step, formatValue, onChange)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(240, 44)
  local label = UI.Label(holder, text, "GameFontHighlight")
  label:SetPoint("TOPLEFT", 0, 0)
  local valueText = UI.Label(holder, "", "GameFontNormalSmall")
  valueText:SetPoint("TOPRIGHT", 0, 0)
  local slider = CreateFrame("Slider", nil, holder, "UISliderTemplate")
  slider:SetPoint("TOPLEFT", 0, -18)
  slider:SetPoint("TOPRIGHT", 0, -18)
  slider:SetHeight(17)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetScript("OnValueChanged", function(_, value, userInput)
    valueText:SetText(formatValue(value))
    if userInput ~= false then onChange(value) end
  end)
  holder.slider = slider
  function holder:SetValue(value)
    slider:SetValue(value)
    valueText:SetText(formatValue(value))
  end
  return holder
end

------------------------------------------------------------------------------
-- Dropdown (our own; no shared menu frames)
--   local dd = UI.Dropdown(parent, 200, function() return items end)
--   items = { { text=, value=, checked=, disabled=, onSelect=function() end }, ... }
------------------------------------------------------------------------------

local openList

local function CloseOpenList()
  if openList then openList:Hide() end
  openList = nil
end
UI.CloseDropdowns = CloseOpenList

function UI.Dropdown(parent, width, getItems)
  local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
  dd:SetSize(width, 24)
  UI.ApplyBackdrop(dd, 0.9)
  dd.text = UI.Label(dd, "", "GameFontHighlight")
  dd.text:SetPoint("LEFT", 8, 0)
  dd.text:SetPoint("RIGHT", -22, 0)
  dd.text:SetWordWrap(false)
  local arrow = dd:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(14, 14)
  arrow:SetPoint("RIGHT", -6, 0)
  arrow:SetRotation(-math.pi / 2)

  local list = CreateFrame("Frame", nil, dd, "BackdropTemplate")
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetClampedToScreen(true)
  UI.ApplyBackdrop(list, 0.98)
  list:Hide()
  list.rows = {}

  local function Row(i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, list)
    row:SetHeight(20)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", 4, 0)
    row.label = UI.Label(row, "", "GameFontHighlight")
    row.label:SetPoint("LEFT", 22, 0)
    row.label:SetPoint("RIGHT", -6, 0)
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
      CloseOpenList()
      if self.item and self.item.onSelect then self.item.onSelect(self.item) end
    end)
    list.rows[i] = row
    return row
  end

  function dd:Open()
    UI.CloseDropdowns()
    local items = getItems() or {}
    for i, item in ipairs(items) do
      local row = Row(i)
      row.item = item
      row.label:SetText(item.text)
      row.check:SetShown(item.checked and true or false)
      row:SetEnabled(not item.disabled)
      row.label:SetFontObject(item.disabled and "GameFontDisable" or "GameFontHighlight")
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
      row:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 20)
      row:Show()
    end
    for i = #items + 1, #list.rows do list.rows[i]:Hide() end
    list:SetSize(math.max(width, 160), 12 + math.max(1, #items) * 20)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
    list:Show()
    openList = list
  end

  dd:SetScript("OnClick", function()
    if list:IsShown() then CloseOpenList() else dd:Open() end
  end)
  dd:SetScript("OnHide", function() if openList == list then CloseOpenList() end end)

  function dd:SetText(text) self.text:SetText(text or "") end
  return dd
end

-- Clicking anywhere outside an open dropdown list closes it.
FWR:RegisterEvent("GLOBAL_MOUSE_DOWN", function()
  if not openList then return end
  local focus = FWR.API.GetMouseFocus()
  while focus do
    if focus == openList or focus == openList:GetParent() then return end
    focus = focus.GetParent and focus:GetParent() or nil
  end
  CloseOpenList()
end)

------------------------------------------------------------------------------
-- Dialog: our own Accept/Cancel popup (with an optional third button and
-- an optional text field). Only one at a time; a new one cancels the old.
------------------------------------------------------------------------------

local dialog

local function BuildDialog()
  local d = CreateFrame("Frame", "ForeverWeaponRackDialog", UIParent, "BackdropTemplate")
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true)
  d:SetClampedToScreen(true)
  d:SetWidth(380)
  d:SetPoint("TOP", UIParent, "TOP", 0, -160)
  d:EnableMouse(true)
  UI.ApplyBackdrop(d, 0.97)
  d.text = UI.Label(d, "", "GameFontHighlight")
  d.text:SetPoint("TOPLEFT", 16, -16)
  d.text:SetPoint("TOPRIGHT", -16, -16)
  d.text:SetJustifyH("CENTER")
  d.text:SetSpacing(2)
  d.edit = UI.EditBox(d, 220)
  d.buttons = {}
  for i = 1, 3 do
    local b = UI.Button(d, "", 110)
    b:SetScript("OnClick", function() d:Resolve(i) end)
    d.buttons[i] = b
  end
  d.edit:SetScript("OnEnterPressed", function() d:Resolve(1) end)
  d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
  d:Hide()
  -- Escape closes it like a Blizzard popup (counts as Cancel).
  tinsert(UISpecialFrames, "ForeverWeaponRackDialog")
  d:SetScript("OnHide", function(self)
    local spec = self.spec
    self.spec = nil
    if spec and spec.onCancel then FWR.SafeCall(spec.onCancel) end
  end)

  function d:Resolve(index)
    local spec = self.spec
    if not spec then return self:Hide() end
    local button = spec.buttons[index]
    self.spec = nil       -- resolved: hiding no longer cancels
    self:Hide()
    if button and button.onClick then
      button.onClick(spec.edit and self.edit:GetText() or nil)
    end
  end
  return d
end

--[[
  UI.ShowDialog{
    text = "...",
    buttons = { { text = "Save", onClick = fn }, { text = "Cancel" }, ... },
    edit = "default text" or nil,      -- shows a text field
    onCancel = fn,                     -- Escape / closed without a choice
  }
]]
function UI.ShowDialog(spec)
  dialog = dialog or BuildDialog()
  if dialog:IsShown() then dialog:Hide() end   -- cancels the previous one
  dialog.spec = spec
  dialog.text:SetText(spec.text or "")
  local textHeight = dialog.text:GetStringHeight()
  local y = -24 - textHeight
  if spec.edit then
    dialog.edit:ClearAllPoints()
    dialog.edit:SetPoint("TOP", dialog, "TOP", 0, y - 6)
    dialog.edit:SetText(spec.edit)
    dialog.edit:Show()
    y = y - 34
  else
    dialog.edit:Hide()
  end
  local count = #spec.buttons
  local total = count * 110 + (count - 1) * 8
  for i, b in ipairs(dialog.buttons) do
    local def = spec.buttons[i]
    if def then
      b:SetText(def.text)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", dialog, "TOP", -total / 2 + (i - 1) * 118, y - 8)
      b:Show()
    else
      b:Hide()
    end
  end
  dialog:SetHeight(-y + 44)
  dialog:Show()
  if spec.edit then
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
  end
end

-- Accept / Cancel. Used by the swap checks, key conflicts and deletes.
function FWR.Confirm(text, onAccept, onCancel)
  UI.ShowDialog({
    text = text,
    buttons = {
      { text = L.ACCEPT, onClick = onAccept },
      { text = L.CANCEL, onClick = onCancel },
    },
    onCancel = onCancel,
  })
end

-- Text prompt (profile names).
function FWR.Prompt(text, default, onAccept)
  UI.ShowDialog({
    text = text,
    edit = default or "",
    buttons = {
      { text = L.ACCEPT, onClick = onAccept },
      { text = L.CANCEL },
    },
  })
end

------------------------------------------------------------------------------
-- Key capture box (DESIGN 4.1 "press a key", 5.2 allowed inputs)
--   UI.KeyCapture(parent, width, {
--     getKey = function() return key end,
--     onKey = function(key) end,       -- a key was pressed (validated later)
--     onClear = function() end,        -- right-click
--   })
------------------------------------------------------------------------------

function UI.KeyCapture(parent, width, handlers)
  local box = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  box:SetSize(width or 160, 22)
  box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  if box.SetMotionScriptsWhileDisabled then box:SetMotionScriptsWhileDisabled(true) end

  local function Refresh()
    if box.capturing then
      box:SetText("|cffffd200" .. L.KEY_PRESS .. "|r")
    else
      local key = handlers.getKey()
      box:SetText(key and FWR.Bindings.KeyText(key) or ("|cff888888" .. L.KEY_NONE .. "|r"))
    end
  end
  box.Refresh = Refresh

  local function Stop()
    box.capturing = false
    box:EnableKeyboard(false)
    box:EnableMouseWheel(false)
    box:UnlockHighlight()
    Refresh()
  end
  box.StopCapture = Stop

  local function Finish(key)
    Stop()
    handlers.onKey(key)
  end

  box:SetScript("OnClick", function(self, button)
    if self.capturing then return end
    -- The mouse-up of a click we just captured must not restart capture.
    if self.swallowClick then
      self.swallowClick = nil
      return
    end
    if button == "RightButton" then
      handlers.onClear()
      Refresh()
      return
    end
    self.capturing = true
    self:EnableKeyboard(true)
    self:EnableMouseWheel(true)
    self:LockHighlight()
    Refresh()
  end)

  box:SetScript("OnKeyDown", function(self, key)
    if not self.capturing then return end
    if key == "ESCAPE" then return Stop() end
    if FWR.Bindings.IsModifierOnly(key) then return end
    Finish(FWR.Bindings.Chord(key))
  end)

  -- Mouse buttons while capturing (the click that started capture is done).
  box:SetScript("OnMouseDown", function(self, button)
    if not self.capturing then return end
    -- Only left/right produce an OnClick on release (see RegisterForClicks).
    if button == "LeftButton" or button == "RightButton" then self.swallowClick = true end
    Finish(FWR.Bindings.Chord(FWR.Bindings.MouseKey(button)))
  end)

  box:SetScript("OnMouseWheel", function(self, delta)
    if not self.capturing then return end
    Finish(FWR.Bindings.Chord(FWR.Bindings.WheelKey(delta)))
  end)

  box:SetScript("OnHide", function(self) if self.capturing then Stop() end end)

  UI.SetTooltip(box, L.KEY_LABEL, { L.KEY_CLICK_TO_BIND, L.KEY_RIGHT_TO_CLEAR, L.KEY_ESC_CANCEL })
  Refresh()
  return box
end
