--[[
  UI/MainWindow.lua
  The window (DESIGN 4): movable, resizable from the bottom-right corner,
  closable and lockable, with two tabs (Edit Set, Sets).

  Header (4.7):
    - turns yellow with "Not wearing any saved set" when your weapons don't
      match any saved set; otherwise lists the sets you're wearing
    - a "Queued" indicator while something waits (combat, dead, casting, or
      key changes waiting for combat to end). Right-click cancels the queue.

  Window position, size, scale and lock are saved in the profile.
]]

local _, FWR = ...
local L = FWR.L
local Sets = FWR.Sets
local Identity = FWR.Identity
local UI = FWR.UI

local MainWindow = {}
UI.MainWindow = MainWindow

local MIN_WIDTH, MIN_HEIGHT = 640, 300
local frame

local function Profile() return FWR.Data:Profile() end

local function SavePosition()
  local p = Profile().window
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  p.point, p.relativePoint, p.x, p.y = point, relativePoint, x, y
  p.width, p.height = frame:GetWidth(), frame:GetHeight()
end

function MainWindow.ApplyProfile()
  if not frame then return end
  local profile = Profile()
  local p = profile.window
  frame:SetScale(p.scale or 1)
  frame:ClearAllPoints()
  frame:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or "CENTER", p.x or 0, p.y or 0)
  frame:SetSize(math.max(MIN_WIDTH, p.width or MIN_WIDTH), math.max(MIN_HEIGHT, p.height or MIN_HEIGHT))
  MainWindow.UpdateLock()
end

function MainWindow.UpdateLock()
  if not frame then return end
  local locked = Profile().locked
  frame.resizeGrip:SetShown(not locked)
  frame.lockButton.icon:SetTexture(locked and "Interface\\Buttons\\LockButton-Locked-Up"
    or "Interface\\Buttons\\LockButton-Unlocked-Up")
end

function MainWindow.SetLocked(locked)
  Profile().locked = locked and true or false
  MainWindow.UpdateLock()
  FWR:Fire("SETTINGS_CHANGED")
end

------------------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------------------

function MainWindow.ShowTab(name)
  if not frame then return end
  frame.activeTab = name
  frame.editPage:SetShown(name == "edit")
  frame.setsPage:SetShown(name == "sets")
  frame.editTab:SetEnabled(name ~= "edit")
  frame.setsTab:SetEnabled(name ~= "sets")
  MainWindow.Refresh()
end

-- Leaving the Edit tab with unsaved changes asks first.
local function RequestTab(name)
  if name == frame.activeTab then return end
  if frame.activeTab == "edit" then
    UI.EditTab.ConfirmLeave(function() MainWindow.ShowTab(name) end)
  else
    MainWindow.ShowTab(name)
  end
end

------------------------------------------------------------------------------
-- Header
------------------------------------------------------------------------------

local function RefreshHeader()
  local sets = Sets.All()
  local worn = {}
  for _, set in ipairs(sets) do
    if Identity.IsWearing(set) then worn[#worn + 1] = set.name end
  end
  if #sets == 0 then
    frame.status:SetText(L.HEADER_NO_SETS)
    frame.status:SetTextColor(0.7, 0.7, 0.7)
    frame.headerTint:Hide()
  elseif #worn == 0 then
    frame.status:SetText(L.HEADER_NOT_WEARING)
    frame.status:SetTextColor(1, 0.82, 0)
    frame.headerTint:Show()
  else
    frame.status:SetText(L.HEADER_WEARING:format(table.concat(worn, ", ")))
    frame.status:SetTextColor(0.6, 1, 0.6)
    frame.headerTint:Hide()
  end

  local queued = FWR.Queue.request ~= nil or FWR.Bindings.pending
  frame.queued:SetShown(queued and true or false)
end

local function QueuedTooltip()
  local lines = {}
  local Queue = FWR.Queue
  if Queue.request then
    lines[#lines + 1] = L.QUEUED_TIP_SWAP:format(Queue.Label(Queue.request), Queue.ReasonText(Queue.reason))
  end
  if FWR.Bindings.pending then lines[#lines + 1] = L.QUEUED_TIP_BINDINGS end
  if Queue.request then lines[#lines + 1] = "|cff88ccff" .. L.QUEUED_TIP_CANCEL .. "|r" end
  return lines
end

------------------------------------------------------------------------------
-- Building the window
------------------------------------------------------------------------------

local function Build()
  frame = CreateFrame("Frame", "ForeverWeaponRackFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 1400, 900)
  elseif frame.SetMinResize then
    frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
  end
  frame:EnableMouse(true)
  UI.ApplyBackdrop(frame, 0.96)
  frame:Hide()
  -- Escape closes it.
  tinsert(UISpecialFrames, "ForeverWeaponRackFrame")

  -- Title bar (drag to move)
  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", 4, -4)
  titleBar:SetPoint("TOPRIGHT", -4, -4)
  titleBar:SetHeight(46)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function()
    if not Profile().locked then frame:StartMoving() end
  end)
  titleBar:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
  end)

  frame.headerTint = titleBar:CreateTexture(nil, "BACKGROUND")
  frame.headerTint:SetAllPoints()
  frame.headerTint:SetColorTexture(1, 0.82, 0, 0.18)
  frame.headerTint:Hide()

  local title = UI.Label(titleBar, FWR.title, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 10, -6)
  local experimental = UI.Label(titleBar, "(" .. L.EXPERIMENTAL .. ")", "GameFontNormalSmall")
  experimental:SetTextColor(1, 0.55, 0)
  experimental:SetPoint("LEFT", title, "RIGHT", 6, 0)

  frame.status = UI.Label(titleBar, "", "GameFontHighlightSmall")
  frame.status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  frame.status:SetPoint("RIGHT", titleBar, "RIGHT", -150, 0)
  frame.status:SetWordWrap(false)

  -- Close
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() MainWindow.Hide() end)

  -- Lock
  frame.lockButton = CreateFrame("Button", nil, frame)
  frame.lockButton:SetSize(24, 24)
  frame.lockButton:SetPoint("RIGHT", close, "LEFT", -2, 0)
  frame.lockButton.icon = frame.lockButton:CreateTexture(nil, "ARTWORK")
  frame.lockButton.icon:SetAllPoints()
  frame.lockButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  frame.lockButton:SetScript("OnClick", function() MainWindow.SetLocked(not Profile().locked) end)
  UI.SetTooltip(frame.lockButton, L.LOCK_WINDOW, function()
    return Profile().locked and L.LOCKED_HINT or L.UNLOCKED_HINT
  end)

  -- Settings
  local settings = CreateFrame("Button", nil, frame)
  settings:SetSize(20, 20)
  settings:SetPoint("RIGHT", frame.lockButton, "LEFT", -4, 0)
  local gear = settings:CreateTexture(nil, "ARTWORK")
  gear:SetAllPoints()
  gear:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  settings:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  settings:SetScript("OnClick", function() FWR.Settings.Open() end)
  UI.SetTooltip(settings, L.SETTINGS)

  -- Queued indicator (right-click cancels)
  frame.queued = CreateFrame("Button", nil, frame)
  frame.queued:SetSize(70, 18)
  frame.queued:SetPoint("RIGHT", settings, "LEFT", -8, 0)
  frame.queued:RegisterForClicks("RightButtonUp")
  local queuedText = UI.Label(frame.queued, L.QUEUED, "GameFontNormalSmall")
  queuedText:SetPoint("CENTER")
  queuedText:SetTextColor(1, 0.55, 0)
  local queuedBg = frame.queued:CreateTexture(nil, "BACKGROUND")
  queuedBg:SetAllPoints()
  queuedBg:SetColorTexture(1, 0.55, 0, 0.15)
  frame.queued:SetScript("OnClick", function() FWR.Queue.Cancel() end)
  UI.SetTooltip(frame.queued, L.QUEUED_TIP_TITLE, QueuedTooltip)
  frame.queued:Hide()

  -- Tabs
  frame.editTab = UI.Button(frame, L.TAB_EDIT, 100, function() RequestTab("edit") end)
  frame.editTab:SetPoint("TOPLEFT", 12, -54)
  frame.setsTab = UI.Button(frame, L.TAB_SETS, 100, function() RequestTab("sets") end)
  frame.setsTab:SetPoint("LEFT", frame.editTab, "RIGHT", 4, 0)

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.6, 0.6, 0.65, 0.4)
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", 8, -80)
  divider:SetPoint("TOPRIGHT", -8, -80)

  -- Pages
  local pages = CreateFrame("Frame", nil, frame)
  pages:SetPoint("TOPLEFT", 4, -84)
  pages:SetPoint("BOTTOMRIGHT", -4, 4)
  frame.editPage = CreateFrame("Frame", nil, pages)
  frame.editPage:SetAllPoints()
  frame.setsPage = CreateFrame("Frame", nil, pages)
  frame.setsPage:SetAllPoints()
  UI.EditTab.Create(frame.editPage)
  UI.SetsTab.Create(frame.setsPage)

  -- Resize grip (bottom-right)
  frame.resizeGrip = CreateFrame("Button", nil, frame)
  frame.resizeGrip:SetSize(16, 16)
  frame.resizeGrip:SetPoint("BOTTOMRIGHT", -4, 4)
  frame.resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  frame.resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  frame.resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  frame.resizeGrip:SetScript("OnMouseDown", function()
    if not Profile().locked then frame:StartSizing("BOTTOMRIGHT") end
  end)
  frame.resizeGrip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    SavePosition()
    MainWindow.Refresh()
  end)

  -- Closing with unsaved changes asks first (4.4). Escape hides the window
  -- directly, so the question is asked after; Cancel brings it back.
  frame:SetScript("OnHide", function()
    UI.CloseDropdowns()
    if UI.EditTab.IsDirty() then
      -- Next frame, so the same Escape press doesn't also close the popup.
      C_Timer.After(0, function()
        UI.EditTab.ConfirmLeave(function() end, function() frame:Show() end)
      end)
    end
  end)
  frame:SetScript("OnShow", function() MainWindow.Refresh() end)

  MainWindow.ApplyProfile()
  MainWindow.ShowTab("edit")
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

function MainWindow.Refresh()
  if not frame or not frame:IsShown() then return end
  RefreshHeader()
  if frame.activeTab == "edit" then
    UI.EditTab.Refresh()
  else
    UI.SetsTab.Refresh()
  end
end

function MainWindow.Show()
  if not frame then Build() end
  frame:Show()
  frame:Raise()
end

function MainWindow.Hide()
  if frame then frame:Hide() end
end

function MainWindow.Toggle()
  if frame and frame:IsShown() then
    MainWindow.Hide()
  else
    MainWindow.Show()
  end
end

function MainWindow.IsShown()
  return frame ~= nil and frame:IsShown()
end

-- Redraw (once per frame at most) when anything relevant changes.
local function ScheduleRefresh()
  if frame and frame:IsShown() then
    FWR.Util.RunNextFrame("MAIN_REFRESH", MainWindow.Refresh)
  end
end
for _, message in ipairs({ "SETS_CHANGED", "INVENTORY_CHANGED", "QUEUE_CHANGED", "BINDINGS_CHANGED",
                           "SETTINGS_CHANGED" }) do
  FWR:Listen(message, ScheduleRefresh)
end
FWR:Listen("PROFILE_CHANGED", function()
  MainWindow.ApplyProfile()
  ScheduleRefresh()
end)
