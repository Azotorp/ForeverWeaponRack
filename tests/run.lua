--[[
  tests/run.lua
  Offline logic tests for ForeverWeaponRack. Run from the repository root:

      lua5.1 tests/run.lua

  These use a fake client (tests/wow_stubs.lua). They check the add-on's own
  logic (patterns, identity, set rules, swap planning, cycling, migration),
  not how WoW Forever behaves. In-game behaviour is covered by the Testing
  Checklist in the wiki.
]]

package.path = "./tests/?.lua;" .. package.path
local S = dofile("tests/wow_stubs.lua")

-- Logic files only (no UI), in .toc order.
local FILES = {
  "Core.lua", "Locale.lua", "Data.lua",
  "ItemInfo.lua", "Tooltip.lua", "Identity.lua",
  "Sets.lua", "Queue.lua", "Swap.lua", "Toggle.lua", "Bindings.lua",
}

local available = {}
for _, f in ipairs(FILES) do
  local h = io.open("ForeverWeaponRack/" .. f)
  if h then h:close(); available[#available + 1] = f end
end

local FWR = S.LoadAddon("ForeverWeaponRack", available)
_G.FWR_TEST = FWR

------------------------------------------------------------------------------
-- Tiny test framework
------------------------------------------------------------------------------

local passed, failed = 0, 0
local current

local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    io.stderr:write(("FAIL [%s] %s\n"):format(current, msg or "?"))
  end
end
local function eq(a, b, msg)
  check(a == b, (msg or "") .. (" (got %s, want %s)"):format(tostring(a), tostring(b)))
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

_G.T = { test = test, check = check, eq = eq, S = S, FWR = FWR }

------------------------------------------------------------------------------
-- Item database used by the tests
------------------------------------------------------------------------------

S.DefineItem(100, { name = "Sword A", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7, ilvl = 60 })
S.DefineItem(101, { name = "Dagger B", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 15, ilvl = 55 })
S.DefineItem(102, { name = "Mace MH", equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, subclassID = 4, ilvl = 58 })
S.DefineItem(200, { name = "Greatsword", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 8, ilvl = 62 })
S.DefineItem(201, { name = "Staff", equipLoc = "INVTYPE_2HWEAPON", classID = 2, subclassID = 10, ilvl = 50 })
S.DefineItem(300, { name = "Shield", equipLoc = "INVTYPE_SHIELD", classID = 4, subclassID = 6, ilvl = 60 })
S.DefineItem(301, { name = "Orb", equipLoc = "INVTYPE_HOLDABLE", classID = 4, subclassID = 0, ilvl = 60 })
S.DefineItem(400, { name = "Bow", equipLoc = "INVTYPE_RANGED", classID = 2, subclassID = 2, ilvl = 60 })
S.DefineItem(401, { name = "Gun", equipLoc = "INVTYPE_RANGEDRIGHT", classID = 2, subclassID = 3, ilvl = 60 })
S.DefineItem(402, { name = "Wand", equipLoc = "INVTYPE_RANGEDRIGHT", classID = 2, subclassID = 19, ilvl = 60 })
S.DefineItem(403, { name = "Libram", equipLoc = "INVTYPE_RELIC", classID = 4, subclassID = 7, ilvl = 60 })
S.DefineItem(404, { name = "Crossbow", equipLoc = "INVTYPE_RANGEDRIGHT", classID = 2, subclassID = 18, ilvl = 60 })
S.DefineItem(500, { name = "Rough Arrow", equipLoc = "INVTYPE_AMMO", classID = 6, subclassID = 2, ilvl = 5, ammoDPS = "2.0" })
S.DefineItem(501, { name = "Jagged Arrow", equipLoc = "INVTYPE_AMMO", classID = 6, subclassID = 2, ilvl = 40, ammoDPS = "13.5" })
S.DefineItem(502, { name = "Heavy Shot", equipLoc = "INVTYPE_AMMO", classID = 6, subclassID = 3, ilvl = 15, ammoDPS = "4.5" })
S.DefineItem(600, { name = "BoE Blade", equipLoc = "INVTYPE_WEAPON", classID = 2, subclassID = 7, ilvl = 61, bindType = 2 })

-- Load the test files.
for _, name in ipairs({ "test_core", "test_identity", "test_sets", "test_swap", "test_bindings" }) do
  local h = io.open("tests/" .. name .. ".lua")
  if h then
    h:close()
    dofile("tests/" .. name .. ".lua")
  end
end

-- Data must be loaded before most tests.
FWR.Data:Load()

for _, t in ipairs(tests) do
  current = t.name
  S.Reset()
  if FWR.Identity then FWR.Identity.Invalidate() end
  if FWR.Swap and FWR.Swap.ResetForTests then FWR.Swap.ResetForTests() end
  local ok, err = xpcall(t.fn, debug.traceback)
  if not ok then
    failed = failed + 1
    io.stderr:write(("ERROR [%s] %s\n"):format(t.name, err))
  end
end

print(("%d passed, %d failed, %d errors reported by the add-on"):format(passed, failed, #S.errors))
os.exit((failed == 0 and #S.errors == 0) and 0 or 1)
