--[[
  Init.lua
  Startup: load saved data when our add-on loads, then build the parts that
  need the player in the world (settings panel, minimap button, key
  bindings).
]]

local _, FWR = ...
local L = FWR.L

FWR:RegisterEvent("ADDON_LOADED", function(_, addonName)
  if addonName ~= FWR.name then return end
  FWR.Data:Load()
end)

FWR:RegisterEvent("PLAYER_LOGIN", function()
  FWR.Settings.Register()
  FWR.UI.MinimapButton.Update()
  FWR.UI.MinimapButton.RegisterCompartment()
  -- Keys go live now (or after combat, if the UI was reloaded in combat).
  FWR.Bindings.Apply()
  FWR.Identity.Invalidate()
  FWR:Print(L.LOADED:format(FWR.version))
end)
