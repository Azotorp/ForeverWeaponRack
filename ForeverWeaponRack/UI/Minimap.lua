--[[
  UI/Minimap.lua
  Minimap button that toggles the window (DESIGN 4). Written here instead of
  embedding LibDBIcon, so the add-on ships with no libraries at all.

    Left-click   open or close the window
    Right-click  settings
    Drag         move the button around the minimap (angle saved in profile)

  Also registers with the add-on compartment (the minimap's add-on list)
  when the client has it.
]]

local _, FWR = ...
local L = FWR.L
local UI = FWR.UI

local MinimapButton = {}
UI.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\INV_Sword_04"
local button

local function Settings() return FWR.Data:Profile().minimap end

-- Place the button on the minimap edge at the saved angle. Square minimaps
-- push the button out to the square's edge instead of a circle.
local function Place()
  if not button then return end
  local angle = math.rad(Settings().angle or 215)
  local x, y = math.cos(angle), math.sin(angle)
  local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
  if shape ~= "ROUND" then
    local m = math.max(math.abs(x), math.abs(y))
    if m > 0 then x, y = x / m, y / m end
    x, y = x * 1.1, y * 1.1   -- a little outside the corners
  end
  local radius = (Minimap:GetWidth() / 2) + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  Settings().angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
  Place()
end

local function Build()
  button = CreateFrame("Button", "ForeverWeaponRackMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      FWR.Settings.Open()
    else
      UI.MainWindow.Toggle()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  UI.SetTooltip(button, FWR.title, { L.MINIMAP_TIP_LEFT, L.MINIMAP_TIP_RIGHT, L.MINIMAP_TIP_DRAG })
end

function MinimapButton.Update()
  if Settings().hide then
    if button then button:Hide() end
    return
  end
  if not button then Build() end
  Place()
  button:Show()
end

function MinimapButton.SetShown(show)
  Settings().hide = not show
  MinimapButton.Update()
end

-- The add-on compartment (newer clients): same actions as the button.
function MinimapButton.RegisterCompartment()
  local compartment = _G.AddonCompartmentFrame
  if not (compartment and compartment.RegisterAddon) then return end
  pcall(compartment.RegisterAddon, compartment, {
    text = FWR.title,
    icon = ICON,
    notCheckable = true,
    registerForAnyClick = true,
    func = function(_, inputData)
      local mouseButton = type(inputData) == "table" and inputData.buttonName or inputData
      if mouseButton == "RightButton" then
        FWR.Settings.Open()
      else
        UI.MainWindow.Toggle()
      end
    end,
  })
end

FWR:Listen("PROFILE_CHANGED", function() MinimapButton.Update() end)
