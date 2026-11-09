--[[
  Slash.lua
  /fwr, /weaponrack, /wr (DESIGN 5.5)

    /fwr                     open or close the window
    /fwr equip <set name>    equip a set by name (for macros)
    /fwr debug [...]         testing output (see Debug.lua, DESIGN 9)
    /fwr settings            open the settings
    /fwr help                list the commands

  /wr may clash with another add-on. If so, whichever add-on the game
  registers last wins /wr, and /fwr and /weaponrack still work. /fwr debug
  reports a clash (testing plan item 9).
]]

local _, FWR = ...
local L = FWR.L

SLASH_FOREVERWEAPONRACK1 = "/fwr"
SLASH_FOREVERWEAPONRACK2 = "/weaponrack"
SLASH_FOREVERWEAPONRACK3 = "/wr"

SlashCmdList.FOREVERWEAPONRACK = function(message)
  message = message or ""
  local command, rest = message:match("^%s*(%S*)%s*(.-)%s*$")
  command = (command or ""):lower()

  if command == "" then
    FWR.UI.MainWindow.Toggle()
  elseif command == "equip" then
    if rest == "" then
      FWR:Print(L.SLASH_HELP)
    else
      FWR.Swap.EquipByName(rest)
    end
  elseif command == "debug" then
    FWR.Debug.Run(rest)
  elseif command == "settings" or command == "options" or command == "config" then
    FWR.Settings.Open()
  else
    FWR:Print(L.SLASH_HELP)
  end
end
