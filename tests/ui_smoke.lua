--[[
  tests/ui_smoke.lua
  Loads every file listed in ForeverWeaponRack.toc (UI included) against the
  fake client and clicks through the main paths, to catch Lua runtime errors
  (nil fields, wrong arguments) in code the logic tests don't reach.
  It can't check how anything looks; that needs the game.

      lua5.1 tests/ui_smoke.lua
]]

local S = dofile("tests/wow_stubs.lua")

-- Files in .toc order
local files = {}
for line in io.lines("ForeverWeaponRack/ForeverWeaponRack.toc") do
  line = line:gsub("\r", "")
  if line ~= "" and not line:find("^#") then
    files[#files + 1] = (line:gsub("\\", "/"))
  end
end

local FWR = S.LoadAddon("ForeverWeaponRack", files)

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    io.stderr:write("FAIL " .. msg .. "\n")
  end
end

local function step(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    failures = failures + 1
    io.stderr:write(("ERROR in %s: %s\n"):format(name, err))
  end
end

-- Items
S.DefineItem(100, { name = "Sword A", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7 })
S.DefineItem(101, { name = "Dagger B", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15 })
S.DefineItem(200, { name = "Greatsword", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 8 })
S.DefineItem(300, { name = "Shield", equipLoc = "INVTYPE_SHIELD", classID = 4, subclassID = 6 })
S.DefineItem(400, { name = "Bow", equipLoc = "INVTYPE_RANGED", classID = 2, subclassID = 2 })
S.DefineItem(501, { name = "Jagged Arrow", equipLoc = "INVTYPE_AMMO", classID = 6, subclassID = 2, ammoDPS = "13.5" })
S.DefineItem(600, { name = "BoE Blade", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7, bindType = 2 })

S.equipped[16] = S.Item(100)
S.equipped[17] = S.Item(300)
S.bags[0][1] = S.Item(200)
S.bags[0][2] = S.Item(101)
S.bags[0][3] = S.Item(400)
S.bags[0][4] = S.Item(501, nil, 200)
S.bags[0][5] = S.Item(600)

_G.ClearOverrideBindings = function() end
_G.SetOverrideBinding = function() end
_G.GetBindingAction = function() return "" end

local UI = FWR.UI

step("startup", function()
  S.Fire("ADDON_LOADED", "ForeverWeaponRack")
  S.Fire("PLAYER_LOGIN")
  S.Fire("PLAYER_ENTERING_WORLD")
  S.RunTimers(0)
end)

step("open window with no sets", function()
  SlashCmdList.FOREVERWEAPONRACK("")
  S.RunTimers(0)
  check(UI.MainWindow.IsShown(), "window shown")
end)

step("add set from the Edit tab", function()
  UI.EditTab.frame.addButton:Click()
  S.RunTimers(0)
  check(FWR.Sets.Count() == 1, "one set")
  check(UI.EditTab.selectedId ~= nil, "selected")
end)

local slots
step("slot interactions", function()
  slots = UI.EditTab.frame.slots
  local mh = slots.MAINHAND
  -- Right-click cycle
  mh:Click("RightButton")
  check(UI.EditTab.draft.slots.MAINHAND.state == "empty", "cycled to empty")
  mh:Click("RightButton")
  mh:Click("RightButton")
  check(UI.EditTab.draft.slots.MAINHAND.state == "item", "back to item")
  -- Fake cursor: pick up MH, drop on OH (shield picked up next), cancel undoes
  mh:Click("LeftButton")
  check(UI.FakeCursor.IsHolding(), "holding")
  slots.OFFHAND:Click("LeftButton")
  check(UI.FakeCursor.IsHolding() and UI.FakeCursor.held.ref.id == 300, "holding shield next")
  S.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check(not UI.FakeCursor.IsHolding(), "chain undone")
  check(UI.EditTab.draft.slots.MAINHAND.item.id == 100, "MH restored")
  check(UI.EditTab.draft.slots.OFFHAND.item.id == 300, "OH restored")
  check(not UI.EditTab.IsDirty(), "not dirty after undo")
end)

step("flyout and pick", function()
  local mh = slots.MAINHAND
  mh.__mouseOver = true
  mh.__scripts.OnEnter(mh)
  S.RunTimers(1)
  check(UI.Flyout.IsShown(), "flyout open")
  local first = _G.ForeverWeaponRackFlyout.buttons[1]
  first.__scripts.OnEnter(first)
  first:Click("LeftButton")
  check(UI.EditTab.IsDirty(), "dirty after pick")
  mh.__mouseOver = false
  mh.__scripts.OnLeave(mh)
end)

step("drag from bags", function()
  _G.C_Container.PickupContainerItem(0, 1)   -- greatsword on the real cursor
  slots.MAINHAND.__scripts.OnReceiveDrag(slots.MAINHAND)
  check(S.cursor == nil, "cursor cleared")
  check(UI.EditTab.draft.slots.MAINHAND.item.id == 200, "2H placed")
  check(UI.EditTab.draft.slots.OFFHAND.state == "empty", "OH emptied by 2H")
end)

step("ammo slot appears with a bow", function()
  _G.C_Container.PickupContainerItem(0, 3)
  slots.RANGED.__scripts.OnReceiveDrag(slots.RANGED)
  UI.EditTab.Refresh()
  check(slots.AMMO:IsShown(), "ammo shown")
  check(UI.EditTab.draft.slots.AMMO.item and UI.EditTab.draft.slots.AMMO.item.id == 501, "best ammo picked")
end)

step("save, rename, save as new", function()
  UI.EditTab.frame.saveButton:Click()
  check(not UI.EditTab.IsDirty(), "saved")
  UI.EditTab.frame.nameBox:SetText("Two-Hand")
  UI.EditTab.RefreshNaming()
  UI.EditTab.frame.renameButton:Click()
  check(FWR.Sets.All()[1].name == "Two-Hand", "renamed")
  UI.EditTab.frame.nameBox:SetText("Copy")
  UI.EditTab.RefreshNaming()
  UI.EditTab.frame.saveAsNewButton:Click()
  check(FWR.Sets.Count() == 2, "copied")
end)

step("key capture", function()
  local box = UI.EditTab.frame.keyBox
  box:Click("LeftButton")
  box.__scripts.OnKeyDown(box, "LSHIFT")
  box.__scripts.OnKeyDown(box, "F")
  S.RunTimers(0)
  check(UI.EditTab.Selected().key == "F", "key bound")
  box:Click("LeftButton")
  box.__scripts.OnMouseDown(box, "LeftButton")
  box:Click("LeftButton")          -- mouse-up of that click must not restart capture
  check(not box.capturing, "not capturing again")
  check(UI.EditTab.Selected().key == "F", "plain left click refused")
  box:Click("RightButton")
  check(UI.EditTab.Selected().key == nil, "cleared")
end)

step("sets tab", function()
  UI.MainWindow.ShowTab("sets")
  S.RunTimers(0)
  local rows = UI.SetsTab.frame.rows
  check(#rows >= 2, "rows")
  rows[2].up:Click()
  check(FWR.Sets.All()[1].name == "Copy", "moved up")
  rows[1].equip:Click()
  for _ = 1, 6 do S.Settle() end
  rows[2].delete:Click()
  _G.ForeverWeaponRackDialog.buttons[1]:Click()   -- Accept
  check(FWR.Sets.Count() == 1, "deleted")
  UI.SetsTab.frame.addButton:Click()
  S.RunTimers(0)
  check(FWR.Sets.Count() == 2, "added")
  rows[1].edit:Click()
  S.RunTimers(0)
end)

step("unsaved prompt on close", function()
  UI.MainWindow.ShowTab("edit")
  slots.MAINHAND:Click("RightButton")
  check(UI.EditTab.IsDirty(), "dirty")
  UI.MainWindow.Hide()
  S.RunTimers(0)
  check(_G.ForeverWeaponRackDialog:IsShown(), "save prompt shown")
  _G.ForeverWeaponRackDialog.buttons[2]:Click()   -- Don't Save
  check(not UI.EditTab.IsDirty(), "reverted")
end)

step("settings", function()
  FWR.Settings.Open()
  local panel = _G.ForeverWeaponRackSettingsPanel
  panel:Show()
  FWR.Settings.Refresh()
  panel.lock:SetChecked(true)
  panel.lock:Click()
  panel.perChar:SetChecked(true)
  panel.perChar:Click()
  panel.toggleKey:Click("LeftButton")
  panel.toggleKey.__scripts.OnKeyDown(panel.toggleKey, "T")
  check(FWR.Data:GetToggleKey() == "T", "toggle key")
  panel.newProfile:Click()
  _G.ForeverWeaponRackDialog.edit:SetText("Raid")
  _G.ForeverWeaponRackDialog.buttons[1]:Click()
  check(FWR.Data:ProfileName() == "Raid", "new profile")
  panel.deleteProfile:Click()
  _G.ForeverWeaponRackDialog.buttons[1]:Click()
  check(FWR.Data:ProfileName() == "Default", "back to default")
end)

step("slash and debug", function()
  SlashCmdList.FOREVERWEAPONRACK("help")
  SlashCmdList.FOREVERWEAPONRACK("equip copy")
  for _ = 1, 6 do S.Settle() end
  SlashCmdList.FOREVERWEAPONRACK("equip Nope")
  SlashCmdList.FOREVERWEAPONRACK("debug")
  SlashCmdList.FOREVERWEAPONRACK("debug mh")
  SlashCmdList.FOREVERWEAPONRACK("debug bags")
  SlashCmdList.FOREVERWEAPONRACK("debug bag 0 2")
  SlashCmdList.FOREVERWEAPONRACK("debug " .. S.Link(101))
  check(_G.ForeverWeaponRackCopyFrame:IsShown(), "copy window")
end)

step("minimap", function()
  local b = _G.ForeverWeaponRackMinimapButton
  check(b ~= nil, "minimap button")
  b:Click("LeftButton")
  b.__scripts.OnDragStart(b)
  b.__scripts.OnUpdate(b, 0.1)
  b.__scripts.OnDragStop(b)
end)

step("equipment toggle key press", function()
  _G.ForeverWeaponRack.OnToggleCommand()
  for _ = 1, 6 do S.Settle() end
  _G.ForeverWeaponRack.OnToggleCommand()
  for _ = 1, 6 do S.Settle() end
  SlashCmdList.FOREVERWEAPONRACK("debug swaps")
end)

if #S.errors > 0 then
  failures = failures + #S.errors
end
print(("UI smoke test: %d problem(s), %d add-on error(s)"):format(failures, #S.errors))
os.exit(failures == 0 and 0 or 1)
