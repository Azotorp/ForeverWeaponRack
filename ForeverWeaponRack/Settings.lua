--[[
  Settings.lua
  The settings panel (DESIGN 8.1), registered with the game's Settings
  window (Esc > Options > AddOns > ForeverWeaponRack):

    - window lock and scale
    - hover flyout delay
    - minimap button
    - Equipment Toggle key, in the profile or for this character only
    - profile selection (new, delete, reset)

  Profiles hold global settings only; sets are always per character.
]]

local _, FWR = ...
local L = FWR.L
local Data = FWR.Data
local UI = FWR.UI

local SettingsPanel = {}
FWR.Settings = SettingsPanel

local panel

local function Profile() return Data:Profile() end

local function Changed()
  FWR:Fire("SETTINGS_CHANGED")
end

local function Build()
  panel = CreateFrame("Frame", "ForeverWeaponRackSettingsPanel", UIParent)
  panel.name = FWR.title
  panel:Hide()

  local title = UI.Label(panel, L.SETTINGS_TITLE, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  local subtitle = UI.Label(panel, L.SETTINGS_SUBTITLE, "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  subtitle:SetTextColor(1, 0.55, 0)

  -- Window
  panel.lock = UI.CheckBox(panel, L.SETTING_LOCK, function(checked)
    UI.MainWindow.SetLocked(checked)
  end, L.SETTING_LOCK, { L.LOCKED_HINT })
  panel.lock:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -4, -16)

  panel.minimap = UI.CheckBox(panel, L.SETTING_MINIMAP, function(checked)
    UI.MinimapButton.SetShown(checked)
    Changed()
  end)
  panel.minimap:SetPoint("TOPLEFT", panel.lock, "BOTTOMLEFT", 0, -4)

  panel.scale = UI.Slider(panel, L.SETTING_SCALE, 0.6, 1.5, 0.05,
    function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end,
    function(v)
      Profile().window.scale = v
      UI.MainWindow.ApplyProfile()
      Changed()
    end)
  panel.scale:SetPoint("TOPLEFT", panel.minimap, "BOTTOMLEFT", 4, -14)

  panel.delay = UI.Slider(panel, L.SETTING_FLYOUT_DELAY, 0, 1.5, 0.05,
    function(v) return L.SECONDS:format(v) end,
    function(v)
      Profile().flyoutDelay = v
      Changed()
    end)
  panel.delay:SetPoint("TOPLEFT", panel.scale, "BOTTOMLEFT", 0, -14)
  UI.SetTooltip(panel.delay.slider, L.SETTING_FLYOUT_DELAY, L.SETTING_FLYOUT_DELAY_TIP)

  -- Equipment Toggle
  local toggleHeader = UI.Label(panel, L.TOGGLE_NAME, "GameFontNormal")
  toggleHeader:SetPoint("TOPLEFT", panel.delay, "BOTTOMLEFT", 0, -22)
  local toggleDesc = UI.Label(panel, L.TOGGLE_DESC, "GameFontHighlightSmall")
  toggleDesc:SetPoint("TOPLEFT", toggleHeader, "BOTTOMLEFT", 0, -6)
  toggleDesc:SetWidth(520)
  toggleDesc:SetWordWrap(true)

  local keyLabel = UI.Label(panel, L.SETTING_TOGGLE_KEY, "GameFontHighlight")
  keyLabel:SetPoint("TOPLEFT", toggleDesc, "BOTTOMLEFT", 0, -12)
  panel.toggleKey = UI.KeyCapture(panel, 180, {
    getKey = function() return Data:GetToggleKey() end,
    onKey = function(key)
      FWR.Bindings.RequestToggleKey(key, function() SettingsPanel.Refresh() end)
    end,
    onClear = function()
      FWR.Bindings.SetToggleKey(nil)
      SettingsPanel.Refresh()
    end,
  })
  panel.toggleKey:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)

  panel.perChar = UI.CheckBox(panel, L.SETTING_TOGGLE_PER_CHAR, function(checked)
    Data:SetToggleKeyPerChar(checked)
    FWR.Bindings.Apply()
    SettingsPanel.Refresh()
  end, L.SETTING_TOGGLE_PER_CHAR, L.SETTING_TOGGLE_PER_CHAR_TIP)
  panel.perChar:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", -4, -8)

  -- Profiles
  local profileHeader = UI.Label(panel, L.SETTING_PROFILE, "GameFontNormal")
  profileHeader:SetPoint("TOPLEFT", panel.perChar, "BOTTOMLEFT", 4, -20)
  local profileTip = UI.Label(panel, L.SETTING_PROFILE_TIP, "GameFontHighlightSmall")
  profileTip:SetPoint("TOPLEFT", profileHeader, "BOTTOMLEFT", 0, -6)
  profileTip:SetWidth(520)
  profileTip:SetWordWrap(true)

  panel.profile = UI.Dropdown(panel, 200, function()
    local items = {}
    for _, name in ipairs(Data:ListProfiles()) do
      items[#items + 1] = {
        text = name,
        checked = name == Data:ProfileName(),
        onSelect = function()
          Data:UseProfile(name)
          FWR:Print(L.PROFILE_ACTIVE:format(name))
        end,
      }
    end
    return items
  end)
  panel.profile:SetPoint("TOPLEFT", profileTip, "BOTTOMLEFT", 0, -10)

  panel.newProfile = UI.Button(panel, L.PROFILE_NEW, 70, function()
    FWR.Prompt(L.PROFILE_NEW_Q, "", function(name)
      name = FWR.Util.Trim(name or "")
      if name == "" then return end
      if Data:ProfileExists(name) then
        FWR:ErrorText(L.PROFILE_EXISTS)
        return
      end
      Data:NewProfile(name, true)
      FWR:Print(L.PROFILE_ACTIVE:format(name))
    end)
  end)
  panel.newProfile:SetPoint("LEFT", panel.profile, "RIGHT", 8, 0)

  panel.deleteProfile = UI.Button(panel, L.PROFILE_DELETE, 70, function()
    local name = Data:ProfileName()
    FWR.Confirm(L.PROFILE_DELETE_Q:format(name), function()
      Data:UseProfile(Data.DEFAULT_PROFILE)
      Data:DeleteProfile(name)
      FWR:Print(L.PROFILE_ACTIVE:format(Data.DEFAULT_PROFILE))
    end)
  end)
  panel.deleteProfile:SetPoint("LEFT", panel.newProfile, "RIGHT", 4, 0)

  panel.resetProfile = UI.Button(panel, L.PROFILE_RESET, 70, function()
    FWR.Confirm(L.PROFILE_RESET_Q:format(Data:ProfileName()), function()
      Data:ResetProfile()
    end)
  end)
  panel.resetProfile:SetPoint("LEFT", panel.deleteProfile, "RIGHT", 4, 0)

  panel:SetScript("OnShow", function() SettingsPanel.Refresh() end)
end

function SettingsPanel.Refresh()
  if not panel then return end
  local profile = Profile()
  panel.lock:SetChecked(profile.locked)
  panel.minimap:SetChecked(not profile.minimap.hide)
  panel.scale:SetValue(profile.window.scale or 1)
  panel.delay:SetValue(profile.flyoutDelay or 0.35)
  panel.toggleKey:Refresh()
  panel.perChar:SetChecked(Data.char.toggleKeyPerChar and true or false)
  panel.profile:SetText(Data:ProfileName())
  panel.deleteProfile:SetEnabled(Data:ProfileName() ~= Data.DEFAULT_PROFILE)
end

-- Register with the game's Settings window (or the old Interface Options).
function SettingsPanel.Register()
  if not panel then Build() end
  local blizz = _G.Settings
  if blizz and blizz.RegisterCanvasLayoutCategory and blizz.RegisterAddOnCategory then
    local category = blizz.RegisterCanvasLayoutCategory(panel, FWR.title)
    blizz.RegisterAddOnCategory(category)
    SettingsPanel.category = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function SettingsPanel.Open()
  if not panel then SettingsPanel.Register() end
  local blizz = _G.Settings
  local category = SettingsPanel.category
  if blizz and blizz.OpenToCategory and category then
    local id = (category.GetID and category:GetID()) or category.ID
    blizz.OpenToCategory(id)
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- The old function needs two calls the first time.
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end

for _, message in ipairs({ "PROFILE_CHANGED", "SETTINGS_CHANGED", "BINDINGS_CHANGED" }) do
  FWR:Listen(message, function()
    if panel and panel:IsVisible() then SettingsPanel.Refresh() end
  end)
end
